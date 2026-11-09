@EndUserText.label : 'Upload Attachment SO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztb_upl_att_so {

  key client            : abap.clnt not null;
  key uuid              : sysuuid_x16 not null;
  file_name             : abap.char(255);
  sales_order           : abap.char(10);
  description           : abap.char(255);
  mime_type             : abap.char(128);
  file_size             : abap.int8;
  file_size_text        : abap.char(20);
  attachment            : abap.rawstring(0);
  status                : abap.char(1);
  post_result           : abap.char(1);
  message               : abap.string(0);
  att_doc_number        : abap.char(30);
  posted_by             : syuname;
  posted_at             : timestampl;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  local_last_changed_by : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;

}
