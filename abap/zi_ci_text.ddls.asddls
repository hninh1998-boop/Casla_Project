@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'zi_ci_text'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_ci_text
  as select from ztb_ci_text
{
  key proforma   as ProFormaInvoice,
  key item       as Item,
      invoice_no as InvoiceNo,
      mbl        as MBL,
      hbl        as HBL,
      eta        as ETA,
      changed_by as ChangedBy,
      changed_at as ChangedAt
}
