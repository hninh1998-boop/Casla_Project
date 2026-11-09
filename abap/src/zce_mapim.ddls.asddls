@EndUserText.label: 'Custom Entity - Mappping Inv. - Mat.doc.'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_MAPIM'
@Metadata.allowExtensions: true
define root custom entity zce_mapim
{
  key PONo                          : ebeln; //Line 50 - I_PURCHASEORDERHISTORYAPI01-PurchaseOrder
  key POItem                        : ebelp; //Line 60 - I_PURCHASEORDERHISTORYAPI01-PurchaseOrderItem
  key MatDoc                        : mblnr; //Line 120 - I_PurchaseOrderHistoryAPI01-PurchasingHistoryDocument
  key MatDocItem                    : mblpo; //Line 130 - I_PurchaseOrderHistoryAPI01-PurchasingHistoryDocumentItem
  key GRCategory                    : abap.char(1);
  key Inv                           : mblnr; //Line 230 - I_PurchaseOrderHistoryAPI01-PurchasingHistoryDocument
  key InvItem                       : mblpo; //Line 240 - I_PurchaseOrderHistoryAPI01-PurchasingHistoryDocumentItem
  key IVCategory                    : abap.char(1);
  key GRFiscalYear                  : mjahr;
  key InvFiscalYear                 : mjahr;
      FiscalYear                    : mjahr; //Line 140 - I_PurchaseOrderHistoryAPI01-PurchasingHistoryDocumentYear
      CompanyCode                   : bukrs; //Line 10 - I_COMPANYCODE-CompanyCode
      POSupplier                    : lifnr; //Line 20 - I_PurchaseOrderAPI01-Supplier
      POSupplierName                : abap.string; //Line 30 - I_BUSINESSPARTNER - Logic Code
      GRBasedInv                    : abap.char(3); //Line 40 - Yes/No - I_PurchaseOrderItemAPI01-InvoiceIsGoodsReceiptBased

      MaterialCode                  : matnr; //Line 70 - I_PURCHASEORDERHISTORYAPI01-Material
      MaterialDescription           : txz01; //Line 80 - I_PurchaseOrderItemAPI01-PurchaseOrderItemText
      OrderPriceUnit                : meins; //Line 90 - I_PurchaseOrderHistoryAPI01-OrderPriceUnit
      DeliveryDoc                   : vbeln_vl; //Line 100 - I_PurchaseOrderHistoryAPI01-DeliveryDocument
      DeliveryItem                  : posnr_vl; //Line 110 - I_PurchaseOrderHistoryAPI01-DeliveryDocumentItem

      GRPostingDate                 : budat; //Line 150 - I_PurchaseOrderHistoryAPI01-PostingDate
      @Semantics.quantity.unitOfMeasure: 'OrderPriceUnit'
      GRQty                         : menge_d; //Line 160 - I_PurchaseOrderHistoryAPI01-Quantity
      @Semantics.amount.currencyCode: 'LocaCurrencyKey'
      GRAmountComCode               : dmbtr_cs; //Line 170 - I_PurchaseOrderHistoryAPI01-PurOrdAmountInCompanyCodeCrcy
      LocaCurrencyKey               : waers; //Gán cứng = VND
      @Semantics.amount.currencyCode: 'TransCur'
      GRAmountTransCode             : wrbtr_cs; //Line 180 - I_PurchaseOrderHistoryAPI01-PurchaseOrderAmount
      TransCur                      : waers; //Line 190 - I_PurchaseOrderHistoryAPI01-Currency
      JE                            : abap.char(10); //Line 200 - I_AccountingDocumentJournal-AccountingDocument
      InvoiceNo                     : xblnr1; //Line 210 - C_SupplierInvoiceItemDEX-SupplierInvoiceIDByInvcgParty
      InvoicePostingDate            : budat; //Line 220 - I_PurchaseOrderHistoryAPI01-PostingDate

      @Semantics.quantity.unitOfMeasure: 'OrderPriceUnit'
      InvoiceQty                    : menge_d; //Line 250 - I_PurchaseOrderHistoryAPI01-Quantity
      @Semantics.quantity.unitOfMeasure: 'OrderPriceUnit'
      AllocatedQty                  : menge_d; //Line 260 - I_PurchaseOrderHistoryAPI01-Quantity
      @Semantics.quantity.unitOfMeasure: 'OrderPriceUnit'
      GROpenQty                     : menge_d; //Line 270 - I_PurchaseOrderHistoryAPI01-Quantity
      @Semantics.quantity.unitOfMeasure: 'OrderPriceUnit'
      InvOpenQty                    : menge_d; //Line 280 - I_PurchaseOrderHistoryAPI01-Quantity
      @Semantics.amount.currencyCode: 'LocaCurrencyKey'
      InvoiceAmountComCode          : wrbtr_cs; //Line 290 - I_PurchaseOrderHistoryAPI01-PurOrdAmountInCompanyCodeCrcy
      //      InvoiceAmountComCodeF : abap.char(30);
      @Semantics.amount.currencyCode: 'Currency'
      InvoiceAmountTrans            : wrbtr_cs; //Line 300 - I_PurchaseOrderHistoryAPI01-PurchaseOrderAmount
      //      InvoiceAmountTransF   : abap.char(30);
      @Semantics.amount.currencyCode: 'Currency'
      INVNetPriceTransCur           : wrbtr_cs;
      //      INVNetPriceTransCurF  : abap.char(30); // field string - hiển thị đẹp

      Currency                      : waers; //Line 310 - I_PurchaseOrderHistoryAPI01-Currency
      InvoicingParty                : lifre; //Line 320 - C_SupplierInvoiceItemDEX-InvoicingParty
      InvoicingPartyName            : abap.string; //Line 330 - I_BUSINESSPARTNER - Logic Code
      GRFullyInvoiced               : abap.char(3); //Line 340 - Yes/No - Logic Code
      IVFullyInvoiced               : abap.char(3); //Line 350 - Yes/No - Logic Code
      POFullyInvoiced               : abap.char(3); //Line 360 - Yes/No - Logic Code
      @ObjectModel.text.element     : [ 'StorageLocationName' ]
      StorageLocation               : lgort_d;
      StorageLocationName           : abap.char(16);
      Plant                         : werks_d; //Line 370 - I_PurchaseOrderHistoryAPI01-Plant

      SortOrder                     : abap.numc(1);
      POType                        : abap.char(4);

      @Semantics.amount.currencyCode: 'POCurrency'
      PONetprice                    : abap.curr(11,2);
      POCurrency                    : waers;

      GhiChu                        : abap.string;

      ItemText                      : sgtxt; // I_MaterialDocumentItem_2-MaterialDocumentItemText
      HeaderText                    : bktxt; // I_MaterialDocumentHeader_2-MaterialDocumentHeaderText

      // Dev/NinhNH/ZMapIM/Add 4 field tính toán - v10.01
      @Semantics.amount.currencyCode: 'LocaCurrencyKey'
      AllocatedGRAmountComCode      : dmbtr_cs; // GRAmountComCode * AllocatedQty / GRQty
      @Semantics.amount.currencyCode: 'TransCur'
      AllocatedGRAmountTransCode    : wrbtr_cs; // GRAmountTransCode * AllocatedQty / GRQty
      @Semantics.amount.currencyCode: 'LocaCurrencyKey'
      AllocatedInvoiceAmountComCode : wrbtr_cs; // InvoiceAmountComCode * AllocatedQty / InvoiceQty
      @Semantics.amount.currencyCode: 'Currency'
      AllocatedInvoiceAmountTrans   : wrbtr_cs; // InvoiceAmountTrans * AllocatedQty / InvoiceQty

      // Dev/NinhNH/ZMapIM/Add Batch + Valuation type - FS v2 - 04.11.2026
      Batch                         : charg_d; //Line 42 - I_MaterialDocumentItem_2-Batch
      ValuationType                 : bwtar_d; //Line 43 - I_MaterialDocumentItem_2-InventoryValuationType

}
