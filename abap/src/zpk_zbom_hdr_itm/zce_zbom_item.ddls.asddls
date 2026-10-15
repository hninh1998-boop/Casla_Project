@ObjectModel.query.implementedBy: 'ABAP:ZCL_ZBOM_ITEM_CE'
@EndUserText.label: 'zce_bom_item_8'
@VDM.viewType: #CONSUMPTION
@Metadata.allowExtensions: true
@ObjectModel: {
    usageType: {
        serviceQuality: #X,
        sizeCategory: #S,
        dataClass: #MIXED
    }
}
@OData.entitySet.name : 'ExplodeZBOMItem'
define custom entity zce_zbom_item
{
      //  key ItemIndex                    : int4;
      //  key ItemIndexString              : abap.char(255);
      //  key BillOfMaterial               : abap.char(8);
      //  key BillOfMaterialCategory       : stlty;
      //  key Material                     : matnr;
      //  key Plant                        : werks_d; -- Field 8 - Plant - Header Key
      //  key BillOfMaterialVariantUsage   : abap.char(1);
      //  key SalesOrder                   : vbeln;
      //  key SalesOrderItem               : abap.numc(6);
      //
      //      TreeView                     : abap.char(30);
      //
      //      MaterialType                 : abap.char(4); -- Field 7 - Material Type
      //      BillOfMaterialComponent      : abap.char(40); -- Field 1 - Component
      //
      //      BillOfMaterialItemNodeNumber : stlkn;
      //
      //      BomExplosionLevel            : abap.numc(2);
      //      BomhHdrMatlHierNode          : abap.char(40);
      //      ComponentDescription         : maktx; -- Field 2 - Component Description
      //      @Semantics.quantity.unitOfMeasure: 'BillOfMaterialItemUnit'
      //      BomCompQuant                 : abap.quan(17,3); -- Field 3 - Component Quantity (Component UoM)
      //      BillOfMaterialItemCategory   : postp; -- Field 4 - Item Category
      //      BillOfMaterialItemNumber     : abap.char(4); -- Field 5 - Item Number
      //      IsAssembly                   : abap_boolean; -- Field 6 - Assembly Indicator
      //      @Semantics.unitOfMeasure     : true
      //      BillOfMaterialItemUnit       : meins; -- Field 9 - Base UoM
      //      MaintenanceStatus            : abap.char(1); -- Field 10 - Maintenance Status
      //      ValidityStartDate            : abap.dats; -- Field 11 - Valid From
      //      ChangeNumber                 : abap.char(12); -- Field 12 - Change Number
      //      CreatedOn                    : abp_creation_date; -- Field 13 - Created On
      //      CreatedBy                    : abp_creation_user; -- Field 14 - Created By
      //      ChangedOn                    : abp_lastchange_date; -- Field 15 - Changed On
      //      ChangedBy                    : abp_lastchange_user; -- Field 16 - Changed By
      //      IsBomItemSparePart           : abap_boolean; -- Field 17 - Item Spare Part Indicator
      //
      //      BillOfMaterialVariant        : abap.char(2);
      //      BillOfMaterialVersion        : abap.char(4);
      //      HeaderChangeDocument         : aennr;
  key ItemIndex                    : int4;
  key ItemIndexString              : abap.char(255);
  key BillOfMaterial               : abap.char(8);
  key BillOfMaterialCategory       : stlty;
  key Material                     : matnr;
  key Plant                        : werks_d; -- Field 8 - Plant - Header Key
  key BillOfMaterialVariantUsage   : abap.char(1);
  key SalesOrder                   : vbeln;
  key SalesOrderItem               : abap.numc(6);

  key MaterialHeader               : matnr;

      @Semantics.unitOfMeasure     : true
      UomHeader                    : meins;

      TreeView                     : abap.char(30);
      @Semantics.quantity.unitOfMeasure: 'UomHeader'
      RequiredQuantityHeader       : abap.quan(17,3);

      MaterialType                 : abap.char(4); -- Field 7 - Material Type
      BillOfMaterialComponent      : abap.char(40); -- Field 1 - Component

      BillOfMaterialItemNodeNumber : stlkn;

      BomExplosionLevel            : abap.numc(2);
      BomhHdrMatlHierNode          : abap.char(40);
      ComponentDescription         : maktx; -- Field 2 - Component Description
      @Semantics.quantity.unitOfMeasure: 'BillOfMaterialItemUnit'
      BomCompQuant                 : abap.quan(17,3); -- Field 3 - Component Quantity (Component UoM)
      BillOfMaterialItemCategory   : postp; -- Field 4 - Item Category
      BillOfMaterialItemNumber     : abap.char(4); -- Field 5 - Item Number
      IsAssembly                   : abap_boolean; -- Field 6 - Assembly Indicator
      @Semantics.unitOfMeasure     : true
      BillOfMaterialItemUnit       : meins; -- Field 9 - Base UoM
      MaintenanceStatus            : abap.char(1); -- Field 10 - Maintenance Status
      ValidityStartDate            : abap.dats; -- Field 11 - Valid From
      ChangeNumber                 : abap.char(12); -- Field 12 - Change Number
      CreatedOn                    : abp_creation_date; -- Field 13 - Created On
      CreatedBy                    : abp_creation_user; -- Field 14 - Created By
      ChangedOn                    : abp_lastchange_date; -- Field 15 - Changed On
      ChangedBy                    : abp_lastchange_user; -- Field 16 - Changed By
      IsBomItemSparePart           : abap_boolean; -- Field 17 - Item Spare Part Indicator

      BillOfMaterialVariant        : abap.char(2);
      BillOfMaterialVersion        : abap.char(4);
      HeaderChangeDocument         : aennr;

      _Header                      : association to parent zce_zbom_header on  $projection.BillOfMaterial             = _Header.BillOfMaterial
                                                                           and $projection.BillOfMaterialCategory     = _Header.BillOfMaterialCategory
                                                                           and $projection.Material                   = _Header.Material
                                                                           and $projection.Plant                      = _Header.Plant
                                                                           and $projection.BillOfMaterialVariantUsage = _Header.BillOfMaterialVariantUsage
                                                                           and $projection.SalesOrder                 = _Header.SalesOrder
                                                                           and $projection.SalesOrderItem             = _Header.SalesOrderItem;

}
