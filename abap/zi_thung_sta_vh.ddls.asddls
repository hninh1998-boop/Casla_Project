@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Trạng thái thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_thung_sta_vh
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_THUNG_STATUS' )
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
      @UI.lineItem: [{ position: 40, importance: #HIGH, label: 'Trạng thái' }]
      @UI.identification: [{ label: 'Trạng thái' }]
      @UI.textArrangement: #TEXT_ONLY
      @ObjectModel.text.element: ['description']
      value_low as Status,
      @UI.lineItem: [{ position: 50, importance: #MEDIUM, label: 'Trạng thái' }]
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text: true
      @EndUserText.label: 'Trạng thái'
      text      as description
}
