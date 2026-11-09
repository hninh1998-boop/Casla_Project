@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Journal Entry'
@ObjectModel.usageType: {
    sizeCategory: #S,
    serviceQuality: #A,
    dataClass: #MIXED
}
@ObjectModel.dataCategory: #VALUE_HELP
define view entity zvh_je_mapim
  as select from I_AccountingDocumentJournal( P_Language: $session.system_language )
{
  key CompanyCode,
  key AccountingDocument,
  key Ledger,
  key FiscalYear,
  key LedgerGLLineItem
}
