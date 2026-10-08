@EndUserText.label: 'Custom Entity - Commercial Invoice'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_CI'
@Metadata.allowExtensions: true
define root custom entity zce_ci
{
  key ProFormaInvoice     : vbeln; // I_BillingDocument-BillingDocument
  key Item                : posnr; // I_BillingDocumentItem-BillingDocumentItem

      // I_BillingDocument
      DateCI              : fkdat; // BillingDocumentDate
      PortOfLoading       : abap.char(70); // IncotermsLocation1
      PortOfDestination   : abap.char(70); // IncotermsLocation2
      PriceTerm           : abap.char(35); // IncotermsClassification + IncotermsTransferLocation
      SalesOrganization   : vkorg; // SalesOrganization
      Customer            : kunrg; // PayerParty

      // I_BillingDocumentItem
      Material            : matnr; // Material
      @Semantics.quantity.unitOfMeasure: 'BillingQuantityUnit'
      Quantity            : fkimg; // BillingQuantity
      BillingQuantityUnit : vrkme; // BillingQuantityUnit
      TransactionCurrency : waerk; // TransactionCurrency
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      Amount              : abap.curr(15,2); // NetAmount

      // I_SalesDocument
      PO                  : bstkd; // PurchaseOrderByCustomer

      // I_ProductBasicTextTP_2
      AZTID               : abap.string; // ProductLongText

      // Long text Billing - I_BillingDocumentTP
      VesselName          : abap.string; // Z038

      // Long text DO - I_OutboundDeliveryTP
      ContainerNo         : abap.string; // Z006
      ETD                 : abap.string; // Z010

      // Get by logic
      ToCI                : abap.string; // I_BusinessPartner
      LOT                 : abap.string; // I_ClfnCharacteristic - I_ClfnObjectCharcValue
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      UnitPrice           : abap.curr(15,2); // Amount / Quantity

      // Fix data
      CountryOfOrigin     : abap.char(20); // VIETNAM

      // Chưa rõ logic
      Invoice             : abap.string;
      MBL                 : abap.string;
      HBL                 : abap.string;
      ETA                 : abap.string;
      HTSCode             : abap.string;
      QuartzSlabs         : abap.string;

      // Logic cho tem in - để ở cuối ALV
      AddCI               : abap.string; // Address BP
      TelCI               : abap.string; // Telephone BP

      // Logic cho tem in Packing List - để ở cuối ALV
      // I_ClfnCharacteristic - I_ClfnObjectCharcValue --> CharcValue
      SizeL               : abap.string; // Z_CHIEU_DAI
      SizeW               : abap.string; // Z_CHIEU_RONG
      SizeH               : abap.string; // Z_DO_DAY_2
}
