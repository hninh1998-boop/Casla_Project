CLASS zcl_ce_ci_f01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_sqm,
             proformainvoice TYPE vbeln,
             item            TYPE posnr,
             sqm             TYPE p LENGTH 16 DECIMALS 3,
           END OF ty_sqm,
           tt_sqm TYPE HASHED TABLE OF ty_sqm WITH UNIQUE KEY proformainvoice item.

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
        "abap_true: lấy các dòng cho bảng Packing List (item), thay cho dòng TAN (header)
        iv_pl_items TYPE abap_bool DEFAULT abap_false
      EXPORTING
        et_result   TYPE zcl_ce_ci_top=>tt_result.

    CLASS-METHODS amount_to_words
      IMPORTING
        iv_amount       TYPE zce_ci-Amount
        iv_currency     TYPE zce_ci-TransactionCurrency
      RETURNING
        VALUE(rv_words) TYPE string.

    "DISCOUNT (ZC03) / CLAIM-CREDIT (ZC01, ZC02) của 1 Pro-forma invoice
    CLASS-METHODS get_adjustments
      IMPORTING
        iv_proformainvoice TYPE vbeln
      EXPORTING
        ev_discount        TYPE zce_ci-Amount
        ev_claim           TYPE zce_ci-Amount.

    "SQM (m2) theo I_ProductUnitsOfMeasure - Packing List
    CLASS-METHODS get_sqm
      IMPORTING
        it_data       TYPE zcl_ce_ci_top=>tt_result
      RETURNING
        VALUE(rt_sqm) TYPE tt_sqm.
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

    CLASS-METHODS three_digits_to_words
      IMPORTING
        iv_number       TYPE i
      RETURNING
        VALUE(rv_words) TYPE string.
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
      "In PDF / Excel: lấy các dòng đang chọn
      SELECT FROM I_BillingDocumentItem AS a
      FIELDS
          a~BillingDocument     AS ProFormaInvoice,
          a~BillingDocumentItem AS Item,
          a~SalesDocumentItemCategory AS ItemCategory
      FOR ALL ENTRIES IN @it_keys_pdf
      WHERE
          a~BillingDocument         = @it_keys_pdf-proformainvoice
          AND a~BillingDocumentItem = @it_keys_pdf-item
      INTO TABLE @DATA(lt_keys_sel).

      "Chỉ lấy item có item category = TAN
      "(Packing List: mỗi dòng TAN được tách theo batch của delivery ở cuối method - xem iv_pl_items)
      DELETE lt_keys_sel WHERE ItemCategory <> 'TAN'.

      IF lt_keys_sel IS INITIAL.
        RETURN.
      ENDIF.
      lt_keys = CORRESPONDING #( lt_keys_sel ).
      SORT lt_keys BY ProFormaInvoice Item.
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
    "AZT ID: MaterialByCustomer trên Sales order item của billing item
    SELECT FROM I_BillingDocumentItem AS a
    LEFT JOIN I_SalesOrderItem AS b
        ON  b~SalesOrder     = a~SalesDocument
        AND b~SalesOrderItem = a~SalesDocumentItem
    FIELDS
        a~BillingDocument     AS ProFormaInvoice,
        a~BillingDocumentItem AS Item,
        a~Product             AS Material,
        a~SalesDocumentItemCategory AS ItemCategory,
        a~ReferenceSDDocument,
        a~ReferenceSDDocumentItem,
        b~MaterialByCustomer  AS aztid,
        a~BillingQuantityUnit,
        a~BillingQuantity     AS Quantity,
        a~TransactionCurrency,
        a~NetAmount           AS Amount
    FOR ALL ENTRIES IN @lt_keys
    WHERE
        a~BillingDocument         = @lt_keys-proformainvoice
        AND a~BillingDocumentItem = @lt_keys-item
    INTO TABLE @DATA(lt_material).

    "Amount: ConditionAmount của ZPR0, không có ZPR0 thì lấy ZPR2
    SELECT FROM I_BillingDocumentItemPrcgElmnt
    FIELDS
        BillingDocument     AS ProFormaInvoice,
        BillingDocumentItem AS Item,
        ConditionType,
        ConditionAmount
    FOR ALL ENTRIES IN @lt_keys
    WHERE
        BillingDocument         = @lt_keys-proformainvoice
        AND BillingDocumentItem = @lt_keys-item
        AND ConditionType       IN ( 'ZPR0', 'ZPR2' )
    INTO TABLE @DATA(lt_price).

    "2.6. Get LOT
    IF lt_material IS NOT INITIAL.
      "(2) - Tìm Batch cho LOT
      TYPES: BEGIN OF ty_lot_batch,
               proformainvoice TYPE vbeln,
               item            TYPE posnr,
               material        TYPE matnr,
               batch           TYPE I_BillingDocumentItem-Batch,
               do_item         TYPE posnr,                                      "item delivery của batch
               qty             TYPE I_OutboundDeliveryItem-ActualDeliveryQuantity,
               lot             TYPE string,                                     "lot của riêng batch này
             END OF ty_lot_batch.
      DATA lt_batch TYPE STANDARD TABLE OF ty_lot_batch WITH EMPTY KEY.

      "- Dòng TAN: batch lấy từ delivery (I_OutboundDeliveryItem)
      "  + Item delivery tương ứng (DeliveryDocumentItemCategory = TAN) có batch → lấy batch đó
      "  + Item delivery TAN không có batch (tách batch) → lấy batch của các item con
      "    (HigherLvlItmOfBatSpltItm = item delivery tương ứng, item con là CB99 nên không lọc TAN)
      DATA(lt_tan) = lt_material.
      DELETE lt_tan WHERE ItemCategory <> 'TAN' OR ReferenceSDDocument IS INITIAL.

      IF lt_tan IS NOT INITIAL.
        SELECT FROM I_OutboundDeliveryItem
        FIELDS
            OutboundDelivery,
            OutboundDeliveryItem,
            HigherLvlItmOfBatSpltItm,
            DeliveryDocumentItemCategory,
            Batch,
            ActualDeliveryQuantity
        FOR ALL ENTRIES IN @lt_tan
        WHERE
            OutboundDelivery = @lt_tan-ReferenceSDDocument
            AND ( OutboundDeliveryItem     = @lt_tan-ReferenceSDDocumentItem
               OR HigherLvlItmOfBatSpltItm = @lt_tan-ReferenceSDDocumentItem )
        INTO TABLE @DATA(lt_do_item).
        SORT lt_do_item BY OutboundDelivery OutboundDeliveryItem.

        LOOP AT lt_tan INTO DATA(ls_tan).
          READ TABLE lt_do_item INTO DATA(ls_do_item) WITH KEY OutboundDelivery     = ls_tan-ReferenceSDDocument
                                                               OutboundDeliveryItem = ls_tan-ReferenceSDDocumentItem
                                                               BINARY SEARCH.
          IF sy-subrc <> 0 OR ls_do_item-DeliveryDocumentItemCategory <> 'TAN'.
            CONTINUE.
          ENDIF.

          IF ls_do_item-Batch IS NOT INITIAL.
            APPEND VALUE #( proformainvoice = ls_tan-ProFormaInvoice
                            item            = ls_tan-Item
                            material        = ls_tan-Material
                            batch           = ls_do_item-Batch
                            do_item         = ls_do_item-OutboundDeliveryItem
                            qty             = ls_do_item-ActualDeliveryQuantity ) TO lt_batch.
          ELSE.
            LOOP AT lt_do_item INTO ls_do_item WHERE OutboundDelivery         = ls_tan-ReferenceSDDocument
                                                 AND HigherLvlItmOfBatSpltItm = ls_tan-ReferenceSDDocumentItem
                                                 AND Batch                    IS NOT INITIAL.
              APPEND VALUE #( proformainvoice = ls_tan-ProFormaInvoice
                              item            = ls_tan-Item
                              material        = ls_tan-Material
                              batch           = ls_do_item-Batch
                              do_item         = ls_do_item-OutboundDeliveryItem
                              qty             = ls_do_item-ActualDeliveryQuantity ) TO lt_batch.
            ENDLOOP.
          ENDIF.
        ENDLOOP.
      ENDIF.

      "- Dòng khác TAN (chỉ hiện trên ALV): batch của chính billing item đó
      SELECT FROM I_BillingDocumentItem AS a
      FIELDS
        a~BillingDocument     AS ProformaInvoice,
        a~BillingDocumentItem AS Item,
        a~Product             AS Material,
        a~Batch
      FOR ALL ENTRIES IN @lt_keys
      WHERE
        a~BillingDocument               = @lt_keys-proformainvoice
        AND a~BillingDocumentItem       = @lt_keys-item
        AND a~SalesDocumentItemCategory <> 'TAN'
        AND a~Batch                     <> ''
      APPENDING CORRESPONDING FIELDS OF TABLE @lt_batch.
      SORT lt_batch BY proformainvoice item.

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

      "Không có batch nào thì bỏ qua, tránh select với range rỗng (lấy toàn bộ dữ liệu)
      IF lr_mch1 IS NOT INITIAL.
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
    ENDIF.

    "2.6b. Thông tin in user tự điền (nút Cập nhật thông tin in) - ztb_ci_text
    SELECT FROM zi_ci_text
    FIELDS
        ProFormaInvoice,
        Item,
        InvoiceNo,
        MBL,
        HBL,
        ETA
    FOR ALL ENTRIES IN @lt_keys
    WHERE
        ProFormaInvoice = @lt_keys-proformainvoice
        AND Item        = '000000'         "thông tin cấp header, lưu ở dòng item = 000000
    INTO TABLE @DATA(lt_ci_text).

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
        "Amount: ConditionAmount của ZPR0, không có thì ZPR2
        READ TABLE lt_price INTO DATA(ls_price) WITH KEY proformainvoice = ls_key-proformainvoice
                                                         item            = ls_key-item
                                                         ConditionType   = 'ZPR0'.
        IF sy-subrc <> 0.
          READ TABLE lt_price INTO ls_price WITH KEY proformainvoice = ls_key-proformainvoice
                                                     item            = ls_key-item
                                                     ConditionType   = 'ZPR2'.
        ENDIF.
        <lfs_result>-Amount    = COND #( WHEN sy-subrc = 0 THEN ls_price-ConditionAmount ).
        "Unit price = Amount / Quantity
        <lfs_result>-UnitPrice = COND #( WHEN <lfs_result>-Quantity IS NOT INITIAL
                                         THEN <lfs_result>-Amount / <lfs_result>-Quantity ).
        CLEAR ls_price.
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

      "LOT field - mỗi lot = D_(1)_(2)(3), mỗi lot 1 dòng, không lặp
      "Batch của từng dòng đã xác định ở bước 2.6 (TAN: theo delivery, khác TAN: batch của chính dòng)
      DATA lt_lot TYPE STANDARD TABLE OF string WITH EMPTY KEY.
      CLEAR lt_lot.

      LOOP AT lt_batch INTO ls_batch WHERE proformainvoice = ls_key-proformainvoice
                                       AND item            = ls_key-item.
        DATA(lv_batch_tabix) = sy-tabix.
        "(2) - Batch (cắt 6 ký tự đầu của batch: đang là định dạng yymmdd --> chuyển sang định dạng mmddyyyy)
        DATA(lv_batch_raw) = ls_batch-Batch+0(6). "định dạng yymmdd
        IF lv_batch_raw <> '000000' AND lv_batch_raw CO '0123456789'.
          "Chuyển sang định dạng mmddyyyy
          DATA(lv_batch_date) = |{ lv_batch_raw+2(2) }{ lv_batch_raw+4(2) }20{ lv_batch_raw+0(2) }|.
        ENDIF.

        "(1) - MCH1 - CharcValue (Z_SHADE_1 theo Material + Batch)
        DATA(lv_batch_value) = |{ ls_batch-material WIDTH = 40 ALIGN = LEFT }{ ls_batch-batch }|.

        READ TABLE lt_mch1 INTO DATA(ls_mch1) WITH KEY ClfnObjectID = lv_batch_value.
        IF sy-subrc = 0.
          DATA(lv_mch1) = ls_mch1-CharcValue.
        ENDIF.

        "(3) - MARA - CharcValue (Z_CHE_DO_MAI theo Material)
        READ TABLE lt_mara INTO DATA(ls_mara) WITH KEY ClfnObjectID = ls_batch-material.
        IF sy-subrc = 0.
          DATA(lv_mara) = ls_mara-CharcValue.
        ENDIF.

        IF lv_batch_date IS NOT INITIAL AND lv_mch1 IS NOT INITIAL AND lv_mara IS NOT INITIAL.
          DATA(lv_lot) = |D_{ lv_mch1 }_{ lv_batch_date }{ lv_mara }|.
          lt_batch[ lv_batch_tabix ]-lot = lv_lot. "Packing List: lot của riêng batch
          IF NOT line_exists( lt_lot[ table_line = lv_lot ] ).
            APPEND lv_lot TO lt_lot.
          ENDIF.
        ENDIF.

        CLEAR: lv_batch_raw,
               lv_batch_date,
               lv_batch_value,
               lv_mch1,
               lv_mara,
               lv_lot.
      ENDLOOP.

      <lfs_result>-lot = concat_lines_of( table = lt_lot
                                          sep   = cl_abap_char_utilities=>newline ).

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

      "Thông tin user tự điền (FS ghi "Điền text"): Invoice#, MB/L, HB/L, ETA - cấp header,
      "mọi dòng của Pro-forma invoice dùng chung
      READ TABLE lt_ci_text INTO DATA(ls_ci_text) WITH KEY ProFormaInvoice = ls_key-proformainvoice.
      IF sy-subrc = 0.
        <lfs_result>-Invoice = ls_ci_text-InvoiceNo.
        <lfs_result>-MBL     = ls_ci_text-MBL.
        <lfs_result>-HBL     = ls_ci_text-HBL.
        <lfs_result>-ETA     = ls_ci_text-ETA.
      ENDIF.
      CLEAR ls_ci_text.
    ENDLOOP.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "3. Bảng Packing List: mỗi batch của delivery là 1 dòng (FS: 17 SQM, 18 PCS, 21 LOT)
    "- Dòng TAN có batch          → 1 dòng
    "- Dòng TAN đã tách batch     → mỗi item con (HigherLvlItmOfBatSpltItm) 1 dòng
    "PCS = ActualDeliveryQuantity của item delivery, LOT = lot của riêng batch đó
    "Item của dòng tách ra chỉ là số thứ tự nội bộ trong invoice (không hiện lên form)
    IF iv_pl_items = abap_true.
      DATA: lt_pl_rows    TYPE zcl_ce_ci_top=>tt_result,
            lv_pl_seq     TYPE posnr,
            lv_pl_invoice TYPE vbeln.

      LOOP AT et_result INTO DATA(ls_res).
        "Đánh số lại từ 1 cho mỗi invoice
        IF ls_res-ProFormaInvoice <> lv_pl_invoice.
          lv_pl_invoice = ls_res-ProFormaInvoice.
          CLEAR lv_pl_seq.
        ENDIF.

        DATA(lv_split) = abap_false.
        LOOP AT lt_batch INTO DATA(ls_pl_batch) WHERE proformainvoice = ls_res-ProFormaInvoice
                                                  AND item            = ls_res-Item
                                                  AND do_item         IS NOT INITIAL.
          lv_split = abap_true.
          lv_pl_seq += 1.
          DATA(ls_pl_row)   = ls_res.
          ls_pl_row-Item     = lv_pl_seq.
          ls_pl_row-Quantity = ls_pl_batch-qty.
          ls_pl_row-LOT      = ls_pl_batch-lot.
          APPEND ls_pl_row TO lt_pl_rows.
        ENDLOOP.

        IF lv_split = abap_false.
          lv_pl_seq += 1.
          ls_pl_row      = ls_res.
          ls_pl_row-Item = lv_pl_seq.
          APPEND ls_pl_row TO lt_pl_rows.
        ENDIF.
      ENDLOOP.

      et_result = lt_pl_rows.
    ENDIF.
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

  METHOD amount_to_words.
    "VD: 1234.50 USD => ONE THOUSAND TWO HUNDRED THIRTY-FOUR DOLLARS AND FIFTY CENTS
    DATA: lt_scale       TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lv_abs         TYPE p LENGTH 16 DECIMALS 2,
          lv_integer     TYPE p LENGTH 16 DECIMALS 0,
          lv_cents       TYPE i,
          lv_group       TYPE i,
          lv_index       TYPE i,
          lv_group_words TYPE string.

    lt_scale = VALUE #( ( `` ) ( `THOUSAND` ) ( `MILLION` ) ( `BILLION` ) ( `TRILLION` ) ).

    lv_abs     = abs( iv_amount ).
    lv_integer = trunc( lv_abs ).
    lv_cents   = ( lv_abs - lv_integer ) * 100.

    "Form hiện chỉ dùng USD, tiền tệ khác tạm in mã tiền tệ
    DATA(lv_unit) = COND string( WHEN iv_currency <> 'USD' THEN iv_currency
                                 WHEN lv_integer = 1       THEN `DOLLAR`
                                 ELSE `DOLLARS` ).

    IF lv_integer = 0.
      rv_words = `ZERO`.
    ENDIF.

    "Tách từng nhóm 3 chữ số từ phải sang trái
    WHILE lv_integer > 0.
      lv_index   = lv_index + 1.
      lv_group   = lv_integer MOD 1000.
      lv_integer = lv_integer DIV 1000.
      IF lv_group = 0.
        CONTINUE.
      ENDIF.

      lv_group_words = three_digits_to_words( lv_group ).
      DATA(lv_scale) = lt_scale[ lv_index ].
      IF lv_scale IS NOT INITIAL.
        lv_group_words = |{ lv_group_words } { lv_scale }|.
      ENDIF.
      rv_words = COND #( WHEN rv_words IS INITIAL
                         THEN lv_group_words
                         ELSE |{ lv_group_words } { rv_words }| ).
    ENDWHILE.

    IF iv_amount < 0.
      rv_words = |MINUS { rv_words }|.
    ENDIF.

    rv_words = |{ rv_words } { lv_unit }|.

    IF lv_cents > 0.
      rv_words = |{ rv_words } AND { three_digits_to_words( lv_cents ) } |
              && COND string( WHEN lv_cents = 1 THEN `CENT` ELSE `CENTS` ).
    ENDIF.
  ENDMETHOD.


  METHOD three_digits_to_words.
    DATA: lt_ones       TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lt_tens       TYPE STANDARD TABLE OF string WITH EMPTY KEY,
          lv_rest_words TYPE string.

    lt_ones = VALUE #( ( `ONE` ) ( `TWO` ) ( `THREE` ) ( `FOUR` ) ( `FIVE` )
                       ( `SIX` ) ( `SEVEN` ) ( `EIGHT` ) ( `NINE` ) ( `TEN` )
                       ( `ELEVEN` ) ( `TWELVE` ) ( `THIRTEEN` ) ( `FOURTEEN` ) ( `FIFTEEN` )
                       ( `SIXTEEN` ) ( `SEVENTEEN` ) ( `EIGHTEEN` ) ( `NINETEEN` ) ).
    lt_tens = VALUE #( ( `TEN` ) ( `TWENTY` ) ( `THIRTY` ) ( `FORTY` ) ( `FIFTY` )
                       ( `SIXTY` ) ( `SEVENTY` ) ( `EIGHTY` ) ( `NINETY` ) ).

    DATA(lv_hundreds) = iv_number DIV 100.
    DATA(lv_rest)     = iv_number MOD 100.

    IF lv_hundreds > 0.
      rv_words = |{ lt_ones[ lv_hundreds ] } HUNDRED|.
    ENDIF.

    IF lv_rest = 0.
      RETURN.
    ENDIF.

    IF lv_rest < 20.
      lv_rest_words = lt_ones[ lv_rest ].
    ELSE.
      DATA(lv_ten) = lv_rest DIV 10.
      DATA(lv_one) = lv_rest MOD 10.
      lv_rest_words = lt_tens[ lv_ten ].
      IF lv_one > 0.
        lv_rest_words = |{ lv_rest_words }-{ lt_ones[ lv_one ] }|.
      ENDIF.
    ENDIF.

    rv_words = COND #( WHEN rv_words IS INITIAL
                       THEN lv_rest_words
                       ELSE |{ rv_words } { lv_rest_words }| ).
  ENDMETHOD.

  METHOD get_adjustments.
    CLEAR: ev_discount, ev_claim.

    "DISCOUNT (as for free sample) - ZC03
    SELECT SUM( ConditionAmount )
      FROM I_BillingDocumentItemPrcgElmnt
      WHERE BillingDocument = @iv_proformainvoice
        AND ConditionType   = 'ZC03'
      INTO @DATA(lv_discount).
    ev_discount = lv_discount.

    "CLAIM/CREDIT - ZC01, ZC02
    SELECT SUM( ConditionAmount )
      FROM I_BillingDocumentItemPrcgElmnt
      WHERE BillingDocument = @iv_proformainvoice
        AND ConditionType   IN ( 'ZC01', 'ZC02' )
      INTO @DATA(lv_claim).
    ev_claim = lv_claim.
  ENDMETHOD.


  METHOD get_sqm.
    "1 đơn vị AlternativeUnit = QuantityNumerator / QuantityDenominator đơn vị BaseUnit
    "- AlternativeUnit = M2, BaseUnit <> M2: m2 = Quantity * Denominator / Numerator
    "- BaseUnit = M2, AlternativeUnit = đơn vị bán (PC...): m2 = Quantity * Numerator / Denominator
    IF it_data IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM I_Product AS a
    INNER JOIN I_ProductUnitsOfMeasure AS b
        ON b~Product = a~Product
    FIELDS
        a~Product,
        a~BaseUnit,
        b~AlternativeUnit,
        b~QuantityNumerator,
        b~QuantityDenominator
    FOR ALL ENTRIES IN @it_data
    WHERE
        a~Product = @it_data-Material
    INTO TABLE @DATA(lt_uom).

    LOOP AT it_data INTO DATA(ls_data).
      DATA(ls_sqm) = VALUE ty_sqm( proformainvoice = ls_data-ProFormaInvoice
                                   item            = ls_data-Item ).

      READ TABLE lt_uom INTO DATA(ls_uom) WITH KEY Product         = ls_data-Material
                                                   AlternativeUnit = 'M2'.
      IF sy-subrc = 0 AND ls_uom-BaseUnit <> 'M2' AND ls_uom-QuantityNumerator <> 0.
        ls_sqm-sqm = ls_data-Quantity * ls_uom-QuantityDenominator / ls_uom-QuantityNumerator.
      ELSE.
        READ TABLE lt_uom INTO ls_uom WITH KEY Product         = ls_data-Material
                                               BaseUnit        = 'M2'
                                               AlternativeUnit = ls_data-BillingQuantityUnit.
        IF sy-subrc = 0 AND ls_uom-QuantityDenominator <> 0.
          ls_sqm-sqm = ls_data-Quantity * ls_uom-QuantityNumerator / ls_uom-QuantityDenominator.
        ENDIF.
      ENDIF.

      INSERT ls_sqm INTO TABLE rt_sqm.
      CLEAR ls_uom.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
