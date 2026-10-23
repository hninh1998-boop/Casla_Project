CLASS zcl_ce_sales_da_f01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      ty_result TYPE zce_sales_da,
      tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY,
      ry_string TYPE RANGE OF string,
      ry_date   TYPE RANGE OF d,
      tr_tochucbanhang  TYPE RANGE OF zce_sales_da-ToChucBanHang,
      tr_ngaychungtu    TYPE RANGE OF zce_sales_da-NgayChungTu,
      tr_doituongcongno TYPE RANGE OF zce_sales_da-DoiTuongCongNo,
      tr_mavattu        TYPE RANGE OF zce_sales_da-MaVatTu,
      tr_billingdoc     TYPE RANGE OF zce_sales_da-BillingDocument,
      tr_billingitem    TYPE RANGE OF zce_sales_da-BillingDocumentItem.

    CLASS-METHODS requested
      IMPORTING
        io_request TYPE REF TO if_rap_query_request
      EXPORTING
        et_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    CLASS-METHODS main
      IMPORTING
        it_filters TYPE if_rap_query_filter=>tt_name_range_pairs
      EXPORTING
        et_result  TYPE tt_result.

    CLASS-METHODS response
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_result   TYPE tt_result.
  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_uom,
        product             TYPE I_ProductUnitsOfMeasure-Product,
        alternativeunit     TYPE I_ProductUnitsOfMeasure-AlternativeUnit,
        baseunit            TYPE I_ProductUnitsOfMeasure-BaseUnit,
        quantitynumerator   TYPE I_ProductUnitsOfMeasure-QuantityNumerator,
        quantitydenominator TYPE I_ProductUnitsOfMeasure-QuantityDenominator,
      END OF ty_uom,
      tt_uom TYPE SORTED TABLE OF ty_uom WITH UNIQUE KEY product alternativeunit,

      BEGIN OF ty_prcg,
        billingdocument         TYPE I_BillingDocumentItemPrcgElmnt-BillingDocument,
        billingdocumentitem     TYPE I_BillingDocumentItemPrcgElmnt-BillingDocumentItem,
        conditiontype           TYPE I_BillingDocumentItemPrcgElmnt-ConditionType,
        conditioninactivereason TYPE I_BillingDocumentItemPrcgElmnt-ConditionInactiveReason,
        pricingprocedurestep    TYPE I_BillingDocumentItemPrcgElmnt-PricingProcedureStep,
        pricingprocedurecounter TYPE I_BillingDocumentItemPrcgElmnt-PricingProcedureCounter,
        conditionrateamount     TYPE I_BillingDocumentItemPrcgElmnt-ConditionRateAmount,
        conditionquantity       TYPE I_BillingDocumentItemPrcgElmnt-ConditionQuantity,
        conditionquantityunit   TYPE I_BillingDocumentItemPrcgElmnt-ConditionQuantityUnit,
        conditioncurrency       TYPE I_BillingDocumentItemPrcgElmnt-ConditionCurrency,
      END OF ty_prcg,
      " Condition đang active (ConditionInactiveReason trống) đứng trước
      tt_prcg TYPE SORTED TABLE OF ty_prcg
              WITH NON-UNIQUE KEY billingdocument billingdocumentitem conditiontype conditioninactivereason,

      BEGIN OF ty_rate_factor,
        fromcurrency TYPE I_BillingDocument-TransactionCurrency,
        tocurrency   TYPE I_CompanyCode-Currency,
        factor       TYPE decfloat34,
      END OF ty_rate_factor,
      tt_rate_factor TYPE SORTED TABLE OF ty_rate_factor WITH UNIQUE KEY fromcurrency tocurrency.

    CLASS-METHODS get_invoice_number
      IMPORTING
        iv_reference     TYPE clike
      RETURNING
        VALUE(rv_number) TYPE zce_sales_da-SoHoaDon.

    " Hệ số quy đổi của tỷ giá (vd. USD -> VND lưu theo tỷ lệ 1 : 1000 thì tỷ giá 26,9 = 26.900)
    CLASS-METHODS get_rate_factor
      IMPORTING
        iv_fromcurrency  TYPE I_BillingDocument-TransactionCurrency
        iv_tocurrency    TYPE I_CompanyCode-Currency
        iv_date          TYPE d
      CHANGING
        ct_factor        TYPE tt_rate_factor
      RETURNING
        VALUE(rv_factor) TYPE decfloat34.

    " Làm tròn 5 số lẻ, bỏ các số 0 thừa ở cuối, thêm dấu phân cách hàng nghìn
    " (26900.92000 -> 26,900.92 / 26900.00000 -> 26,900)
    CLASS-METHODS format_rate
      IMPORTING
        iv_value       TYPE decfloat34
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS get_base_unit_price
      IMPORTING
        is_prcg         TYPE ty_prcg
        iv_product      TYPE I_BillingDocumentItem-Product
        iv_baseunit     TYPE I_ProductUnitsOfMeasure-BaseUnit
        it_uom          TYPE tt_uom
      RETURNING
        VALUE(rv_price) TYPE decfloat34.

    CLASS-METHODS conv_customer_range
      IMPORTING
        it_range        TYPE if_rap_query_filter=>tt_range_option
      RETURNING
        VALUE(rt_range) TYPE tr_doituongcongno.

    CLASS-METHODS conv_product_range
      IMPORTING
        it_range        TYPE if_rap_query_filter=>tt_range_option
      RETURNING
        VALUE(rt_range) TYPE tr_mavattu.

    CLASS-METHODS conv_billingdoc_range
      IMPORTING
        it_range        TYPE if_rap_query_filter=>tt_range_option
      RETURNING
        VALUE(rt_range) TYPE tr_billingdoc.

    CLASS-METHODS product_to_internal
      IMPORTING
        iv_value        TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.



CLASS zcl_ce_sales_da_f01 IMPLEMENTATION.


  METHOD requested.
    TRY.
        et_filters = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR et_filters.
    ENDTRY.
  ENDMETHOD.


  METHOD main.
    DATA lr_tochucbanhang  TYPE tr_tochucbanhang.
    DATA lr_ngaychungtu    TYPE tr_ngaychungtu.
    DATA lr_sotokhai       TYPE ry_string.
    DATA lr_doituongcongno TYPE tr_doituongcongno.
    DATA lr_mavattu        TYPE tr_mavattu.
    DATA lr_mavattu_out    TYPE ry_string.
    DATA lr_billingdoc     TYPE tr_billingdoc.
    DATA lr_billingitem    TYPE tr_billingitem.

    TYPES:
      BEGIN OF lty_doc,
        billingdocument           TYPE zce_sales_da-BillingDocument,
        companycode               TYPE I_JournalEntry-CompanyCode,
        fiscalyear                TYPE I_JournalEntry-FiscalYear,
        originalreferencedocument TYPE I_JournalEntry-OriginalReferenceDocument,
        billingdocumentdate       TYPE I_BillingDocument-BillingDocumentDate,
        sotokhai                  TYPE string,
        soinv                     TYPE string,
        sohoadon                  TYPE zce_sales_da-SoHoaDon,
        maloaihinh                TYPE ZR_ECUS_TKHQ_HDR-Maloaihinh,
        cancelled                 TYPE abap_bool,
      END OF lty_doc.

    DATA lt_doc             TYPE SORTED TABLE OF lty_doc WITH UNIQUE KEY billingdocument.
    DATA lt_uom             TYPE tt_uom.
    DATA lt_prcg            TYPE tt_prcg.
    DATA lt_ecus_key        TYPE SORTED TABLE OF ZR_ECUS_TKHQ_HDR-Sotokhai WITH UNIQUE KEY table_line.
    DATA lv_baseunit        TYPE I_ProductUnitsOfMeasure-BaseUnit.
    DATA lv_giacongthuc     TYPE decfloat34.
    DATA lv_giaban          TYPE decfloat34.
    DATA lv_giainvkhachhang TYPE decfloat34.
    DATA lv_ngoaite         TYPE decfloat34.
    DATA lv_tygia           TYPE decfloat34.
    DATA lt_rate_factor     TYPE tt_rate_factor.

    CLEAR et_result.

    " ── 1. LẤY FILTER ──────────────────────────────────────
    LOOP AT it_filters INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'TOCHUCBANHANG'.
          lr_tochucbanhang  = CORRESPONDING #( ls_filter-range ).
        WHEN 'NGAYCHUNGTU'.
          lr_ngaychungtu    = CORRESPONDING #( ls_filter-range ).
        WHEN 'SOTOKHAI'.
          " Long text (Z020) -> lọc sau khi đọc text
          lr_sotokhai       = CORRESPONDING #( ls_filter-range ).
        WHEN 'DOITUONGCONGNO'.
          lr_doituongcongno = conv_customer_range( ls_filter-range ).
        WHEN 'MAVATTU'.
          " Mã vật tư toàn số lưu dạng có số 0 đầu (000000000300006762) -> pattern (vd. 3*) không khớp được
          " trong SELECT, nên có pattern thì lọc sau theo mã hiển thị (bỏ số 0 đầu)
          IF line_exists( ls_filter-range[ option = 'CP' ] ) OR line_exists( ls_filter-range[ option = 'NP' ] ).
            lr_mavattu_out  = CORRESPONDING #( ls_filter-range ).
          ELSE.
            lr_mavattu      = conv_product_range( ls_filter-range ).
          ENDIF.
        WHEN 'BILLINGDOCUMENT'.
          " Key: Object Page đọc 1 dòng theo Billing Document / Item
          lr_billingdoc     = conv_billingdoc_range( ls_filter-range ).
        WHEN 'BILLINGDOCUMENTITEM'.
          lr_billingitem    = CORRESPONDING #( ls_filter-range ).
      ENDCASE.
    ENDLOOP.

    " ── 2. BILLING DOCUMENT + ITEM ─────────────────────────
    " Loại Billing Type F5/F8, chỉ lấy Transaction Currency khác VND và item có số lượng khác 0
    SELECT FROM I_BillingDocument AS h
    INNER JOIN I_BillingDocumentItem AS i
        ON i~BillingDocument = h~BillingDocument
    LEFT OUTER JOIN I_BillingDocumentItemBasic AS b
        ON  b~BillingDocument     = i~BillingDocument
        AND b~BillingDocumentItem = i~BillingDocumentItem
    LEFT OUTER JOIN I_CompanyCode AS c
        ON c~CompanyCode = h~CompanyCode
    LEFT OUTER JOIN I_CountryText AS t
        ON  t~Country  = h~Country
        AND t~Language = @sy-langu
    LEFT OUTER JOIN I_Customer AS k
        ON k~Customer = h~PayerParty
    FIELDS
        h~BillingDocument,
        i~BillingDocumentItem,
        h~BillingDocumentDate,
        h~PayerParty,
        h~AccountingExchangeRate,
        h~Country,
        h~CompanyCode,
        h~FiscalYear,
        h~TransactionCurrency,
        i~Product,
        i~ProductGroup,
        b~YY1_HangTangFree_BDI AS HangTang,
        i~BillingQuantityInBaseUnit,
        i~BaseUnit,
        c~Currency    AS CompanyCodeCurrency,
        t~CountryName,
        k~CustomerName
    WHERE
        h~CompanyCode             IN @lr_tochucbanhang
        AND h~BillingDocumentDate IN @lr_ngaychungtu
        AND h~BillingDocumentType NOT IN ( 'F5', 'F8' )
        AND h~TransactionCurrency <> 'VND'
        AND h~PayerParty          IN @lr_doituongcongno
        AND h~BillingDocument     IN @lr_billingdoc
        AND i~BillingDocumentItem IN @lr_billingitem
        AND i~Product             IN @lr_mavattu
        AND i~BillingQuantityInBaseUnit <> 0
    INTO TABLE @DATA(lt_item).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Filter Mã vật tư dạng pattern: so theo mã hiển thị
    IF lr_mavattu_out IS NOT INITIAL.
      LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item_filter>).
        DATA(lv_product_out) = condense( |{ <ls_item_filter>-Product ALPHA = OUT }| ).
        IF lv_product_out NOT IN lr_mavattu_out.
          DELETE lt_item.
        ENDIF.
      ENDLOOP.
      IF lt_item IS INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    " Dữ liệu mức header của từng Billing Document
    LOOP AT lt_item INTO DATA(ls_item).
      INSERT VALUE #( billingdocument           = ls_item-BillingDocument
                      companycode               = ls_item-CompanyCode
                      fiscalyear                = ls_item-FiscalYear
                      originalreferencedocument = ls_item-BillingDocument
                      billingdocumentdate       = ls_item-BillingDocumentDate ) INTO TABLE lt_doc.
    ENDLOOP.

    " ── 3. CHỨNG TỪ FI: SỐ HOÁ ĐƠN + LOGIC HUỶ ─────────────
    SELECT FROM I_JournalEntry
    FIELDS
        CompanyCode,
        FiscalYear,
        AccountingDocument,
        OriginalReferenceDocument,
        DocumentReferenceID,
        PostingDate,
        IsReversal,
        IsReversed,
        ReverseDocument,
        ReverseDocumentFiscalYear
    FOR ALL ENTRIES IN @lt_doc
    WHERE
        CompanyCode                   = @lt_doc-companycode
        AND FiscalYear                = @lt_doc-fiscalyear
        AND OriginalReferenceDocument = @lt_doc-originalreferencedocument
        AND ReferenceDocumentType     = 'VBRK'
    INTO TABLE @DATA(lt_je).

    " Chứng từ đối ứng của chứng từ huỷ / bị huỷ
    DATA(lt_je_reverse) = lt_je.
    DELETE lt_je_reverse WHERE ReverseDocument IS INITIAL
                            OR ( IsReversed = abap_false AND IsReversal = abap_false ).
    IF lt_je_reverse IS NOT INITIAL.
      SELECT FROM I_JournalEntry
      FIELDS
          CompanyCode,
          FiscalYear,
          AccountingDocument,
          PostingDate
      FOR ALL ENTRIES IN @lt_je_reverse
      WHERE
          CompanyCode            = @lt_je_reverse-CompanyCode
          AND FiscalYear         = @lt_je_reverse-ReverseDocumentFiscalYear
          AND AccountingDocument = @lt_je_reverse-ReverseDocument
      INTO TABLE @DATA(lt_reverse).
      SORT lt_reverse BY CompanyCode FiscalYear AccountingDocument.
    ENDIF.

    SORT lt_je BY CompanyCode FiscalYear AccountingDocument.
    LOOP AT lt_je INTO DATA(ls_je).
      DATA(lv_billing) = CONV zce_sales_da-BillingDocument( ls_je-OriginalReferenceDocument ).
      ASSIGN lt_doc[ billingdocument = lv_billing ] TO FIELD-SYMBOL(<ls_doc>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF <ls_doc>-sohoadon IS INITIAL.
        <ls_doc>-sohoadon = get_invoice_number( ls_je-DocumentReferenceID ).
      ENDIF.

      " Chứng từ huỷ và chứng từ bị huỷ cùng nằm trong kỳ (tháng) của Ngày chứng từ -> loại khỏi báo cáo
      IF ( ls_je-IsReversed = abap_true OR ls_je-IsReversal = abap_true )
         AND ls_je-ReverseDocument IS NOT INITIAL.
        READ TABLE lt_reverse INTO DATA(ls_reverse)
             WITH KEY CompanyCode        = ls_je-CompanyCode
                      FiscalYear         = ls_je-ReverseDocumentFiscalYear
                      AccountingDocument = ls_je-ReverseDocument
             BINARY SEARCH.
        IF sy-subrc = 0
           AND ls_je-PostingDate(6)      = <ls_doc>-billingdocumentdate(6)
           AND ls_reverse-PostingDate(6) = <ls_doc>-billingdocumentdate(6).
          <ls_doc>-cancelled = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.

    DELETE lt_doc WHERE cancelled = abap_true.
    IF lt_doc IS INITIAL.
      RETURN.
    ENDIF.

    " ── 4. LONG TEXT HEADER: SỐ TỜ KHAI (Z020), SỐ INV (Z027) ──
    READ ENTITIES OF I_BillingDocumentTP FORWARDING PRIVILEGED
    ENTITY BillingDocument
    BY \_Text
    ALL FIELDS WITH VALUE #( FOR ls_key IN lt_doc ( BillingDocument = ls_key-billingdocument ) )
    RESULT DATA(lt_longtext)
    FAILED DATA(ls_failed)
    REPORTED DATA(ls_reported).

    LOOP AT lt_longtext INTO DATA(ls_longtext)
         WHERE LongTextID = 'Z020' OR LongTextID = 'Z027'.
      ASSIGN lt_doc[ billingdocument = ls_longtext-BillingDocument ] TO <ls_doc>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Ưu tiên ngôn ngữ đăng nhập, không có thì lấy ngôn ngữ bất kỳ
      " Bỏ ký tự xuống dòng / tab trong long text để so khớp Số tờ khai với ECUS không bị lệch
      DATA(lv_text) = CONV string( ls_longtext-LongText ).
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf          IN lv_text WITH ` `.
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline        IN lv_text WITH ` `.
      REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_text WITH ` `.
      lv_text = condense( lv_text ).
      CASE ls_longtext-LongTextID.
        WHEN 'Z020'.
          IF <ls_doc>-sotokhai IS INITIAL OR ls_longtext-Language = sy-langu.
            <ls_doc>-sotokhai = lv_text.
          ENDIF.
        WHEN 'Z027'.
          IF <ls_doc>-soinv IS INITIAL OR ls_longtext-Language = sy-langu.
            <ls_doc>-soinv = lv_text.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    " Filter Số tờ khai: chỉ lọc được sau khi đọc long text
    IF lr_sotokhai IS NOT INITIAL.
      DELETE lt_doc WHERE sotokhai NOT IN lr_sotokhai.
    ENDIF.

    " Bỏ item của các Billing Document đã bị loại
    LOOP AT lt_item INTO ls_item.
      IF NOT line_exists( lt_doc[ billingdocument = ls_item-BillingDocument ] ).
        DELETE lt_item.
      ENDIF.
    ENDLOOP.
    IF lt_item IS INITIAL.
      RETURN.
    ENDIF.

    " ── 5. VẬT TƯ: TÊN + ĐƠN VỊ TÍNH ───────────────────────
    SELECT FROM I_ProductText
    FIELDS
        Product,
        ProductName
    FOR ALL ENTRIES IN @lt_item
    WHERE
        Product      = @lt_item-Product
        AND Language = @sy-langu
    INTO TABLE @DATA(lt_product_text).
    SORT lt_product_text BY Product.

    SELECT FROM I_ProductUnitsOfMeasure
    FIELDS
        Product,
        AlternativeUnit,
        BaseUnit,
        QuantityNumerator,
        QuantityDenominator
    FOR ALL ENTRIES IN @lt_item
    WHERE
        Product = @lt_item-Product
    INTO CORRESPONDING FIELDS OF TABLE @lt_uom.

    " ── 6. PRICING ELEMENT: ZPXX / ZPRM / ZPR1 ─────────────
    SELECT FROM I_BillingDocumentItemPrcgElmnt
    FIELDS
        BillingDocument,
        BillingDocumentItem,
        ConditionType,
        ConditionInactiveReason,
        PricingProcedureStep,
        PricingProcedureCounter,
        ConditionRateAmount,
        ConditionQuantity,
        ConditionQuantityUnit,
        ConditionCurrency
    FOR ALL ENTRIES IN @lt_item
    WHERE
        BillingDocument         = @lt_item-BillingDocument
        AND BillingDocumentItem = @lt_item-BillingDocumentItem
        AND ConditionType       IN ( 'ZPXX', 'ZPRM', 'ZPR1' )
    INTO CORRESPONDING FIELDS OF TABLE @lt_prcg.

    " ── 7. ECUS: MÃ LOẠI HÌNH CỦA TỜ KHAI ──────────────────
    " Số tờ khai trên Billing (long text Z020) = ZR_ECUS_TKHQ_HDR-Sotokhai (CHAR 12)
    LOOP AT lt_doc INTO DATA(ls_doc_key) WHERE sotokhai IS NOT INITIAL.
      IF strlen( ls_doc_key-sotokhai ) <= 12.
        INSERT CONV ZR_ECUS_TKHQ_HDR-Sotokhai( ls_doc_key-sotokhai ) INTO TABLE lt_ecus_key.
      ENDIF.
    ENDLOOP.

    IF lt_ecus_key IS NOT INITIAL.
      SELECT FROM ZR_ECUS_TKHQ_HDR
      FIELDS
          Sotokhai,
          Maloaihinh
      FOR ALL ENTRIES IN @lt_ecus_key
      WHERE
          Sotokhai = @lt_ecus_key-table_line
      INTO TABLE @DATA(lt_ecus).
      SORT lt_ecus BY Sotokhai.

      LOOP AT lt_doc ASSIGNING <ls_doc> WHERE sotokhai IS NOT INITIAL.
        IF strlen( <ls_doc>-sotokhai ) > 12.
          CONTINUE.
        ENDIF.
        READ TABLE lt_ecus INTO DATA(ls_ecus)
             WITH KEY Sotokhai = CONV ZR_ECUS_TKHQ_HDR-Sotokhai( <ls_doc>-sotokhai )
             BINARY SEARCH.
        IF sy-subrc = 0.
          <ls_doc>-maloaihinh = ls_ecus-Maloaihinh.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " ── 8. RESULT ──────────────────────────────────────────
    LOOP AT lt_item INTO ls_item.
      READ TABLE lt_doc INTO DATA(ls_doc) WITH TABLE KEY billingdocument = ls_item-BillingDocument.

      DATA(ls_result) = VALUE ty_result(
          BillingDocument     = ls_item-BillingDocument
          BillingDocumentItem = ls_item-BillingDocumentItem
          BillingDocumentTitle = |{ ls_item-BillingDocument ALPHA = OUT }/{ CONV i( ls_item-BillingDocumentItem ) }|
          NgayChungTu         = ls_item-BillingDocumentDate
          SoToKhai            = ls_doc-sotokhai
          SoHoaDon            = ls_doc-sohoadon
          DoiTuongCongNo      = ls_item-PayerParty
          TenDoiTuongCongNo   = ls_item-CustomerName
          SoInv               = ls_doc-soinv
          MaVatTu             = ls_item-Product
          SoLuong             = ls_item-BillingQuantityInBaseUnit
          QuocGiaDen          = ls_item-Country
          TenQuocGiaDen       = ls_item-CountryName
          CompanyCodeCurrency = ls_item-CompanyCodeCurrency
          ToChucBanHang       = ls_item-CompanyCode ).

      READ TABLE lt_product_text INTO DATA(ls_product_text)
           WITH KEY Product = ls_item-Product
           BINARY SEARCH.
      IF sy-subrc = 0.
        ls_result-TenVatTu = ls_product_text-ProductName.
      ENDIF.

      " Đơn vị tính = Base Unit của vật tư
      CLEAR lv_baseunit.
      READ TABLE lt_uom INTO DATA(ls_uom) WITH KEY product = ls_item-Product.
      IF sy-subrc = 0.
        lv_baseunit = ls_uom-baseunit.
      ENDIF.
      ls_result-DonViTinh = COND #( WHEN lv_baseunit IS NOT INITIAL
                                    THEN lv_baseunit
                                    ELSE ls_item-BaseUnit ).

      " Giá công thức (ZPXX): quy về Base Unit
      CLEAR: lv_giacongthuc, lv_giaban, lv_giainvkhachhang.
      READ TABLE lt_prcg INTO DATA(ls_zpxx)
           WITH KEY billingdocument     = ls_item-BillingDocument
                    billingdocumentitem = ls_item-BillingDocumentItem
                    conditiontype       = 'ZPXX'.
      IF sy-subrc = 0.
        lv_giacongthuc = get_base_unit_price( is_prcg     = ls_zpxx
                                              iv_product  = ls_item-Product
                                              iv_baseunit = lv_baseunit
                                              it_uom      = lt_uom ).
      ELSE.
        CLEAR ls_zpxx.
      ENDIF.

      " Giá bán (ZPRM) = ConditionRateAmount / ConditionQuantity
      READ TABLE lt_prcg INTO DATA(ls_zprm)
           WITH KEY billingdocument     = ls_item-BillingDocument
                    billingdocumentitem = ls_item-BillingDocumentItem
                    conditiontype       = 'ZPRM'.
      IF sy-subrc = 0.
        lv_giaban = COND #( WHEN ls_zprm-conditionquantity <> 0
                            THEN ls_zprm-conditionrateamount / ls_zprm-conditionquantity
                            ELSE ls_zprm-conditionrateamount ).
      ELSE.
        CLEAR ls_zprm.
      ENDIF.

      " Giá Inv Khách hàng (ZPR1): quy về Base Unit
      READ TABLE lt_prcg INTO DATA(ls_zpr1)
           WITH KEY billingdocument     = ls_item-BillingDocument
                    billingdocumentitem = ls_item-BillingDocumentItem
                    conditiontype       = 'ZPR1'.
      IF sy-subrc = 0.
        lv_giainvkhachhang = get_base_unit_price( is_prcg     = ls_zpr1
                                                  iv_product  = ls_item-Product
                                                  iv_baseunit = lv_baseunit
                                                  it_uom      = lt_uom ).
      ELSE.
        CLEAR ls_zpr1.
      ENDIF.

      ls_result-ConditionCurrency = COND #( WHEN ls_zprm-conditioncurrency IS NOT INITIAL THEN ls_zprm-conditioncurrency
                                            WHEN ls_zpxx-conditioncurrency IS NOT INITIAL THEN ls_zpxx-conditioncurrency
                                            WHEN ls_zpr1-conditioncurrency IS NOT INITIAL THEN ls_zpr1-conditioncurrency
                                            ELSE ls_item-TransactionCurrency ).

      lv_ngoaite = ls_item-BillingQuantityInBaseUnit * lv_giaban.

      ls_result-GiaCongThuc     = lv_giacongthuc.
      ls_result-GiaBan          = lv_giaban.
      ls_result-ChenhLech       = lv_giaban - lv_giacongthuc.
      ls_result-GiaInvHaiQuan   = lv_giaban.
      ls_result-GiaInvKhachHang = lv_giainvkhachhang.
      ls_result-NgoaiTe         = lv_ngoaite.

      " Tỷ giá trên billing lưu theo hệ số quy đổi của cặp tiền tệ -> nhân hệ số để ra tỷ giá thật
      DATA(lv_rate_factor) = get_rate_factor( EXPORTING iv_fromcurrency = ls_item-TransactionCurrency
                                                        iv_tocurrency   = ls_item-CompanyCodeCurrency
                                                        iv_date         = ls_item-BillingDocumentDate
                                              CHANGING  ct_factor       = lt_rate_factor ).
      lv_tygia = ls_item-AccountingExchangeRate * lv_rate_factor.
      ls_result-TyGia           = round( val = lv_tygia dec = 5 ).
      ls_result-TyGiaText       = format_rate( lv_tygia ).
      ls_result-ThanhTien       = lv_ngoaite * lv_tygia.

      " Loại đá: Material Group của item + Mã loại hình của tờ khai (ECUS)
      " Hàng tặng: I_BillingDocumentItemBasic-YY1_HangTangFree_BDI = X
      DATA(lv_is_gift) = xsdbool( ls_item-HangTang IS NOT INITIAL ).

      CASE ls_item-ProductGroup.
        WHEN '320001'.
          IF ls_doc-maloaihinh = 'E62'.
            ls_result-LoaiDaSlabE62 = 'X'.
          ENDIF.
        WHEN '320004'.
          IF ls_doc-maloaihinh = 'E62'.
            ls_result-LoaiDaCutToSizeE62 = 'X'.
          ENDIF.
        WHEN '320002'.
          IF ls_doc-maloaihinh = 'E62' AND lv_is_gift = abap_false.
            ls_result-LoaiDaMauBanE62 = 'X'.
          ELSEIF ls_doc-maloaihinh = 'E62' AND lv_is_gift = abap_true.
            ls_result-LoaiDaMauTangE62 = 'X'.
          ELSEIF ls_doc-maloaihinh = 'H21' AND lv_is_gift = abap_true.
            ls_result-LoaiDaMauTangH21 = 'X'.
          ENDIF.
        WHEN '320003'.
          IF ls_doc-maloaihinh = 'E52'.
            ls_result-LoaiDaGiaCongE52 = 'X'.
          ENDIF.
      ENDCASE.

      APPEND ls_result TO et_result.
    ENDLOOP.
  ENDMETHOD.


  METHOD response.
    DATA(lv_total) = lines( ct_result ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( CONV int8( lv_total ) ).
    ENDIF.

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
      " Mặc định: Ngày chứng từ -> Billing Document -> Billing Item (tăng dần)
      SORT ct_result BY NgayChungTu BillingDocument BillingDocumentItem.
    ENDIF.

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

    IF io_request->is_data_requested( ).
      io_response->set_data( ct_result ).
    ENDIF.
  ENDMETHOD.


  METHOD get_invoice_number.
    " Số hoá đơn = phần nằm sau dấu # của DocumentReferenceID (vd. XXXXX#123456789 -> 123456789)
    " Không có dấu # -> không lấy
    DATA(lv_reference) = condense( CONV string( iv_reference ) ).
    IF lv_reference CS '#'.
      rv_number = substring_after( val = lv_reference sub = '#' ).
    ENDIF.
  ENDMETHOD.


  METHOD get_rate_factor.
    DATA lv_foreign_amount TYPE p LENGTH 16 DECIMALS 2 VALUE 1.
    DATA lv_local_amount   TYPE p LENGTH 16 DECIMALS 2.

    READ TABLE ct_factor INTO DATA(ls_factor)
         WITH TABLE KEY fromcurrency = iv_fromcurrency
                        tocurrency   = iv_tocurrency.
    IF sy-subrc = 0.
      rv_factor = ls_factor-factor.
      RETURN.
    ENDIF.

    rv_factor = 1.

    IF iv_fromcurrency IS NOT INITIAL AND iv_tocurrency IS NOT INITIAL AND iv_fromcurrency <> iv_tocurrency.
      TRY.
          cl_exchange_rates=>convert_to_local_currency(
            EXPORTING
              date             = iv_date
              foreign_amount   = lv_foreign_amount
              foreign_currency = iv_fromcurrency
              local_currency   = iv_tocurrency
              rate_type        = 'M'
            IMPORTING
              foreign_factor   = DATA(lv_foreign_factor)
              local_factor     = DATA(lv_local_factor)
              local_amount     = lv_local_amount
          ).
          IF lv_foreign_factor <> 0 AND lv_local_factor <> 0.
            rv_factor = CONV decfloat34( lv_local_factor ) / lv_foreign_factor.
          ENDIF.
        CATCH cx_root.
          " Không xác định được hệ số -> giữ nguyên tỷ giá trên billing
          rv_factor = 1.
      ENDTRY.
    ENDIF.

    INSERT VALUE #( fromcurrency = iv_fromcurrency
                    tocurrency   = iv_tocurrency
                    factor       = rv_factor ) INTO TABLE ct_factor.
  ENDMETHOD.


  METHOD format_rate.
    DATA(lv_text) = |{ rescale( val = abs( iv_value ) dec = 5 ) }|.
    IF lv_text CS '.'.
      lv_text = replace( val = lv_text pcre = `\.?0+$` with = `` ).
    ENDIF.

    SPLIT lv_text AT '.' INTO DATA(lv_integer) DATA(lv_fraction).

    " Dấu phân cách hàng nghìn
    WHILE strlen( lv_integer ) > 3.
      DATA(lv_rest) = strlen( lv_integer ) - 3.
      rv_text    = |,{ substring( val = lv_integer off = lv_rest len = 3 ) }{ rv_text }|.
      lv_integer = substring( val = lv_integer len = lv_rest ).
    ENDWHILE.
    rv_text = lv_integer && rv_text.

    IF lv_fraction IS NOT INITIAL.
      rv_text = |{ rv_text }.{ lv_fraction }|.
    ENDIF.
    IF iv_value < 0.
      rv_text = |-{ rv_text }|.
    ENDIF.
  ENDMETHOD.


  METHOD get_base_unit_price.
    rv_price = is_prcg-conditionrateamount.

    " Case 1: đơn vị tính của giá trùng Base Unit -> giữ nguyên
    IF is_prcg-conditionquantityunit IS INITIAL OR is_prcg-conditionquantityunit = iv_baseunit.
      RETURN.
    ENDIF.

    " Case 2: khác Base Unit -> Giá / ( QuantityNumerator / QuantityDenominator )
    READ TABLE it_uom INTO DATA(ls_uom)
         WITH TABLE KEY product         = iv_product
                        alternativeunit = is_prcg-conditionquantityunit.
    IF sy-subrc = 0 AND ls_uom-quantitynumerator <> 0 AND ls_uom-quantitydenominator <> 0.
      rv_price = rv_price * ls_uom-quantitydenominator / ls_uom-quantitynumerator.
    ENDIF.
  ENDMETHOD.


  METHOD conv_customer_range.
    LOOP AT it_range INTO DATA(ls_range).
      " Pattern (CP/NP) giữ nguyên, còn lại thêm số 0 đầu theo ALPHA
      IF ls_range-option <> 'CP' AND ls_range-option <> 'NP'.
        IF ls_range-low IS NOT INITIAL.
          ls_range-low = |{ CONV zce_sales_da-DoiTuongCongNo( ls_range-low ) ALPHA = IN }|.
        ENDIF.
        IF ls_range-high IS NOT INITIAL.
          ls_range-high = |{ CONV zce_sales_da-DoiTuongCongNo( ls_range-high ) ALPHA = IN }|.
        ENDIF.
      ENDIF.
      APPEND CORRESPONDING #( ls_range ) TO rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD conv_product_range.
    LOOP AT it_range INTO DATA(ls_range).
      IF ls_range-option <> 'CP' AND ls_range-option <> 'NP'.
        ls_range-low  = product_to_internal( ls_range-low ).
        ls_range-high = product_to_internal( ls_range-high ).
      ENDIF.
      APPEND CORRESPONDING #( ls_range ) TO rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD conv_billingdoc_range.
    LOOP AT it_range INTO DATA(ls_range).
      IF ls_range-option <> 'CP' AND ls_range-option <> 'NP'.
        IF ls_range-low IS NOT INITIAL.
          ls_range-low = |{ CONV zce_sales_da-BillingDocument( ls_range-low ) ALPHA = IN }|.
        ENDIF.
        IF ls_range-high IS NOT INITIAL.
          ls_range-high = |{ CONV zce_sales_da-BillingDocument( ls_range-high ) ALPHA = IN }|.
        ENDIF.
      ENDIF.
      APPEND CORRESPONDING #( ls_range ) TO rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD product_to_internal.
    " Mã vật tư toàn số lưu dạng 18 ký tự có số 0 đầu; mã có chữ giữ nguyên
    rv_value = condense( iv_value ).
    IF rv_value IS NOT INITIAL AND rv_value CO '0123456789' AND strlen( rv_value ) < 18.
      rv_value = |{ rv_value WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
