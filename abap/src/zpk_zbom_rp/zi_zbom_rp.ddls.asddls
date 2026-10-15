@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Báo cáo BOM Chi Tiết'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}

define root view entity ZI_ZBOM_RP
  //  as select from    I_BillOfMaterialItemBasic   as Item
  as select from    I_BillOfMaterialItemDEX_3   as Item

    inner join      I_BillOfMaterialHeaderDEX_2 as Hdr      on  Hdr.BillOfMaterial         = Item.BillOfMaterial
                                                            and Hdr.BillOfMaterialCategory = Item.BillOfMaterialCategory
                                                            and Hdr.BillOfMaterialVariant  = Item.BillOfMaterialVariant

    inner join      I_MaterialBOMLink           as MLink    on  MLink.BillOfMaterial         = Item.BillOfMaterial
                                                            and MLink.BillOfMaterialCategory = Item.BillOfMaterialCategory
                                                            and MLink.BillOfMaterialVariant  = Item.BillOfMaterialVariant

    left outer join I_ProductDescription        as MatDesc  on  MatDesc.Product  = MLink.Material
                                                            and MatDesc.Language = $session.system_language

    left outer join I_ProductDescription        as CompDesc on  CompDesc.Product  = Item.BillOfMaterialComponent
                                                            and CompDesc.Language = $session.system_language

{
      // (1) Material Number
  key MLink.Material,

      // (3) Plant
  key MLink.Plant,

      // (4) BOM Usage
  key Hdr.BillOfMaterialVariantUsage,

      // (5) Alternative BOM
  key Hdr.BillOfMaterialVariant,

      // (6) Sales Order
  key cast( '' as vbeln )         as SalesOrder,

      // (7) Sales Order Item
  key cast( '000000' as posnr )   as SalesOrderItem,

      // (12) BOM Item Number
  key Item.BillOfMaterialItemNumber,

      // internal key
  key Item.BillOfMaterialItemNodeNumber,
  key Item.BOMItemInternalChangeCount,

      // (25) Bill of Material
  key Item.BillOfMaterial,

      // (26) Bill of Material Category
  key Item.BillOfMaterialCategory,

      // (2) Material Description
      MatDesc.ProductDescription  as MaterialDescription,

      // (8) Valid-From Date
      Hdr.HeaderValidityStartDate,

      // (9) BOM Status
      Hdr.BillOfMaterialStatus,

      // (10) Base Quantity
      @Semantics.quantity.unitOfMeasure: 'BOMHeaderBaseUnit'
      Hdr.BOMHeaderQuantityInBaseUnit,

      // (11) Base Unit of Measure
      Hdr.BOMHeaderBaseUnit,

      // (13) BOM Component
      Item.BillOfMaterialComponent,

      // (14) BOM Item Category
      Item.BillOfMaterialItemCategory,

      // (15) Component Quantity
      @Semantics.quantity.unitOfMeasure: 'BillOfMaterialItemUnit'
      Item.BillOfMaterialItemQuantity,

      // (16) Component Description
      CompDesc.ProductDescription as ComponentDescription,

      // (17) Component Unit of Measure
      Item.BillOfMaterialItemUnit,

      // (18) Component Scrap in Percent
      Item.ComponentScrapInPercent,

      // (19) Special Procurement
      Item.SpecialProcurementType,

      // (20) BOM Item Text Line 1
      Item.BOMItemDescription     as BOMItemText1,

      // (21) BOM Item Text Line 2
      Item.BOMItemText2,

      // (22) BOM Item Long Text
      //      Item.LongTextLanguage,

      // (23) Relevancy to Costing
      Item.BOMItemIsCostingRelevant,

      // (24) Issue Location
      Item.ProdOrderIssueLocation
}
where
  Item.BillOfMaterialCategory = 'M'

union all

select from       I_SalesOrderBOMItemDEX   as Item

  inner join      I_SalesOrderBOMHeaderDEX as Hdr      on  Hdr.BillOfMaterial         = Item.BillOfMaterial
                                                       and Hdr.BillOfMaterialCategory = Item.BillOfMaterialCategory
                                                       and Hdr.BillOfMaterialVariant  = Item.BillOfMaterialVariant

  inner join      I_SalesOrderBOMLink      as KLink    on  KLink.BillOfMaterial         = Item.BillOfMaterial
                                                       and KLink.BillOfMaterialCategory = Item.BillOfMaterialCategory
                                                       and KLink.BillOfMaterialVariant  = Item.BillOfMaterialVariant

  left outer join I_ProductDescription     as MatDesc  on  MatDesc.Product  = KLink.Material
                                                       and MatDesc.Language = $session.system_language

  left outer join I_ProductDescription     as CompDesc on  CompDesc.Product  = Item.BillOfMaterialComponent
                                                       and CompDesc.Language = $session.system_language

{
  
      // (1) Material Number
  key KLink.Material,

      // (3) Plant
  key KLink.Plant,

      // (4) BOM Usage
  key Hdr.BillOfMaterialVariantUsage,

      // (5) Alternative BOM
  key Hdr.BillOfMaterialVariant,

      // (6) Sales Order
  key KLink.SalesOrder,

      // (7) Sales Order Item
  key KLink.SalesOrderItem,

      // (12) BOM Item Number
  key Item.BillOfMaterialItemNumber,

      // internal key
  key Item.BillOfMaterialItemNodeNumber,
  key Item.BOMItemInternalChangeCount,

      // (25) Bill of Material
  key Item.BillOfMaterial,

      // (26) Bill of Material Category
  key Item.BillOfMaterialCategory,

      // (2) Material Description
      MatDesc.ProductDescription  as MaterialDescription,

      // (8) Valid-From Date
      Hdr.HeaderValidityStartDate,

      // (9) BOM Status
      Hdr.BillOfMaterialStatus,

      // (10) Base Quantity
      Hdr.BOMHeaderQuantityInBaseUnit,

      // (11) Base Unit of Measure
      Hdr.BOMHeaderBaseUnit,

      // (13) BOM Component
      Item.BillOfMaterialComponent,

      // (14) BOM Item Category
      Item.BillOfMaterialItemCategory,

      // (15) Component Quantity
      Item.BillOfMaterialItemQuantity,

      // (16) Component Description
      CompDesc.ProductDescription as ComponentDescription,

      // (17) Component Unit of Measure
      Item.BillOfMaterialItemUnit,

      // (18) Component Scrap in Percent
      Item.ComponentScrapInPercent,

      // (19) Special Procurement
      Item.SpecialProcurementType,

      // (20) BOM Item Text Line 1
      Item.BOMItemDescription     as BOMItemText1,

      // (21) BOM Item Text Line 2
      Item.BOMItemText2,

      // (22) BOM Item Long Text
      //      Item.LongTextLanguage,

      // (23) Relevancy to Costing
      Item.BOMItemIsCostingRelevant,

      // (24) Issue Location
      Item.ProdOrderIssueLocation
}
where
  Item.BillOfMaterialCategory = 'K'
