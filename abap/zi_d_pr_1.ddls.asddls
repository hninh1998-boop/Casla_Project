@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View - Data Upload PR 1'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_d_pr_1
  as select from ztb_d_pr_1
  association [0..1] to zi_msg_sta_mass_pr_vh as _OverallStatus on $projection.Messagetype = _OverallStatus.Status
  association        to parent zi_m_pr_1      as _ManageFile    on $projection.Uuidfile = _ManageFile.Uuid
{
  key uuid                       as Uuid,
  key uuidfile                   as Uuidfile,
      messagetype                as Messagetype,

      case messagetype
      when '' then 0
      when 'E' then 1
      when 'S' then 3
      else 0
      end                        as Criticality,

      message                    as Message,

      type                       as Type,
      purchase_requisition       as PurchaseRequisition,
      purchase_requisition_type  as PurchaseRequisitionType,
      pur_reqn_description       as PurReqnDescription,
      pur_reqn_header_note       as PurReqnHeaderNote,
      purchase_requisition_item  as PurchaseRequisitionItem,
      material                   as Material,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      requested_quantity         as RequestedQuantity,
      base_unit                  as BaseUnit,
      plant                      as Plant,
      storage_location           as StorageLocation,
      @Semantics.amount.currencyCode: 'PurReqnItemCurrency'
      purchase_requisition_price as PurchaseRequisitionPrice,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      pur_reqn_price_quantity    as PurReqnPriceQuantity,
      pur_reqn_item_currency     as PurReqnItemCurrency,
      purchasing_group           as PurchasingGroup,
      delivery_date              as DeliveryDate,
      requirement_tracking       as RequirementTracking,
      requested_by               as RequestedBy,

      @Semantics.user.createdBy: true
      created_by                 as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                 as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at      as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at            as LastChangedAt,

      //Association
      _OverallStatus,
      _ManageFile
}
