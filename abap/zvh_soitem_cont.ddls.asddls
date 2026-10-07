@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - SO Item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
define view entity zvh_soitem_cont
  as select from I_SalesOrderItem
{
  key SalesOrder,
  key SalesOrderItem,
      SalesOrderItemText
}
