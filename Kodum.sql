SELECT 
	'Kill '+Convert(nvarchar(10),s.session_id),
   [Session ID]    = s.session_id, 
   [User Process]  = CONVERT(CHAR(1), s.is_user_process),
   [Login]         = s.login_name,   
   [Database]      = ISNULL(db_name(p.dbid), N''), 
   [Task State]    = ISNULL(t.task_state, N''), 
   [Command]       = ISNULL(r.command, N''), 
   [Application]   = ISNULL(s.program_name, N''), 
   [Wait Time (ms)]     = ISNULL(w.wait_duration_ms, 0),
   [Wait Type]     = ISNULL(w.wait_type, N''),
   [Wait Resource] = ISNULL(w.resource_description, N''), 
   [Blocked By]    = ISNULL(CONVERT (varchar, w.blocking_session_id), ''), 
   [Head Blocker]  = 
        CASE 
            -- session has an active request, is blocked, but is blocking others or session is idle but has an open tran and is blocking others
            WHEN r2.session_id IS NOT NULL AND (r.blocking_session_id = 0 OR r.session_id IS NULL) THEN '1' 
            -- session is either not blocking someone, or is blocking someone but is blocked by another party
            ELSE ''
        END, 
   [Total CPU (ms)] = s.cpu_time, 
   [Total Physical I/O (MB)]   = (s.reads + s.writes) * 8 / 1024, 
   [Memory Use (KB)]  = s.memory_usage * 8192 / 1024, 
   [Open Transactions] = ISNULL(r.open_transaction_count,0), 
   [Login Time]    = s.login_time, 
   [Last Request Start Time] = s.last_request_start_time,
   [Host Name]     = ISNULL(s.host_name, N''),
   --[Net Address]   = ISNULL(c.client_net_address, N''), 
   --[Execution Context ID] = ISNULL(t.exec_context_id, 0),
   --[Request ID] = ISNULL(r.request_id, 0),
   [Workload Group] = ISNULL(g.name, N'')
FROM sys.dm_exec_sessions (Nolock) s LEFT OUTER JOIN sys.dm_exec_connections (Nolock) c ON (s.session_id = c.session_id)
LEFT OUTER JOIN sys.dm_exec_requests (Nolock) r ON (s.session_id = r.session_id)
LEFT OUTER JOIN sys.dm_os_tasks (Nolock) t ON (r.session_id = t.session_id AND r.request_id = t.request_id)
LEFT OUTER JOIN 
(
    -- In some cases (e.g. parallel queries, also waiting for a worker), one thread can be flagged as 
    -- waiting for several different threads.  This will cause that thread to show up in multiple rows 
    -- in our grid, which we don't want.  Use ROW_NUMBER to select the longest wait for each thread, 
    -- and use it as representative of the other wait relationships this thread is involved in. 
    SELECT *, ROW_NUMBER() OVER (PARTITION BY waiting_task_address ORDER BY wait_duration_ms DESC) AS row_num
    FROM sys.dm_os_waiting_tasks (Nolock) ) w ON (t.task_address = w.waiting_task_address) AND w.row_num = 1
LEFT OUTER JOIN sys.dm_exec_requests (Nolock) r2 ON (s.session_id = r2.blocking_session_id)
LEFT OUTER JOIN sys.dm_resource_governor_workload_groups (Nolock) g ON (g.group_id = s.group_id)
LEFT OUTER JOIN sys.sysprocesses (Nolock) p ON (s.session_id = p.spid) where (task_state='RUNNABLE' or task_state='RUNNING' or task_state='SUSPENDED') and 
s.session_id>50 
and g.name<>'internal'

--and s.Last_request_start_time <dateadd(hh,-1,Getdate())
--Mashup Engine
--and w.resource_description Is Not Null
--and s.host_name like 'AXHQTOUYIISPRD'
--and s.login_name = 'supplierportaluser'
--and p.dbid =(Select dbid from sys.sysdatabases where name='Tempdb')
--and s.program_name like'IWESINTEGRATIONMIDDLEWAREGOODSIN'
--and s.session_id=11804
--and s.Last_request_start_time <'2016-02-23 22:06'--:02.467Select Getdate()-1
--and w.resource_description like '2:%'
--and w.wait_type Is Not Null--='PAGELATCH_UP'
--Select top 1000 * from Retail.Dbo.tb_DepoIslemZaman nolock Order by kayittarihi desc   11804
--and r2.session_id IS NOT NULL AND (r.blocking_session_id = 0 OR r.session_id IS NULL)
ORDER BY 
--[Total CPU (ms)] desc
s.Last_request_start_time asc
--w.wait_duration_ms desc
--dbcc inputbuffer(6852)
--kill 8821 with statusonly
--Select name from msdb.dbo.sysjobs where job_id=





/*
Resource Governor User List

select 'Kill '+Convert(Varchar,Session_id),session_id,login_name,host_name,g.group_id,g.name from sys.dm_exec_sessions s (nolock)
Inner Join sys.dm_resource_governor_workload_groups g (nolock) on  s.group_id=g.group_id
Where s.session_id>50 and g.group_id not in (1,2)
Gesource Governor total 
select g.group_id,g.name,Count(s.group_id) from sys.dm_exec_sessions s (nolock)
Inner Join sys.dm_resource_governor_workload_groups g (nolock) on  s.group_id=g.group_id
Where s.session_id>50 --and g.group_id not in (1,2)
Group by g.group_id,g.name,s.group_id
*/


/*
TOP CPU
select
  r.*,
  SUBSTRING(t.text, r.statement_start_offset / 2, 
    (CASE WHEN r.statement_end_offset = -1 
        THEN DATALENGTH(t.text)
        ELSE r.statement_end_offset END  - r.statement_start_offset) / 2)
	as sqlcmd
from sys.dm_exec_requests r
cross apply sys.dm_exec_sql_text(r.sql_handle) as t
where r.session_id > 50
  and r.status = 'running'
order by cpu_time desc;


*/