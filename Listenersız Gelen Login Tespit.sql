USE [master]
GO
/****** Object:  Table [dbo].[LoginList]    Script Date: 12/7/2022 8:38:52 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LoginList](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[login_name] [nvarchar](50) NULL,
	[program_name] [nvarchar](100) NULL,
	[host_name] [nvarchar](50) NULL,
	[local_net_address] [nvarchar](25) NULL,
	[client_net_address] [nvarchar](25) NULL,
	[connect_time] [datetime] NULL,
	[net_transport] [nvarchar](15) NULL,
	[protocol_type] [nvarchar](15) NULL,
	[encrypt_option] [nvarchar](25) NULL,
	[last_read] [datetime] NULL,
	[last_write] [datetime] NULL,
	[createdtime] [datetime] NULL,
 CONSTRAINT [PK_LoginList] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LoginList] ADD  CONSTRAINT [DF_LoginList_createdtime]  DEFAULT (getdate()) FOR [createdtime]
GO
/****** Object:  StoredProcedure [dbo].[sp_LoginList]    Script Date: 12/7/2022 8:38:52 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE  PROCEDURE [dbo].[sp_LoginList] (@local_net_address nvarchar(25))
as
begin

INSERT INTO LoginList (
 [login_name], [program_name], [host_name], [local_net_address], [client_net_address], [connect_time], [net_transport], [protocol_type], [encrypt_option], [last_read], [last_write])

select login_name, program_name, host_name, local_net_address, client_net_address, connect_time, net_transport, 
protocol_type, encrypt_option, last_read, last_write
from sys.dm_exec_sessions as s
INNER JOIN sys.dm_exec_connections as c on s.session_id=c.session_id
where 
--program_name='Microsoft SQL Server' and--login_name='DbaCollector'
 local_net_address!=@local_net_address ---Listener ile gelmeyenler anlamına geliyor'10.12.53.55'

 end
GO


USE [msdb]
GO

/****** Object:  Job [ListenersızGelenLoginTespit]    Script Date: 12/7/2022 8:39:12 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 12/7/2022 8:39:12 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'ListenersızGelenLoginTespit', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [1]    Script Date: 12/7/2022 8:39:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N' exec sp_LoginList ''10.12.53.55''', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'2', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=30, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20221207, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'085dd171-7e02-4ff5-b719-841ed484f1ce'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


