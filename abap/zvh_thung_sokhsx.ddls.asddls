@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Số KHSX thùng mẫu'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
define view entity zvh_thung_sokhsx
  as select distinct from ztb_custom_hu
{
      @EndUserText.label: 'Số KHSX'
  key so_khsx as SoKhsx
}
