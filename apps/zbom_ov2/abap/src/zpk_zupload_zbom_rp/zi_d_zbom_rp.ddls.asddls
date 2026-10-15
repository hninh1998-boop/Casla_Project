@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View - Data Upload ZBOM_RP'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_d_zbom_rp
  as select from ztb_d_zbom_rp
  association [0..1] to ZI_MSG_STA_zbom_rp_VH as _OverallStatus on $projection.Messagetype = _OverallStatus.Status
  association        to parent zi_m_zbom_rp   as _ManageFile    on $projection.Uuidfile = _ManageFile.Uuid
{
  key  uuid                           as Uuid,
  key  uuidfile                       as Uuidfile,

       messagetype                    as Messagetype,

       case messagetype
       when '' then 0
       when 'E' then 1
       when 'S' then 3
       else 0
       end                            as Criticality,

       message                        as Message,

       sales_order                    as SalesOrder,
       sales_order_item               as SalesOrderItem,
       material                       as Material,
       plant                          as Plant,
       bill_of_material_variant       as BillOfMaterialVariant,
       bill_of_material_variant_usage as BillOfMaterialVariantUsage,
       bill_of_material_item_number   as BillOfMaterialItemNumber,
       bill_of_material_item_category as BillOfMaterialItemCategory,
       component                      as Component,
       @Semantics.quantity.unitOfMeasure: 'ComponentUnit'
       component_quantity             as ComponentQuantity,
       component_unit                 as ComponentUnit,
       is_net_scrap                   as IsNetScrap,
       component_scrap_in_percent     as ComponentScrapInPercent,
       bom_item_is_costing_relevant   as BomItemIsCostingRelevant,
       special_procurement_type       as SpecialProcurementType,
       prod_order_issue_location      as ProdOrderIssueLocation,

       @Semantics.user.createdBy: true
       created_by                     as CreatedBy,
       @Semantics.systemDateTime.createdAt: true
       created_at                     as CreatedAt,
       @Semantics.user.lastChangedBy: true
       last_changed_by                as LastChangedBy,
       @Semantics.systemDateTime.localInstanceLastChangedAt: true
       local_last_changed_at          as LocalLastChangedAt,
       @Semantics.systemDateTime.lastChangedAt: true
       last_changed_at                as LastChangedAt,

       //Association
       _OverallStatus,
       _ManageFile
}
