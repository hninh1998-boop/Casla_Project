@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZC_ZBOM_AUTH'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_ZBOM_AUTH
  provider contract transactional_query
  as projection on ZI_ZBOM_AUTH
{
  key Uname
}
