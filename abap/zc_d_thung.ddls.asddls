@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons.View - Data Upload thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zc_d_thung
  as projection on zi_d_thung
{
  key Uuid,
  key Uuidfile,

      @ObjectModel.text.element: ['OverallStatusText']
      Messagetype,

      Criticality,

      Message,

      Type,
      SoKhsx,
      SoThung,
      Material,
      Batch,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Quantity,
      BaseUnit,
      StorageLocation,
      Customer,
      NgayNhapKho,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'zi_thung_tem_vh', element: 'Tem' } }]
      Tem,

      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _ManageFile : redirected to parent zc_m_thung,
      _OverallStatus
}
