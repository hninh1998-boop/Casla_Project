CLASS zcl_ce_sales_v3 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider .

    TYPES tt_result   TYPE STANDARD TABLE OF zce_sales_v3 WITH EMPTY KEY.
    TYPES tr_company  TYPE RANGE OF bukrs.
    TYPES tr_pdate    TYPE RANGE OF zce_sales_v3-postingdate.
    TYPES tr_plant    TYPE RANGE OF werks_d.
    TYPES tr_product  TYPE RANGE OF matnr.
    TYPES tr_district TYPE RANGE OF zce_sales_v3-salesdistrict.

    " Pad mã hàng trong filter về dạng nội bộ (18 ký tự, số 0 ở đầu)
    CLASS-METHODS conv_product_range
      IMPORTING it_range          TYPE if_rap_query_filter=>tt_range_option
      RETURNING VALUE(rr_product) TYPE tr_product.

    " Lấy dữ liệu báo cáo theo filter (đã gộp nhóm, đã sắp xếp mặc định, chưa đánh STT)
    " Dùng chung cho query của custom entity và xuất Excel (làm sau)
    CLASS-METHODS get_data
      IMPORTING ir_company       TYPE tr_company
                ir_pdate         TYPE tr_pdate
                ir_plant         TYPE tr_plant    OPTIONAL
                ir_product       TYPE tr_product  OPTIONAL
                ir_district      TYPE tr_district OPTIONAL
      RETURNING VALUE(rt_result) TYPE tt_result.

    " Kiểm tra quyền xem Company Code (F_BKPF_BUK, ACTVT 03)
    CLASS-METHODS check_authority
      IMPORTING ir_company TYPE tr_company
      RAISING   zcx_sales_v3.
  PROTECTED SECTION.
  PRIVATE SECTION.

    " Ghép hiển thị dạng mã(tên): 01(Argentina)
    CLASS-METHODS code_name
      IMPORTING iv_code        TYPE csequence
                iv_name        TYPE csequence
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_ce_sales_v3 IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE tt_result.

    " ── 1. LẤY FILTER ──────────────────────────────────────
    DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).

    DATA lr_company  TYPE tr_company.
    DATA lr_pdate    TYPE tr_pdate.
    DATA lr_plant    TYPE tr_plant.
    DATA lr_product  TYPE tr_product.
    DATA lr_district TYPE tr_district.

    LOOP AT lt_filters INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'COMPANYCODE'.
          lr_company  = CORRESPONDING #( ls_filter-range ).
        WHEN 'POSTINGDATE'.
          lr_pdate    = CORRESPONDING #( ls_filter-range ).
        WHEN 'PLANT'.
          lr_plant    = CORRESPONDING #( ls_filter-range ).
        WHEN 'PRODUCT'.
          lr_product  = conv_product_range( ls_filter-range ).
        WHEN 'SALESDISTRICT'.
          lr_district = CORRESPONDING #( ls_filter-range ).
      ENDCASE.
    ENDLOOP.

    " ── 2. LẤY DỮ LIỆU (Company Code + Posting Date bắt buộc) ──
    IF lr_company IS NOT INITIAL AND lr_pdate IS NOT INITIAL.

      check_authority( lr_company ).

      lt_result = get_data( ir_company  = lr_company
                            ir_pdate    = lr_pdate
                            ir_plant    = lr_plant
                            ir_product  = lr_product
                            ir_district = lr_district ).
    ENDIF.

    " ── 3. SORT theo yêu cầu FE (mặc định đã sort trong get_data) ──
    DATA(lt_sort) = io_request->get_sort_elements( ).
    DELETE lt_sort WHERE element_name = 'STT'.
    IF lt_sort IS NOT INITIAL.
      DATA lt_sort_order TYPE abap_sortorder_tab.
      LOOP AT lt_sort INTO DATA(ls_sort).
        APPEND VALUE #(
            name       = ls_sort-element_name
            descending = ls_sort-descending
        ) TO lt_sort_order.
      ENDLOOP.
      SORT lt_result BY (lt_sort_order).
    ENDIF.

    " ── 4. STT theo thứ tự hiển thị ─────────────────────────
    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<ls_result>).
      <ls_result>-stt = sy-tabix.
    ENDLOOP.

    " ── 5. RESPONSE + PAGING ────────────────────────────────
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( CONV int8( lines( lt_result ) ) ).
    ENDIF.

    IF io_request->is_data_requested( ).

      DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
      DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).

      IF lv_skip > 0.
        DELETE lt_result TO lv_skip.
      ENDIF.

      IF lv_top <> if_rap_query_paging=>page_size_unlimited AND lv_top < lines( lt_result ).
        DELETE lt_result FROM lv_top + 1.
      ENDIF.

      io_response->set_data( lt_result ).
    ENDIF.

  ENDMETHOD.


  METHOD conv_product_range.

    " Chỉ mã toàn số mới có số 0 ở đầu (100000051 → 000000000100000051), mã có chữ giữ nguyên
    " Wildcard (CP / NP) giữ nguyên, get_data so theo mã hiển thị
    LOOP AT it_range INTO DATA(ls_range_prod).
      rr_product = VALUE #( BASE rr_product (
        sign   = ls_range_prod-sign
        option = ls_range_prod-option
        low    = COND #(
          WHEN ls_range_prod-option = 'CP' OR ls_range_prod-option = 'NP'
            OR ls_range_prod-low CN '0123456789'
          THEN ls_range_prod-low
          ELSE |{ ls_range_prod-low  WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
        )
        high   = COND #(
          WHEN ls_range_prod-option = 'CP' OR ls_range_prod-option = 'NP'
            OR ls_range_prod-high CN '0123456789'
          THEN ls_range_prod-high
          ELSE |{ ls_range_prod-high WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
        )
      ) ).
    ENDLOOP.

  ENDMETHOD.


  METHOD check_authority.

    LOOP AT ir_company INTO DATA(ls_company) WHERE sign = 'I' AND option = 'EQ'.
      AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
        ID 'BUKRS' FIELD ls_company-low
        ID 'ACTVT' FIELD '03'.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_sales_v3
          EXPORTING
            textid      = zcx_sales_v3=>no_auth_company_code
            companycode = ls_company-low.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_data.

    " ── 0. PRODUCT CÓ KÝ TỰ ĐẠI DIỆN (1*, *051, ...) ─────────
    " Mã nội bộ có số 0 ở đầu (000000000100000051) nên LIKE '1%' trên DB không khớp
    " → bỏ filter Product khỏi SELECT, lọc lại sau theo mã hiển thị (bỏ số 0 đầu)
    DATA(lr_product_db) = ir_product.
    DATA lr_product_ext TYPE tr_product.

    IF line_exists( ir_product[ option = 'CP' ] ) OR line_exists( ir_product[ option = 'NP' ] ).
      CLEAR lr_product_db.
      lr_product_ext = VALUE #( FOR ls_prod IN ir_product
                                ( sign   = ls_prod-sign
                                  option = ls_prod-option
                                  low    = shift_left( val = CONV string( ls_prod-low )  sub = `0` )
                                  high   = shift_left( val = CONV string( ls_prod-high ) sub = `0` ) ) ).
    ENDIF.

    " ── 1. SELECT: cộng sẵn theo Plant + Product + Sales District + G/L ──
    " Không loại trừ chứng từ hủy / bị hủy: toàn bộ line item thỏa điều kiện đều được cộng
    " Lọc ZPL + PL_RESULT là bắt buộc: view có key SemanticTag/GLAccountHierarchy,
    " không lọc thì 1 line item lặp lại theo từng tag
    SELECT gli~plant,
           gli~product,
           gli~salesdistrict,
           gli~glaccount,
           gli~companycodecurrency,
           plnt~plantname,
           ptxt~productname,
           prod~baseunit,
           prod~productgroup,
           pgtxt~productgroupname,
           sdtxt~salesdistrictname,
           SUM( gli~quantity ) AS quantity,
           SUM( CASE
               WHEN gli~transactioncurrency = 'USD'
               THEN gli~amountintransactioncurrency
               ELSE CAST( 0 AS CURR( 23, 2 ) )
           END ) AS amountusd,
           SUM( gli~amountincompanycodecurrency ) AS amountcc

      FROM i_glaccountlineitemsemtag AS gli

      LEFT OUTER JOIN i_plant AS plnt
        ON plnt~plant = gli~plant

      LEFT OUTER JOIN i_product AS prod
        ON prod~product = gli~product

      LEFT OUTER JOIN i_producttext AS ptxt
        ON  ptxt~product  = gli~product
        AND ptxt~language = @sy-langu

      LEFT OUTER JOIN i_productgrouptext_2 AS pgtxt
        ON  pgtxt~productgroup = prod~productgroup
        AND pgtxt~language     = @sy-langu

      LEFT OUTER JOIN i_salesdistricttext AS sdtxt
        ON  sdtxt~salesdistrict = gli~salesdistrict
        AND sdtxt~language      = @sy-langu

      WHERE gli~companycode        IN @ir_company
        AND gli~postingdate        IN @ir_pdate
        AND gli~plant              IN @ir_plant
        AND gli~product            IN @lr_product_db
        AND gli~salesdistrict      IN @ir_district
        AND gli~ledger             =  '0L'
        AND gli~glaccounthierarchy =  'ZPL'
        AND gli~semantictag        =  'PL_RESULT'
        AND (    ltrim( gli~glaccount, '0' ) LIKE '511%'
              OR ltrim( gli~glaccount, '0' ) LIKE '521%'
              OR ltrim( gli~glaccount, '0' ) LIKE '632%' )

      GROUP BY gli~plant,
               gli~product,
               gli~salesdistrict,
               gli~glaccount,
               gli~companycodecurrency,
               plnt~plantname,
               ptxt~productname,
               prod~baseunit,
               prod~productgroup,
               pgtxt~productgroupname,
               sdtxt~salesdistrictname

      INTO TABLE @DATA(lt_db).

    IF lr_product_ext IS NOT INITIAL.
      LOOP AT lt_db INTO DATA(ls_chk).
        DATA(lv_product_ext) = CONV matnr( shift_left( val = CONV string( ls_chk-product ) sub = `0` ) ).
        IF lv_product_ext NOT IN lr_product_ext.
          DELETE lt_db.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " ── 2. GỘP NHÓM THEO FS ─────────────────────────────────
    " TH1: có ít nhất 1 trong Plant / Product / Sales District -> gộp theo Plant + Product + Sales District
    " TH2: cả 3 trống                                          -> gộp theo từng tài khoản G/L
    " Sorted key = thứ tự mặc định: TH1 trước (Plant, Product, Sales District), TH2 cuối (G/L)
    TYPES: BEGIN OF lty_group,
             glrow               TYPE abap_boolean,
             plant               TYPE werks_d,
             product             TYPE matnr,
             salesdistrict       TYPE zce_sales_v3-salesdistrict,
             glaccount           TYPE zce_sales_v3-glaccount,
             companycodecurrency TYPE waers,
             plantname           TYPE string,
             productname         TYPE string,
             baseunit            TYPE meins,
             productgroup        TYPE string,
             productgroupname    TYPE string,
             salesdistrictname   TYPE string,
             qty511              TYPE p LENGTH 16 DECIMALS 3,
             qty521              TYPE p LENGTH 16 DECIMALS 3,
             usd511              TYPE p LENGTH 16 DECIMALS 2,
             usd521              TYPE p LENGTH 16 DECIMALS 2,
             vnd511              TYPE p LENGTH 16 DECIMALS 2,
             vnd521              TYPE p LENGTH 16 DECIMALS 2,
             vnd632              TYPE p LENGTH 16 DECIMALS 2,
           END OF lty_group.

    DATA lt_group TYPE SORTED TABLE OF lty_group
      WITH UNIQUE KEY glrow plant product salesdistrict glaccount.

    LOOP AT lt_db INTO DATA(ls_db).

      DATA(ls_key) = VALUE lty_group( companycodecurrency = ls_db-companycodecurrency ).

      IF ls_db-plant IS INITIAL AND ls_db-product IS INITIAL AND ls_db-salesdistrict IS INITIAL.
        " TH2: Tên hàng / ĐVT / Loại hàng để trống
        ls_key-glrow     = abap_true.
        ls_key-glaccount = ls_db-glaccount.
      ELSE.
        ls_key-plant             = ls_db-plant.
        ls_key-product           = ls_db-product.
        ls_key-salesdistrict     = ls_db-salesdistrict.
        ls_key-plantname         = ls_db-plantname.
        ls_key-productname       = ls_db-productname.
        ls_key-baseunit          = ls_db-baseunit.
        ls_key-productgroup      = ls_db-productgroup.
        ls_key-productgroupname  = ls_db-productgroupname.
        ls_key-salesdistrictname = ls_db-salesdistrictname.
      ENDIF.

      ASSIGN lt_group[ glrow         = ls_key-glrow
                       plant         = ls_key-plant
                       product       = ls_key-product
                       salesdistrict = ls_key-salesdistrict
                       glaccount     = ls_key-glaccount ] TO FIELD-SYMBOL(<ls_group>).
      IF sy-subrc <> 0.
        INSERT ls_key INTO TABLE lt_group ASSIGNING <ls_group>.
      ENDIF.

      " Cột VND chỉ lấy khi Company Code Currency = VND
      DATA(lv_vnd) = COND #( WHEN ls_db-companycodecurrency = 'VND' THEN ls_db-amountcc ).

      DATA(lv_gl_prefix) = substring( val = shift_left( val = CONV string( ls_db-glaccount ) sub = `0` )
                                      len = 3 ).
      CASE lv_gl_prefix.
        WHEN '511'.
          <ls_group>-qty511 += ls_db-quantity.
          <ls_group>-usd511 += ls_db-amountusd.
          <ls_group>-vnd511 += lv_vnd.
        WHEN '521'.
          <ls_group>-qty521 += ls_db-quantity.
          <ls_group>-usd521 += ls_db-amountusd.
          <ls_group>-vnd521 += lv_vnd.
        WHEN '632'.
          <ls_group>-vnd632 += lv_vnd.
      ENDCASE.

    ENDLOOP.

    " ── 3. MAP TO RESULT ────────────────────────────────────
    " Số lượng / Doanh thu: (- SUM 511) - SUM 521, không lấy trị tuyệt đối
    " Giá vốn: SUM 632, giữ nguyên dấu
    LOOP AT lt_group INTO DATA(ls_group).
      APPEND VALUE zce_sales_v3(
        plant               = ls_group-plant
        product             = ls_group-product
        salesdistrict       = ls_group-salesdistrict
        glaccount           = ls_group-glaccount
        companycode         = VALUE #( ir_company[ 1 ]-low OPTIONAL )
        tennhamay           = code_name( iv_code = ls_group-plant
                                         iv_name = ls_group-plantname )
        mahang              = COND #( WHEN ls_group-glrow = abap_true
                                      THEN |{ ls_group-glaccount ALPHA = OUT }|
                                      ELSE |{ ls_group-product ALPHA = OUT }| )
        tenhang             = ls_group-productname
        donvitinh           = ls_group-baseunit
        loaihang            = code_name( iv_code = ls_group-productgroup
                                         iv_name = ls_group-productgroupname )
        " Số lượng: 511 đổi dấu từng line rồi cộng (= - SUM 511), 521 để nguyên, lấy 511 - 521
        soluong             = - ls_group-qty511 - ls_group-qty521
        " Doanh thu: 511 đổi dấu từng line rồi cộng (= - SUM 511), 521 để nguyên, lấy 511 - 521
        doanhthuusd         = - ls_group-usd511 - ls_group-usd521
        currencyusd         = 'USD'
        doanhthuvnd         = - ls_group-vnd511 - ls_group-vnd521
        " Giá vốn: cộng / trừ các line 632* ra bao nhiêu để nguyên dấu (không lấy trị tuyệt đối)
        giavonvnd           = ls_group-vnd632
        companycodecurrency = ls_group-companycodecurrency
        thitruongxuatkhau   = code_name( iv_code = ls_group-salesdistrict
                                         iv_name = ls_group-salesdistrictname )
      ) TO rt_result.
    ENDLOOP.

    " ── 4. FILTER ZERO ROWS ─────────────────────────────────
    DELETE rt_result WHERE soluong     = 0
                       AND doanhthuusd = 0
                       AND doanhthuvnd = 0
                       AND giavonvnd   = 0.

  ENDMETHOD.


  METHOD code_name.

    IF iv_code IS INITIAL.
      RETURN.
    ENDIF.

    rv_text = COND #( WHEN iv_name IS INITIAL
                      THEN condense( iv_code )
                      ELSE |{ condense( iv_code ) }({ condense( iv_name ) })| ).

  ENDMETHOD.
ENDCLASS.
