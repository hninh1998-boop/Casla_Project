@EndUserText.label: 'Abs.Ent. - Mapping Inv-Matdoc Export Param'
define abstract entity zabs_mapim_export_param
{
  // Filter + sort đang áp trên bảng, dạng JSON (xem ty_export_param trong zbp_ce_mapim)
  JsonString : abap.string(0);
}
