@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Tình trạng xóa thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity zvh_thung_hienthi
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_THUNG_DEL' )
{
      @UI.hidden: true
  key domain_name,
      @UI.hidden: true
  key value_position,
      @UI.hidden: true
      @Semantics.language: true
  key language,
      @UI.textArrangement: #TEXT_ONLY
      @ObjectModel.text.element: ['description']
      @EndUserText.label: 'Tình trạng xóa'
      value_low as DelStatus,
      @Semantics.text: true
      @EndUserText.label: 'Tình trạng xóa'
      text      as description
}
where
     value_low = 'A'
  or value_low = 'X'
