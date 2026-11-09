@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - PO Supplier'
@ObjectModel.usageType: {
    sizeCategory: #S,
    serviceQuality: #A,
    dataClass: #MIXED
}
@ObjectModel.dataCategory: #VALUE_HELP
define view entity zvh_posupplier_mapim
  as select from I_BusinessPartner as bp
{
      @EndUserText.label: 'PO Supplier'
  key bp.BusinessPartner as POSupplier,
      @EndUserText.label: 'PO Supplier Name'
      case
        when bp.OrganizationBPName2 is not initial
          or bp.OrganizationBPName3 is not initial
          or bp.OrganizationBPName4 is not initial
            then concat( concat( bp.OrganizationBPName2, bp.OrganizationBPName3 ), bp.OrganizationBPName4 )
        when bp.OrganizationBPName1 is not initial
            then bp.OrganizationBPName1
        else bp.LastName
      end                as POSupplierName
}
