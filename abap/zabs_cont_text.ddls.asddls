@EndUserText.label: 'Abs.Ent. - Cont'
define abstract entity zabs_cont_text
{

  @EndUserText.label      : 'Ngày đóng cont'
  NgayDongCont            : abap.dats(8);
  DongDauThung            : abap.string(0);
  Cont                    : abap.string(0);
  KeHoachDongCont         : abap.string(0);
  GhiChuKhac              : abap.string(0);
  GhiChuGiaoHang          : abap.string(0);
  NgayTauChay             : abap.string(0);
  ThoiGianCatMang         : abap.string(0);
  @EndUserText.label      : 'Địa điểm đóng hàng'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_PlantStdVH', element: 'Plant' } }]
  @ObjectModel.text.element:[ 'DiaDiemDongHangContName' ]
  @UI.textArrangement     : #TEXT_LAST
  DiaDiemDongHangCont     : werks_d;

  @EndUserText.label      : 'Tên địa điểm đóng hàng'
  @Semantics.text         : true
  @UI.hidden              : true
  DiaDiemDongHangContName : abap.char(30);
}
