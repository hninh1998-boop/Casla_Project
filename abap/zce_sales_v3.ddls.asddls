@EndUserText.label: 'Custom Entity - Báo cáo bán hàng v3'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_SALES_V3'
@Metadata.allowExtensions: true
define root custom entity zce_sales_v3
{
      // Khóa dòng: TH1 = Plant + Product + Sales District (GLAccount trống)
      //            TH2 = GLAccount (Plant / Product / Sales District trống)
      @EndUserText.label: 'Plant'
  key Plant                : werks_d;
      @EndUserText.label: 'Product Sold'
  key Product              : matnr;
      @EndUserText.label: 'Sales District'
  key SalesDistrict        : abap.char(6);
      @EndUserText.label: 'G/L Account'
  key GLAccount            : abap.char(10);

      // ── Tham số ──────────────────────────────────────────
      @EndUserText.label: 'Company Code'
      CompanyCode          : abap.char(4);
      @EndUserText.label: 'Posting Date'
      PostingDate          : abap.dats;

      // ── Cột báo cáo ──────────────────────────────────────
      @EndUserText.label: 'STT'
      STT                  : abap.int4;
      @EndUserText.label: 'Tên Nhà Máy'
      TenNhaMay            : abap.char(40);
      @EndUserText.label: 'Mã Hàng'
      MaHang               : abap.char(40);
      @EndUserText.label: 'Tên Hàng'
      TenHang              : abap.char(40);
      @EndUserText.label: 'Đơn Vị Tính'
      DonViTinh            : meins;
      @EndUserText.label: 'Loại Hàng'
      LoaiHang             : abap.char(40);
      @EndUserText.label: 'Số Lượng'
      SoLuong              : abap.dec(13,3);

      @EndUserText.label: 'Doanh Thu USD'
      @Semantics.amount.currencyCode: 'CurrencyUSD'
      DoanhThuUSD          : abap.curr(13,2);
      CurrencyUSD          : abap.cuky;

      // VND có 0 số lẻ: SAP lưu nội bộ dạng 2 số lẻ, hiển thị theo currency -> khai báo curr(15,2)
      @EndUserText.label: 'Doanh Thu VND'
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      DoanhThuVND          : abap.curr(15,2);
      @EndUserText.label: 'Giá Vốn VND'
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      GiaVonVND            : abap.curr(15,2);
      CompanyCodeCurrency  : abap.cuky;

      @EndUserText.label: 'Thị Trường Xuất Khẩu'
      ThiTruongXuatKhau    : abap.char(40);
}
