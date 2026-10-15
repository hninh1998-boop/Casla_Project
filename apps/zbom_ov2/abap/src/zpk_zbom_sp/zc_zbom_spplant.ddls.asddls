@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZC_ZBOM_SPPLANT'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_ZBOM_SPPLANT
  provider contract transactional_query
  as projection on ZI_ZBOM_SPPLANT
{
  key Plant,
  key SpType,
      ProcurementType,
      SpecialProcurement,
      IssuingPlant,
      Description,
      LocalLastChangedAt,
      LastChangedAt
}
