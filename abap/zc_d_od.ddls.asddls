@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons.View - Data Upload lệnh xuất hàng'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zc_d_od
  as projection on zi_d_od
{
  key Uuid,
  key Uuidfile,

      @ObjectModel.text.element: ['OverallStatusText']
      Messagetype,

      Criticality,

      Message,

      SoThung,
      Delivery,

      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _ManageFile : redirected to parent zc_m_od,
      _OverallStatus
}
