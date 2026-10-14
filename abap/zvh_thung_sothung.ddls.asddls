@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Số thùng/Pallet'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
define view entity zvh_thung_sothung
  as select distinct from ztb_custom_hu
{
      @EndUserText.label: 'Số thùng/Pallet'
  key so_thung as SoThung
}
