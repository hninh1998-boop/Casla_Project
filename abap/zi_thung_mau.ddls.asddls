@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View - Quản lý thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
define root view entity zi_thung_mau
  as select from ztb_custom_hu
  association [0..1] to I_ProductText   as _ProductText on  $projection.Material  = _ProductText.Product
                                                        and _ProductText.Language = $session.system_language
  association [0..1] to zi_thung_charc  as _Charc       on  $projection.Material = _Charc.Product
  association [0..1] to zi_thung_sta_vh as _Status      on  $projection.TrangThai = _Status.Status
  association [0..1] to zi_thung_del_vh as _DelFlag     on  $projection.DelFlag = _DelFlag.DelFlag
  association [0..1] to zi_thung_tem_vh as _Tem         on  $projection.Tem = _Tem.Tem
{
  key so_khsx               as SoKhsx,
  key so_thung              as SoThung,
  key material              as Material,
  key batch                 as Batch,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      quantity              as Quantity,
      base_unit             as BaseUnit,
      storage_location      as StorageLocation,
      customer              as Customer,
      ngay_nhap_kho         as NgayNhapKho,
      tem                   as Tem,
      khoi_luong            as KhoiLuong,
      status                as TrangThai,
      del_flag              as DelFlag,

      // Filter "Bao gồm": A = đang sử dụng, X = đã xóa, D = đã dỡ thùng (đủ giá trị domain ZDO_THUNG_DEL)
      case del_flag
      when '' then 'A'
      else del_flag
      end                   as DelStatus,

      // Màu cột Trạng thái: chỉ theo trạng thái (Tồn kho xanh, Đã xuất vàng)
      case status
      when '1' then 3
      when '2' then 2
      else 0
      end                   as Criticality,

      // Màu cột Đánh dấu xóa và vạch đầu dòng: đỏ khi đã xóa / dỡ thùng
      case
      when del_flag <> '' then 1
      else 0
      end                   as DelCriticality,

      uuidfile              as Uuidfile,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      // Association
      _ProductText,
      _Charc,
      _Status,
      _DelFlag,
      _Tem
}
