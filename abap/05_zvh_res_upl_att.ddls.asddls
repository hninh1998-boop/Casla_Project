@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Post Result Upload Att SO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZVH_RES_UPL_ATT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_RES_UPL_ATT' )
{
      @ObjectModel.text.element: ['Description']
      @UI.textArrangement: #TEXT_ONLY
      @EndUserText.label: 'Result'
  key value_low as PostResult,
      @Semantics.text: true
      @EndUserText.label: 'Result'
      text      as Description
}
