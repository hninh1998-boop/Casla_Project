@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - PO'
@ObjectModel.usageType: {
    sizeCategory: #S,
    serviceQuality: #A,
    dataClass: #MIXED
}
@ObjectModel.dataCategory: #VALUE_HELP
define view entity zvh_po_mapim
  as select from I_PurchaseOrderHistoryAPI01
{
  key PurchaseOrder,
  key PurchaseOrderItem,
  key AccountAssignmentNumber,
  key PurchasingHistoryDocumentType,
  key PurchasingHistoryDocumentYear,
  key PurchasingHistoryDocument,
  key PurchasingHistoryDocumentItem

      //      @EndUserText.label: 'GR Posting Date'
      //      PostingDate as GRPostingDate,
      //      @EndUserText.label: 'Invoice Posting Date'
      //      PostingDate as InvoicePostingDate
}
