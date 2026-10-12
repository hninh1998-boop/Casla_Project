@EndUserText.label: 'Custom Entity - Sales Đá'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_SALES_DA'
@Metadata.allowExtensions: true
define root custom entity zce_sales_da
{
  key BillingDocument     : vbeln; // I_BillingDocumentItem-BillingDocument
  key BillingDocumentItem : posnr; // I_BillingDocumentItem-BillingDocumentItem

      // Tiêu đề màn hình detail: BillingDocument/BillingDocumentItem
      BillingDocumentTitle : abap.char(20);

      // I_BillingDocument
      NgayChungTu         : abap.dats; // BillingDocumentDate
      DoiTuongCongNo      : kunrg; // PayerParty
      TyGia               : abap.dec(15,5); // AccountingExchangeRate * hệ số quy đổi của cặp tiền tệ
      TyGiaText           : abap.char(30); // TyGia dạng chữ để hiển thị, không có số 0 thừa (vd. 26,900.92)
      QuocGiaDen          : land1; // Country;

      // I_Customer
      TenDoiTuongCongNo   : abap.char(80); // CustomerName

      // I_CountryText
      TenQuocGiaDen       : abap.char(50); // CountryName

      // I_BillingDocumentItem
      MaVatTu             : matnr; // Product
      @Semantics.quantity.unitOfMeasure: 'DonViTinh'
      SoLuong             : abap.quan(13,3); // BillingQuantity

      // I_BillingDocumentTextTP
      SoToKhai            : abap.string; // LongTextID = Z020 --> LongText
      SoInv               : abap.string; // LongTextID = Z027 --> LongText

      // I_JournalEntry (Example: AccountingDocument = 9400000036 --> DocumentReferenceID)
      SoHoaDon            : abap.char(16); // DocumentReferenceID

      // I_ProductText
      TenVatTu            : abap.char(40); // ProductName

      // I_ProductUnitsOfMeasure
      DonViTinh           : meins; // BaseUnit

      // I_BillingDocumentItemPrcgElmnt
      @Semantics.amount.currencyCode: 'ConditionCurrency'
      GiaCongThuc         : abap.dec(24,9); // ConditionRateAmount
      ConditionCurrency   : waers; // ConditionCurrency
      @Semantics.amount.currencyCode: 'ConditionCurrency'
      GiaBan              : abap.dec(24,9);
      @Semantics.amount.currencyCode: 'ConditionCurrency'
      ChenhLech           : abap.dec(24,9);
      @Semantics.amount.currencyCode: 'ConditionCurrency'
      GiaInvHaiQuan       : abap.dec(24,9);
      @Semantics.amount.currencyCode: 'ConditionCurrency'
      GiaInvKhachHang     : abap.dec(24,9);
      @Semantics.amount.currencyCode: 'ConditionCurrency'
      NgoaiTe             : abap.dec(24,9);
      // Thành tiền = Ngoại tệ * Tỷ giá --> tiền theo Company Code Currency
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      ThanhTien           : abap.dec(24,9);
      CompanyCodeCurrency : waers; // I_CompanyCode-Currency

      // Get by Logic ECUS
      LoaiDaSlabE62       : abap.char(1);
      LoaiDaCutToSizeE62  : abap.char(1);
      LoaiDaMauBanE62     : abap.char(1);
      LoaiDaMauTangE62    : abap.char(1);
      LoaiDaMauTangH21    : abap.char(1);
      LoaiDaGiaCongE52    : abap.char(1);

      // Parameter Only
      ToChucBanHang       : bukrs; // ZI_COMPANYCODE_VH-CompanyCode

}
