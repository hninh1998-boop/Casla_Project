@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons.View - Data PR 1'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zc_d_pr_1
  as projection on zi_d_pr_1
{
  key Uuid,
  key Uuidfile,

      @ObjectModel.text.element: ['OverallStatusText']
      Messagetype,

      Criticality,

      Message,

      Type,
      PurchaseRequisition,
      PurchaseRequisitionType,
      PurReqnDescription,
      PurReqnHeaderNote,
      PurchaseRequisitionItem,
      Material,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      RequestedQuantity,
      BaseUnit,
      Plant,
      StorageLocation,
      @Semantics.amount.currencyCode: 'PurReqnItemCurrency'
      PurchaseRequisitionPrice,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      PurReqnPriceQuantity,
      PurReqnItemCurrency,
      PurchasingGroup,
      DeliveryDate,
      RequirementTracking,
      RequestedBy,

      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      /* Associations */

      _ManageFile : redirected to parent ZC_M_PR_1,
      _OverallStatus
}
