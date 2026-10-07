@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - So KH'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
define view entity zvh_sokh_cont
  as select from I_SalesOrderItem
{
      @EndUserText.label: 'Số SO'
  key SalesOrder,
      @EndUserText.label: 'Số SO Item'
  key SalesOrderItem,
      // Cùng format với zce_cont-SoKH: SO/SOItem (bỏ số 0 đầu)
      @EndUserText.label: 'Số KH'
      concat( concat( ltrim( SalesOrder, '0' ), '/' ),
              ltrim( cast( SalesOrderItem as abap.char(6) ), '0' ) ) as SoKH,
      @EndUserText.label: 'Mã hàng'
      Product,
      @EndUserText.label: 'Tên hàng'
      SalesOrderItemText,
      Plant
}
where
       SalesOrderType         = 'TA'
  and(
       SalesOrderItemCategory = 'TAN'
    or SalesOrderItemCategory = 'CBXN'
  )
