@ObjectModel.query.implementedBy: 'ABAP:ZCL_ZBOM_HEADER_CE'
@VDM.viewType: #CONSUMPTION
@EndUserText.label: 'BOM Explosion Custom Entity'
@Metadata.allowExtensions: true
@ObjectModel: {
    usageType: {
        serviceQuality: #X,
        sizeCategory: #S,
        dataClass: #MIXED
    }
}
@OData.entitySet.name : 'ExplodeZBOMHead'
define root custom entity zce_zbom_header
{
  key BillOfMaterial                 : abap.char(8);
  key BillOfMaterialCategory         : zde_bomcat;
  key Material                       : matnr;
      @ObjectModel.text.element      : [ 'PlantName' ]
  key Plant                          : abap.char(4);
      @ObjectModel.text.element      : [ 'BillOfMaterialVariantUsageDesc' ]
  key BillOfMaterialVariantUsage     : abap.char(1);
  key SalesOrder                     : vbeln;
  key SalesOrderItem                 : abap.numc(6);
      RequiredQuantityHeader         : abap.numc(20);
      @Semantics.text                : true
      PlantName                      : text30;
      ProductDescription             : maktx;
      @Semantics.text                : true
      BillOfMaterialVariantUsageDesc : text30;
      BaseUnit                       : meins;

      IsVersionBillOfMaterial        : abap_boolean;
      BOMExplosionApplication        : abap.char(4);

      DeliveryDate                   : abap.dats; //NinhNH added
      ProductType                   : abap.char(4); //NinhNH added

      //      @Semantics.quantity.unitOfMeasure: 'UnitHeader'

      UnitHeader                     : meins;

      _Item                          : composition [0..*] of zce_zbom_item;
}
