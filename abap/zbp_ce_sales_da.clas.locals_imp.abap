CLASS lhc_salesda DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Cấu trúc của JsonString, FE gửi filter đang chọn trên màn hình, ví dụ:
    " { "ToChucBanHang": [ { "sign": "I", "option": "EQ", "low": "6730" } ],
    "   "NgayChungTu":   [ { "option": "BT", "low": "20260801", "high": "20260831" } ],
    "   "SoToKhai": [], "DoiTuongCongNo": [], "MaVatTu": [], "BillingDocument": [] }
    " sign / option bỏ trống → mặc định I / EQ (BT nếu có high)
    TYPES: BEGIN OF ty_filter,
             tochucbanhang   TYPE if_rap_query_filter=>tt_range_option,
             ngaychungtu     TYPE if_rap_query_filter=>tt_range_option,
             sotokhai        TYPE if_rap_query_filter=>tt_range_option,
             doituongcongno  TYPE if_rap_query_filter=>tt_range_option,
             mavattu         TYPE if_rap_query_filter=>tt_range_option,
             billingdocument TYPE if_rap_query_filter=>tt_range_option,
           END OF ty_filter.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR salesda RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ salesda RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK salesda.

    METHODS exportexcel FOR MODIFY
      IMPORTING keys FOR ACTION salesda~exportexcel RESULT result.

    METHODS add_filter
      IMPORTING iv_name    TYPE string
                it_range   TYPE if_rap_query_filter=>tt_range_option
      CHANGING  ct_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    " Dòng "Từ ngày ... đến ngày ..." của file excel, theo khoảng Ngày chứng từ đang lọc
    METHODS get_subtitle
      IMPORTING it_range           TYPE if_rap_query_filter=>tt_range_option
      RETURNING VALUE(rv_subtitle) TYPE string.

    " YYYYMMDD → DD/MM/YYYY
    METHODS format_date
      IMPORTING iv_date        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    " Tên + địa chỉ công ty theo Company Code đang chọn
    METHODS get_company
      IMPORTING iv_companycode TYPE zce_sales_da-ToChucBanHang
      EXPORTING ev_name        TYPE string
                ev_address     TYPE string.

ENDCLASS.

CLASS lhc_salesda IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD exportexcel.
    DATA ls_filter  TYPE ty_filter.
    DATA lt_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    READ TABLE keys INDEX 1 INTO DATA(ls_key).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " ── 1. LẤY FILTER TỪ JsonString ─────────────────────────
    /ui2/cl_json=>deserialize(
      EXPORTING
        json = ls_key-%param-JsonString
      CHANGING
        data = ls_filter
    ).

    add_filter( EXPORTING iv_name = `TOCHUCBANHANG`   it_range = ls_filter-tochucbanhang   CHANGING ct_filters = lt_filters ).
    add_filter( EXPORTING iv_name = `NGAYCHUNGTU`     it_range = ls_filter-ngaychungtu     CHANGING ct_filters = lt_filters ).
    add_filter( EXPORTING iv_name = `SOTOKHAI`        it_range = ls_filter-sotokhai        CHANGING ct_filters = lt_filters ).
    add_filter( EXPORTING iv_name = `DOITUONGCONGNO`  it_range = ls_filter-doituongcongno  CHANGING ct_filters = lt_filters ).
    add_filter( EXPORTING iv_name = `MAVATTU`         it_range = ls_filter-mavattu         CHANGING ct_filters = lt_filters ).
    add_filter( EXPORTING iv_name = `BILLINGDOCUMENT` it_range = ls_filter-billingdocument CHANGING ct_filters = lt_filters ).

    " Validate filter bắt buộc (giống màn hình)
    IF NOT line_exists( lt_filters[ name = `TOCHUCBANHANG` ] )
       OR NOT line_exists( lt_filters[ name = `NGAYCHUNGTU` ] ).
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-salesda.
      APPEND VALUE #( %cid = ls_key-%cid
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'Vui lòng nhập Tổ chức bán hàng và Ngày chứng từ' )
                    ) TO reported-salesda.
      RETURN.
    ENDIF.

    " ── 2. LẤY DỮ LIỆU (dùng chung logic với màn hình) ──────
    zcl_ce_sales_da_f01=>main(
      EXPORTING
        it_filters = lt_filters
      IMPORTING
        et_result  = DATA(lt_data)
    ).

    IF lt_data IS INITIAL.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-salesda.
      APPEND VALUE #( %cid = ls_key-%cid
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'Không có dữ liệu để export' )
                    ) TO reported-salesda.
      RETURN.
    ENDIF.

    SORT lt_data BY NgayChungTu BillingDocument BillingDocumentItem.

    " ── 3. THÔNG TIN HEADER CỦA FILE ────────────────────────
    get_company( EXPORTING iv_companycode = lt_data[ 1 ]-ToChucBanHang
                 IMPORTING ev_name        = DATA(lv_company_name)
                           ev_address     = DATA(lv_company_address) ).

    " ── 4. SINH FILE XLSX ───────────────────────────────────
    DATA(lv_xlsx) = zcl_ce_sales_da_xlsx=>build(
                      it_data            = lt_data
                      iv_company_name    = lv_company_name
                      iv_company_address = lv_company_address
                      iv_subtitle        = get_subtitle( ls_filter-ngaychungtu ) ).

    result = VALUE #( ( %cid   = ls_key-%cid
                        %param = VALUE #( FileContent   = cl_web_http_utility=>encode_x_base64( lv_xlsx )
                                          FileName      = |BaoCaoDoanhThuDa_{ cl_abap_context_info=>get_system_date( ) }|
                                          FileExtension = 'xlsx'
                                          MimeType      = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) ) ).
  ENDMETHOD.

  METHOD add_filter.
    DATA(lt_range) = it_range.

    DELETE lt_range WHERE low IS INITIAL AND high IS INITIAL.
    IF lt_range IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_range ASSIGNING FIELD-SYMBOL(<ls_range>).
      IF <ls_range>-sign IS INITIAL.
        <ls_range>-sign = 'I'.
      ENDIF.
      IF <ls_range>-option IS INITIAL.
        <ls_range>-option = COND #( WHEN <ls_range>-high IS INITIAL THEN 'EQ' ELSE 'BT' ).
      ENDIF.
    ENDLOOP.

    APPEND VALUE #( name = iv_name range = lt_range ) TO ct_filters.
  ENDMETHOD.

  METHOD get_subtitle.
    READ TABLE it_range INDEX 1 INTO DATA(ls_range).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lv_low)  = format_date( ls_range-low ).
    DATA(lv_high) = format_date( ls_range-high ).

    rv_subtitle = SWITCH #( ls_range-option
      WHEN 'BT'         THEN |Từ ngày { lv_low } đến ngày { lv_high }|
      WHEN 'GE' OR 'GT' THEN |Từ ngày { lv_low }|
      WHEN 'LE' OR 'LT' THEN |Đến ngày { lv_low }|
      ELSE                   |Từ ngày { lv_low } đến ngày { lv_low }| ).
  ENDMETHOD.

  METHOD format_date.
    IF strlen( iv_date ) = 8.
      rv_text = |{ iv_date+6(2) }/{ iv_date+4(2) }/{ iv_date(4) }|.
    ENDIF.
  ENDMETHOD.

  METHOD get_company.
    CLEAR: ev_name, ev_address.

    " ZI_COMPANYCODE_VH-CityName = địa chỉ đầy đủ của công ty (đã ghép sẵn trong CDS)
    SELECT SINGLE FROM ZI_COMPANYCODE_VH
    FIELDS
        CompanyCodeName,
        CityName
    WHERE
        CompanyCode = @iv_companycode
    INTO @DATA(ls_company).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ev_name = ls_company-CompanyCodeName.

    " Bỏ dấu phẩy / khoảng trắng thừa ở đầu (khi địa chỉ thiếu phần đường, vd. ",Ninh Bình")
    DATA(lv_address) = condense( CONV string( ls_company-CityName ) ).
    WHILE lv_address IS NOT INITIAL AND lv_address(1) = ','.
      lv_address = condense( substring( val = lv_address off = 1 ) ).
    ENDWHILE.

    ev_address = COND #( WHEN lv_address IS INITIAL
                         THEN `Việt Nam`
                         ELSE |{ lv_address }, Việt Nam| ).
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zce_sales_da DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zce_sales_da IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
