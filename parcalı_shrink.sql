USE [AXPROD]
GO
DBCC SHRINKFILE (N'AXPROD_20' , 10240)
GO
DBCC SHRINKFILE (N'AXPROD_20' , EMPTYFILE)
GO


declare @r int
set @r = 213395
while @r > 10240 
begin
       DBCC SHRINKFILE (N'AXPROD_20' , @r)
       Print 'DB ' +  Convert(Varchar(10), @r) + ' shrink edildi.'
       set @r=@r-500
end




--------------------

DECLARE @FileName sysname = N'OrderFulfilmentService';
DECLARE @TargetSize INT = (SELECT 1 + size*8./1024 FROM sys.database_files WHERE name = @FileName);
select @TargetSize
DECLARE @Factor FLOAT = .999;

SET @TargetSize *= @Factor;
select @TargetSize
 
WHILE @TargetSize > 423110
BEGIN
    SET @TargetSize *= @Factor;
    DBCC SHRINKFILE(@FileName, @TargetSize);
    DECLARE @msg VARCHAR(200) = CONCAT('Shrink file completed. Target Size: ', 
         @TargetSize, ' MB. Timestamp: ', CURRENT_TIMESTAMP);
    RAISERROR(@msg, 1, 1) WITH NOWAIT;
    WAITFOR DELAY '00:00:01';
END;


-------------------------------------------

DECLARE @FileName sysname = N'OrderFulfilmentService';
DECLARE @TargetSize INT = (SELECT 1 + size*8./1024 FROM sys.database_files WHERE name = @FileName);
DECLARE @count INT =100
DECLARE @komut NVARCHAR(1000)
DECLARE @komut2 NVARCHAR(1000)

--drop table #indexList
create table #indexList
                           (
                                  command nvarchar(4000)
                           )
 
WHILE @count > 0
BEGIN

DECLARE @TTargetSize NVARCHAR(1000)
set @TTargetSize  = convert(varchar, @TargetSize)

Set @komut='USE [master]
GO
ALTER DATABASE [OrderFulfilmentService ] MODIFY FILE ( NAME = N''OrderFulfilmentService'', SIZE ='+@TTargetSize+'MB )
GO'
--Select @komut;


set @komut2='
use [OrderFulfilmentService]
go
DBCC SHRINKFILE (N''OrderFulfilmentService'' , EMPTYFILE)
GO'

insert into #indexList VALUES (@komut+@komut2+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10))


	SET @TargetSize=@TargetSize+128;
	set @count=@count-1

    
END
select * from #indexList;

------------------------------------------

DECLARE @FileName sysname = N'OrderFulfilmentService';
DECLARE @TargetSize INT = (SELECT 1 + size*8./1024 FROM sys.database_files WHERE name = @FileName);
DECLARE @count INT =100
DECLARE @komut NVARCHAR(1000)
DECLARE @komut2 NVARCHAR(1000)

--drop table #indexList
create table #indexList
                           (
                                  command nvarchar(4000)
                           )
 
WHILE @count > 0
BEGIN

DECLARE @TTargetSize NVARCHAR(1000)
set @TTargetSize  = convert(varchar, @TargetSize)

Set @komut='USE [master]
GO
ALTER DATABASE [OrderFulfilmentService ] MODIFY FILE ( NAME = N''OrderFulfilmentService'', SIZE ='+@TTargetSize+'MB )
GO'
--Select @komut;


set @komut2='
use [OrderFulfilmentService]
go
DBCC SHRINKFILE (N''OrderFulfilmentService'' , EMPTYFILE)
GO'

insert into #indexList VALUES (@komut+@komut2+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10))


	SET @TargetSize=@TargetSize+128;
	set @count=@count-1

    
END
select * from #indexList;