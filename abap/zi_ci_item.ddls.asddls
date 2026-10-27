@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'zi_ci_item'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_ci_item
  as select from ztb_ci_item
{
  key proforma     as ProFormaInvoice,
  key billing_item as BillingItem,
  key batch        as Batch,
      net_weight   as NetWeight,
      gross_weight as GrossWeight,
      changed_by   as ChangedBy,
      changed_at   as ChangedAt
}
