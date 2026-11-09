@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View - Data Upload CRUD POC'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_d_crud_poc
  as select from ztb_d_crud_poc
  association [0..1] to zi_msg_sta_crud_poc_vh as _OverallStatus on $projection.Messagetype = _OverallStatus.Status
  association        to parent zi_m_crud_poc   as _ManageFile    on $projection.Uuidfile = _ManageFile.Uuid
{
  key uuid                          as Uuid,
  key uuidfile                      as Uuidfile,

      messagetype                   as Messagetype,

      case messagetype
      when '' then 0
      when 'E' then 1
      when 'S' then 3
      else 0
      end                           as Criticality,

      message                       as Message,

      type                          as Type,
      manufacturing_order           as ManufacturingOrder,
      manufacturing_order_operation as ManufacturingOrderOperation,
      bom_item                      as BomItem,
      bom_item_category             as BomItemCategory,
      material                      as Material,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      required_quantity             as RequiredQuantity,
      base_unit                     as BaseUnit,
      plant                         as Plant,
      storage_location              as StorageLocation,

      @Semantics.user.createdBy: true
      created_by                    as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                    as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by               as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at         as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at               as LastChangedAt,

      //Association
      _OverallStatus,
      _ManageFile
}
