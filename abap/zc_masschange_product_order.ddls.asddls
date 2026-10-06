@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MASSCHANGE_PRODUCT_ORDER'
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
define root view entity zc_MASSCHANGE_PRODUCT_ORDER
  as select from I_ManufacturingOrder
  association [0..1] to I_ProductDescription as _PRODUCTDESCRIPTION on  $projection.Material         = _PRODUCTDESCRIPTION.Product
                                                                    and _PRODUCTDESCRIPTION.Language = 'E'
{
  key ManufacturingOrder,
      MfgOrderPlannedStartDate,
      MfgOrderPlannedEndDate,
      YY1_So_May_ORD,
      YY1_Thu_Tu_ORD,
      YY1_MaterialName_ORD,
      Material,
      _PRODUCTDESCRIPTION.ProductDescription,
      SalesOrder,
      SalesOrderItem,
      @Semantics: {
      quantity.unitOfMeasure: 'productionunit'
      }
      MfgOrderPlannedTotalQty,
      @Semantics: {
      quantity.unitOfMeasure: 'productionunit'
      }
      ActualDeliveredQuantity,
      @Semantics: {
      quantity.unitOfMeasure: 'productionunit'
      }
      MfgOrderConfirmedYieldQty,
      ProductionPlant,
      ManufacturingOrderType,
      IsCompletelyDelivered,
      ProductionUnit,
      @Consumption.filter.hidden: true
      @UI.hidden: true
      Batch as btnSet
}
where
  IsMarkedForDeletion <> 'X'
