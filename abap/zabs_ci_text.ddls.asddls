@EndUserText.label: 'Abs.Ent. - Commercial Invoice Text'
define abstract entity zabs_ci_text
{
  // Các mục FS ghi "Điền text". Để trống = giữ nguyên giá trị đang có, nhập D = xóa giá trị
  // Cả 4 mục đều cấp header: áp dụng cho cả Pro-forma invoice của dòng được chọn
  @EndUserText.label : 'Invoice#'
  InvoiceNo          : abap.string(0);
  @EndUserText.label : 'MB/L#'
  MBL                : abap.string(0);
  @EndUserText.label : 'HB/L#'
  HBL                : abap.string(0);
  @EndUserText.label : 'ETA'
  ETA                : abap.string(0);
}
