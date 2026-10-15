@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons.View - Data Upload'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_D_ZBOM_RP
  as projection on zi_d_zbom_rp
{
  key  Uuid,
  key  Uuidfile,

       @ObjectModel.text.element: ['OverallStatusText']
       Messagetype,

       Criticality,

       Message,

       SalesOrder,
       SalesOrderItem,
       Material,
       Plant,
       BillOfMaterialVariant,
       BillOfMaterialVariantUsage,
       BillOfMaterialItemNumber,
       BillOfMaterialItemCategory,
       Component,
       @Semantics.quantity.unitOfMeasure: 'ComponentUnit'
       ComponentQuantity,
       ComponentUnit,
       IsNetScrap,
       ComponentScrapInPercent,
       BomItemIsCostingRelevant,
       SpecialProcurementType,
       ProdOrderIssueLocation,

       @EndUserText.label: 'Status'
       @Semantics.text: true
       _OverallStatus.description as OverallStatusText,

       CreatedBy,
       CreatedAt,
       LastChangedBy,
       LocalLastChangedAt,
       LastChangedAt,

       /* Associations */
       _ManageFile : redirected to parent ZC_M_ZBOM_RP,
       _OverallStatus
}
