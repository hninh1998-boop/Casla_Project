@EndUserText.label: 'Abs.Ent. - Commercial Invoice Weight'
define abstract entity zabs_ci_weight
{
  // Nút Edit trên bảng Items (chỉ dòng ProductGroup khác 320001)
  @EndUserText.label : 'Net weight (KGS)'
  NetWeight          : abap.dec(15,3);
  @EndUserText.label : 'Gross weight (KGS)'
  GrossWeight        : abap.dec(15,3);
}
