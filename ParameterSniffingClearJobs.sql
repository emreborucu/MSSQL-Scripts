USE [msdb]
GO

/****** Object:  Job [VeriMudurlugu - ParameterSniffingClear]    Script Date: 12.04.2023 10:35:32 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Veri Surecleri]    Script Date: 12.04.2023 10:35:32 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Veri Surecleri' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Veri Surecleri'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'VeriMudurlugu - ParameterSniffingClear', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Parameter Sniffing yaþadýðý muhtemel prosedürlere müdahale eder.', 
		@category_name=N'Veri Surecleri', 
		@owner_login_name=N'LCWAIKIKI\Kemal', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ParameterSniffing]    Script Date: 12.04.2023 10:35:32 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ParameterSniffing', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'If  OBJECT_ID(''tempdb..#PossibleParameterSniffing'') Is Not Null
	Begin
	Drop Table #PossibleParameterSniffing
	End

Declare @PossibleParameterSniffing As Table  (
Id Int Identity(1,1),
plan_handle varbinary(64),
min_worker_time Bigint,	max_worker_time Bigint,	LogicalCpuRatio Bigint,	min_logical_reads Bigint,	max_logical_reads Bigint,	LogicalReadsDevRatio Bigint,	max_elapsed_time Bigint,	
min_elapsed_time Bigint,	LogicalElapsedTimDevRatio Bigint
)



Declare @StartTime DateTime = DATEADD(MINUTE,-15,Getdate())
;WITH Execution_Detail AS (
SELECT 

        qs.plan_handle,
        min_worker_time, max_worker_time,
        ISNULL((max_worker_time - min_worker_time) / NULLIF(min_worker_time, 0), 0) AS LogicalCpuRatio, 
        min_logical_reads,max_logical_reads,
        ISNULL((max_logical_reads - min_logical_reads) / NULLIF(min_logical_reads, 0), 0) AS LogicalReadsDevRatio,
        max_elapsed_time, min_elapsed_time,
        ISNULL((max_elapsed_time - min_elapsed_time) / NULLIF(min_elapsed_time, 0), 0) AS LogicalElapsedTimDevRatio
FROM sys.dm_exec_query_stats AS QS
        --CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) AS ST
Where QS.creation_time>@StartTime and QS.last_elapsed_time>1000		)
		

Insert Into @PossibleParameterSniffing(plan_handle ,min_worker_time ,	max_worker_time ,	
LogicalCpuRatio ,	min_logical_reads ,	max_logical_reads ,	LogicalReadsDevRatio ,	max_elapsed_time ,	min_elapsed_time ,	LogicalElapsedTimDevRatio   )

 
        SELECT distinct  d.* FROM Execution_Detail d
		--LEft Join SunucuYonetim.dbo.ddl_log ddl on d.ObjectName=ddl.OBjeAdi
		WHERE  LogicalCpuRatio >=100 AND LogicalReadsDevRatio>=100 AND LogicalElapsedTimDevRatio>=100
		--and ObjectName=''sp_MagazaTransferGet''

Declare @Cnt Int =(Select MAX(Id) From @PossibleParameterSniffing)
Declare @Plan varbinary(64)

While @Cnt>0

	Begin
	Set @Plan = (Select plan_handle From @PossibleParameterSniffing where Id=@Cnt)
	DBCC FREEPROCCACHE (@plan)
	Set @Cnt=@Cnt -1
	End


', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Sc1', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20230412, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'2f8a0bd5-5c85-4b14-b966-c9b87d804414'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


