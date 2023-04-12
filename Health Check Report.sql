

USE [master]
GO


 declare @MailProfile NVARCHAR(200) = NULL,   
  @MailID NVARCHAR(2000) = NULL,  
  @Server VARCHAR(100) = @@SERVERNAME  
 
SET NOCOUNT ON;  
SET ARITHABORT ON;  
  
DECLARE @ServerName VARCHAR(100);  
SET @ServerName = ISNULL(@Server,@@SERVERNAME);  
  
/*************************************************************/  
/****************** Server Reboot Details ********************/  
/*************************************************************/  
  
CREATE TABLE #RebootDetails                                
(                                
 LastRecycle datetime,                                
 CurrentDate datetime,                                
 UpTimeInDays varchar(100)                          
)                        
Insert into #RebootDetails          
SELECT sqlserver_start_time 'Last Recycle',GetDate() 'Current Date', DATEDIFF(DD, sqlserver_start_time,GETDATE())'Up Time in Days'  
FROM sys.dm_os_sys_info;  
  

/*************************************************************/  
/****************** AlwaysOn Details *************************/  
/*************************************************************/  
--DROP TABLE #AlwaysOnDetails

CREATE TABLE #AlwaysOnDetails                                
(  
	 ID INT IDENTITY PRIMARY KEY NOT NULL,
	servername NVARCHAR(50), 
	database_name NVARCHAR(50), 
	is_failover_ready BIT, 
	is_local BIT, 
	synchronization_health_desc NVARCHAR(60), 
	database_state_desc NVARCHAR(60),
	last_sent_time DATETIME,
	last_received_time DATETIME, 
	last_hardened_time DATETIME,
	last_redone_time DATETIME, 
	log_send_queue_size BIGINT,
	log_send_rate BIGINT,
	redo_queue_size BIGINT,
	redo_rate BIGINT, 
	end_of_log_lsn NUMERIC(25,0), 
	last_commit_time DATETIME, 
	last_commit_lsn NUMERIC(25,0), 
	low_water_mark_for_ghosts BIGINT, 
	is_suspended BIT, 
	suspend_reason_desc NVARCHAR(60), 
	recovery_lsn NUMERIC(25,0), 
	truncation_lsn NUMERIC(25,0), 
	last_sent_lsn NUMERIC(25,0), 
	last_received_lsn NUMERIC(25,0),
	last_hardened_lsn NUMERIC(25,0),
	last_redone_lsn NUMERIC(25,0)
)
INSERT INTO #AlwaysOnDetails (servername,database_name,is_failover_ready , 	is_local , 	synchronization_health_desc , 	database_state_desc ,	last_sent_time ,	last_received_time , 	last_hardened_time ,	last_redone_time , 	log_send_queue_size ,
	log_send_rate ,	redo_queue_size ,	redo_rate , 	end_of_log_lsn, 	last_commit_time , 	last_commit_lsn , 	low_water_mark_for_ghosts , 	is_suspended , 	suspend_reason_desc , 	recovery_lsn , 	truncation_lsn , 	last_sent_lsn , 
	last_received_lsn ,	last_hardened_lsn ,	last_redone_lsn)
	select  
	replica_server_name as servername,
	DB_NAME(database_id) as database_name, 
	cs.is_failover_ready,
	is_local,
	synchronization_health_desc,
	database_state_desc,
	last_sent_time,
	last_received_time,
	last_hardened_time,
	last_redone_time,
	log_send_queue_size,
	log_send_rate,
	redo_queue_size,
	redo_rate,
	end_of_log_lsn,
	last_commit_time,
	last_commit_lsn,
	low_water_mark_for_ghosts ,
	is_suspended,
	suspend_reason_desc,
	rep_state.recovery_lsn,
	rep_state.truncation_lsn,
	last_sent_lsn,
	last_received_lsn,
	last_hardened_lsn,
	last_redone_lsn
	FROM sys.dm_hadr_database_replica_states as rep_state, 
	sys.availability_replicas as ar,
	sys.dm_hadr_database_replica_cluster_states as cs
	where rep_state.replica_id=ar.replica_id AND rep_state.group_id = ar.group_id 
	AND cs.replica_id = ar.replica_id AND cs.group_database_id = rep_state.group_database_id


/*************************************************************/  
/****************** LogShipping Details *************************/  
/*************************************************************/  
CREATE TABLE #LogShippingDetails                                
(
	 ID INT IDENTITY PRIMARY KEY NOT NULL,
	primary_server NVARCHAR(50),
	primary_database NVARCHAR(50),
	secondary_server NVARCHAR(50),
	secondary_database NVARCHAR(50),
	restore_threshold INT,
	last_restored_latency INT,
	last_copied_date DATETIME,
	last_restored_date DATETIME,
	last_copied_file NVARCHAR(500),
	last_restored_file NVARCHAR(500)
)
INSERT INTO #LogShippingDetails (primary_server,	primary_database ,	secondary_server ,	secondary_database ,	restore_threshold ,	last_restored_latency ,	last_copied_date ,	last_restored_date ,	last_copied_file ,	last_restored_file)
SELECT 
 primary_server,
 primary_database,
 secondary_server,
 secondary_database,
 restore_threshold,
 last_restored_latency,
 last_copied_date,
 last_restored_date,
 last_copied_file,
 last_restored_file 
FROM msdb.dbo.log_shipping_monitor_secondary



/*************************************************************/  
/****************** Current Blocking Details *****************/  
/*************************************************************/  
CREATE TABLE #BlkProcesses                                
(                                
 spid  varchar(5),                                
 Blkspid  varchar(5),                                
 PrgName  varchar(100),          
 LoginName varchar(100),                                
 ObjName  varchar(100),                                
 Query  varchar(255)                                 
)    
insert into #BlkProcesses  
SELECT s.spid, BlockingSPID = s.blocked, substring(s.program_name,1,99), SUBSTRING(s.loginame,1,99),           
   ObjectName = substring( OBJECT_NAME(objectid, s.dbid),1,99), Definition = CAST(text AS VARCHAR(255))          
FROM  sys.sysprocesses s          
CROSS APPLY sys.dm_exec_sql_text (sql_handle)          
WHERE        s.spid > 50  AND s.blocked > 0   
  
  
/*************************************************************/  
/****************** Errors audit for last 4 Days *************/  
/*************************************************************/  
  
CREATE TABLE #ErrorLogInfo_all                                
(                                
 LogDate  datetime,  
 processinfo varchar(200),                                
 LogInfo  varchar(1000)                                 
)

CREATE TABLE #ErrorLogInfo                                
(                                
 ID INT IDENTITY PRIMARY KEY NOT NULL,
 LogDate  varchar(100),  
 LogInfo  varchar(2000)                                 
)

DECLARE @A VARCHAR(10), @B VARCHAR(10);
SELECT @A = CONVERT(VARCHAR(20),GETDATE()-1,112);
SELECT @B = CONVERT(VARCHAR(20),GETDATE()+1,112);
INSERT INTO #ErrorLogInfo_all
EXEC XP_READERRORLOG 0, 1,N'', N'', @A,@B,'DESC';
/*EXEC XP_READERRORLOG 0, 1,N'', N'Failed', @A,@B,'DESC';  hepsinin gelmesi için failed kaldýrýldý*/

INSERT INTO #ErrorLogInfo (LogDate,LogInfo)
select DISTINCT ISNULL(CONVERT(VARCHAR(100),LogDate,120 ),''),LogInfo  from #ErrorLogInfo_all;

  
/***********************************************************/  
/************* Windows Disk Space Details ******************/  
/***********************************************************/  

CREATE TABLE #FreeSpace (DName CHAR(1), Free_MB BIGINT, Free_GB DECIMAL(16,2))
INSERT INTO #FreeSpace (DName,Free_MB) EXEC xp_fixeddrives;
UPDATE #FreeSpace SET Free_GB = CAST(Free_MB / 1024.00 AS DECIMAL(16,2));  
  
								--/*************************************************************/  
								--/************* SQL Server CPU Usage Details ******************/  
								--/*************************************************************/  
								--Create table #CPU(               
								--servername varchar(100),                           
								--EventTime2 datetime,                            
								--SQLProcessUtilization varchar(50),                           
								--SystemIdle varchar(50),  
								--OtherProcessUtilization varchar(50),  
								--load_date datetime                            
								--)      
								--DECLARE @ts BIGINT;  DECLARE @lastNmin TINYINT;  
								--SET @lastNmin = 240;  
								--SELECT @ts =(SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info);   
								--insert into #CPU  
								--SELECT TOP 10 * FROM (  
								--SELECT TOP(@lastNmin)  
								--  @ServerName AS 'ServerName',  
								--  DATEADD(ms,-1 *(@ts - [timestamp]),GETDATE())AS [Event_Time],   
								--  SQLProcessUtilization AS [SQLServer_CPU_Utilization],   
								--  SystemIdle AS [System_Idle_Process],   
								--  100 - SystemIdle - SQLProcessUtilization AS [Other_Process_CPU_Utilization],  
								--  GETDATE() AS 'LoadDate'  
								--FROM (SELECT record.value('(./Record/@id)[1]','int')AS record_id,   
								--record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int')AS [SystemIdle],   
								--record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]','int')AS [SQLProcessUtilization],   
								--[timestamp]        
								--FROM (SELECT[timestamp], convert(xml, record) AS [record]               
								--FROM sys.dm_os_ring_buffers               
								--WHERE ring_buffer_type =N'RING_BUFFER_SCHEDULER_MONITOR'AND record LIKE'%%')AS x )AS y   
								--ORDER BY SystemIdle ASC) d  
  
/*************************************************************/  
/************* SQL Server Memory Usage Details ***************/  
/*************************************************************/  
  
CREATE TABLE #Memory_BPool (  
BPool_Committed_MB VARCHAR(50),  
BPool_Commit_Tgt_MB VARCHAR(50),  
BPool_Visible_MB VARCHAR(50));  

/****  
  
-- SQL server 2008 / 2008 R2  
INSERT INTO #Memory_BPool    
SELECT  
     (bpool_committed*8)/1024.0 as BPool_Committed_MB,  
     (bpool_commit_target*8)/1024.0 as BPool_Commit_Tgt_MB,  
     (bpool_visible*8)/1024.0 as BPool_Visible_MB  
FROM sys.dm_os_sys_info;  
****/  

-- SQL server 2012 / 2014 / 2016  
INSERT INTO #Memory_BPool   
SELECT  
      (committed_kb)/1024.0 as BPool_Committed_MB,  
      (committed_target_kb)/1024.0 as BPool_Commit_Tgt_MB,  
      (visible_target_kb)/1024.0 as BPool_Visible_MB  
FROM  sys.dm_os_sys_info;  

CREATE TABLE #Memory_sys (  
total_physical_memory_mb VARCHAR(50),  
available_physical_memory_mb VARCHAR(50),  
total_page_file_mb VARCHAR(50),  
available_page_file_mb VARCHAR(50),  
Percentage_Used VARCHAR(50),  
system_memory_state_desc VARCHAR(50));  
  
INSERT INTO #Memory_sys  
select  
      total_physical_memory_kb/1024 AS total_physical_memory_mb,  
      available_physical_memory_kb/1024 AS available_physical_memory_mb,  
      total_page_file_kb/1024 AS total_page_file_mb,  
      available_page_file_kb/1024 AS available_page_file_mb,  
      100 - (100 * CAST(available_physical_memory_kb AS DECIMAL(18,3))/CAST(total_physical_memory_kb AS DECIMAL(18,3)))   
      AS 'Percentage_Used',  
      system_memory_state_desc  
from  sys.dm_os_sys_memory;  
  
  
CREATE TABLE #Memory_process(  
physical_memory_in_use_GB VARCHAR(50),  
locked_page_allocations_GB VARCHAR(50),  
virtual_address_space_committed_GB VARCHAR(50),  
available_commit_limit_GB VARCHAR(50),  
page_fault_count VARCHAR(50))  
  
INSERT INTO #Memory_process  
select  
      physical_memory_in_use_kb/1048576.0 AS 'Physical_Memory_In_Use(GB)',  
      locked_page_allocations_kb/1048576.0 AS 'Locked_Page_Allocations(GB)',  
      virtual_address_space_committed_kb/1048576.0 AS 'Virtual_Address_Space_Committed(GB)',  
      available_commit_limit_kb/1048576.0 AS 'Available_Commit_Limit(GB)',  
      page_fault_count as 'Page_Fault_Count'  
from  sys.dm_os_process_memory;  
  
  
CREATE TABLE #Memory(  
ID INT IDENTITY NOT NULL,
Parameter VARCHAR(200),  
Value VARCHAR(100));  
  
INSERT INTO #Memory   
SELECT 'BPool_Committed_MB',BPool_Committed_MB FROM #Memory_BPool  
UNION  
SELECT 'BPool_Commit_Tgt_MB', BPool_Commit_Tgt_MB FROM #Memory_BPool  
UNION   
SELECT 'BPool_Visible_MB', BPool_Visible_MB FROM #Memory_BPool  
UNION  
SELECT 'Total_Physical_Memory_MB',total_physical_memory_mb FROM #Memory_sys  
UNION  
SELECT 'Available_Physical_Memory_MB',available_physical_memory_mb FROM #Memory_sys
UNION  
SELECT 'Percentage_Used',Percentage_Used FROM #Memory_sys  
UNION
SELECT 'System_memory_state_desc',system_memory_state_desc FROM #Memory_sys  
UNION  
SELECT 'Total_page_file_mb',total_page_file_mb FROM #Memory_sys  
UNION  
SELECT 'Available_page_file_mb',available_page_file_mb FROM #Memory_sys  
UNION  
SELECT 'Physical_memory_in_use_GB',physical_memory_in_use_GB FROM #Memory_process  
UNION  
SELECT 'Locked_page_allocations_GB',locked_page_allocations_GB FROM #Memory_process  
UNION  
SELECT 'Virtual_Address_Space_Committed_GB',virtual_address_space_committed_GB FROM #Memory_process  
UNION  
SELECT 'Available_Commit_Limit_GB',available_commit_limit_GB FROM #Memory_process  
UNION  
SELECT 'Page_Fault_Count',page_fault_count FROM #Memory_process;  
  
  
/******************************************************************/  
/*************** Performance Counter Details **********************/  
/******************************************************************/  
  
CREATE TABLE #PerfCntr_Data(
ID INT IDENTITY NOT NULL,
Parameter VARCHAR(300),  
Value VARCHAR(100));  
  
-- Get size of SQL Server Page in bytes  
DECLARE @pg_size INT, @Instancename varchar(50)  
SELECT @pg_size = low from master..spt_values where number = 1 and type = 'E'  
  
-- Extract perfmon counters to a temporary table  
IF OBJECT_ID('tempdb..#perfmon_counters') is not null DROP TABLE #perfmon_counters  
SELECT * INTO #perfmon_counters FROM sys.dm_os_performance_counters;  
  
-- Get SQL Server instance name as it require for capturing Buffer Cache hit Ratio  
SELECT  @Instancename = LEFT([object_name], (CHARINDEX(':',[object_name])))   
FROM    #perfmon_counters   
WHERE   counter_name = 'Buffer cache hit ratio';  
  
INSERT INTO #PerfCntr_Data  
SELECT CONVERT(VARCHAR(300),Cntr) AS Parameter, CONVERT(VARCHAR(100),Value) AS Value  
FROM  
(  
SELECT  'Page Life Expectency in seconds' as Cntr,  
        cntr_value  AS Value 
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Page life expectancy'  
UNION ALL  
SELECT  'BufferCache HitRatio'  as Cntr,  
        (a.cntr_value * 1.0 / b.cntr_value) * 100.0  AS Value 
FROM    sys.dm_os_performance_counters a  
        JOIN (SELECT cntr_value,OBJECT_NAME FROM sys.dm_os_performance_counters  
              WHERE counter_name = 'Buffer cache hit ratio base' AND   
                    OBJECT_NAME = @Instancename+'Buffer Manager') b ON   
                    a.OBJECT_NAME = b.OBJECT_NAME WHERE a.counter_name = 'Buffer cache hit ratio'   
                    AND a.OBJECT_NAME = @Instancename+'Buffer Manager'
UNION ALL
SELECT  'Total Server Memory (GB)' as Cntr,  
        (cntr_value/1048576.0) AS Value   
FROM    #perfmon_counters   
WHERE   counter_name = 'Total Server Memory (KB)'  
UNION ALL  
SELECT  'Target Server Memory (GB)',   
        (cntr_value/1048576.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Target Server Memory (KB)'  
UNION ALL  
SELECT  'Connection Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Connection Memory (KB)'  
UNION ALL  
SELECT  'Lock Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Lock Memory (KB)'  
UNION ALL  
SELECT  'SQL Cache Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'SQL Cache Memory (KB)'  
UNION ALL  
SELECT  'Optimizer Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Optimizer Memory (KB) '  
UNION ALL  
SELECT  'Granted Workspace Memory (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Granted Workspace Memory (KB) '  
UNION ALL  
SELECT  'Cursor memory usage (MB)',   
        (cntr_value/1024.0)   
FROM    #perfmon_counters   
WHERE   counter_name = 'Cursor memory usage' and instance_name = '_Total'  
UNION ALL  
SELECT  'Total pages Size (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name= @Instancename+'Buffer Manager'   
        and counter_name = 'Total pages'  
UNION ALL  
SELECT  'Database pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name = @Instancename+'Buffer Manager' and counter_name = 'Database pages'  
UNION ALL  
SELECT  'Free pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name = @Instancename+'Buffer Manager'   
        and counter_name = 'Free pages'  
UNION ALL  
SELECT  'Reserved pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Reserved pages'  
UNION ALL  
SELECT  'Stolen pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Stolen pages'  
UNION ALL  
SELECT  'Cache Pages (MB)',   
        (cntr_value*@pg_size)/1048576.0   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Plan Cache'   
        and counter_name = 'Cache Pages' and instance_name = '_Total'  
UNION ALL  

SELECT  'Checkpoint pages/sec',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Checkpoint pages/sec'  
			--UNION ALL  
			--SELECT  'Lazy writes/sec',  
			--		cntr_value   
			--FROM    #perfmon_counters   
			--WHERE   object_name=@Instancename+'Buffer Manager'   
			--		and counter_name = 'Lazy writes/sec'  
UNION ALL  
SELECT  'Memory Grants Pending',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Memory Manager'   
        and counter_name = 'Memory Grants Pending'  
UNION ALL  
SELECT  'Memory Grants Outstanding',  
        cntr_value   
FROM    #perfmon_counters   
WHERE   object_name=@Instancename+'Memory Manager'   
        and counter_name = 'Memory Grants Outstanding'  
UNION ALL  
SELECT  'Process_Physical_Memory_Low',  
        process_physical_memory_low   
FROM    sys.dm_os_process_memory WITH (NOLOCK)  
UNION ALL  
SELECT  'Process_Virtual_Memory_Low',  
        process_virtual_memory_low   
FROM    sys.dm_os_process_memory WITH (NOLOCK)  
UNION ALL  
SELECT  'Max_Server_Memory (MB)' ,  
        [value_in_use]   
FROM    sys.configurations   
WHERE   [name] = 'max server memory (MB)'  
UNION ALL  
SELECT  'Min_Server_Memory (MB)' ,  
        [value_in_use]   
FROM    sys.configurations   
WHERE   [name] = 'min server memory (MB)') AS P;  
  
 
 
DECLARE @LazyWrites1 bigint;
SELECT @LazyWrites1 = cntr_value
  FROM sys.dm_os_performance_counters
  WHERE counter_name = 'Lazy writes/sec';
 
WAITFOR DELAY '00:00:10';
 
INSERT INTO #PerfCntr_Data 
SELECT 'Lazy writes/sec', (cntr_value - @LazyWrites1) / 10 
  FROM sys.dm_os_performance_counters
  WHERE counter_name = 'Lazy writes/sec';

  --------------------------------------------
DECLARE @FreeListStalls bigint;
SELECT @FreeListStalls = cntr_value
  FROM sys.dm_os_performance_counters
 WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Free list stalls/sec'  ;
 
WAITFOR DELAY '00:00:10';
 
INSERT INTO #PerfCntr_Data 
SELECT 'Free list stalls/sec', (cntr_value - @FreeListStalls) / 10 
  FROM sys.dm_os_performance_counters
 WHERE   object_name=@Instancename+'Buffer Manager'   
        and counter_name = 'Free list stalls/sec'  ;
  
/******************************************************************/  
/*************** Database Backup Report ***************************/  
/******************************************************************/  
  

CREATE TABLE #Backup_Report(  
Database_Name VARCHAR(300),  
RecoveryModel VARCHAR(50),
[State] VARCHAR(50),
Warnings VARCHAR(100),
[LastFull]  DATETIME,
[Uncompressed Size MB]  VARCHAR(50),
[LastDifferentialAfterFull]  DATETIME,
[LastLogAfterFullOrDifferential]  DATETIME,
Notes  VARCHAR(250),
LastFullFilename  VARCHAR(500),
);  
  


 
DECLARE @redDays   AS INTEGER;
DECLARE @greenDays AS INTEGER;

SET @redDays   = 7;
SET @greenDays = 1;

DECLARE @fullEveryXDays AS INTEGER;
SET @fullEveryXDays = @redDays;

;WITH backupSetCTE
AS (
   SELECT sdb.name as database_name, 
	        bs.backup_finish_date,
	        ISNULL(CASE type
		          WHEN 'L' THEN 'Log'
		          WHEN 'I' THEN 'Differential'
		          WHEN 'D' THEN 'Full Database'
		          ELSE type
	        END , 'Full Database') + 
	        CASE bs.is_copy_only WHEN 1 THEN '(COPY_ONLY)' ELSE '' END AS type,
			    bs.is_copy_only,
          bs.backup_size,
          ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_finish_date DESC) as ranker,
		  bmf.physical_device_name as backupFileName
     FROM sys.databases sdb WITH (NOLOCK)
     LEFT JOIN msdb.dbo.backupset bs WITH (NOLOCK) ON sdb.name = bs.database_name
	 LEFT JOIN msdb.dbo.backupmediafamily bmf WITH (NOLOCK) ON bs.media_set_id = bmf.media_set_id
    WHERE sdb.state_desc <> 'RESTORING'
	    AND bs.backup_finish_date > GETDATE() - 30
), latestBackupCTE AS
(
  SELECT * 
 	  FROM backupSetCTE
	 WHERE ranker = 1
)
SELECT * 
INTO #tempBackups
FROM latestBackupCTE;

INSERT INTO #Backup_Report 
SELECT 
	     db.name,
		 UPPER(LEFT(db.recovery_model_desc, 1))+LOWER(SUBSTRING(db.recovery_model_desc, 2, LEN(db.recovery_model_desc))) as RecoveryModel,
       case when db.state_desc = 'ONLINE' AND db.user_access_desc != 'MULTI_USER' THEN db.user_access_desc else db.state_desc end as [State],
       case when db.state_desc = 'OFFLINE' THEN 'Database Offline'
			when isnull(f.backup_finish_date, '2000/01/01') < getdate() - @fullEveryXDays then 'No recent full backup' 
			when isnull(f.backupFileName, '') = 'NUL' then 'Backup to NUL' 
			else '' end as Warnings,
	  f.backup_finish_date as [LastFull], 

			CASE WHEN f.backup_size / 1024 / 1024 / 1024 > 1100 THEN cast(cast(f.backup_size / 1024 / 1024 / 1024 /1024 as decimal(10,1)) as varchar(100)) + 'TB'
			WHEN f.backup_size / 1024 / 1024 > 1100 THEN cast(cast(f.backup_size / 1024 / 1024 / 1024 as decimal(10,1)) as varchar(100)) + 'GB'
			ELSE cast(cast(f.backup_size / 1024 / 1024 as decimal(10,1)) as varchar(100)) + 'MB'
			END
			
			as [Uncompressed Size MB],

	 d.backup_finish_date as [LastDifferentialAfterFull],

	   l.backup_finish_date as [LastLogAfterFullOrDifferential],
	  CASE WHEN f.is_copy_only = 1 THEN 'Last full backup was COPY_ONLY' 
	       WHEN isnull(f.backupFileName, '') = 'NUL' then 'Backup is not recoverable.' 
		     ELSE '' 
         END AS Notes,
	  f.backupFileName as LastFullFilename
   FROM #tempBackups as f
   FULL OUTER JOIN #tempBackups as d ON d.database_name = f.database_name AND d.type = 'Differential'
   FULL OUTER JOIN #tempBackups as l ON l.database_name = f.database_name AND l.type = 'Log'
  RIGHT OUTER JOIN sys.databases as db on f.database_name = db.name
  WHERE (f.type = 'Full Database' or f.type = 'Full Database(COPY_ONLY)' or f.type is null)
    AND lower(db.name) <> 'tempdb'
    AND db.state_desc <> 'RESTORING'
    AND db.is_read_only = 0
  ORDER BY 2 desc, f.database_name;

DROP TABLE #tempBackups; -- DatabaseHealth 
  
       
/*************************************************************/  
/****************** Connection Details ***********************/  
/*************************************************************/  
  
-- Number of connection on the instance grouped by hostnames  
Create table #ConnInfo(               
Hostname varchar(100),                           
NumberOfconn varchar(10)                          
)    
insert into #ConnInfo  
SELECT  Case when len(hostname)=0 Then 'Internal Process' Else hostname END,count(*)NumberOfconnections   
FROM sys.sysprocesses  
GROUP BY hostname  
  
  
/*************************************************************/  
/************** Currently Running Jobs Info ******************/  
/*************************************************************/  
--Create table #JobInfo(               
--spid varchar(10),                           
--lastwaittype varchar(100),                           
--dbname varchar(100),                           
--login_time varchar(100),                           
--status varchar(100),                           
--opentran varchar(100),                           
--hostname varchar(100),                          
--JobName varchar(100),                          
--command nvarchar(2000),  
--domain varchar(100),   
--loginname varchar(100)     
--)   
--insert into #JobInfo  
--SELECT  distinct p.spid,p.lastwaittype,DB_NAME(p.dbid),p.login_time,p.status,p.open_tran,p.hostname,J.name,  
--p.cmd,p.nt_domain,p.loginame  
--FROM master..sysprocesses p  
--INNER JOIN msdb..sysjobs j ON   
--substring(left(j.job_id,8),7,2) + substring(left(j.job_id,8),5,2) + substring(left(j.job_id,8),3,2) + substring(left(j.job_id,8),1,2) = substring(p.program_name, 32, 8)   
--Inner join msdb..sysjobactivity sj on j.job_id=sj.job_id  
--WHERE program_name like'SQLAgent - TSQL JobStep (Job %' and sj.stop_execution_date is null  
 
 
Create table #JobInfo_(               
                        
dbname varchar(100),                                                  
jobName varchar(150),                           
stepName varchar(150),                           
runDateTime varchar(100),                          
mesaj  nvarchar(max),                       
duration varchar(20)  
)   
insert into #JobInfo_
	SELECT   
			s.database_name AS [dataBase],
			j.[name] AS jobName,
			 s.step_name AS stepName,
			CONVERT(VARCHAR(100),msdb.dbo.agent_datetime(run_date, run_time), 120) as runDateTime, 
			 h.message,         
			  duration = STUFF(STUFF(REPLACE(STR(h.run_duration,7,0),' ','0'),4,0,':'),7,0,':')
	FROM     msdb.dbo.sysjobhistory h
			 INNER JOIN msdb.dbo.sysjobs j      ON h.job_id = j.job_id
			 INNER JOIN msdb.dbo.sysjobsteps s         ON j.job_id = s.job_id        AND h.step_id = s.step_id
	WHERE    h.run_status = 0 -- Failure
	AND CONVERT(DATE, msdb.dbo.agent_datetime(run_date, run_time), 101)>= CONVERT(DATE,DATEADD(DAY, -2,GETDATE()), 101)
  
/*************************************************************/  
/****************** Tempdb File Info *************************/  
/*************************************************************/  
-- tempdb file usage  
Create table #tempdbfileusage(               
servername varchar(100),                           
databasename varchar(100),                           
filename varchar(100),                           
physicalName varchar(100),                           
filesizeMB varchar(100),                           
availableSpaceMB varchar(100),                           
percentfull varchar(100)   
)   
  
DECLARE @TEMPDBSQL NVARCHAR(4000);  
SET @TEMPDBSQL = ' USE Tempdb;  
SELECT  CONVERT(VARCHAR(100), @@SERVERNAME) AS [server_name]  
                ,db.name AS [database_name]  
                ,mf.[name] AS [file_logical_name]  
                ,mf.[filename] AS[file_physical_name]  
                ,convert(FLOAT, mf.[size]/128) AS [file_size_mb]               
                ,convert(FLOAT, (mf.[size]/128 - (CAST(FILEPROPERTY(mf.[name], ''SpaceUsed'') AS int)/128))) as [available_space_mb]  
                ,convert(DECIMAL(38,2), (CAST(FILEPROPERTY(mf.[name], ''SpaceUsed'') AS int)/128.0)/(mf.[size]/128.0))*100 as [percent_full]      
FROM   tempdb.dbo.sysfiles mf  
JOIN      master..sysdatabases db  
ON         db.dbid = db_id()';  
--PRINT @TEMPDBSQL;  
insert into #tempdbfileusage  
EXEC SP_EXECUTESQL @TEMPDBSQL;  
  
  
/*************************************************************/  
/****************** Database Log Usage ***********************/  
/*************************************************************/  
CREATE TABLE #LogSpace(  
DBName VARCHAR(100),  
LogSize VARCHAR(50),  
LogSpaceUsed_Percent VARCHAR(100),   
LStatus CHAR(1));  
  
INSERT INTO #LogSpace  
EXEC ('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS;');  
  
/********************************************************************/  
/****************** Long Running Transactions ***********************/  
/********************************************************************/  
  
CREATE TABLE #OpenTran_Detail(  
 [SPID] [varchar](20) NULL,  
 [TranID] [varchar](50) NULL,  
 [User_Tran] [varchar](5) NOT NULL,  
 [DBName] [nvarchar](250) NULL,  
 [Login_Time] [varchar](60) NULL,  
 [Duration] [varchar](20) NULL,  
 [Last_Batch] [varchar](200) NULL,  
 [Status] [nvarchar](50) NULL,  
 [LoginName] [nvarchar](250) NULL,  
 [HostName] [nvarchar](250) NULL,  
 [ProgramName] [nvarchar](250) NULL,  
 [CMD] [nvarchar](50) NULL,  
 [SQL] [nvarchar](max) NULL,  
 [Blocked] [varchar](6) NULL  
);  
  
  
  
;WITH OpenTRAN AS  
(SELECT session_id,transaction_id,is_user_transaction   
FROM sys.dm_tran_session_transactions)   
INSERT INTO #OpenTran_Detail  
SELECT        
 LTRIM(RTRIM(OT.session_id)) AS 'SPID',  
 LTRIM(RTRIM(OT.transaction_id)) AS 'TranID',  
 CASE WHEN OT.is_user_transaction = '1' THEN 'Yes' ELSE 'No' END AS 'User_Tran',  
    db_name(LTRIM(RTRIM(s.dbid)))DBName,  
    LTRIM(RTRIM(login_time)) AS 'Login_Time',   
 DATEDIFF(MINUTE,login_time,GETDATE()) AS 'Duration',  
 LTRIM(RTRIM(last_batch)) AS 'Last_Batch',  
    LTRIM(RTRIM(status)) AS 'Status',  
 LTRIM(RTRIM(loginame)) AS 'LoginName',   
    LTRIM(RTRIM(hostname)) AS 'HostName',   
    LTRIM(RTRIM(program_name)) AS 'ProgramName',  
    LTRIM(RTRIM(cmd)) AS 'CMD',  
 LTRIM(RTRIM(a.text)) AS 'SQL',  
    LTRIM(RTRIM(blocked)) AS 'Blocked'  
FROM sys.sysprocesses AS s  
CROSS APPLY sys.dm_exec_sql_text(s.sql_handle)a  
INNER JOIN OpenTRAN AS OT ON OT.session_id = s.spid   
WHERE s.spid <> @@spid AND s.dbid>4;  



								--/********************************************************************/  
								--/****************** Top 20 Tables ***********************/  
								--/********************************************************************/  
  
								--	CREATE TABLE #Tab (
								--			[Name]		 NVARCHAR(128),    
								--			[Rows]		 CHAR(11),    
								--			[Reserved]	 VARCHAR(18),  
								--			[Data]		 VARCHAR(18),     
								--			[Index_size] VARCHAR(18),    
								--			[Unused]	 VARCHAR(18)); 

								--	CREATE TABLE #Table_Counts (
								--			ID			 INT IDENTITY NOT NULL PRIMARY KEY,
								--			[Table_Name]	 NVARCHAR(128),    
								--			[Row_Count]		 VARCHAR(100),    
								--			[TotalSize(MB)]	 VARCHAR(18),
								--			[TotalSize(GB)]	 VARCHAR(18),
								--			[Data(MB)]		 VARCHAR(18),     
								--			[Index_Size(MB)] VARCHAR(18), 
								--			[UnUsed(MB)]	 VARCHAR(18)); 


								--	--Capture all tables data allocation information 
								--	INSERT #Tab 
								--	EXEC sp_msForEachTable 'EXEC sp_spaceused ''?''' ;

								--	--Alter Rows column datatype to BIGINT to get the result in sorted order
								--	ALTER TABLE #Tab ALTER COLUMN [ROWS] BIGINT  ;

								--	-- Get the final result: Remove KB and convert it into MB
								--	INSERT INTO #Table_Counts ([Table_Name],[Row_Count],[TotalSize(MB)],[TotalSize(GB)],[Data(MB)],[Index_Size(MB)],[UnUsed(MB)])
								--	SELECT	TOP 20
								--		 Name,
								--		[Rows],
								--		CAST(CAST(LTRIM(RTRIM(REPLACE(Reserved,'KB',''))) AS BIGINT)/1024.0 AS DECIMAL(18,2)) AS 'TotalSize MB',
								--		CAST(CAST(LTRIM(RTRIM(REPLACE(Reserved,'KB',''))) AS BIGINT)/(1024.0*1024.0) AS DECIMAL(18,2)) AS 'TotalSize GB',
								--		CAST(CAST(LTRIM(RTRIM(REPLACE(Data,'KB',''))) AS BIGINT)/1024.0 AS DECIMAL(18,2)) AS 'Data MB',
								--		CAST(CAST(LTRIM(RTRIM(REPLACE(Index_Size,'KB',''))) AS BIGINT)/1024.0 AS DECIMAL(18,2)) AS 'Index_Size MB',
								--		CAST(CAST(LTRIM(RTRIM(REPLACE(Unused,'KB',''))) AS BIGINT)/1024.0 AS DECIMAL(18,2)) AS 'Unused MB'
								--	FROM #Tab 
								--	ORDER BY CAST(CAST(LTRIM(RTRIM(REPLACE(Reserved,'KB',''))) AS BIGINT)/1024.0 AS DECIMAL(18,2)) DESC;



--/********************************************************************/  
--/****************** Index Fragmentation Details ***********************/  
--/********************************************************************/  



--CREATE TABLE #IdxFrag_Detail(  
--[dbName]  NVARCHAR(250),
--[table]	   NVARCHAR(250),
--[indexName]    NVARCHAR(250),
--[indexType]    NVARCHAR(100),
--[avgFragmentationPercent] NVARCHAR(250),
--[pageCount] NVARCHAR(500), 
--[insertDate] DATETIME,
--LastAlterDate DATETIME,
--previousFragmentation  NVARCHAR(15)
--);

--INSERT INTO #IdxFrag_Detail
--SELECT i.[dataBase],i.[table], i.indexName, i.indexType, i.avgFragmentationPercent, i.pageCount, i.insertDate,
--c.EndTime AS LastAlterDate, 
--SUBSTRING(CAST(c.ExtendedInfo AS VARCHAR(1000)), CHARINDEX('<Fragmentation>', CAST(c.ExtendedInfo AS VARCHAR(1000))) +15, CHARINDEX('</Fragmentation>', CAST(c.ExtendedInfo AS VARCHAR(1000))) - CHARINDEX('<Fragmentation>', CAST(c.ExtendedInfo AS VARCHAR(1000))) -17 ) AS previousFragmentation 
--FROM [SunucuYonetim].[IndexMain].[CommandLog_AUTO] AS i WITH(NOLOCK)
--LEFT JOIN (
--	SELECT MAX(il.ID) AS ID,il.DatabaseName, il.IndexName 
--	FROM [master].[dbo].[CommandLog]  AS il WITH(NOLOCK)
--	WHERE il.EndTime IS NOT NULL AND il.CommandType='ALTER_INDEX'
--	GROUP BY il.DatabaseName, il.IndexName 
--) AS ilx ON ilx.IndexName = i.indexName AND ilx.DatabaseName=i.[dataBase]
--LEFT JOIN [SunucuYonetim].[IndexMain].[CommandLog_AUTO]  AS c WITH(NOLOCK) ON c.ID=ilx.ID
--WHERE i.avgFragmentationPercent>50 AND i.pageCount>250
--ORDER BY i.avgFragmentationPercent DESC




--/********************************************************************/  
--/****************** DBCC Check DB Result ***********************/  
--/********************************************************************/  
IF OBJECT_ID('tempdb..#DBCCs') IS NOT NULL
DROP TABLE #DBCCs;

IF OBJECT_ID('tempdb..#DBCCs_Result') IS NOT NULL
DROP TABLE #DBCCs_Result;

CREATE TABLE #DBCCs_Result
(
	DbName NVARCHAR(128),
	LastGoodDBCC DATETIME
)

CREATE TABLE #DBCCs
(
ID INT IDENTITY(1, 1)
PRIMARY KEY ,
ParentObject VARCHAR(255) ,
Object VARCHAR(255) ,
Field VARCHAR(255) ,
Value VARCHAR(255) ,
DbName NVARCHAR(128) NULL
)

/*Check for the last good DBCC CHECKDB date */
BEGIN
		EXEC sp_MSforeachdb N'USE [?];
		INSERT #DBCCs
		(ParentObject,
		Object,
		Field,
		Value)
		EXEC (''DBCC DBInfo() With TableResults, NO_INFOMSGS'');
		UPDATE #DBCCs SET DbName = N''?'' WHERE DbName IS NULL;';

		
		WITH DB2
		AS ( SELECT DISTINCT
		Field ,
		Value ,
		DbName
		FROM #DBCCs
		WHERE Field = 'dbi_dbccLastKnownGood'
		)

		INSERT INTO #DBCCs_Result
		SELECT 
		DB2.DbName AS DatabaseName ,
		CONVERT(DATETIME, DB2.Value, 121) AS LastGoodDBCC
		FROM DB2
		WHERE DB2.DbName NOT IN ( 'tempdb' )
END

--/********************************************************************/  
--/****************** Job Schedules List ***********************/  
--/********************************************************************/  

CREATE TABLE #JobSchedulesList (job_name NVARCHAR(300), frequency NVARCHAR(30), Days NVARCHAR(100), time NVARCHAR(60))
INSERT INTO #JobSchedulesList
SELECT sysjobs.name job_name
,case
 when freq_type = 4 then 'Daily'
end frequency
,
'every ' + cast (freq_interval as varchar(3)) + ' day(s)'  Days
,
case
 when freq_subday_type = 2 then ' every ' + cast(freq_subday_interval as varchar(7)) 
 + ' seconds' + ' starting at '
 + stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')
 when freq_subday_type = 4 then ' every ' + cast(freq_subday_interval as varchar(7)) 
 + ' minutes' + ' starting at '
 + stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')
 when freq_subday_type = 8 then ' every ' + cast(freq_subday_interval as varchar(7)) 
 + ' hours'   + ' starting at '
 + stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')
 else ' starting at ' 
 +stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')
end time
from msdb.dbo.sysjobs
inner join msdb.dbo.sysjobschedules on sysjobs.job_id = sysjobschedules.job_id
inner join msdb.dbo.sysschedules on sysjobschedules.schedule_id = sysschedules.schedule_id
where freq_type = 4 AND sysjobs.enabled=1 
--AND (sysjobs.name LIKE '%indexOptimize%' OR sysjobs.name LIKE '%databaseIntegrityCheck%')

union

-- jobs with a weekly schedule
select sysjobs.name job_name
,case
 when freq_type = 8 then 'Weekly'
end frequency
,
replace
(
 CASE WHEN freq_interval&1 = 1 THEN 'Sunday, ' ELSE '' END
+CASE WHEN freq_interval&2 = 2 THEN 'Monday, ' ELSE '' END
+CASE WHEN freq_interval&4 = 4 THEN 'Tuesday, ' ELSE '' END
+CASE WHEN freq_interval&8 = 8 THEN 'Wednesday, ' ELSE '' END
+CASE WHEN freq_interval&16 = 16 THEN 'Thursday, ' ELSE '' END
+CASE WHEN freq_interval&32 = 32 THEN 'Friday, ' ELSE '' END
+CASE WHEN freq_interval&64 = 64 THEN 'Saturday, ' ELSE '' END
,', '
,''
) Days
,
case
 when freq_subday_type = 2 then ' every ' + cast(freq_subday_interval as varchar(7)) 
 + ' seconds' + ' starting at '
 + stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':') 
 when freq_subday_type = 4 then ' every ' + cast(freq_subday_interval as varchar(7)) 
 + ' minutes' + ' starting at '
 + stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')
 when freq_subday_type = 8 then ' every ' + cast(freq_subday_interval as varchar(7)) 
 + ' hours'   + ' starting at '
 + stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')
 else ' starting at ' 
 + stuff(stuff(RIGHT(replicate('0', 6) +  cast(active_start_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':')
end time
from msdb.dbo.sysjobs
inner join msdb.dbo.sysjobschedules on sysjobs.job_id = sysjobschedules.job_id
inner join msdb.dbo.sysschedules on sysjobschedules.schedule_id = sysschedules.schedule_id
where freq_type = 8 AND sysjobs.enabled=1 
--AND (sysjobs.name LIKE '%indexOptimize%' OR sysjobs.name LIKE '%databaseIntegrityCheck%')

    
/*************************************************************/  
/****************** HTML Preparation *************************/  
/*************************************************************/  
  
DECLARE @TableHTML  VARCHAR(MAX),                                    
  @StrSubject VARCHAR(100),                                    
  @Oriserver VARCHAR(100),                                
  @Version VARCHAR(250),                                
  @Edition VARCHAR(100),                                
  @ISClustered VARCHAR(100),                                
  @SP VARCHAR(100),                                
  @ServerCollation VARCHAR(100),                                
  @SingleUser VARCHAR(5),                                
  @LicenseType VARCHAR(100),                                
  @Cnt int,           
  @URL varchar(1000),                                
  @Str varchar(1000),                                
  @NoofCriErrors varchar(3)       
  
-- Variable Assignment              
  
SELECT @Version = @@version                                
SELECT @Edition = CONVERT(VARCHAR(100), serverproperty('Edition'))                                
SET @Cnt = 0                                
IF serverproperty('IsClustered') = 0                                 
BEGIN                                
 SELECT @ISClustered = 'No'                                
END                                
ELSE        
BEGIN                                
 SELECT @ISClustered = 'YES'                                
END                                
SELECT @SP = CONVERT(VARCHAR(100), SERVERPROPERTY ('productlevel'))                                
SELECT @ServerCollation = CONVERT(VARCHAR(100), SERVERPROPERTY ('Collation'))                                 
SELECT @LicenseType = CONVERT(VARCHAR(100), SERVERPROPERTY ('LicenseType'))                                 
SELECT @SingleUser = CASE SERVERPROPERTY ('IsSingleUser')                                
      WHEN 1 THEN 'Yes'                                
      WHEN 0 THEN 'No'                                
      ELSE                                
      'null' END                                
SELECT @OriServer = CONVERT(VARCHAR(50), SERVERPROPERTY('servername'))                                  
SELECT @strSubject =CONCAT( 'Daily SQL Server Report ('+ CONVERT(VARCHAR(100), @SERVERNAME) + ') - ', CONVERT(VARCHAR, GETDATE(), 120))
   
  
SET @TableHTML =
'
'  
SET @TableHTML = @TableHTML +                                     
 '
 <div><font face="Verdana" size="2" color="#4d4d4f"><H2><bold>' + @ServerName +' Daily SQL Server Report </bold> ('+ CONVERT(VARCHAR, GETDATE(), 120) + ')</H2></font></div>                                  
 <table border="1" cellpadding="0" cellspacing="0" style="border-collapse: collapse" bordercolor="#111111" width="47%" id="AutoNumber1" height="50">                                  
 <tr>                                  
 <td width="39%" height="22" bgcolor="#dca300"><b>                           
 <font face="Verdana" size="2" color="#FFFFFF">Server Name</font></b></td>                                  
 </tr>                                  
 <tr>                                  
 <td width="39%" height="23"><font face="Verdana" size="1">' + @ServerName +'</font></td>                                  
 </tr>                                  
 </table>   <br>                              
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="2">                                
 <tr>                                
 <td align="Center" width="60%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Version</font></b></td>                                
 <td align="Center" width="17%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Edition</font></b></td>                                
 <td align="Center" width="35%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Service Pack</font></b></td>                                
 <td align="Center" width="60%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Collation</font></b></td>                                
 <td align="Center" width="93%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">LicenseType</font></b></td>                                
 <td align="Center" width="40%" bgcolor="#dca300" height="15"><b>                                
<font face="Verdana" color="#ffffff" size="1">SingleUser</font></b></td>                                
 <td align="Center" width="93%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Clustered</font></b></td>                                
 </tr>                                
 <tr>                                
 <td align="Center" width="50%" height="27"><font face="Verdana" size="1">'+@version +'</font></td>                                
 <td align="Center" width="17%" height="27"><font face="Verdana" size="1">'+@edition+'</font></td>                                
 <td align="Center" width="18%" height="27"><font face="Verdana" size="1">'+@SP+'</font></td>                                
 <td align="Center" width="17%" height="27"><font face="Verdana" size="1">'+@ServerCollation+'</font></td>                                
 <td align="Center" width="25%" height="27"><font face="Verdana" size="1">'+@LicenseType+'</font></td>                                
 <td align="Center" width="25%" height="27"><font face="Verdana" size="1">'+@SingleUser+'</font></td>                                
 <td align="Center" width="93%" height="27"><font face="Verdana" size="1">'+@ISClustered+'</font></td>                                
 </tr>'                             
                
  
 SELECT                                   
 @TableHTML = @TableHTML +                                     
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Instance last Recycled</bold></H3></font>                                  
 <table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="67%" bgColor="#ffffff" borderColorLight="#000000" border="2">                                      
 <tr>                                      
 <th align="Center" width="100" bgcolor="#dca300">                                      
  <font face="Verdana" size="1" color="#FFFFFF">Last_Recycle</font></th>                                      
 <th align="Center" width="100" bgcolor="#dca300">                                      
  <font face="Verdana" size="1" color="#FFFFFF">Current_DateTime</font></th>                                      
 <th align="Center" width="100" bgcolor="#dca300">                                   
 <font face="Verdana" size="1" color="#FFFFFF">UpTimeInDays</font></th>                                      
  </tr>'                                  
                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                       
 '<tr>                                    
 <td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), LastRecycle, 120 ), '')  +'</font></td>' +                                        
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  CurrentDate, 120 ), '')  +'</font></td>' +                                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  UpTimeInDays ), '')  +'</font></td>' +                                        
  '</tr>'   
FROM                                   
 #RebootDetails   

/***** AlwaysOn Report Start****/ 

IF ISNULL((SELECT SUM(1) FROM #AlwaysOnDetails),0)>0
BEGIN
		 SELECT                                   
		 @TableHTML = @TableHTML +                                     
		 '</table>                                  
		<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
		<font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' AlwaysOn Status</bold></H3></font>                                  
		<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="67%" bgColor="#ffffff" borderColorLight="#000000" border="2">                                      
		<tr>                                      
		<th align="LEFT" width="100" bgcolor="#dca300">                                      
		<font face="Verdana" size="1" color="#FFFFFF">ServerName</font></th>                                      
		<th align="LEFT" width="100" bgcolor="#dca300">                                      
		<font face="Verdana" size="1" color="#FFFFFF">DatabaseName</font></th>                                      
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Is_Failover Ready</font></th>  
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Is local</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Synchronization Health</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Database State</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Sent_Time</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Received_Time</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Hardened_Time</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Redone_Time</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">LogSend Queue Size</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">LogSend Rate</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Redo Queue Size</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Redo Rate</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Commit_Time</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Is Suspended</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Suspend Reason</font></th>
		</tr>' 
		
		/*<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">low_water_mark_for_ghosts</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">end_of_log_lsn</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">last_commit_lsn</font></th>
		<font face="Verdana" size="1" color="#FFFFFF">recovery_lsn</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">truncation_lsn</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">last_sent_lsn</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">last_received_lsn</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">last_hardened_lsn</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">last_redone_lsn</font></th> */
		                                   
		 

		SELECT                                   
		 @TableHTML =  @TableHTML +                                       
		 '<tr>'+
			 CASE
				WHEN ROW_NUMBER() OVER (ORDER BY ID )%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
			 ELSE  '<tr style="background-color:#fff">'
			 END 	
		+ '                                    
		 <td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), servername, 120 ), '')  +'</font></td>' +                                        
		 '<td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  database_name, 120 ), '')  +'</font></td>' +                                   
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  is_failover_ready ), '')  +'</font></td>' +                                        
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  is_local ), '')  +'</font></td>' + 
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  synchronization_health_desc ), '')  +'</font></td>' + 
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  database_state_desc ), '')  +'</font></td>' + 
		  '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_sent_time,120 ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_received_time,120 ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_hardened_time,120 ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_redone_time,120 ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  log_send_queue_size ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  log_send_rate ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  redo_queue_size ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  redo_rate ), '')  +'</font></td>' + 
		/*'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  end_of_log_lsn ), '')  +'</font></td>' + */
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_commit_time,120 ), '')  +'</font></td>' + 
		/*'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_commit_lsn ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  low_water_mark_for_ghosts ), '')  +'</font></td>' + */
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  is_suspended ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  suspend_reason_desc ), '')  +'</font></td>' + 
		/*'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  recovery_lsn ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  truncation_lsn ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_sent_lsn ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_received_lsn ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_hardened_lsn ), '')  +'</font></td>' + 
		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_redone_lsn ), '')  +'</font></td>' + */
		'</tr>'   
		FROM #AlwaysOnDetails 
END


/***** AlwaysOn Report End****/ 

/***** LogShipping Report Start****/ 

IF ISNULL((SELECT SUM(1) FROM #LogShippingDetails),0)>0
BEGIN
		 SELECT                                   
		 @TableHTML = @TableHTML +                                     
		 '</table>                                  
		<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
		<font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' LogShipping Status</bold></H3></font>                                  
		<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="67%" bgColor="#ffffff" borderColorLight="#000000" border="2">                                      
		<tr>                                      
		<th align="LEFT" width="100" bgcolor="#dca300">                                      
		<font face="Verdana" size="1" color="#FFFFFF">PrimaryServer</font></th>                                      
		<th align="LEFT" width="100" bgcolor="#dca300">                                      
		<font face="Verdana" size="1" color="#FFFFFF">PrimaryDatabase</font></th>                                      
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">SecondaryServer</font></th>  
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">SecondaryDatabase</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">RestoreThreshold</font></th> 
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">LastRestoredLatency</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Copied_Date__</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Restored_Date</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Copied_File</font></th>
		<th align="Center" width="100" bgcolor="#dca300">                                   
		<font face="Verdana" size="1" color="#FFFFFF">Last_Restored_File</font></th>
		</tr>' 
		 

		SELECT                                   
		 @TableHTML =  @TableHTML +                                       
		  '<tr>'+
			 CASE
				WHEN ROW_NUMBER() OVER (ORDER BY ID )%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
			 ELSE  '<tr style="background-color:#fff">'
			 END 	
		+ '                                    
		 <td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), primary_server ), '')  +'</font></td>' +                                        
		 '<td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  primary_database ), '')  +'</font></td>' +                                   
		 '<td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  secondary_server ), '')  +'</font></td>' +                                        
		 '<td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  secondary_database ), '')  +'</font></td>' + 
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(10),  restore_threshold ), '')  +'</font></td>' + 
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(10),  last_restored_latency ), '')  +'</font></td>' +
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_copied_date,120 ), '')  +'</font></td>' + 
		 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_restored_date,120 ), '')  +'</font></td>' + 
		 '<td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_copied_file ), '')  +'</font></td>' + 
		 '<td align="LEFT"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  last_restored_file ), '')  +'</font></td>' + 
		'</tr>'   
		FROM #LogShippingDetails 
END




/***** LogShipping Report End****/ 



/***** Free Disk Space Report ****/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Disk Space Report</bold></H3></font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="47%" border="2">                                  
   <tr>                
 <th align="Center" width="136" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Drive Name</font></th>                              
  <th align="Center" width="200" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Free Space (GB)</font></th>              
   </tr>'                                  
SELECT      
 @TableHTML =  @TableHTML +                                       
 '<tr>                                    
 <td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  DName ), '')  +'</font></td>' +
CASE WHEN Free_GB < 30 THEN 
  '<td align="Center"><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100),  Free_GB), '')  +'</font></td>' 
ELSE 
  '<td align="Center"><font face="Verdana" size="1" color="#40C211"><b>' + ISNULL(CONVERT(VARCHAR(100),  Free_GB), '')  +'</font></td>'  
END +
  '</tr>'                                  
FROM             
#FreeSpace

  
/**** Tempdb File Usage *****/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Tempdb File Usage</bold></H3></font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="2">                                  
   <tr>                
 <th align="Center" width="150" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Database</font></th>               
 <th align="Center" width="150" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">File Name</font></th>               
 <th align="Center" width="500" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Physical Name</font></th>               
 <th align="Center" width="250" bgcolor="#dca300">                                
 <font face="Verdana" size="1" color="#FFFFFF">FileSize MB</font></th>               
 <th align="Center" width="200" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Available MB</font></th>               
 <th align="Center" width="200" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Percent_full </font></th>               
   </tr>'                                  
select                                   
@TableHTML =  @TableHTML +                                     
 '<tr>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(databasename, '') + '</font></td>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(FileName, '') +'</font></td>' +                                      
 '<td align="left"><font face="Verdana" size="1">' + ISNULL(physicalName, '') +'</font></td>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(filesizeMB, '') +'</font></td>' +                                  
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(availableSpaceMB, '') +'</font></td>' +  
 CASE WHEN CONVERT(DECIMAL(10,3),percentfull) >80.00 THEN    
'<td align="Center"><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(percentfull, '') +'</b></font></td></tr>'                                               
 ELSE  
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(percentfull, '') +'</font></td></tr>' END                                
from                                   
 #tempdbfileusage       
  
  
								--/**** CPU Usage *****/  
								--SELECT                                   
								-- @TableHTML =  @TableHTML +                              
								-- '</table>                                  
								-- <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
								-- <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>CPU Usage</bold></H3></font>                                  
								-- <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="80%" border="2">                                  
								--   <tr>                
								-- <th align="Center" width="300" bgcolor="#dca300">                                    
								-- <font face="Verdana" size="1" color="#FFFFFF">System Time</font></th>               
								-- <th align="Center" width="300" bgcolor="#dca300">                                    
								-- <font face="Verdana" size="1" color="#FFFFFF">SQLProcessUtilization</font></th>               
								-- <th align="Center" width="250" bgcolor="#dca300">                                    
								-- <font face="Verdana" size="1" color="#FFFFFF">SystemIdle</font></th>               
								-- <th align="Center" width="250" bgcolor="#dca300">                                    
								-- <font face="Verdana" size="1" color="#FFFFFF">OtherProcessUtilization</font></th>               
								-- <th align="Center" width="200" bgcolor="#dca300">               
								-- <font face="Verdana" size="1" color="#FFFFFF">load DateTime</font></th>               
								--   </tr>'                                  
								--SELECT                                   
								--	@TableHTML =  @TableHTML +                                     
								--	'<tr>' +                                      
								--	'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), EventTime2 ), '')  +'</font></td>' +    
								--	'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), SQLProcessUtilization ), '')  +'</font></td>' +    
								--	'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), SystemIdle ), '')  +'</font></td>' +                              
								--	'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), OtherProcessUtilization ), '')  +'</font></td>' +                              
								--	'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), load_date ), '')  +'</font></td> </tr>'                                  
								--FROM                                   
								--	#CPU  ORDER BY EventTime2; 
  
/***** Memory Usage ****/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Memory Usage</bold></H3></font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="47%" border="2">                                  
   <tr>                
 <th align="left" width="136" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Parameter</font></th>                              
  <th align="left" width="200" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Value</font></th>              
   </tr>'                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                       
 '<tr>'+
 CASE
	WHEN ROW_NUMBER() OVER (ORDER BY Parameter)%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
 ELSE  '<tr style="background-color:#fff">'
 END 	
 +'                                    
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(200),  Parameter ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Value ), '')  +'</font></td>' +                                     
  '</tr>'                                  
FROM                                   
 #Memory ORDER BY ID;   
  
/***** Performance Counter Values ****/  
SELECT                                   
	@TableHTML =  @TableHTML +                              
	'</table>                                  
	<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
	<font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Performance Counter Data</bold></H3></font>                                  
	<table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="47%" border="2">                                  
	<tr>                
	<th align="left" width="136" bgcolor="#dca300">                                    
	<font face="Verdana" size="1" color="#FFFFFF">Performance Counter</font></th>                              
	<th align="left" width="400" bgcolor="#dca300">               
	<font face="Verdana" size="1" color="#FFFFFF">Value</font></th>  
	<th align="center" width="400" bgcolor="#dca300">               
	<font face="Verdana" size="1" color="#FFFFFF">BestPractise</font></th>  
	</tr>'                                  
SELECT                                   
	@TableHTML =  @TableHTML +                                       
	 '<tr>'+
	 CASE
		WHEN ROW_NUMBER() OVER (ORDER BY ID)%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
	 ELSE  '<tr style="background-color:#fff">'
	 END 	
	 +'                                    
	<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(300),  Parameter ), '')  +'</font></td>' + 
	
	CASE 
	WHEN Parameter='Page Life Expectency in seconds' AND CONVERT(BIGINT,Value) <300 THEN  '<td><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100),  Value ), '')  +'</b></font></td>' 
	WHEN Parameter='Page Life Expectency in seconds' AND CONVERT(BIGINT,Value) BETWEEN 300 AND 500 THEN  '<td><font face="Verdana" size="1" color="#F57F17"><b>' + ISNULL(CONVERT(VARCHAR(100),  Value ), '')  +'</b></font></td>'
	WHEN Parameter='Page Life Expectency in seconds' AND CONVERT(BIGINT,Value)> 500 THEN  '<td><font face="Verdana" size="1" color="#40C211"><b>' + ISNULL(CONVERT(VARCHAR(100),  Value ), '')  +'</b></font></td>'
	
	WHEN Parameter='BufferCache HitRatio' AND CONVERT(FLOAT,SUBSTRING(Value,1,5)) <90.00 THEN  '<td><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100),  SUBSTRING(Value,1,5) ), '')  +'</b></font></td>' 
	WHEN Parameter='BufferCache HitRatio' AND CONVERT(FLOAT,SUBSTRING(Value,1,5))>=90.00 THEN  '<td><font face="Verdana" size="1" color="#40C211"><b>' + ISNULL(CONVERT(VARCHAR(100),  SUBSTRING(Value,1,5) ), '')  +'</b></font></td>'

	WHEN Parameter='Free list stalls/sec' AND CONVERT(BIGINT,Value) <=2 THEN  '<td><font face="Verdana" size="1" color="#40C211"><b>' + ISNULL(CONVERT(VARCHAR(100), Value ), '')  +'</b></font></td>' 
	WHEN Parameter='Free list stalls/sec' AND CONVERT(BIGINT,Value)>2 THEN  '<td><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100), Value ), '')  +'</b></font></td>'

	WHEN Parameter='Lazy writes/sec' AND CONVERT(BIGINT,Value) <20 THEN  '<td><font face="Verdana" size="1" color="#40C211"><b>' + ISNULL(CONVERT(VARCHAR(100), Value ), '')  +'</b></font></td>' 
	WHEN Parameter='Lazy writes/sec' AND CONVERT(BIGINT,Value)>=20 THEN  '<td><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100), Value ), '')  +'</b></font></td>'

	WHEN Parameter='Memory Grants Pending' AND CONVERT(BIGINT,Value) =0 THEN  '<td><font face="Verdana" size="1" color="#40C211"><b>' + ISNULL(CONVERT(VARCHAR(100), Value ), '')  +'</b></font></td>' 
	WHEN Parameter='Memory Grants Pending' AND CONVERT(BIGINT,Value)>0 THEN  '<td><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100), Value ), '')  +'</b></font></td>'
	
	ELSE '<td><font face="Verdana" size="1" >' + ISNULL(CONVERT(VARCHAR(100),  Value ), '')  +'</font></td>' 
	end+
	
	CASE 
	WHEN Parameter='Page Life Expectency in seconds' THEN  '<td><font face="Verdana" size="1"> &nbsp >300</font></td>' 
	WHEN Parameter='BufferCache HitRatio' THEN  '<td><font face="Verdana" size="1">	&nbsp Avg >90%</font></td>' 
	WHEN Parameter='Free list stalls/sec' THEN  '<td><font face="Verdana" size="1">	&nbsp <2</font></td>' 
	WHEN Parameter='Lazy writes/sec' THEN  '<td><font face="Verdana" size="1">	&nbsp <20</font></td>'
	WHEN Parameter='Memory Grants Pending' THEN  '<td><font face="Verdana" size="1">&nbsp =0</font></td>'
	ELSE '<td></td>' 
	end
	+                                     
	'</tr>'                                  
FROM                                   
#PerfCntr_Data 
ORDER BY ID; 


   
/***** Database Backup Report ****/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Backup Report</bold></H3></font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0"  border="2">                                  
   <tr>                
 <th align="left" width="136" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Database_Name</font></th>                              
  <th align="left" width="50" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Recovery_Model</font></th>  
 <th align="left" width="50" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">State</font></th>
  <th align="left" width="150" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Warnings</font></th>
  <th align="left" width="100" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Last_Full</font></th>
 <th align="left" width="100" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Uncompressed_Size_MB</font></th>   
 <th align="left" width="100" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Last_Differential_After_Full</font></th>   
 <th align="left" width="100" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Last_Log_After_Full_Or_Differential</font></th>   
 <th align="left" width="100" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Notes</font></th>
 <th align="left" width="100" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Last_Full_FileName</font></th> 
  </tr>'                                  
SELECT      
 @TableHTML =  @TableHTML +                                 
  '<tr>'+
 CASE
	WHEN ROW_NUMBER() OVER (ORDER BY Database_Name)%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
 ELSE  '<tr style="background-color:#fff">'
 END 	
 +'                                     
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  [Database_Name]), '')  +'</font></td>' + 
  '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  RecoveryModel), '')  +'</font></td>' + 
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  [State]), '')  +'</font></td>' +
'<td><font face="Verdana" size="1" color="#FF0000">' + ISNULL(CONVERT(VARCHAR(100),  Warnings), '')  +'</font></td>' +  
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LastFull,120), '')  +'</font></td>' +  
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(50),  [Uncompressed Size MB]), '')  +'</font></td>' +  
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LastDifferentialAfterFull,120), '')  +'</font></td>' + 
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LastLogAfterFullOrDifferential,120), '')  +'</font></td>' + 
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Notes), '')  +'</font></td>' + 
'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LastFullFilename), '')  +'</font></td>' + 
 '</tr>'                                  
FROM             
 #Backup_Report  




 /***** DBCC Check Report ****/  --SELECT * FROM #DBCC_Check
					--SELECT                                   
					-- @TableHTML =  @TableHTML +                              
					-- '</table>                                  
					-- <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
					-- <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>DBCC Check Result Report</bold></H3></font>                                  
					-- <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="47%" border="2">                                  
					--   <tr>                
					-- <th align="left" width="136" bgcolor="#dca300">                                    
					-- <font face="Verdana" size="1" color="#FFFFFF">Database Name</font></th>                              
					--  <th align="left" width="200" bgcolor="#dca300">               
					-- <font face="Verdana" size="1" color="#FFFFFF">LastGoodDBCC</font></th>              
					--   </tr>'                                  
					--SELECT      
					-- @TableHTML =  @TableHTML +                                       
					-- '<tr>                                    
					-- <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  DBName ), '')  +'</font></td>' +                                        
					-- '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LastGoodDBCC), '')  +'</font></td>' +                                     
					--  '</tr>'                                  
					--FROM             
					-- #DBCCs_Result
					-- ORDER BY CASE WHEN ISNULL(CONVERT(VARCHAR(100),  LastGoodDBCC), '')='Never' THEN '1900-01-01 00:00:00.000' ELSE LastGoodDBCC END;

			 --------------
			 SELECT                                   
			 @TableHTML =  @TableHTML +                              
			 '</table>                                  
			 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
			 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' DBCC Check Result Report</bold></H3></font>                                  
			 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="50%" border="2">                                  
			   <tr>                
			 <th align="left" width="136" bgcolor="#dca300">                                    
			 <font face="Verdana" size="1" color="#FFFFFF">Performance_Counter</font></th>                              
			  <th align="left" width="500" bgcolor="#dca300">               
			 <font face="Verdana" size="1" color="#FFFFFF">LastGoodDBCC_DateTime</font></th>              
			   </tr>'                                  
			SELECT                                   
			 @TableHTML =  @TableHTML +                                       
			   '<tr>'+
				CASE
				WHEN ROW_NUMBER() OVER (ORDER BY DBName)%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
				ELSE  '<tr style="background-color:#fff">'
				END 	
				+'                                      
			 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(300),  DBName ), '')  +'</font></td>' +      
			 
			 CASE 
				WHEN (DATEDIFF(DAY, CAST(LastGoodDBCC AS DATE), CAST(GETDATE() AS DATE))>6) OR LastGoodDBCC IS NULL OR LastGoodDBCC='1900-01-01 00:00:00.000' THEN  '<td><font face="Verdana" size="1" color="#FF0000">' + ISNULL(CONVERT(VARCHAR(100),  LastGoodDBCC,120 ), '')  +'</font></td>'
				ELSE '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LastGoodDBCC,120 ), '')  +'</font></td>' 
			 END+                                     
			  '</tr>'                                  
			FROM                                   
			 #DBCCs_Result
			 --ORDER BY CASE WHEN ISNULL(CONVERT(VARCHAR(100),  LastGoodDBCC), '')='Never' THEN '1900-01-01 00:00:00.000' ELSE LastGoodDBCC END;  
			-- ---------------
  




 /****** Connection Information *****/  
  
 SELECT                                   
 @TableHTML = @TableHTML +                                     
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Total Number of Database Connections</bold></H3></font>                                  
 <table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="47%" bgColor="#ffffff" borderColorLight="#000000" border="2">                                      
 <tr>                                      
 <th align="Center" width="136" bgcolor="#dca300">                                      
  <font face="Verdana" size="1" color="#FFFFFF">Host Name</font></th>                                      
 <th align="Center" width="200" bgcolor="#dca300">                                      
  <font face="Verdana" size="1" color="#FFFFFF">Total</font></th>                                      
  </tr>'                                  
                         
SELECT                                   
 @TableHTML =  @TableHTML +                          
 '<tr>           
<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), Hostname ), '')  +'</font></td>' +                               
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), NumberOfconn  ), '')  +'</font></td>' +                                   
  '</tr>'                                  
FROM                                   
 #ConnInfo                                  
      
/***** Log Space Usage ****/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Database Log Space Usage</bold></H3></font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="47%" border="2">                                  
   <tr>                
 <th align="left" width="136" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Database_Name</font></th>                              
  <th align="left" width="200" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Log_Space_Used</font></th>                              
  <th align="left" width="200" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">Log_Usage_%</font></th>              
   </tr>'                                  
SELECT                                   
 @TableHTML =  @TableHTML +                                       
 '<tr>'+
	 CASE
		WHEN ROW_NUMBER() OVER (ORDER BY DBName)%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
	 ELSE  '<tr style="background-color:#fff">'
	 END 	
	 +'                                    
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  DBName ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LogSize ), '')  +'</font></td>' +   
 CASE WHEN CONVERT(DECIMAL(10,3),LogSpaceUsed_Percent) >80.00 THEN  
  '<td><font face="Verdana" size="1" color="#FF0000"><b>' + ISNULL(CONVERT(VARCHAR(100),  LogSpaceUsed_Percent ), '')  +'</b></font></td>'  
 ELSE  
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LogSpaceUsed_Percent ), '')  +'</font></td>'   
 END +                                     
  '</tr>'                               
FROM                                   
 #LogSpace   

	--/**** INDEX ANALYSIS*****/  
	--	SELECT                                   
	--		@TableHTML =  @TableHTML +                              
	--		'</table>                                  
	--		<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
	--		<font face="Verdana" size="4" color="#4d4d4f"><H3><bold>Index Analysis (Fragmentation>50 and PageCount>250)</bold></H3></font>                                  
	--		<table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="2">                                  
	--		<tr>                
	--		<th align="Center" width="250" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Database Name</font></th>  
	--		<th align="Center" width="250" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Table</font></th>                
	--		<th align="Center" width="300" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Index Name</font></th>               
	--		<th align="Center" width="250" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Index Type</font></th>               
	--	<th align="Center" width="250" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Fragmentation%</font></th>               
	--	<th align="Center" width="200" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Page Count</font></th>               
	--	<th align="Center" width="200" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Insert_Date</font></th>     
	--		<th align="Center" width="300" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Last_Alter_Date</font></th>               
	--	<th align="Center" width="300" bgcolor="#dca300">                                    
	--		<font face="Verdana" size="1" color="#FFFFFF">Previous Frag.%</font></th>
	--		</tr>' 
			
	--	select                                   
	--	@TableHTML =  @TableHTML +                                     
	--		 '<tr>'+
	--		 CASE
	--			WHEN ROW_NUMBER() OVER (ORDER BY [avgFragmentationPercent] DESC, [dbName],[table],[indexName])%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
	--		 ELSE  '<tr style="background-color:#fff">'
	--		 END 	
	--		 +                                     
	--		'<td align="LEFT"><font face="Verdana" size="1">' + ISNULL([dbName], '') + '</font></td>' +   
	--		'<td align="LEFT"><font face="Verdana" size="1">' + ISNULL([table], '') + '</font></td>' +                                      
	--		'<td align="LEFT"><font face="Verdana" size="1">' + ISNULL([indexName], '') +'</font></td>' +                                      
	--		'<td align="LEFT"><font face="Verdana" size="1">' + ISNULL([indexType], '') +'</font></td>' +  
			
	--		CASE 
	--			WHEN CONVERT(DECIMAL(10,3),[avgFragmentationPercent])>=50  then '<td align="Center"><font face="Verdana" size="1"  color="#FF0000">' + ISNULL([avgFragmentationPercent], '') +'</font></td>' 
	--		ELSE '<td align="Center"><font face="Verdana" size="1">' + ISNULL([avgFragmentationPercent], '') +'</font></td>'
	--		END	                                     
	--		 +                   
	--		'<td align="Center"><font face="Verdana" size="1">' + ISNULL([pageCount], '') +'</font></td>' +    
	--		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),[insertDate],120), '') +'</font></td>'+
			
	--		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),LastAlterDate,120), '') +'</font></td>'+
	--		'<td align="Center"><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),previousFragmentation), '') +'</font></td>'+
	--		'</tr>'                 
	--	from                                   
	--		#IdxFrag_Detail  ORDER BY [avgFragmentationPercent] DESC;       


/*** Job Schedules List *****/ 
SELECT                                   
			@TableHTML =  @TableHTML +                              
			'</table>                                  
			<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
			<font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Job Schedules List</bold></H3></font>                                  
			<table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="2">                                  
			<tr>                
			<th align="Center" width="400" bgcolor="#dca300">                                    
			<font face="Verdana" size="1" color="#FFFFFF">Job Name</font></th>  
			<th align="Center" width="200" bgcolor="#dca300">                                    
			<font face="Verdana" size="1" color="#FFFFFF">Frequency</font></th>                
			<th align="Center" width="200" bgcolor="#dca300">                                    
			<font face="Verdana" size="1" color="#FFFFFF">Days</font></th>               
			<th align="Center" width="250" bgcolor="#dca300">                                    
			<font face="Verdana" size="1" color="#FFFFFF">Time</font></th>               
			</tr>' 


			SELECT                                   
			@TableHTML =  @TableHTML +                                     
			'<tr>'+
			 CASE
				WHEN ROW_NUMBER() OVER (ORDER BY job_name )%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
			 ELSE  '<tr style="background-color:#fff">'
			 END 	
		+ ' <td align="LEFT"><font face="Verdana" size="1">' + ISNULL(job_name, '') + '</font></td>' +                                      
			'<td align="Center"><font face="Verdana" size="1">' + ISNULL(frequency, '') +'</font></td>' +                                      
			'<td align="Center"><font face="Verdana" size="1">' + ISNULL([Days], '') +'</font></td>' +                                      
			'<td align="Center"><font face="Verdana" size="1">' + ISNULL([time], '') +'</font></td></tr>'                                  
			from  #JobSchedulesList     
  
/******** Job Info *******/  
SELECT                                   
 @TableHTML = @TableHTML +                                   
 '</table>                          
 <p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' SQL Agent Job Status (Failure)</bold></H3></font>' +                                      
 '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" cellspacing="6"  bgColor="#ffffff" borderColorLight="#000000" border="1" with="100%">                                    
 <tr>                                    
 <th align="left" width="200" height="5" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Database</font></th>   
 <th align="left" width="70" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Job Name</font></th>                                    
 <th align="left" width="85" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Step Name</font></th>                                    
 <th align="left" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">RunDateTime</font></th>                                    
 <th align="left" width="600" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Message</font></th>                                    
 <th align="left" width="136" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Duration</font></th>      
                               
 </tr>'                                    
                                  
SELECT                                   
 @TableHTML = ISNULL(CONVERT(VARCHAR(MAX), @TableHTML), 'No Job Running') + '<tr>' +                                      
 CASE
	WHEN ROW_NUMBER() OVER (ORDER BY dbname,jobName, runDateTime)%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
 ELSE  '<tr style="background-color:#fff">'
 END 
	+'
	<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), dbname),'') + '</font></td>' +                                                    
	'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(150), jobName),'') +'</font></td>' +     
	'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(150), stepName),'') +'</font></td>' +     
	'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100), runDateTime,120),'') +'</font></td>' +     
    '<td><font face="Verdana" size="0.5">' + ISNULL(CONVERT(VARCHAR(MAX), mesaj),'') +'</font></td>'+
	'<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(20), duration),'') +'</font></td></tr>'      
FROM                                   
 #JobInfo_  
  
   
   
 /****** Blocking Information ****/  
  
 SELECT                                   
 @TableHTML = @TableHTML +                  
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Blocking Process Information</bold></H3></font>                            
 <table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="2">                                      
 <tr>     
  <th align="Center" width="50" bgcolor="#dca300">                                      
  <font face="Verdana" size="1" color="#FFFFFF">ServerName</font></th>                                     
 <th align="Center" width="50" bgcolor="#dca300">                                      
  <font face="Verdana" size="1" color="#FFFFFF">SpID</font></th>                                      
 <th align="Center" width="50" bgcolor="#dca300">                                      
  <font face="Verdana" size="1" color="#FFFFFF">BlockingSPID</font></th>       <th align="Center" width="50" bgcolor="#dca300">                                   
 <font face="Verdana" size="1" color="#FFFFFF">ProgramName</font></th>                                      
 <th align="Center" width="50" bgcolor="#dca300">                                      
 <font face="Verdana" size="1" color="#FFFFFF">LoginName</font></th>                  
 <th align="Center" width="40" bgcolor="#dca300">                                      
 <font face="Verdana" size="1" color="#FFFFFF">ObjName</font></th>                        
 <th align="left" width="150" bgcolor="#dca300">                                      
 <font face="Verdana" size="1" color="#FFFFFF">Query</font></th>                                      
 </tr>'             
                                 
SELECT                                   
 @TableHTML =  @TableHTML +                                 
 '<tr>    
 <td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  @SERVERNAME ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  spid ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Blkspid ), '')  +'</font></td>' +                                   
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  PrgName ), '')  +'</font></td>' +                                        
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  LoginName ), '')  +'</font></td>' +                                     
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  ObjName ), '')  +'</font></td>' +                                     
 '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(VARCHAR(100),  Query ), '')  +'</font></td>' +                                     
  '</tr>'                       
FROM                                   
 #BlkProcesses                 
ORDER BY     spid    
  
  
/**** Long running Transactions*****/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                                  
 <p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>                                  
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' Long Running Transactions</bold></H3></font>                                  
 <table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="2">                                  
   <tr>                
 <th align="Center" width="300" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">SPID</font></th>               
 <th align="Center" width="300" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">TranID</font></th>               
 <th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">User_Tran</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">DB_Name</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Login_Time</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Duration</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Last_Batch</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Status</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">LoginName</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Host_Name</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">PrgName</font></th>               
<th align="Center" width="250" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">CMD</font></th>               
 <th align="Center" width="200" bgcolor="#dca300">               
 <font face="Verdana" size="1" color="#FFFFFF">SQL</font></th>               
 <th align="Center" width="200" bgcolor="#dca300">                                    
 <font face="Verdana" size="1" color="#FFFFFF">Blocked </font></th>               
   </tr>'                                  
select                                   
@TableHTML =  @TableHTML +                                     
 '<tr>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(SPID, '') + '</font></td>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(TranID, '') +'</font></td>' +                                      
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(User_Tran, '') +'</font></td>' +                                      
  '<td align="Center"><font face="Verdana" size="1">' + ISNULL(DBName, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(Login_Time, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(Duration, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(Last_Batch, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL([Status], '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(LoginName, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(HostName, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(ProgramName, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(CMD, '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL([SQL], '') +'</font></td>' +                   
 '<td align="Center"><font face="Verdana" size="1">' + ISNULL(Blocked, '') +'</font></td></tr>'                                 
from                                   
 #OpenTran_Detail       





/*** Error Log *****/  
SELECT                                   
 @TableHTML =  @TableHTML +                              
 '</table>                   
 <p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>                                
 <font face="Verdana" size="4" color="#4d4d4f"><H3><bold>' + @ServerName +' SQL ErrorLog</bold></H3></font>' +                                    
 '                               
 <table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="47%" bgColor="#ffffff" borderColorLight="#000000" border="2">                                  
 <tr>                                
 <td width="25%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Error_Log_DateTime</font></b></td>                     
 <td width="75%" bgcolor="#dca300" height="15"><b>                                
 <font face="Verdana" color="#ffffff" size="1">Error Message</font></b></td>                                
 </tr>';                                

SELECT    TOP 5000                             
 @TableHTML = @TableHTML + 
'<tr>'+
			 CASE
				WHEN ROW_NUMBER() OVER (ORDER BY ID )%2 = 0 THEN '<tr style="background-color:#FFF9C4">'
			 ELSE  '<tr style="background-color:#fff">'
			 END 	
 + '                               
 <td width="20%" height="27"><font face="Verdana" size="1">'+ ISNULL(CONVERT(VARCHAR(100),LogDate,120 ),'') +'</font></td>                                
 <td width="80%" height="27"><font face="Verdana" size="1">'+ISNULL(CONVERT(VARCHAR(2000),LogInfo ),'')+'</font></td>                                
 </tr>'                                
FROM  #ErrorLogInfo   
ORDER BY  LogDate DESC;
   
 /****** End to HTML Formatting  ***/    
SELECT                              
 @TableHTML =  @TableHTML +  '</table>' +                                  
 '<p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>                                  
 <p>&nbsp;</p>'    
        
IF (@MailProfile IS NOT NULL AND @MailID IS NOT NULL)
BEGIN
	EXEC msdb.dbo.sp_send_dbmail 
		 @profile_name = @MailProfile, 
		 @recipients = @MailID, 
		 @subject = @strSubject, 
		 @body = @TableHTML, 
		 @body_format = 'HTML';
END

SELECT @TableHTML "HC_Report";  

  
DROP TABLE  #RebootDetails  
DROP TABLE	#FreeSpace;
DROP TABLE  #BlkProcesses  
DROP TABLE  #ErrorLogInfo  
--DROP TABLE  #CPU  
DROP TABLE  #Memory_BPool;  
DROP TABLE  #Memory_sys;  
DROP TABLE  #Memory_process;  
DROP TABLE  #Memory;  
DROP TABLE  #perfmon_counters;  
DROP TABLE  #PerfCntr_Data;  
DROP TABLE  #Backup_Report;  
DROP TABLE  #ConnInfo;  
DROP TABLE  #JobInfo_;  
DROP TABLE  #tempdbfileusage;  
DROP TABLE  #LogSpace;  
DROP TABLE  #OpenTran_Detail; 
DROP TABLE  #DBCCs_Result
DROP TABLE #DBCCs
DROP TABLE #JobSchedulesList  
DROP TABLE #AlwaysOnDetails
DROP TABLE #LogShippingDetails
DROP TABLE #ErrorLogInfo_all
SET NOCOUNT OFF;  
SET ARITHABORT OFF;  



