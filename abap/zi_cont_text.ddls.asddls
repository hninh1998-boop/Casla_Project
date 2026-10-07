@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'zi_cont_text'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_cont_text
  as select from ztb_cont_text
{
  key so                           as So,
  key so_item                      as SoItem,
  key so_lenh                      as SoLenh,
  key so_lenh_item                 as SoLenhItem,
      ngay_dong_cont               as NgayDongCont,
      dong_dau_thung               as DongDauThung,
      cont                         as Cont,
      ke_hoach_dong_cont           as KeHoachDongCont,
      ghi_chu_khac                 as GhiChuKhac,
      ghi_chu_giao_hang            as GhiChuGiaoHang,
      ngay_tau_chay                as NgayTauChay,
      thoi_gian_cat_mang           as ThoiGianCatMang,
      dia_diem_dong_hang_cont      as DiaDiemDongHangCont,
      dia_diem_dong_hang_cont_name as DiaDiemDongHangContName,
      sort_order                   as SortOrder,
      changed_by                   as ChangedBy,
      changed_at                   as ChangedAt
}
