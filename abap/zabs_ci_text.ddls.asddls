@EndUserText.label: 'Abs.Ent. - Commercial Invoice Text'
define abstract entity zabs_ci_text
{
  // Nút Change header trên danh sách (chọn nhiều invoice). Để trống = giữ nguyên, nhập D = xóa giá trị
  @EndUserText.label : 'Invoice#'
  InvoiceNo          : abap.string(0);
  @EndUserText.label : 'MB/L#'
  MBL                : abap.string(0);
  @EndUserText.label : 'HB/L#'
  HBL                : abap.string(0);
  @EndUserText.label : 'Vessel Name'
  VesselName         : abap.string(0);
  @EndUserText.label : 'ETD'
  ETD                : abap.string(0);
  @EndUserText.label : 'ETA'
  ETA                : abap.string(0);
}
