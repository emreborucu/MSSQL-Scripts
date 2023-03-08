USE [SunucuYonetim]
GO
/****** Object:  Table [dbo].[Tb_LongTransactions]    Script Date: 7.02.2023 14:14:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tb_LongTransactions](
	[Spid] [smallint] NULL,
	[Loginame] [nchar](128) NULL,
	[Hostname] [nchar](128) NULL,
	[ProgramName] [nvarchar](255) NULL,
	[Last_Batch_Time] [datetime] NULL,
	[Action_Time] [datetime] NULL,
	[Status] [nchar](30) NULL,
	[open_tran] [smallint] NULL,
	[cmd] [nchar](16) NULL,
	[Text] [text] NULL,
	[ItWasReported] [bit] NULL,
	[Transaction_Begin_Time] [datetime] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tb_LongTransactionsExceptionList]    Script Date: 7.02.2023 14:14:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
GO
CREATE TABLE [dbo].[Tb_LongTransactionsExceptionList](
	[ExType] [nvarchar](5) NULL,
	[Exception] [nchar](128) NULL,
	[ExceptionEndTime] [datetime] NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [ic_Tb_LongTransactionsexceptionList_ExType_Exception]    Script Date: 7.02.2023 14:20:29 ******/
CREATE UNIQUE CLUSTERED INDEX [ic_Tb_LongTransactionsexceptionList_ExType_Exception] ON [dbo].[Tb_LongTransactionsExceptionList]
(
	[ExType] ASC,
	[Exception] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 95) ON [PRIMARY]
GO
INSERT [dbo].[Tb_LongTransactionsExceptionList] ([ExType], [Exception], [ExceptionEndTime]) VALUES (N'LOGIN', N'LCWAIKIKI\ENVER.KARAKAS                                                                                                         ', NULL)
GO
INSERT [dbo].[Tb_LongTransactionsExceptionList] ([ExType], [Exception], [ExceptionEndTime]) VALUES (N'LOGIN', N'LCWAIKIKI\KEMAL                                                                                                                 ', NULL)
GO
INSERT [dbo].[Tb_LongTransactionsExceptionList] ([ExType], [Exception], [ExceptionEndTime]) VALUES (N'LOGIN', N'LCWAIKIKI\storagebck                                                                                                            ', NULL)
GO

--select * from Tb_LongTransactionsExceptionList

INSERT INTO Tb_LongTransactionsExceptionList (ExType, Exception) VALUES ('LOGIN','LCWAIKIKI\storagebck')
GO
INSERT INTO Tb_LongTransactionsExceptionList (ExType, Exception) VALUES ('LOGIN','LCWAIKIKI\AUTOMIC.USER')
GO
INSERT INTO Tb_LongTransactionsExceptionList (Exception, ExType)
SELECT CONCAT('LCWAIKIKI\',SUBSTRING(Exception,0,CHARINDEX('@', Exception))), ExType
FROM(
	SELECT DISTINCT(service_account) AS Exception, 'LOGIN' as ExType
	FROM sys.dm_server_services
) AS A

GO



/****** Object:  StoredProcedure [dbo].[Sp_LongTransactionsKill]    Script Date: 7.02.2023 14:14:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Proc  [dbo].[Sp_LongTransactionsKill]
As

Begin

		
		Delete from Tb_LongTransactionsExceptionList Where ExceptionEndTime<GETDATE()
		/*
		30 dk. yi gecmis olan spidler tespit edilerek temp tabloya alınıyor
		sys.dm_tran_active_transactions

		*/
		IF OBJECT_ID('tempdb..#OpenTrnList') IS NOT NULL
			DROP TABLE tempdb..#OpenTrnList
			/*
		Select 
		se.session_id,se.login_name,se.host_name, 
		Case When se.program_name Like 'SQLAgent - TSQL JobStep%'then SunucuYonetim.Dbo.GetJobNameFromProgramName(se.program_name)
		Else se.program_name  END as ProgramName
		,er.start_time As Last_Batch_Time,Getdate() As Action_Time,
		se.status,
		se.open_transaction_count,
		er.command,
		(Select  text from sys.fn_get_sql(er.sql_handle)) As Text

		into #OpenTrnList 
		from sys.dm_exec_sessions se
		join sys.dm_exec_requests er on se.session_id=er.session_id

		Where se.open_transaction_count>0  and er.start_time <DATEADD(mi, -30, GETDATE())
		*/
		Select 
		se.session_id,se.login_name,se.host_name, 
		Case When se.program_name Like 'SQLAgent - TSQL JobStep%'then SunucuYonetim.Dbo.GetJobNameFromProgramName(se.program_name)
		Else se.program_name  END as ProgramName
		--,er.start_time As Last_Batch_Time
		,se.last_request_start_time As Last_Batch_Time,
		Getdate() As Action_Time,
		se.status,
		se.open_transaction_count,
		er.command,
		(Select  text from sys.fn_get_sql(er.sql_handle)) As Text
		,Trn.Transaction_Begin_Time
		into #OpenTrnList 
		from sys.dm_exec_sessions se
		
		join
		(
		select session_id, --open_transaction_count,ta.transaction_begin_time
		Sum(open_transaction_count)  Open_Transaction_Count ,Min(ta.transaction_begin_time) Transaction_Begin_Time
		from sys.dm_tran_session_transactions ts
		Join sys.dm_tran_active_transactions ta on ts.transaction_id=ta.transaction_id
		Where ta.transaction_begin_time <DATEADD(mi, -30, GETDATE())
		Group by session_id
		)Trn on se.session_id=Trn.session_id
		Left join sys.dm_exec_requests er on se.session_id=er.session_id

		where  Trn.open_transaction_count>0   and Trn.transaction_begin_time <DATEADD(mi, -30, GETDATE())		
		/*Aşağıdaki satır romr den gelen ve iki thread çalışan sorgu için mekanizmanın hata almaması için eklendi.*/
		--and er.start_time Is Not Null
		


				Create Clustered Index ic_#OpenTrnList_Loginame_Hostname On #OpenTrnList
				(
				login_name,
				host_name
				)





		/*
		Exception listte bulunan hostname  ait kayıtlar temptablodan çıkarılıyor
		*/
		Delete From #OpenTrnList where host_name in (Select distinct Exception From Tb_LongTransactionsExceptionList Where ExType='HOST')

		/*
		Exception listte bulunan Login lere  ait kayıtlar temptablodan çıkarılıyor
		*/
		Delete From #OpenTrnList where login_name in (Select distinct Exception From Tb_LongTransactionsExceptionList Where ExType='LOGIN')


		/*
		Kill Edilecek spidler icin cursor olusturuluyor
		kill edilen her session a ait bilgiler Tb_LongTransactions tablosuna yaziliyor
		*/

		Declare @Spid Int
		Declare @KillCommand nVarChar(10)

		Declare SPID_Cursor Cursor For
			Select session_id From #OpenTrnList

			Open SPID_Cursor
		
					Fetch Next From SPID_Cursor Into @Spid
					While @@FETCH_STATUS =0
						Begin
							/*Kill etme islemi yapiliyor*/	
							Set @KillCommand= 'Kill '+Convert(nVarChar(5),@Spid)
							Exec Sp_ExecuteSQL @KillCommand
							/*Asagida sonlandirilan spid e ait bilgiler loglaniyor*/	
							Insert Into SunucuYonetim.Dbo.Tb_LongTransactions
							(Spid,Loginame,Hostname, ProgramName,Last_Batch_Time,Action_Time,Status,open_tran,cmd,Text,Transaction_Begin_Time)

							Select 
							session_id,login_name,host_name, ProgramName,Last_Batch_Time,Action_Time,status,open_transaction_count,command,Text,Transaction_Begin_Time
							from #OpenTrnList Where session_id=@Spid
				
							Fetch Next From SPID_Cursor Into @Spid
						End
			
			Close SPID_Cursor
			Deallocate SPID_Cursor
End
GO


------------------------------------------------------------

USE [msdb]
GO

/****** Object:  Job [VeriMudurlugu - LongTransactionKiller]    Script Date: 7.02.2023 14:11:59 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Veri Surecleri]    Script Date: 7.02.2023 14:11:59 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Veri Surecleri' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Veri Surecleri'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'VeriMudurlugu - LongTransactionKiller', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'BASVURU:
TemaVeriTabaniYoneticileri@LCWAIKIKI.COM;
TURKALP.ULUCUTSOY@Lcwaikiki.com;
AYKUT.ALTINISIK@Lcwaikiki.com;
GOKHAN.BELINDIR@Lcwaikiki.com;', 
		@category_name=N'Veri Surecleri', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [VeriMudurlugu - KillLongTransaction-DeleteEndedExceptions]    Script Date: 7.02.2023 14:12:00 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'VeriMudurlugu - KillLongTransaction-DeleteEndedExceptions', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Delete from Tb_LongTransactionsExceptionList Where ExceptionEndTime<GETDATE()
Go', 
		@database_name=N'SunucuYonetim', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [VeriMudurlugu - KillLongTransaction]    Script Date: 7.02.2023 14:12:00 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'VeriMudurlugu - KillLongTransaction', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec Sunucuyonetim.Dbo.Sp_LongTransactionsKill
Go', 
		@database_name=N'SunucuYonetim', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'VeriMudurlugu - KillLongTransaction', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20160801, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'7fa0612f-1b02-4618-87ce-89796a07b161'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


