
--running statement

select percent_complete, estimated_completion_time , (select substring(text , statement_start_offset/ 2 ,(case when statement_end_offset < 0 then 100000 else statement_end_offset end - statement_start_offset)/2)  from fn_Get_sql(sql_Handle))
from sys.dm_exec_requests where Session_id =     7415

dbcc inputbuffer(6095)
--tran locks
SELECT request_session_id,Count(1)
FROM sys.dm_tran_locks
Group by request_session_id
order by 2 desc

--Secondary Revert Status
SELECT [object_name],
[counter_name],
instance_name,
[cntr_value] FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Database Replica%'
AND [counter_name] = 'Log remaining for undo'
and cntr_value<>0


/*Object Stats*/
Select substring(text , statement_start_offset/ 2 ,(case when statement_end_offset < 0 then 100000 else statement_end_offset end - statement_start_offset)/2), * from sys.dm_exec_query_stats qs 
cross apply sys.fn_get_sql(qs.sql_handle) t
where t.text like '%Fn_DistributeNewOrders%'
OPTION (MAXDOP 8)





--locks

select distinct object_name(a.rsc_objid),a.req_spid,b.loginame
from sys.syslockinfo a (nolock) join sys.sysprocesses b (nolock) 
on a.req_spid=b.spid
where object_name(a.rsc_objid) is not null


--ugur
SELECT (SELECT TOP 1 SUBSTRING(sql_text.text,statement_start_offset / 2+1 ,   
       ((CASE WHEN statement_end_offset = -1   
         THEN (LEN(CONVERT(nvarchar(max),sql_text.text)) * 2)
         ELSE statement_end_offset END)  - statement_start_offset) / 2+1))  AS text,  
        cast(txt_query_plan.query_plan as xml) query_plan
FROM sys.dm_exec_query_stats AS Query_Stats
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sql_text
cross apply sys.dm_exec_text_query_plan (plan_handle, statement_start_offset, statement_end_offset) txt_query_plan


/*Get Execution Plan For Object*/

 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT  [ProcedureName]          =   OBJECT_NAME([ps].[object_id], [ps].[database_id]) 
       ,[ProcedureExecutes]      =   [ps].[execution_count] 
       ,[VersionOfPlan]          =   [qs].[plan_generation_num]
       ,[ExecutionsOfCurrentPlan]    =   [qs].[execution_count] 
       ,[Query Plan XML]         =   [qp].[query_plan]  

FROM       [sys].[dm_exec_procedure_stats] AS [ps]
       JOIN [sys].[dm_exec_query_stats] AS [qs] ON [ps].[plan_handle] = [qs].[plan_handle]
       CROSS APPLY [sys].[dm_exec_query_plan]([qs].[plan_handle]) AS [qp]
WHERE   [ps].[database_id] = DB_ID() 
       AND  OBJECT_NAME([ps].[object_id], [ps].[database_id])  = 'sp_OKR_AnlikStokTransfer_opt'


-- Not include common internal waits
select top 10 *
from sys.dm_os_wait_stats
where wait_type not in --remove common waits to identify worst bottlenecks
( 
 'KSOURCE_WAKEUP', 'SLEEP_BPOOL_FLUSH', 'BROKER_TASK_STOP',
'XE_TIMER_EVENT', 'XE_DISPATCHER_WAIT', 'FT_IFTS_SCHEDULER_IDLE_WAIT',   
 'SQLTRACE_BUFFER_FLUSH', 'CLR_AUTO_EVENT', 'BROKER_EVENTHANDLER',
'LAZYWRITER_SLEEP', 'BAD_PAGE_PROCESS', 'BROKER_TRANSMITTER', 
 'CHECKPOINT_QUEUE', 'DBMIRROR_EVENTS_QUEUE', 'LAZYWRITER_SLEEP', 
 'ONDEMAND_TASK_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH', 'LOGMGR_QUEUE', 
 'SLEEP_TASK', 'SQLTRACE_BUFFER_FLUSH', 'CLR_MANUAL_EVENT',
'BROKER_RECEIVE_WAITFOR', 'PREEMPTIVE_OS_GETPROCADDRESS', 
 'PREEMPTIVE_OS_AUTHENTICATIONOPS', 'BROKER_TO_FLUSH'
) 
 order by wait_time_ms desc
 

-- Running Suspended Requests with SPID and exec plans
select TOP 20
                b.query_plan as QueryPlan,
                es.session_id as SPID,
                er.database_id,
                db_name(er.database_id) AS DBName,
                a.text,
                wait_time, 
                wait_type, 
                blocking_session_id,
                er.cpu_time as CPU,
                er.logical_reads,
                * 
from
                sys.dm_exec_sessions es
                inner join sys.dm_exec_requests er on es.session_id = er.session_id
                CROSS APPLY sys.dm_exec_query_plan  (Plan_Handle) as b
                           CROSS APPLY  fn_get_sql(SQL_HANDLE) AS a
where er.status in ('running', 'suspended')
                order by er.LOGICAL_READS DESC


-- Query Stats
select    total_logical_reads as tot_log_reads, total_worker_time as tot_wrk_time, execution_count ,total_logical_reads/execution_count 'avg reads' , total_worker_time/execution_count 'avg cpu' , A.text, *
from      sys.dm_exec_query_stats
CROSS APPLY  fn_get_sql(SQL_HANDLE) AS A
order by total_worker_time desc


Select text,query_plan,* from sys.dm_exec_requests
CROSS APPLY sys.dm_exec_query_plan(plan_handle)
CROSS APPLY sys.dm_exec_sql_text(plan_handle)


-- Connections
  select  most_recent_sql_handle, count(*)  
  from                   sys.dm_exec_connections                                                        
  group by            most_recent_sql_handle
  order by            count(*) DESC

SELECT * FROM fn_get_sql(0x03001900CDC17312579E3B013D9D00000100000000000000)


WITH CONN1 as
  (
  select  count(*) AS SAYI  
  from                   sys.dm_exec_connections                                                        
  group by            most_recent_sql_handle 
     )
     SELECT SUM(SAYI) FROM CONN1
  --order by         count(*) DESC






  WITH [Waits] AS
    (SELECT
        [wait_type],
        [wait_time_ms] / 1000.0 AS [WaitS],
        ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
        [signal_wait_time_ms] / 1000.0 AS [SignalS],
        [waiting_tasks_count] AS [WaitCount],
       100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR',
        N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
        N'CHKPT', N'CLR_AUTO_EVENT',
        N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
 
        -- Maybe uncomment these four if you have mirroring issues
        N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD',
 
        N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC', N'FSAGENT',
        N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
 
        -- Maybe uncomment these six if you have AG issues
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',
        N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
 
        N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
        N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT',
        N'ONDEMAND_TASK_QUEUE',
        N'PREEMPTIVE_XE_GETTARGETSTATE',
        N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'PWAIT_DIRECTLOGCONSUMER_GETNEXT',
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', N'QDS_ASYNC_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK',
        N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE',
        N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP',
        N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
        N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT',
        N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SQLTRACE_BUFFER_FLUSH',
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS',
        N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_RECOVERY',
        N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
        N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
        N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT')
    AND [waiting_tasks_count] > 0
    )
SELECT
    MAX ([W1].[wait_type]) AS [WaitType],
    CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
    CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
    CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
    MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
    CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
    CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
    CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S],
    CAST ('https://www.sqlskills.com/help/waits/' + MAX ([W1].[wait_type]) as XML) AS [Help/Info URL]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
    ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX( [W1].[Percentage] ) < 95; -- percentage threshold
GO



--DBCC SQLPERF ("sys.dm_os_wait_stats" , CLEAR)