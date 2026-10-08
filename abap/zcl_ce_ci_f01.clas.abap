CLASS zcl_ce_ci_f01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS requested
      IMPORTING
        io_request TYPE REF TO if_rap_query_request
      EXPORTING
        et_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    CLASS-METHODS response
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_result   TYPE zcl_ce_ci_top=>tt_result.

    CLASS-METHODS main
      IMPORTING
        it_filters  TYPE if_rap_query_filter=>tt_name_range_pairs
        it_keys_pdf TYPE zcl_ce_ci_top=>tt_key_pdf OPTIONAL
      EXPORTING
        et_result   TYPE zcl_ce_ci_top=>tt_result.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS get_longtext_result_billing
      IMPORTING
        it_longtext_billing TYPE zcl_ce_ci_top=>tt_longtext_billing
        iv_billing          TYPE I_BillingDocumentTP-BillingDocument
        iv_longtextid       TYPE I_BillingDocumentTextTP-LongTextID
      RETURNING
        VALUE(rv_data)      TYPE string.

    CLASS-METHODS get_longtext_result_do
      IMPORTING
        it_longtext_do TYPE zcl_ce_ci_top=>tt_longtext_do
        iv_longtextid  TYPE string
        iv_do          TYPE I_OutboundDelivery-OutboundDelivery
      RETURNING
        VALUE(rv_data) TYPE string.
ENDCLASS.



CLASS ZCL_CE_CI_F01 IMPLEMENTATION.


  METHOD main.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "1. Build Param
    LOOP AT it_filters INTO  DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'SALESORGANIZATION'.
          DATA(lr_SalesOrganization) = CORRESPONDING zcl_ce_ci_top=>ry_string( ls_filter-range ).
        WHEN 'DATE'.
          DATA(lr_Date) = CORRESPONDING zcl_ce_ci_top=>ry_string( ls_filter-range ).
        WHEN 'PROFORMAINVOICE'.
          DATA(lr_ProFormaInvoice) = CORRESPONDING zcl_ce_ci_top=>ry_string( ls_filter-range ).
        WHEN 'CUSTOMER'.
          DATA(lr_Customer) = CORRESPONDING zcl_ce_ci_top=>ry_string( ls_filter-range ).
        WHEN 'ITEM'.
          DATA(lr_item) = CORRESPONDING zcl_ce_ci_top=>ry_string( ls_filter-range ).
      ENDCASE.
    ENDLOOP.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "2. Build Main Data
    "2.1. Get BP Customer
    SELECT FROM I_BusinessPartner AS a
    INNER JOIN I_BusinessPartnerCustomer AS b
        ON b~BusinessPartner = a~BusinessPartner
    FIELDS
        b~Customer,

        a~BusinessPartnerCategory,
        a~OrganizationBPName2,
        a~OrganizationBPName3,
        a~OrganizationBPName4,
        a~BusinessPartnerFullName
    WHERE
        a~SearchTerm1              LIKE 'AT%'
        AND b~CustomerAccountGroup = 'CUST'
    INTO TABLE @DATA(lt_bp_cust).
    IF lt_bp_cust IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_bp_cust BY Customer.
    DELETE ADJACENT DUPLICATES FROM lt_bp_cust COMPARING Customer.

    DATA: lr_bp_cust TYPE RANGE OF kunnr.
    LOOP AT lt_bp_cust INTO DATA(ls_bp_cust).
      APPEND INITIAL LINE TO lr_bp_cust ASSIGNING FIELD-SYMBOL(<lfs_bp_cust>).
      <lfs_bp_cust>-sign   = 'I'.
      <lfs_bp_cust>-option = 'EQ'.
      <lfs_bp_cust>-low    = ls_bp_cust-Customer.
    ENDLOOP.

    "2.2. Get keys
    IF it_keys_pdf IS INITIAL.
      SELECT FROM I_BillingDocumentItem AS a
      INNER JOIN I_BillingDocument AS b
          ON b~BillingDocument = a~BillingDocument
      FIELDS
          a~BillingDocument     AS ProFormaInvoice,
          a~BillingDocumentItem AS Item
      WHERE
          b~BillingDocumentType            = 'F8'
          AND b~BillingDocumentIsCancelled IS INITIAL
          AND b~CancelledBillingDocument   IS INITIAL
          AND b~PayerParty                 IN @lr_bp_cust
          AND ( ( a~SalesDocumentItemCategory  = 'TAN' AND a~BillingQuantity <> 0 )
             OR   a~SalesDocumentItemCategory IN ( 'CB99', 'CBLN' ) )
          AND b~SalesOrganization   IN @lr_salesorganization
          AND b~BillingDocumentDate IN @lr_date
          AND b~BillingDocument     IN @lr_proformainvoice
          AND b~PayerParty          IN @lr_customer
          AND a~BillingDocumentItem IN @lr_item
      GROUP BY
          a~BillingDocument,
          a~BillingDocumentItem
      INTO TABLE @DATA(lt_keys_raw).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      DATA(lt_keys) = lt_keys_raw.
    ELSE.
      lt_keys = it_keys_pdf.
    ENDIF.

    "2.3. Get bases
    SELECT FROM @lt_keys AS a
    LEFT JOIN I_BillingDocument AS b
        ON b~BillingDocument = a~proformainvoice
    FIELDS
        a~proformainvoice,
        a~item,
        b~PayerParty          AS Customer,
        b~BillingDocumentDate AS DateCI,
        b~IncotermsLocation1  AS PortOfLoading,
        b~IncotermsLocation2  AS PortOfDestination,
        b~IncotermsClassification,
        b~IncotermsTransferLocation
    INTO TABLE @DATA(lt_bases).

    "2.4. Get PO
    SELECT FROM I_BillingDocumentItem AS b
    LEFT JOIN I_SalesDocument AS c
        ON c~SalesDocument = b~SalesDocument
    FIELDS
        b~BillingDocument     AS ProFormaInvoice,
        b~BillingDocumentItem AS Item,

        c~PurchaseOrderByCustomer AS po
    FOR ALL ENTRIES IN @lt_keys
    WHERE
        b~BillingDocument         = @lt_keys-proformainvoice
        AND b~BillingDocumentItem = @lt_keys-item
    INTO TABLE @DATA(lt_po).

    "2.5. Get Material
    SELECT FROM I_BillingDocumentItem AS a
    LEFT JOIN I_ProductBasicTextTP_2 AS b
        ON b~Product   = a~Product
        AND b~Language = @sy-langu
    FIELDS
        a~BillingDocument     AS ProFormaInvoice,
        a~BillingDocumentItem AS Item,
        a~Product             AS Material,
        b~ProductLongText     AS aztid,
        a~BillingQuantityUnit,
        a~BillingQuantity     AS Quantity,
        a~TransactionCurrency,
        a~NetAmount           AS Amount
    FOR ALL ENTRIES IN @lt_keys
    WHERE
        a~BillingDocument         = @lt_keys-proformainvoice
        AND a~BillingDocumentItem = @lt_keys-item
    INTO TABLE @DATA(lt_material).

    "2.6. Get LOT
    IF lt_material IS NOT INITIAL.
      "(2) - Tìm Batch
      SELECT FROM I_BillingDocumentItem AS a
      FIELDS
        a~BillingDocument     AS ProformaInvoice,
        a~BillingDocumentItem AS Item,
        a~Product             AS Material,
        a~Batch
      FOR ALL ENTRIES IN @lt_keys
      WHERE
        a~BillingDocument         = @lt_keys-proformainvoice
        AND a~BillingDocumentItem = @lt_keys-item
      INTO TABLE @DATA(lt_batch).

      DATA: lr_mch1 TYPE RANGE OF I_ClfnObjectCharcValue-CharcValue,
            lr_mara TYPE RANGE OF I_ClfnObjectCharcValue-CharcValue.
      LOOP AT lt_batch INTO DATA(ls_batch).
        "Build MCH1 - Material + Batch
        IF ls_batch-batch IS NOT INITIAL.
          APPEND INITIAL LINE TO lr_mch1 ASSIGNING FIELD-SYMBOL(<lfs_mch1>).
          <lfs_mch1>-sign   = 'I'.
          <lfs_mch1>-option = 'EQ'.
          <lfs_mch1>-low    = |{ ls_batch-material WIDTH = 40 ALIGN = LEFT }{ ls_batch-batch }|.
        ENDIF.
        "Build MARA - Material
        APPEND INITIAL LINE TO lr_mara ASSIGNING FIELD-SYMBOL(<lfs_mara>).
        <lfs_mara>-sign   = 'I'.
        <lfs_mara>-option = 'EQ'.
        <lfs_mara>-low    = ls_batch-material.
      ENDLOOP.

      "(1) Tìm charc Value - MCH1
      SELECT FROM I_ClfnObjectCharcValue AS a
      INNER JOIN I_ClfnCharacteristic AS b
          ON b~CharcInternalID     = a~CharcInternalID
          AND b~TimeIntervalNumber = a~TimeIntervalNumber
      FIELDS
          a~ClfnObjectID,
          a~CharcValue
      WHERE
          b~Characteristic      = 'Z_SHADE_1'
          AND a~ClassType       = '023'
          AND a~ClfnObjectID    IN @lr_mch1
          AND a~ClfnObjectTable = 'MCH1'
      INTO TABLE @DATA(lt_mch1).

      "(3) Tìm charc Value - MARA
      SELECT FROM I_ClfnObjectCharcValue AS a
      INNER JOIN I_ClfnCharacteristic AS b
          ON b~CharcInternalID     = a~CharcInternalID
          AND b~TimeIntervalNumber = a~TimeIntervalNumber
      FIELDS
          a~ClfnObjectID,
          a~CharcValue
      WHERE
          b~Characteristic      = 'Z_CHE_DO_MAI'
          AND a~ClassType       = '001'
          AND a~ClfnObjectID IN @lr_mara
          AND a~ClfnObjectTable = 'MARA'
      INTO TABLE @DATA(lt_mara).
    ENDIF.

    "2.7. Long text Billing - I_BillingDocumentTP
    READ ENTITIES OF I_BillingDocumentTP FORWARDING PRIVILEGED
    ENTITY BillingDocument
    BY \_Text
    ALL FIELDS WITH VALUE #( FOR key IN lt_keys ( BillingDocument = key-proformainvoice ) )
    RESULT DATA(lt_longtext_billing)
    FAILED DATA(ls_failed_billing)
    REPORTED DATA(ls_reported_billing).

    "2.8. Long text DO - I_OutboundDeliveryTP
    "(1) - Lấy dữ liệu DO
    SELECT FROM I_BillingDocumentItem AS a
    INNER JOIN I_OutboundDelivery AS b
        ON b~OutboundDelivery = a~ReferenceSDDocument
    FIELDS
        a~BillingDocument     AS ProformaInvoice,
        a~BillingDocumentItem AS Item,
        b~OutboundDelivery AS do
    FOR ALL ENTRIES IN @lt_keys
    WHERE
        a~ReferenceSDDocumentCategory = 'J'
        AND a~BillingDocument         = @lt_keys-proformainvoice
        AND a~BillingDocumentItem     = @lt_keys-item
    INTO TABLE @DATA(lt_do).

    "(2) - lấy longtext DO qua I_OutboundDeliveryTP
    READ ENTITIES OF I_OutboundDeliveryTP FORWARDING PRIVILEGED
    ENTITY OutboundDelivery
    BY \_Text
    ALL FIELDS WITH VALUE #( FOR do IN lt_do ( OutboundDelivery = do-do ) )
    RESULT DATA(lt_longtext_do)
    FAILED DATA(ls_failed_do)
    REPORTED DATA(ls_reported_do).

    "2.9. Get Address + Telephone
    SELECT FROM i_businesspartner
    FIELDS
        BusinessPartner AS customer,
        \_CurrentDefaultAddress-AddressID
    WHERE BusinessPartner IN @lr_bp_cust
    INTO TABLE @DATA(lt_addressid).
    IF sy-subrc = 0.
      "(1) - Address
      SELECT FROM i_address_2 WITH PRIVILEGED ACCESS
      LEFT JOIN I_CountryText
          ON I_CountryText~Language = @sy-langu
          AND I_CountryText~Country = i_address_2~Country
      FIELDS
          i_address_2~AddressID,
          i_address_2~streetname        AS Street1,
          i_address_2~streetprefixname1 AS Street2,
          i_address_2~streetprefixname2 AS Street3,
          i_address_2~streetsuffixname1 AS Street4,
          i_address_2~CityName          AS City,
          i_address_2~Country,
          I_CountryText~CountryShortName AS CountryForeignName
      FOR ALL ENTRIES IN @lt_addressid
      WHERE AddressID = @lt_addressid-addressid
      INTO TABLE @DATA(lt_address).

      "(2) - Telephone
      SELECT FROM I_AddressPhoneNumber_2 WITH PRIVILEGED ACCESS
      FIELDS
          AddressID,
          PhoneAreaCodeSubscriberNumber AS Telephone,
          PhoneExtensionNumber
      FOR ALL ENTRIES IN @lt_addressid
      WHERE
          AddressID           = @lt_addressid-addressid
          AND AddressPersonID IS INITIAL
      INTO TABLE @DATA(lt_tel).
    ENDIF.

    "2.10. Get Size L W H
    IF lr_mara IS NOT INITIAL.
      SELECT FROM I_ClfnObjectCharcValue AS a
      INNER JOIN I_ClfnCharacteristic AS b
          ON b~CharcInternalID     = a~CharcInternalID
          AND b~TimeIntervalNumber = a~TimeIntervalNumber
      FIELDS
          a~ClfnObjectID,
          b~Characteristic,
          a~CharcValue
      WHERE
          b~Characteristic      IN ( 'Z_CHIEU_DAI', 'Z_CHIEU_RONG', 'Z_DO_DAY_2' )
          AND a~ClassType       = '001'
          AND a~ClfnObjectID IN @lr_mara
          AND a~ClfnObjectTable = 'MARA'
      INTO TABLE @DATA(lt_size_lwh).
    ENDIF.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "3. Build Result Data
    LOOP AT lt_keys INTO DATA(ls_key).
      APPEND INITIAL LINE TO et_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      "Key fields
      <lfs_result>-ProFormaInvoice = ls_key-proformainvoice.
      <lfs_result>-Item            = ls_key-item.

      READ TABLE lt_bases INTO DATA(ls_base) WITH KEY proformainvoice = ls_key-proformainvoice
                                                      item            = ls_key-item.
      IF sy-subrc = 0.
        "Base fields
        <lfs_result>-DateCI            = ls_base-dateci.
        <lfs_result>-Customer          = ls_base-customer.
        <lfs_result>-PortOfLoading     = ls_base-portofloading.
        <lfs_result>-PortOfDestination = ls_base-portofdestination.
        <lfs_result>-PriceTerm         = |{ ls_base-IncotermsClassification } |
                                         && ls_base-IncotermsTransferLocation.

        READ TABLE lt_bp_cust INTO ls_bp_cust WITH KEY Customer = ls_base-customer.
        IF sy-subrc = 0.
          "ToCI field
          <lfs_result>-ToCI = COND #( WHEN ls_bp_cust-BusinessPartnerCategory = '2' THEN ls_bp_cust-OrganizationBPName2
                                                                                         && ls_bp_cust-OrganizationBPName3
                                                                                         && ls_bp_cust-OrganizationBPName4
                                      WHEN ls_bp_cust-BusinessPartnerCategory = '1' THEN ls_bp_cust-BusinessPartnerFullName ).

          READ TABLE lt_addressid INTO DATA(ls_addressid) WITH KEY customer = ls_base-customer.
          IF sy-subrc = 0.
            "Address field
            READ TABLE lt_address INTO DATA(ls_address) WITH KEY AddressID = ls_addressid-addressid.
            IF sy-subrc = 0.
              DATA(lt_parts) = VALUE string_table( ( CONV string( ls_address-street1 ) )
                                                   ( CONV string( ls_address-street2 ) )
                                                   ( CONV string( ls_address-street3 ) )
                                                   ( CONV string( ls_address-street4 ) )
                                                   ( CONV string( ls_address-city ) )
                                                   ( CONV string( ls_address-countryforeignname ) ) ).
              DELETE lt_parts WHERE TABLE_line IS INITIAL.
              <lfs_result>-AddCI = concat_lines_of( table = lt_parts
                                                    sep   = `, ` ).
            ENDIF.
            "Tel field
            READ TABLE lt_tel INTO DATA(ls_tel) WITH KEY AddressID = ls_addressid-addressid.
            IF sy-subrc = 0.
              <lfs_result>-TelCI = COND #( WHEN ls_tel-PhoneExtensionNumber IS NOT INITIAL
                                           THEN |{ ls_tel-telephone }-{ ls_tel-PhoneExtensionNumber }|
                                           ELSE ls_tel-telephone ).
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      "PO field
      READ TABLE lt_po INTO DATA(ls_po) WITH KEY proformainvoice = ls_key-proformainvoice
                                                 item            = ls_key-item.
      IF sy-subrc = 0.
        <lfs_result>-po = ls_po-po.
      ENDIF.

      "Material field
      READ TABLE lt_material INTO DATA(ls_material) WITH KEY proformainvoice = ls_key-proformainvoice
                                                             item            = ls_key-item.
      IF sy-subrc = 0.
        <lfs_result>-Material            = ls_material-material.
        <lfs_result>-aztid               = ls_material-aztid.
        <lfs_result>-BillingQuantityUnit = ls_material-BillingQuantityUnit.
        <lfs_result>-Quantity            = ls_material-quantity.
        <lfs_result>-TransactionCurrency = ls_material-TransactionCurrency.
        <lfs_result>-Amount              = ls_material-amount.
        <lfs_result>-UnitPrice           = COND #( WHEN <lfs_result>-quantity IS NOT INITIAL
                                                   THEN <lfs_result>-amount / <lfs_result>-Quantity
                                                   ELSE 0 ).
        "Size L W H
        READ TABLE lt_size_lwh INTO DATA(ls_size) WITH KEY ClfnObjectID   = ls_material-material
                                                           Characteristic = 'Z_CHIEU_DAI'.
        IF sy-subrc = 0.
          <lfs_result>-SizeL = ls_size-CharcValue.
        ENDIF.

        READ TABLE lt_size_lwh INTO ls_size WITH KEY ClfnObjectID   = ls_material-material
                                                     Characteristic = 'Z_CHIEU_RONG'.
        IF sy-subrc = 0.
          <lfs_result>-SizeW = ls_size-CharcValue.
        ENDIF.

        READ TABLE lt_size_lwh INTO ls_size WITH KEY ClfnObjectID   = ls_material-material
                                                     Characteristic = 'Z_DO_DAY_2'.
        IF sy-subrc = 0.
          <lfs_result>-SizeH = ls_size-CharcValue.
        ENDIF.
      ENDIF.

      "LOT field: D_(1)_(2)(3)
      READ TABLE lt_batch INTO ls_batch WITH KEY proformainvoice = ls_key-proformainvoice
                                                 item            = ls_key-item.
      IF sy-subrc = 0.
        IF ls_batch-batch IS NOT INITIAL.
          "(2) - Batch (cắt 6 ký tự đầu của batch: đang là định dạng yymmdd --> chuyển sang định dạng mmddyyyy)
          DATA(lv_batch_raw) = ls_batch-Batch+0(6). "định dạng yymmdd
          IF lv_batch_raw <> '000000' AND lv_batch_raw CO '0123456789'.
            "Chuyển sang định dạng mmddyyyy
            DATA(lv_batch_date) = |{ lv_batch_raw+2(2) }{ lv_batch_raw+4(2) }20{ lv_batch_raw+0(2) }|.
          ENDIF.

          "(1) - MCH1 - CharcValue
          DATA(lv_batch_value) = |{ ls_batch-material WIDTH = 40 ALIGN = LEFT }{ ls_batch-batch }|.

          READ TABLE lt_mch1 INTO DATA(ls_mch1) WITH KEY ClfnObjectID = lv_batch_value.
          IF sy-subrc = 0.
            DATA(lv_mch1) = ls_mch1-CharcValue.
          ENDIF.
        ENDIF.

        "(3) - MARA - CharcValue
        READ TABLE lt_mara INTO DATA(ls_mara) WITH KEY ClfnObjectID = ls_batch-material.
        IF sy-subrc = 0.
          DATA(lv_mara) = ls_mara-CharcValue.
        ENDIF.
      ENDIF.

      IF lv_batch_date IS NOT INITIAL AND lv_mch1 IS NOT INITIAL AND lv_mara IS NOT INITIAL.
        <lfs_result>-lot = |D_{ lv_mch1 }_{ lv_batch_date }{ lv_mara }|.
      ENDIF.

      CLEAR: lv_batch_raw,
             lv_batch_date,
             lv_batch_value,
             lv_mch1,
             lv_mara.

      "Long text Billing field
      "Vessel's Name - Z038
      <lfs_result>-VesselName = get_longtext_result_billing( it_longtext_billing = lt_longtext_billing
                                                             iv_billing          = ls_key-proformainvoice
                                                             iv_longtextid       = 'Z038' ).

      "Longtext DO Field
      READ TABLE lt_do INTO DATA(ls_do) WITH KEY proformainvoice = ls_key-proformainvoice
                                                 item            = ls_key-item.
      IF sy-subrc = 0.
        "ETD - Z010
        <lfs_result>-etd = get_longtext_result_do( it_longtext_do = lt_longtext_do
                                                   iv_do          = ls_do-do
                                                   iv_longtextid  = 'Z010' ).
        "Container No - Z006
        <lfs_result>-ContainerNo = get_longtext_result_do( it_longtext_do = lt_longtext_do
                                                           iv_do          = ls_do-do
                                                           iv_longtextid  = 'Z006' ).

      ENDIF.

      "Country of Origin - Fix Text VIETNAM
      <lfs_result>-CountryOfOrigin = 'VIETNAM'.
    ENDLOOP.
  ENDMETHOD.


  METHOD requested.
    TRY.
        et_filters = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        "handle exception
    ENDTRY.
  ENDMETHOD.


  METHOD response.
    " ── a. AGGREGATION ──
    TRY.
        DATA(lo_aggregation) = io_request->get_aggregation( ).
        DATA(lt_group_by)    = lo_aggregation->get_grouped_elements( ).    " table of string
        DATA(lt_agg_elems)   = lo_aggregation->get_aggregated_elements( ). " table of ty_aggregation_element
      CATCH cx_rap_query_provider.
    ENDTRY.

    " ── b. RESPONSE ────────────────────────────────
    DATA(lv_total) = lines( ct_result ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( CONV int8( lv_total ) ).
    ENDIF.
    " ── c. HANDLE SORT ─────────────────────────────────────
    DATA(lt_sort) = io_request->get_sort_elements( ).
    IF lt_sort IS NOT INITIAL.
      DATA lt_sort_order TYPE abap_sortorder_tab.
      LOOP AT lt_sort INTO DATA(ls_sort).
        APPEND VALUE #(
            name       = ls_sort-element_name
            descending = ls_sort-descending
        ) TO lt_sort_order.
      ENDLOOP.
      SORT ct_result BY (lt_sort_order).
    ELSE.
      " Default sort
    ENDIF.


    " ── d. PAGING ──────────────────────────────────────────
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).

    IF lv_top = if_rap_query_paging=>page_size_unlimited.
      lv_top = lv_total.
    ENDIF.

    IF lv_skip > 0.
      DELETE ct_result TO lv_skip.
    ENDIF.

    IF lv_top < lines( ct_result ).
      DELETE ct_result FROM lv_top + 1.
    ENDIF.

    io_response->set_data( ct_result ).
  ENDMETHOD.


  METHOD get_longtext_result_billing.
    READ TABLE it_longtext_billing INTO DATA(ls_longtext) WITH KEY entity
      COMPONENTS %key-BillingDocument = iv_billing
                 %key-Language        = sy-langu
                 %key-LongTextID      = iv_longtextid.
    IF sy-subrc = 0.
      rv_data = ls_longtext-LongText.
    ENDIF.
  ENDMETHOD.


  METHOD get_longtext_result_do.
    READ TABLE it_longtext_do INTO DATA(ls_longtext) WITH KEY entity
      COMPONENTS %key-OutboundDelivery = iv_do
                 %key-LongTextID = iv_longtextid
                 %key-Language = sy-langu.
    IF sy-subrc = 0.
      rv_data = ls_longtext-LongText.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
