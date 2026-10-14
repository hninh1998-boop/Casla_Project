@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Đánh dấu xóa thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_thung_del_vh
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_THUNG_DEL' )
{
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @UI.hidden: true
  key domain_name,
      @UI.hidden: true
      @UI.lineItem: [{ position: 20, importance: #MEDIUM }]
  key value_position,
      @UI.lineItem: [{ position: 30, importance: #MEDIUM }]
      @Semantics.language: true
  key language,
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 40, importance: #HIGH, label: 'Đánh dấu xóa' }]
      @UI.identification: [{ label: 'Đánh dấu xóa' }]
      @UI.textArrangement: #TEXT_ONLY
      @ObjectModel.text.element: ['description']
      value_low as DelFlag,
      @UI.lineItem: [{ position: 50, importance: #MEDIUM, label: 'Đánh dấu xóa' }]
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text: true
      @EndUserText.label: 'Đánh dấu xóa'
      text      as description
}
