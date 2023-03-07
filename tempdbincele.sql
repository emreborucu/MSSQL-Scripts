select  SUBSTRING(Name,0,CHARINDEX('__',name)) TableName,Count(1) Cnt from tempdb.sys.tables (nolock)
Where LEN(name)>9
Group by SUBSTRING(Name,0,CHARINDEX('__',name))
order by 2 desc
go
select  Count(1) Cnt from tempdb.sys.tables (nolock)
Where LEN(name)>9


--Select name from tempdb.sys.tables (nolock)



SELECT top 5 * FROM sys.dm_db_session_space_usage
ORDER BY (user_objects_alloc_page_count + internal_objects_alloc_page_count) DESC

select sum(user_object_reserved_page_count)*8 as user_objects_kb,
    sum(internal_object_reserved_page_count)*8 as internal_objects_kb,
    sum(version_store_reserved_page_count)*8  as version_store_kb,
    sum(unallocated_extent_page_count)*8 as freespace_kb
from sys.dm_db_file_space_usage
where database_id = 2

Select top 100 * from sys.dm_db_task_space_usage








Select  cast(query_text as nVarchar(100)),Count(1) from [dbo].[TempDbConsumingQueries] where CollectDate='2022-07-25 17:00:01.933'
group by  cast(query_text as nVarchar(100))

Select  Query_Text,OutStanding_internal_objects_page_counts+OutStanding_user_objects_page_counts from [dbo].[TempDbConsumingQueries] where CollectDate='2022-07-25 17:00:01.933'
order by 2 desc


Select * from [dbo].[TempDbConsumingQueries]  x
Right Join (
		Select top 10 cast(query_text as nVarchar(100)) queryy,sUM(OutStanding_internal_objects_page_counts+OutStanding_user_objects_page_counts) PageCnt from [dbo].[TempDbConsumingQueries] where CollectDate='2022-07-25 17:00:01.933'
		group by cast(query_text as nVarchar(100))
		order by 2 desc
		)y on cast(x.query_text as nVarchar(100))=y.queryy
and CollectDate='2022-07-25 17:00:01.933'



Select CollectDate,COUNT(1) from [dbo].[TempDbConsumingQueries] (nolock) where  CollectDate>Getdate()-1
GRoup by CollectDate
Order by CollectDate

