CLASS lhc_salesv3 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Cấu trúc của JsonString, FE gửi filter đang chọn trên màn hình, ví dụ:
    " { "CompanyCode": [ { "sign": "I", "option": "EQ", "low": "1000" } ],
    "   "PostingDate": [ { "option": "BT", "low": "20261001", "high": "20261031" } ],
    "   "Plant": [], "Product": [], "SalesDistrict": [] }
    " sign / option bỏ trống → mặc định I / EQ (BT nếu có high)
    TYPES: BEGIN OF ty_filter,
             companycode   TYPE if_rap_query_filter=>tt_range_option,
             postingdate   TYPE if_rap_query_filter=>tt_range_option,
             plant         TYPE if_rap_query_filter=>tt_range_option,
             product       TYPE if_rap_query_filter=>tt_range_option,
             salesdistrict TYPE if_rap_query_filter=>tt_range_option,
           END OF ty_filter.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR salesv3 RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ salesv3 RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK salesv3.

    METHODS exportexcel FOR MODIFY
      IMPORTING keys FOR ACTION salesv3~exportexcel RESULT result.

    " Bỏ dòng trống, điền sign / option mặc định
    METHODS normalize
      IMPORTING it_range        TYPE if_rap_query_filter=>tt_range_option
      RETURNING VALUE(rt_range) TYPE if_rap_query_filter=>tt_range_option.

    " Dòng kỳ báo cáo của file excel, theo khoảng Posting Date đang lọc:
    " trọn 1 tháng → "Tháng 10 năm 2026", còn lại → "Từ ngày ... đến ngày ..."
    METHODS get_subtitle
      IMPORTING it_range           TYPE zcl_ce_sales_v3=>tr_pdate
      RETURNING VALUE(rv_subtitle) TYPE string.

    " Plant đang lọc, in ở footer góc trái (FS: <Plant>)
    METHODS get_plant_text
      IMPORTING it_range       TYPE zcl_ce_sales_v3=>tr_plant
      RETURNING VALUE(rv_text) TYPE string.

    " YYYYMMDD → DD/MM/YYYY
    METHODS format_date
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.

CLASS lhc_salesv3 IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD exportexcel.
    DATA ls_filter TYPE ty_filter.

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

    DATA(lr_company)  = CORRESPONDING zcl_ce_sales_v3=>tr_company( normalize( ls_filter-companycode ) ).
    DATA(lr_pdate)    = CORRESPONDING zcl_ce_sales_v3=>tr_pdate( normalize( ls_filter-postingdate ) ).
    DATA(lr_plant)    = CORRESPONDING zcl_ce_sales_v3=>tr_plant( normalize( ls_filter-plant ) ).
    DATA(lr_product)  = zcl_ce_sales_v3=>conv_product_range( normalize( ls_filter-product ) ).
    DATA(lr_district) = CORRESPONDING zcl_ce_sales_v3=>tr_district( normalize( ls_filter-salesdistrict ) ).

    " Validate filter bắt buộc (giống màn hình)
    IF lr_company IS INITIAL OR lr_pdate IS INITIAL.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-salesv3.
      APPEND VALUE #( %cid = ls_key-%cid
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'Vui lòng nhập Company Code và Posting Date' )
                    ) TO reported-salesv3.
      RETURN.
    ENDIF.

    " ── 2. PHÂN QUYỀN COMPANY CODE (giống màn hình) ─────────
    TRY.
        zcl_ce_sales_v3=>check_authority( lr_company ).
      CATCH zcx_sales_v3 INTO DATA(lx_auth).
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-salesv3.
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = lx_auth->get_text( ) )
                      ) TO reported-salesv3.
        RETURN.
    ENDTRY.

    " ── 3. LẤY DỮ LIỆU (dùng chung logic với màn hình) ──────
    DATA(lt_data) = zcl_ce_sales_v3=>get_data( ir_company  = lr_company
                                               ir_pdate    = lr_pdate
                                               ir_plant    = lr_plant
                                               ir_product  = lr_product
                                               ir_district = lr_district ).

    IF lt_data IS INITIAL.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-salesv3.
      APPEND VALUE #( %cid = ls_key-%cid
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'Không có dữ liệu để export' )
                    ) TO reported-salesv3.
      RETURN.
    ENDIF.

    " Thứ tự mặc định của get_data (giống màn hình chưa sort), STT tăng dần
    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      <ls_data>-stt = sy-tabix.
    ENDLOOP.

    " ── 4. SINH FILE XLSX ───────────────────────────────────
    DATA(lv_xlsx) = zcl_ce_sales_v3_xlsx=>build(
                      it_data         = lt_data
                      iv_subtitle     = get_subtitle( lr_pdate )
                      iv_footer_plant = get_plant_text( lr_plant ) ).

    result = VALUE #( ( %cid   = ls_key-%cid
                        %param = VALUE #( FileContent   = cl_web_http_utility=>encode_x_base64( lv_xlsx )
                                          FileName      = |BaoCaoBanHang_{ cl_abap_context_info=>get_system_date( ) }|
                                          FileExtension = 'xlsx'
                                          MimeType      = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) ) ).
  ENDMETHOD.

  METHOD normalize.
    rt_range = it_range.

    DELETE rt_range WHERE low IS INITIAL AND high IS INITIAL.

    LOOP AT rt_range ASSIGNING FIELD-SYMBOL(<ls_range>).
      IF <ls_range>-sign IS INITIAL.
        <ls_range>-sign = 'I'.
      ENDIF.
      IF <ls_range>-option IS INITIAL.
        <ls_range>-option = COND #( WHEN <ls_range>-high IS INITIAL THEN 'EQ' ELSE 'BT' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_subtitle.
    READ TABLE it_range INDEX 1 INTO DATA(ls_range).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Trọn 1 tháng: từ ngày 01 đến ngày cuối cùng của cùng tháng
    IF ls_range-option = 'BT'
       AND ls_range-low+6(2) = '01'
       AND ls_range-low(6)   = ls_range-high(6).
      DATA(lv_next) = CONV d( ls_range-high + 1 ).
      IF lv_next+6(2) = '01'.
        rv_subtitle = |Tháng { ls_range-low+4(2) } năm { ls_range-low(4) }|.
        RETURN.
      ENDIF.
    ENDIF.

    DATA(lv_low)  = format_date( ls_range-low ).
    DATA(lv_high) = format_date( ls_range-high ).

    rv_subtitle = SWITCH #( ls_range-option
      WHEN 'BT'         THEN |Từ ngày { lv_low } đến ngày { lv_high }|
      WHEN 'GE' OR 'GT' THEN |Từ ngày { lv_low }|
      WHEN 'LE' OR 'LT' THEN |Đến ngày { lv_low }|
      ELSE                   |Ngày { lv_low }| ).
  ENDMETHOD.

  METHOD get_plant_text.
    DATA(lt_plant) = VALUE string_table( FOR ls_plant IN it_range
                                         WHERE ( sign = 'I' AND option = 'EQ' )
                                         ( CONV string( ls_plant-low ) ) ).

    rv_text = COND #( WHEN lt_plant IS INITIAL
                      THEN `Plant: Tất cả`
                      ELSE |Plant: { concat_lines_of( table = lt_plant sep = `, ` ) }| ).
  ENDMETHOD.

  METHOD format_date.
    IF iv_date IS NOT INITIAL.
      rv_text = |{ iv_date+6(2) }/{ iv_date+4(2) }/{ iv_date(4) }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zce_sales_v3 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zce_sales_v3 IMPLEMENTATION.

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
