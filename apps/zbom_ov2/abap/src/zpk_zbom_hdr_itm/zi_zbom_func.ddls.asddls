@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZBOM function anchor'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ZBOM_FUNC as select from ztb_zbom_func
{
    key func as Func
}
