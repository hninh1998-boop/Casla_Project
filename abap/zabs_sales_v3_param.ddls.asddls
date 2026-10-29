@EndUserText.label: 'Abs.Ent. - Sales V3 Export Parameter'
define abstract entity zabs_sales_v3_param
{
  // Filter đang chọn trên màn hình, dạng JSON (xem ty_filter trong zbp_ce_sales_v3)
  JsonString : abap.string(0);
}
