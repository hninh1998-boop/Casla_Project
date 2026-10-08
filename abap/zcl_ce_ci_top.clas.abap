CLASS zcl_ce_ci_top DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_result           TYPE STANDARD TABLE OF zce_ci,
           ry_string           TYPE RANGE OF string,
           tt_longtext_billing TYPE TABLE FOR READ RESULT I_BillingDocumentTP\\BillingDocument\_Text,
           tt_longtext_do      TYPE TABLE FOR READ RESULT I_OutboundDeliveryTP\\OutboundDelivery\_Text.

    TYPES: BEGIN OF ty_key_pdf,
             ProFormaInvoice TYPE vbeln,
             Item            TYPE posnr,
           END OF ty_key_pdf,
           tt_key_pdf TYPE STANDARD TABLE OF ty_key_pdf.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CE_CI_TOP IMPLEMENTATION.
ENDCLASS.
