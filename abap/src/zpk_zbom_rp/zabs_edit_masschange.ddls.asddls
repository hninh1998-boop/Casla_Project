@EndUserText.label: 'zabs_edit_massChange'
define abstract entity zabs_edit_massChange
{
  LineItem                     : abap.int4;
  Component                    : abap.char(40);
  ComponentQuantity            : abap.dec(13,3);
  ComponentScrap               : abap.dec(5,2);
  SpecialProcurementType       : abap.char(2);
  BOMItemIsCostingRelevant     : abap.char(1);
  ComponentUOM                 : abap.char(3);
  ProdOrderIssueLocation       : abap.char(4);

  RunInBackground              : abap_boolean;
  RunNow                       : abap_boolean;
  JobText                      : abap.string(0);

  EditComponent                : abap_boolean;
  EditComponentQuantity        : abap_boolean;
  EditComponentScrap           : abap_boolean;
  EditSpecialProcurementType   : abap_boolean;
  EditBOMItemIsCostingRelevant : abap_boolean;
  EditComponentUOM             : abap_boolean;
  EditProdOrderIssueLocation   : abap_boolean;
}
