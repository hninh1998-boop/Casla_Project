@EndUserText.label: 'Abs.Ent. - Commercial Invoice Text'
define abstract entity zabs_ci_text
{
  // Để trống = giữ nguyên giá trị đang có, nhập D = xóa giá trị (giống Cập nhật thông tin Cont)
  @EndUserText.label : 'Invoice#'
  InvoiceNo          : abap.string(0);
  @EndUserText.label : 'Remarks'
  Remarks            : abap.string(0);
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
  @EndUserText.label : 'Container No'
  ContainerNo        : abap.string(0);
}
