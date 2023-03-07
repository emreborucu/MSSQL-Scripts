--DROP Table #TumDDLYetkiler 

Create Table #TumDDLYetkiler 
(
Seviye nVarChar(512) NULL,
YetkilendirmeTipi nVarChar(200) NULL,
Yetkili Sysname NULL,
--YetkiliTipi nVarChar(120) NULL,
--VeriTabani Sysname NULL,
Obje_Role Sysname NULL,
--YetkiTipi Char(4) NULL,
YetkiAdi nVarChar(256) NULL,
--YetkiDurumTip Char(1) NULL,
YetkiDurum nVarChar(120) NULL,
CreateScript nVarChar(2000)
)


/*
Tanýmlar:
Seviye :Verilen Yetkinin hangi düzeyde lduðunu tutar (Server,Satabase,Schema,Obje).
YetkilendirmeTipi: Yetkinin Bir Role Üyeliði mi yoksa Doðrudan verilmiþ bir yetki olup olmadýðýný tutar.
Yetkili: Yetkilendirilmiþ kullanýcý adý bilgisini tutar.
YetkiliTipi : Yetkilinin User mý yoksa Role mü olduðu bilgisini Tutar.
VeriTabani : Ýþlemin Gerçekleþtirildiði veritabaný bilgisini tutar.
Obje_Role: Üye olunan role,yetki verilen schema yada yetki verilen objenin adýný tutar.
YetkiTipi :Yetkinin SQL server tarafýnda ki kodunu tutar.
YetkiAdi : Yetkinin Açýklamasýný tutar
YetkiDurumTip : Grant yada Deny kodunu tutar.
YetkiDurum : Grant yada Deny tanýmýný tutar.
*/

/*Server Level Permissions*/
Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,YetkiAdi,YetkiDurum,CreateScript)
Select spe.class_desc As Seviye,'DOÐRUDAN' As YetkilendirmeTipi,spri.name As Yetkili,spe.permission_name As YetkiAdi,spe.state_desc As YetkiDurum ,
'GRANT ['+spe.permission_name+'] to ['+spri.name+'] '
from sys.server_principals spri (nolock)
Join sys.server_permissions spe (nolock) on spri.principal_id=spe.grantee_principal_id
	Where spri.name not like '##%'
		  and spri.name not like 'NT %'
		  and spri.name not in ('sa','public')
		  and spe.permission_name <>'CONNECT SQL'
		  and spe.permission_name <>'CONNECT'

/*Server Level Role Members*/

Declare @SrvRoles Table ( ServerRole sysname,	MemberName sysname,	MemberSID sysname)
Insert @SrvRoles Exec sp_helpsrvrolemember 
Insert Into #TumDDLYetkiler (Seviye,YetkilendirmeTipi,Yetkili,Obje_Role,CreateScript)
	Select 'Server' As Seviye,'ROLEMEMBER' As YetkilendirmeTipi,MemberName As Yetkili, ServerRole As Obje_Role, 
	'ALTER SERVER ROLE ['+ServerRole+'] ADD MEMBER ['+MemberName+'] '
	from @SrvRoles 
	Where MemberName Not Like 'NT %'
	And MemberName Not In ('sa')



Select * from #TumDDLYetkiler 
Drop Table #TumDDLYetkiler 



