@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZI_ZBOM_SPPLANT'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_ZBOM_SPPLANT
  as select from ztb_zbom_spplant
{
  key plant                 as Plant,
  key sp_type               as SpType,
      procurement_type      as ProcurementType,
      special_procurement   as SpecialProcurement,
      issuing_plant         as IssuingPlant,
      description           as Description,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt

}
