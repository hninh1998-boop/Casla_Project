@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Check Status Upload Att SO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZVH_STA_UPL_ATT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_STA_UPL_ATT' )
{
      @ObjectModel.text.element: ['Description']
      @UI.textArrangement: #TEXT_ONLY
      @EndUserText.label: 'Status'
  key value_low as Status,
      @Semantics.text: true
      @EndUserText.label: 'Status'
      text      as Description
}
// Không lọc theo ngôn ngữ logon: fixed value chỉ có text EN (giống ZVH_MSG_STA_OD_H),
// lọc theo VI sẽ mất text.
