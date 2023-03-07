----Db_size info
--with fs
--as
--(
--    select database_id, type, size * 8.0 / 1024 /1024 size
--    from sys.master_files
--)
--select
--    name,
--    (select sum(size) from fs where type = 0 and fs.database_id = db.database_id) DataFileSizeInGB,
--    (select sum(size) from fs where type = 1 and fs.database_id = db.database_id) LogFileSizeInGB
--from sys.databases db


--SELECT DISTINCT
--cast(SERVERPROPERTY('MachineName') as varchar(100)) AS server_name
--,cast( ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') as varchar(100)) AS instance_name
--,vs.volume_mount_point AS volume_letter
--,vs.logical_volume_name AS volume_label
--,vs.total_bytes/1024/1024/1024 AS volume_capacity_gb
--,vs.available_bytes/1024/1024/1024 AS volume_free_space_gb
--,CAST(vs.available_bytes * 100.0 / vs.total_bytes AS DECIMAL(5, 2)) AS percentage_free_space
--FROM sys.master_files AS mf
--CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs


sp_configure 'show',1
reconfigure with override
GO
sp_configure 'Ole Automation Procedures',1
reconfigure with override
GO


SET NOCOUNT ON


IF EXISTS (SELECT name FROM tempdb..sysobjects WHERE name = '##_DriveSpace')
	DROP TABLE ##_DriveSpace

IF EXISTS (SELECT name FROM tempdb..sysobjects WHERE name = '##_DriveInfo')
	DROP TABLE ##_DriveInfo


DECLARE @Result INT
	, @objFSO INT
	, @Drv INT 
	, @cDrive VARCHAR(13) 
	, @Size VARCHAR(50) 
	, @Free VARCHAR(50)
	, @Label varchar(10)

CREATE TABLE ##_DriveSpace  
	(
	  DriveLetter CHAR(1) not null
	, FreeSpace VARCHAR(10) not null

	 )

CREATE TABLE ##_DriveInfo
	(
	DriveLetter CHAR(1)
	, TotalSpace bigint
	, FreeSpace bigint
	, Label varchar(10)
	)

INSERT INTO ##_DriveSpace 
	EXEC master.dbo.xp_fixeddrives


-- Iterate through drive letters.
DECLARE  curDriveLetters CURSOR
	FOR SELECT driveletter FROM ##_DriveSpace

DECLARE @DriveLetter char(1)
	OPEN curDriveLetters

FETCH NEXT FROM curDriveLetters INTO @DriveLetter
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		 SET @cDrive = 'GetDrive("' + @DriveLetter + '")' 

			EXEC @Result = sp_OACreate 'Scripting.FileSystemObject', @objFSO OUTPUT 

				IF @Result = 0  

					EXEC @Result = sp_OAMethod @objFSO, @cDrive, @Drv OUTPUT 

				IF @Result = 0  

					EXEC @Result = sp_OAGetProperty @Drv,'TotalSize', @Size OUTPUT 

				IF @Result = 0  

					EXEC @Result = sp_OAGetProperty @Drv,'FreeSpace', @Free OUTPUT 

				IF @Result = 0  

					EXEC @Result = sp_OAGetProperty @Drv,'VolumeName', @Label OUTPUT 

				IF @Result <> 0  
 
					EXEC sp_OADestroy @Drv 
					EXEC sp_OADestroy @objFSO 

			SET @Size = (CONVERT(BIGINT,@Size) / 1048576 )

			SET @Free = (CONVERT(BIGINT,@Free) / 1048576 )

			INSERT INTO ##_DriveInfo
				VALUES (@DriveLetter, @Size, @Free, @Label)

	END
	FETCH NEXT FROM curDriveLetters INTO @DriveLetter
END

CLOSE curDriveLetters
DEALLOCATE curDriveLetters

PRINT 'Drive information for server ' + @@SERVERNAME + '.'
PRINT ''

-- Produce report.
SELECT DriveLetter
	, Label
	, FreeSpace AS [FreeSpace MB]
	, (TotalSpace - FreeSpace) AS [UsedSpace MB]
	, TotalSpace AS [TotalSpace MB]
	, ((CONVERT(NUMERIC(9,0),FreeSpace) / CONVERT(NUMERIC(9,0),TotalSpace)) * 100) AS [Percentage Free]

FROM ##_DriveInfo
ORDER BY [DriveLetter] ASC	
GO

DROP TABLE ##_DriveSpace
DROP TABLE ##_DriveInfo


exec sp_configure 'Ole Automation Procedures',0
reconfigure with override
GO
sp_configure 'show',0
reconfigure with override
GO






-------------------------------
--File space used for all files
IF object_id('tempdb.dbo.#_mdw_spaceused') IS NOT NULL
BEGIN
	DROP TABLE #_mdw_spaceused;
END

CREATE TABLE #_mdw_spaceused (
	database_id INT
	,[file_id] INT
	,space_used_mb NUMERIC(18, 2)
	,free_space_perc NUMERIC(18, 2)
	);

EXEC sp_msforeachdb N'use [?]; 
			insert into #_mdw_spaceused
			select DB_ID() database_id, f.[file_id], CONVERT(numeric(18,2),FILEPROPERTY(f.name,''SpaceUsed'')*8.0/1024.0) ''space_used_mb'',(f.size/128.0 - CONVERT(numeric(18,2),FILEPROPERTY(f.name,''SpaceUsed'')*8.0/1024.0))*100/(f.size/128.0) ''free_space_perc''
			from sys.database_files as f';

SELECT DB_NAME(f.database_id) database_name
	,f.database_id
	,f.[file_id]
	,f.type_desc
	,UPPER(left(f.physical_name, 1)) disk_drive
	,f.physical_name
	,CONVERT(NUMERIC(18, 2), fs.size_on_disk_bytes / 1024.0 / 1024.0) size_on_disk_mb
	,s.space_used_mb
	,s.free_space_perc
	,CASE f.is_percent_growth
		WHEN 0
			THEN CAST(CONVERT(INT, CONVERT(NUMERIC, f.growth) * 8 / 1024) AS VARCHAR) + ' MB'
		WHEN 1
			THEN CAST(f.growth AS VARCHAR) + '%'
		END growth
	,CASE f.is_percent_growth
		WHEN 0
			THEN CONVERT(NUMERIC(18, 2), CONVERT(NUMERIC, f.growth) * 8 / 1024)
		WHEN 1
			THEN CONVERT(NUMERIC(18, 2), (CONVERT(NUMERIC, f.size) * f.growth / 100) * 8 / 1024)
		END next_growth_mb
	,fs.num_of_reads
	,fs.num_of_bytes_read
	,fs.io_stall_read_ms
	,fs.num_of_writes
	,fs.num_of_bytes_written
	,fs.io_stall_write_ms
FROM sys.master_files f
LEFT JOIN sys.dm_io_virtual_file_stats(DEFAULT, DEFAULT) fs ON fs.database_id = f.database_id
	AND fs.[file_id] = f.[file_id]
LEFT JOIN #_mdw_spaceused s ON s.database_id = f.database_id
	AND s.[file_id] = f.[file_id]
	--where f.physical_name like 'X:\tempdb\%'
	--order by size_on_disk_mb desc

DROP TABLE #_mdw_spaceused;


