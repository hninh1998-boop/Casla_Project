@EndUserText.label: 'Custom Entity - Commercial Invoice Item'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_CI_Q'
@Metadata.allowExtensions: true
define custom entity zce_ci_i
{
      // Màn hình chi tiết: mỗi batch của dòng TAN 1 dòng (giống bảng Packing List)
  key ProFormaInvoice     : vbeln;
  key BillingItem         : posnr;
  key Batch               : abap.char(10);      // Lot. No

      PO                  : bstkd;
      Material            : matnr;
      AZTID               : abap.string;
      VendorID            : abap.char(10);
      @Semantics.quantity.unitOfMeasure: 'BillingQuantityUnit'
      Quantity            : fkimg;
      BillingQuantityUnit : vrkme;
      NetWeight           : abap.dec(15,3);     // Điền tay - ztb_ci_item
      GrossWeight         : abap.dec(15,3);     // Điền tay - ztb_ci_item
      SizeL               : abap.string;
      SizeW               : abap.string;
      SizeH               : abap.string;
      LOT                 : abap.string;
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      UnitPrice           : abap.curr(15,2);
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      Amount              : abap.curr(15,2);
      TransactionCurrency : waerk;
      WeightAuto          : abap_boolean;       // X = ProductGroup 320001, N.W / G.W tự tính, không sửa tay

      _Header             : association to parent zce_ci_h on $projection.ProFormaInvoice = _Header.ProFormaInvoice;
}
