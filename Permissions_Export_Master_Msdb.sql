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


/*
Tan�mlar:
Seviye :Verilen Yetkinin hangi d�zeyde ldu�unu tutar (Server,Satabase,Schema,Obje).
YetkilendirmeTipi: Yetkinin Bir Role �yeli�i mi yoksa Do�rudan verilmi� bir yetki olup olmad���n� tutar.
Yetkili: Yetkilendirilmi� kullan�c� ad� bilgisini tutar.
YetkiliTipi : Yetkilinin User m� yoksa Role m� oldu�u bilgisini Tutar.
VeriTabani : ��lemin Ger�ekle�tirildi�i veritaban� bilgisini tutar.
Obje_Role: �ye olunan role,yetki verilen schema yada yetki verilen objenin ad�n� tutar.
YetkiTipi :Yetkinin SQL server taraf�nda ki kodunu tutar.
YetkiAdi : Yetkinin A��klamas�n� tutar
YetkiDurumTip : Grant yada Deny kodunu tutar.
YetkiDurum : Grant yada Deny tan�m�n� tutar.
*/




Declare @Script nVarChar(Max),@Script2 nVarChar(Max),@Script3 nVarChar(Max),@Script4 nVarChar(Max)
Declare @Db sysname 
Declare @Say Int =1
	While (@Say<=(Select Max(database_id) from sys.databases where name In ('master','msdb')))
		Begin
			If Exists (Select name from sys.databases where database_id=@Say)
			Begin
				Set @Db=(Select name from sys.databases where database_id=@Say)
				Set @Script ='Use 	'+
				@Db+
				'
				/*Database Level RoleMembers*/
				Declare @DbRoles Table ( DbRole sysname, MemberName sysname, MemberSID sysname)
				Insert @DbRoles Exec sp_helprolemember 
				Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,Obje_Role,SCRIPT)
					Select ''DATABASE'' As Seviye,''ROLEMEMBER'' As YetkilendirmeTipi,MemberName As Yetkili, DB_NAME() As VeriTabani, DbRole As Obje_Role,
					 
					 ''USE ''+DB_NAME()+'' GO ALTER ROLE [''+DbRole+''] ADD MEMBER [''+MemberName+''] GO ''  
					from @DbRoles 
					Where MemberName Not Like ''NT %''
					And MemberName Not In (''sa'',''dbo'')
					--And DbRole In (''db_owner'',''db_accessadmin'',''db_securityadmin'',''db_ddladmin'',''db_backupoperator'',''db_datareader'',''db_datawriter'',''db_denydatareader'',''db_denydatawriter'')
					'

				
				Set @Script2 ='Use 	'+
				@Db+
				'
				/*Database Level Permissions*/
				Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,YetkiTipi,YetkiAdi,YetkiDurumTip,YetkiDurum,SCRIPT)
				select dpe.class_desc As Seviye,''DO�RUDAN'' As YetkilendirmeTipi,dpri.name As Yetkili,DB_NAME() As VeriTabani,dpe.type As YetkiTipi,dpe.permission_name As YetkiAdi,dpe.state As YetkiDurumTip,dpe.state_desc As YetkiDurum, 
				 ''USE ''+DB_NAME()+'' GO ''+dpe.state_desc+'' ''+dpe.permission_name+'' TO [''+dpri.name+''] GO ''  
				from sys.database_principals dpri (Nolock)
				Join  sys.database_permissions dpe (Nolock) on dpri.principal_id=dpe.grantee_principal_id
					Where dpe.permission_name <>''CONNECT'' 
					and dpe.class_desc In (''DATABASE'')
					and dpri.name Not Like ''##%'''

				Set @Script3 ='Use 	'+
				@Db+
				'
				/*Schema Level Permissions*/
				Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,Obje_Role,YetkiTipi,YetkiAdi,YetkiDurumTip,YetkiDurum,SCRIPT)
				select dpe.class_desc As Seviye,''SCHEMA'' As YetkilendirmeTipi,dpri.name As Yetkili,DB_NAME() As VeriTabani,sc.name As Obje_Role,dpe.type As YetkiTipi,dpe.permission_name As YetkiAdi,dpe.state As YetkiDurumTip,dpe.state_desc As YetkiDurum,
				''USE ''+DB_NAME()+'' GO ''+
				'' ''+dpe.state_desc+'' ''+dpe.permission_name+'' ON SCHEMA::[''+sc.name+''] TO [''+dpri.name+'']
				GO ''
				from sys.database_principals dpri (Nolock)
				Join  sys.database_permissions dpe (Nolock) on dpri.principal_id=dpe.grantee_principal_id
				Join sys.schemas sc (nolock) on dpe.major_id=sc.schema_id
					Where dpe.permission_name <>''CONNECT'' 
					and dpe.class_desc In (''SCHEMA'')'

				Set @Script4 ='Use 	'+
								@Db+
								'
				/*Object Level Permissions*/
				Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,VeriTabani,Obje_Role,YetkiliTipi,YetkiTipi,YetkiAdi,YetkiDurumTip,YetkiDurum,SCRIPT)
				select dpe.class_desc As Seviye,''DO�RUDAN'' As YetkilendirmeMotodu,dpri.name As Yetkili,DB_NAME() As VeriTabani,sc.name+''.''+o.name Obje_Role,dpri.type_desc As YetkiliTipi,dpe.type As YetkiTipi,dpe.permission_name As YetkiAdi,dpe.state As YetkiDurumTip,dpe.state_desc as YetkiDurum,
				''USE ''+DB_NAME()+'' GO ''+
				'' ''+dpe.state_desc+'' ''+dpe.permission_name+'' ON  [''+o.name+''] TO [''+dpri.name+'']
				GO ''
				
				from sys.database_principals dpri (Nolock)
				Join  sys.database_permissions dpe (Nolock) on dpri.principal_id=dpe.grantee_principal_id
				Join sys.all_objects o (Nolock) on dpe.major_id=o.object_id
				Join sys.schemas sc (Nolock) on o.schema_id=sc.schema_id
					Where --dpe.permission_name <>''CONNECT'' and 
					dpe.class_desc = ''OBJECT_OR_COLUMN'' and o.is_ms_shipped=0
					--and dpe.permission_name Not In (''CONNECT'',''SELECT'',''INSERT'',''UPDATE'',''DELETE'',''EXECUTE'')
					'
				
				Exec Sp_ExecuteSql @Script
				Exec Sp_ExecuteSql @Script2
				Exec Sp_ExecuteSql @Script3
				Exec Sp_ExecuteSql @Script4
					
			End
		Set @Say=@Say+1
		End



Select * from #TumDDLYetkiler 
Drop Table #TumDDLYetkiler 



