@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View - Data Upload thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_d_thung
  as select from ztb_d_thung
  association [0..1] to zi_msg_sta_mass_pr_vh as _OverallStatus on $projection.Messagetype = _OverallStatus.Status
  association        to parent zi_m_thung     as _ManageFile    on $projection.Uuidfile = _ManageFile.Uuid
{
  key uuid                  as Uuid,
  key uuidfile              as Uuidfile,
      messagetype           as Messagetype,

      case messagetype
      when '' then 0
      when 'E' then 1
      when 'S' then 3
      else 0
      end                   as Criticality,

      message               as Message,

      type                  as Type,
      so_khsx               as SoKhsx,
      so_thung              as SoThung,
      material              as Material,
      batch                 as Batch,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      quantity              as Quantity,
      base_unit             as BaseUnit,
      storage_location      as StorageLocation,
      customer              as Customer,
      ngay_nhap_kho         as NgayNhapKho,
      tem                   as Tem,
      khoi_luong            as KhoiLuong,

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

      //Association
      _OverallStatus,
      _ManageFile
}
