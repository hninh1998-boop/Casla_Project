@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View - Báo cáo BOM Chi Tiết'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_ZBOM_RP
  provider contract transactional_query
  as projection on ZI_ZBOM_RP

{

          // (1) Material Number
  key     Material,

          // (3) Plant
  key     Plant,

          // (4) BOM Usage
  key     BillOfMaterialVariantUsage,

          // (5) Alternative BOM
  key     BillOfMaterialVariant,

          // (6) Sales Order
  key     SalesOrder,

          // (7) Sales Order Item
  key     SalesOrderItem,

          // (12) BOM Item Number
  key     BillOfMaterialItemNumber,

          // internal key
  key     BillOfMaterialItemNodeNumber,
  key     BOMItemInternalChangeCount,

          // (25) Bill of Material
  key     BillOfMaterial,

          // (26) Bill of Material Category
  key     BillOfMaterialCategory,

          // (2) Material Description
          MaterialDescription,

          // (8) Valid-From Date
          HeaderValidityStartDate,

          // (9) BOM Status
          BillOfMaterialStatus,

          // (10) Base Quantity
          @Semantics.quantity.unitOfMeasure: 'BOMHeaderBaseUnit'
          BOMHeaderQuantityInBaseUnit,

          // (11) Base Unit of Measure
          BOMHeaderBaseUnit,

          // (13) BOM Component
          BillOfMaterialComponent,

          // (14) BOM Item Category
          BillOfMaterialItemCategory,

          // (15) Component Quantity
          @Semantics.quantity.unitOfMeasure: 'BillOfMaterialItemUnit'
          BillOfMaterialItemQuantity,

          // (16) Component Description
          ComponentDescription,

          // (17) Component Unit of Measure
          BillOfMaterialItemUnit,

          // (18) Component Scrap in Percent
          ComponentScrapInPercent,

          // (19) Special Procurement
          SpecialProcurementType,

          // (20) BOM Item Text Line 1
          BOMItemText1,

          // (21) BOM Item Text Line 2
          BOMItemText2,

          // (22) Relevancy to Costing
          BOMItemIsCostingRelevant,

          // (23) Issue Location
          ProdOrderIssueLocation,

          //  key LineItem,
          //      // (0) Line Item - Auto Calculation
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_ZBOM_RP_LINE_ITEM'
  virtual LineItem : abap.int4
}
