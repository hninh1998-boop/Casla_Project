@EndUserText.label: 'zce_zbom_detail'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_ZBOM_DETAIL_CE'
@VDM.viewType: #CONSUMPTION
@Metadata.allowExtensions: true
@ObjectModel: {
    usageType: {
        serviceQuality: #X,
        sizeCategory: #S,
        dataClass: #MIXED
    }
}
@OData.entitySet.name : 'ExplodeZBOMDetail'

define root custom entity zce_zbom_detail
{
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
      MaterialDescription          : maktx; -- Mô tả của MaterialHeader (cột Material)

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
      ComponentScrapInPercent      : abap.dec(5,2); -- Field 18 - Component Scrap in Percent

      BillOfMaterialVariant        : abap.char(2);
      BillOfMaterialVersion        : abap.char(4);
      HeaderChangeDocument         : aennr;
}
