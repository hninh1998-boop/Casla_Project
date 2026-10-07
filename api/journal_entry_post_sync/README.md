# Journal Entry - Post (Synchronous)

- Service: `JournalEntryCreateRequestConfirmation_In` (SOAP, đồng bộ)
- Communication scenario: `SAP_COM_0002` (Finance - Posting Integration)
- Endpoint: `https://<host>-api.s4hana.cloud.sap/sap/bc/srt/scs_ext/sap/journalentrycreaterequestconfi`
- Namespace: `http://sap.com/xi/SAPSCORE/SFIN`
- Code gọi API: `abap/zcl_dntt_je_api.clas.abap`

## File trong thư mục

| File | Nội dung |
|---|---|
| `JournalEntryCreateRequestConfirmation_In.wsdl` | WSDL tải từ Communication Arrangement SAP_COM_0002 (icon tải ở cột WSDL/Service Metadata, dòng *Journal Entry - Post (Synchronous)*) |
| `payload_*.xml` | Payload mẫu của BA / request-response thực tế để đối chiếu |

## Lưu ý từ WSDL (đã xác nhận)

- `MessageHeader`: `ID` (≤35) → `CreationDateTime` (dạng `yyyy-mm-ddThh:mm:ssZ`) → `TestDataIndicator`
- `JournalEntry` theo đúng thứ tự: `OriginalReferenceDocumentType`, `BusinessTransactionType`, `AccountingDocumentType`,
  `DocumentHeaderText`, `CreatedByUser`, `CompanyCode`, `DocumentDate`, `PostingDate`, ..., `ExchangeRateDate`, ...,
  `Item*`, `DebtorItem*`, `CreditorItem*`, `ProductTaxItem*`, `WithholdingTaxItem*`
- `ExchangeRateDate` có trong `JournalEntry` (kiểu Date, không bắt buộc) - nằm sau `PostingDate`
- Response: `JournalEntryBulkCreateConfirmation` → `JournalEntryCreateConfirmation*` (MessageHeader, JournalEntryCreateConfirmation/AccountingDocument, Log) → `Log`

## CreditorItem (xác nhận từ payload BA - HTTP 200)

```
CreditorItem
  ReferenceDocumentItem, Creditor, AmountInTransactionCurrency(@currencyCode), DebitCreditCode,
  DocumentItemText, AssignmentReference, Reference1/2/3IDByBusinessPartner,
  CashDiscountTerms   { DueCalculationBaseDate, NetPaymentDays }
  PaymentDetails      { PaymentMethod, BPBankAccountInternalID }
  DownPaymentTerms    { SpecialGLCode, TargetSpecialGLCode, ProfitCenter }   <- ProfitCenter ở ĐÂY
```

- `ProfitCenter` đặt trực tiếp trong `CreditorItem` bị SAP **bỏ qua không báo lỗi**
  → lỗi `F5 808 Field Profit Ctr is a required field for G/L account ...` (xem `payload_A4_*`).
- `ProfitCenter` gửi dạng `671001` (không cần thêm số 0) vẫn được nhận.

| File | Nội dung |
|---|---|
| `payload_BA_request_ok.xml` | Payload BA test Postman - chạy được |
| `payload_A4_request_profitcenter_error.xml` / `payload_A4_response_profitcenter_error.xml` | Request sai vị trí ProfitCenter + response lỗi |
