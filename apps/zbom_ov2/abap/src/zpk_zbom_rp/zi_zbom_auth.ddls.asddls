@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZI_ZBOM_AUTH'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_ZBOM_AUTH
  as select from ztb_zbom_auth
{
  key uname          as Uname
}
