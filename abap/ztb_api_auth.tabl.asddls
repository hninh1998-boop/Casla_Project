@EndUserText.label : 'Thông tin xác thực API'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztb_api_auth {

  key client      : abap.clnt not null;
  key systemid    : abap.char(10) not null;
  key api_user    : abap.char(50) not null;
  api_password    : abap.char(50) not null;
  api_url         : abap.char(255) not null;
  api_token       : abap.char(255) not null;
  created_by      : abp_creation_user;
  created_at      : abp_creation_tstmpl;
  last_changed_by : abp_locinst_lastchange_user;
  last_changed_at : abp_locinst_lastchange_tstmpl;

}
