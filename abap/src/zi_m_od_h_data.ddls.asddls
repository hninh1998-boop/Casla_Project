@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int. View - Data Mass Upload OD Header'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_m_od_h_data
  as select from ztb_m_od_h_data
  association [0..1] to zvh_msg_sta_od_h      as _OverallStatus on $projection.MessageType = _OverallStatus.Status
  association        to parent zi_m_od_h_file as _ManageFile    on $projection.UuidFile = _ManageFile.Uuid
{
  key uuid                       as Uuid,
  key uuid_file                  as UuidFile,
      od                         as Od,
      plan_gi_date               as PlanGiDate,
      inco_vers                  as IncoVers,
      incoterm                   as Incoterm,
      inco_loc1                  as IncoLoc1,
      inco_loc2                  as IncoLoc2,
      nha_cung_cap_van_tai       as NhaCungCapVanTai,
      phan_loai_ptvt             as PhanLoaiPtvt,
      so_luong_ptvt              as SoLuongPtvt,
      bien_so_xe                 as BienSoXe,
      so_container               as SoContainer,
      so_seal                    as SoSeal,
      tare_weight                as TareWeight,
      booking                    as Booking,
      ngay_tau_chay              as NgayTauChay,
      ngay_gio_xuat_hang         as NgayGioXuatHang,
      cut_off_time               as CutOffTime,
      ghi_chu_giao_hang          as GhiChuGiaoHang,
      ty_gia_lo_noi_dia          as TyGiaLoNoiDia,
      has_plan_gi_date           as HasPlanGiDate,
      has_inco_vers              as HasIncoVers,
      has_incoterm               as HasIncoterm,
      has_inco_loc1              as HasIncoLoc1,
      has_inco_loc2              as HasIncoLoc2,
      has_nha_cung_cap_van_tai   as HasNhaCungCapVanTai,
      has_phan_loai_ptvt         as HasPhanLoaiPtvt,
      has_so_luong_ptvt          as HasSoLuongPtvt,
      has_bien_so_xe             as HasBienSoXe,
      has_so_container           as HasSoContainer,
      has_so_seal                as HasSoSeal,
      has_tare_weight            as HasTareWeight,
      has_booking                as HasBooking,
      has_ngay_tau_chay          as HasNgayTauChay,
      has_ngay_gio_xuat_hang     as HasNgayGioXuatHang,
      has_cut_off_time           as HasCutOffTime,
      has_ghi_chu_giao_hang      as HasGhiChuGiaoHang,
      has_ty_gia_lo_noi_dia      as HasTyGiaLoNoiDia,

      @ObjectModel.text.element: ['OverallStatusText']
      message_type               as MessageType,
      case message_type
        when 'E' then 1
        when 'J' then 2
        when 'S' then 3
        else 0
      end                        as Criticality,
      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,
      message                    as Message,
      @Semantics.user.createdBy: true
      created_by                 as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                 as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at            as LastChangedAt,
      _ManageFile,
      _OverallStatus
}
