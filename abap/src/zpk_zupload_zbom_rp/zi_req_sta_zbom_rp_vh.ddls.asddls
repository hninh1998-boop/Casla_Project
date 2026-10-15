@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Require Status ZBOM_RP'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zi_req_sta_zbom_rp_vh
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_REQ_STA_ZBOM_RP' )
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
      @UI.lineItem: [{ position: 40, importance: #HIGH, label: 'Characteristic Id' }]
      @UI.identification: [{ label: 'Characteristic Id' }]
      @UI.textArrangement: #TEXT_ONLY
      @ObjectModel.text.element: ['description']
      value_low as Status,
      @UI.lineItem: [{ position: 50, importance: #MEDIUM, label: 'Status' }]
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text: true
      @EndUserText.label: 'Status'
      text      as description
}
