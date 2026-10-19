@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'zi_ci_text'
@Metadata.ignorePropagatedAnnotations: true
define view entity zi_ci_text
  as select from ztb_ci_text
{
  key proforma     as ProFormaInvoice,
      invoice_no   as InvoiceNo,
      remarks      as Remarks,
      mbl          as MBL,
      hbl          as HBL,
      vessel_name  as VesselName,
      etd          as ETD,
      eta          as ETA,
      container_no as ContainerNo,
      changed_by   as ChangedBy,
      changed_at   as ChangedAt
}
