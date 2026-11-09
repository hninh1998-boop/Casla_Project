@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cons.View - Data Upload'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity zc_d_crud_poc
  as projection on zi_d_crud_poc
{
  key Uuid,
  key Uuidfile,

      @ObjectModel.text.element: ['OverallStatusText']
      Messagetype,

      Criticality,

      Message,

      Type,
      ManufacturingOrder,
      ManufacturingOrderOperation,
      BomItem,
      BomItemCategory,
      Material,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      RequiredQuantity,
      BaseUnit,
      Plant,
      StorageLocation,

      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      /* Associations */

      _ManageFile : redirected to parent zc_m_crud_poc,
      _OverallStatus
}
