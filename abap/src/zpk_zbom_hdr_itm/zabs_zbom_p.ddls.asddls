@EndUserText.label: 'Abs. Ent. for ZBOM Explode - Parameters'
define abstract entity zabs_zbom_p
{
  //  @EndUserText.label      : 'Alternative BOM'
  //  AlternativeBOM          : abap.char(2);
  //
  //  @EndUserText.label      : 'BOM Application'
  //  BOMExplosionApplication : abap.char(4);

  @EndUserText.label     : 'Required Quantity'
  //  @Semantics.quantity.unitOfMeasure: 'RequiredQuantityUnit'
  RequiredQuantityHeader : abap.numc( 6 );

  //  @EndUserText.label      : 'Unit'
  //  @Semantics.unitOfMeasure: true
  //  RequiredQuantityUnit    : meins;
  //
  //  @EndUserText.label      : 'Valid From'
  //  ValidFrom               : abap.dats;
  //
  //  @EndUserText.label      : 'Change Number'
  //  ChangeNumber            : abap.char(12);
}
