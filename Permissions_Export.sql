--Drop Table #TumDDLYetkiler 

Create Table #TumDDLYetkiler 
(
Seviye nVarChar(512) NULL,
YetkilendirmeTipi nVarChar(200) NULL,
Yetkili Sysname NULL,
YetkiliTipi nVarChar(120) NULL,
VeriTabani Sysname NULL,
Obje_Role Sysname NULL,
YetkiTipi Char(4) NULL,
YetkiAdi nVarChar(256) NULL,
YetkiDurumTip Char(1) NULL,
YetkiDurum nVarChar(120) NULL,
SCRIPT nVarChar(2000)
)

/*Database Level RoleMembers*/
Declare @DbRoles Table ( DbRole sysname, MemberName sysname, MemberSID sysname)
Insert @DbRoles Exec sp_helprolemember 
Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,Obje_Role,SCRIPT)
	Select 'DATABASE' As Seviye,'ROLEMEMBER' As YetkilendirmeTipi,MemberName As Yetkili, DB_NAME() As VeriTabani, DbRole As Obje_Role,
					 
		'USE '+DB_NAME()+' GO ALTER ROLE ['+DbRole+'] ADD MEMBER ['+MemberName+'] GO '  
	from @DbRoles 
	Where MemberName Not Like 'NT %'
	And MemberName Not In ('sa','dbo')
	--And DbRole In ('db_owner','db_accessadmin','db_securityadmin','db_ddladmin','db_backupoperator','db_datareader','db_datawriter','db_denydatareader','db_denydatawriter')
	/*Database Level Permissions*/
Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,YetkiTipi,YetkiAdi,YetkiDurumTip,YetkiDurum,SCRIPT)
select dpe.class_desc As Seviye,'DOÐRUDAN' As YetkilendirmeTipi,dpri.name As Yetkili,DB_NAME() As VeriTabani,dpe.type As YetkiTipi,dpe.permission_name As YetkiAdi,dpe.state As YetkiDurumTip,dpe.state_desc As YetkiDurum, 
	'USE '+DB_NAME()+' GO '+dpe.state_desc+' '+dpe.permission_name+' TO ['+dpri.name+'] GO '  
from sys.database_principals dpri (Nolock)
Join  sys.database_permissions dpe (Nolock) on dpri.principal_id=dpe.grantee_principal_id
	Where dpe.permission_name <>'CONNECT' 
	and dpe.class_desc In ('DATABASE')
	and dpri.name Not Like '##%'

			
/*Schema Level Permissions*/
Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,Obje_Role,YetkiTipi,YetkiAdi,YetkiDurumTip,YetkiDurum,SCRIPT)
select dpe.class_desc As Seviye,'SCHEMA' As YetkilendirmeTipi,dpri.name As Yetkili,DB_NAME() As VeriTabani,sc.name As Obje_Role,dpe.type As YetkiTipi,dpe.permission_name As YetkiAdi,dpe.state As YetkiDurumTip,dpe.state_desc As YetkiDurum,
'USE '+DB_NAME()+' GO '+
' '+dpe.state_desc+' '+dpe.permission_name+' ON SCHEMA::['+sc.name+'] TO ['+dpri.name+']
GO '
from sys.database_principals dpri (Nolock)
Join  sys.database_permissions dpe (Nolock) on dpri.principal_id=dpe.grantee_principal_id
Join sys.schemas sc (nolock) on dpe.major_id=sc.schema_id
	Where dpe.permission_name <>'CONNECT' 
	and dpe.class_desc In ('SCHEMA')

				 
/*Object Level Permissions*/
Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,Obje_Role,YetkiliTipi,YetkiTipi,YetkiAdi,YetkiDurumTip,YetkiDurum,SCRIPT)
select dpe.class_desc As Seviye,'DOÐRUDAN' As YetkilendirmeMotodu,dpri.name As Yetkili,DB_NAME() As VeriTabani,sc.name+'.'+o.name Obje_Role,dpri.type_desc As YetkiliTipi,dpe.type As YetkiTipi,dpe.permission_name As YetkiAdi,dpe.state As YetkiDurumTip,dpe.state_desc as YetkiDurum,
'USE '+DB_NAME()+' GO '+
' '+dpe.state_desc+' '+dpe.permission_name+' ON [''+sc.name+''].[''+o.name+''] TO [''+dpri.name+'']
GO '
				
from sys.database_principals dpri (Nolock)
Join  sys.database_permissions dpe (Nolock) on dpri.principal_id=dpe.grantee_principal_id
Join sys.all_objects o (Nolock) on dpe.major_id=o.object_id
Join sys.schemas sc (Nolock) on o.schema_id=sc.schema_id
	Where --dpe.permission_name <>'CONNECT' and 
	dpe.class_desc = 'OBJECT_OR_COLUMN' and o.is_ms_shipped=0
	--and dpe.permission_name Not In ('CONNECT','SELECT','INSERT','UPDATE','DELETE','EXECUTE')
					
				 

Select * from #TumDDLYetkiler where Yetkili like '%EXEC%'

