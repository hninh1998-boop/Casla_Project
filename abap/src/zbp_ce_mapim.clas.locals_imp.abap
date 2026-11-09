CLASS lhc_mapim DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Cấu trúc của JsonString, FE gửi filter + sort đang áp trên bảng, ví dụ:
    " { "filters": [ { "name": "COMPANYCODE", "range": [ { "sign": "I", "option": "EQ", "low": "6710", "high": "" } ] },
    "               { "name": "GRPOSTINGDATE", "range": [ { "sign": "I", "option": "BT", "low": "20261001", "high": "20261031" } ] } ],
    "   "sort":    [ { "name": "PONO", "descending": false } ] }
    " name = tên field của zce_mapim viết hoa, giống tên filter mà zcl_ce_mapim_implement=>select nhận
    TYPES: BEGIN OF ty_export_param,
             filters TYPE if_rap_query_filter=>tt_name_range_pairs,
             sort    TYPE abap_sortorder_tab,
           END OF ty_export_param.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR MapIM RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ MapIM RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK MapIM.

    METHODS ExportExcel FOR MODIFY
      IMPORTING keys FOR ACTION MapIM~ExportExcel RESULT result.

    " Chuẩn hoá filter giống lúc query màn hình: sign / option mặc định,
    " thêm số 0 đầu cho các field ALPHA / NUMC (gateway tự convert khi query, action thì không)
    METHODS normalize_filters
      CHANGING ct_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    METHODS alpha_in
      IMPORTING iv_value        TYPE string
                iv_length       TYPE i
      RETURNING VALUE(rv_value) TYPE string.

    " Sort giống màn hình: theo sort của bảng, không có thì theo sort mặc định (zcl_ce_mapim_implement=>response)
    METHODS sort_export_data
      IMPORTING it_sort TYPE abap_sortorder_tab
      CHANGING  ct_data TYPE zcl_ce_mapim_implement=>tt_result.

    " Ngày hiện tại theo time zone của user (tên file)
    METHODS get_today
      RETURNING VALUE(rv_date) TYPE d.

ENDCLASS.

CLASS lhc_mapim IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD ExportExcel.
    DATA ls_param TYPE ty_export_param.

    READ TABLE keys INDEX 1 INTO DATA(ls_key).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " ── 1. LẤY FILTER + SORT TỪ JsonString ──────────────────
    /ui2/cl_json=>deserialize(
      EXPORTING
        json = ls_key-%param-JsonString
      CHANGING
        data = ls_param
    ).

    normalize_filters( CHANGING ct_filters = ls_param-filters ).

    " Validate filter bắt buộc (giống màn hình: required-in-filter)
    IF NOT line_exists( ls_param-filters[ name = `COMPANYCODE` ] )
       OR NOT line_exists( ls_param-filters[ name = `FISCALYEAR` ] )
       OR NOT line_exists( ls_param-filters[ name = `POTYPE` ] ).
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-mapim.
      APPEND VALUE #( %cid = ls_key-%cid
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'Vui lòng nhập Company Code, Fiscal year và PO Type' )
                    ) TO reported-mapim.
      RETURN.
    ENDIF.

    " ── 2. LẤY DỮ LIỆU (dùng chung logic với màn hình) ──────
    zcl_ce_mapim_implement=>select(
      EXPORTING
        it_filters = ls_param-filters
      IMPORTING
        et_result  = DATA(lt_data)
    ).

    IF lt_data IS INITIAL.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-mapim.
      APPEND VALUE #( %cid = ls_key-%cid
                      %msg = new_message_with_text(
                        severity = if_abap_behv_message=>severity-error
                        text     = 'Không có dữ liệu để Export' )
                    ) TO reported-mapim.
      RETURN.
    ENDIF.

    sort_export_data( EXPORTING it_sort = ls_param-sort
                      CHANGING  ct_data = lt_data ).

    " ── 3. SINH FILE XLSX ───────────────────────────────────
    DATA(lv_today) = get_today( ).
    DATA(lv_xlsx)  = zcl_ce_mapim_xlsx=>build( lt_data ).

    result = VALUE #( ( %cid   = ls_key-%cid
                        %param = VALUE #( FileContent   = cl_web_http_utility=>encode_x_base64( lv_xlsx )
                                          FileName      = zcl_ce_mapim_xlsx=>file_name( lv_today )
                                          FileExtension = 'xlsx'
                                          MimeType      = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) ) ).
  ENDMETHOD.


  METHOD normalize_filters.
    LOOP AT ct_filters ASSIGNING FIELD-SYMBOL(<ls_filter>).
      <ls_filter>-name = to_upper( <ls_filter>-name ).

      " Độ dài để thêm số 0 đầu (ALPHA: ebeln / lifnr / mblnr; NUMC: ebelp / mblpo / mjahr)
      " MATERIALCODE: MATN1 → mã số thuần được lưu 18 ký tự có số 0 đầu
      DATA(lv_length) = SWITCH i( <ls_filter>-name
                                  WHEN `PONO` OR `POSUPPLIER` OR `INVOICINGPARTY`
                                    OR `MATDOC` OR `INV`                      THEN 10
                                  WHEN `MATERIALCODE`                         THEN 18
                                  WHEN `POITEM`                               THEN 5
                                  WHEN `MATDOCITEM` OR `INVITEM` OR `FISCALYEAR` THEN 4
                                  ELSE 0 ).

      LOOP AT <ls_filter>-range ASSIGNING FIELD-SYMBOL(<ls_range>).
        IF <ls_range>-sign IS INITIAL.
          <ls_range>-sign = 'I'.
        ENDIF.
        IF <ls_range>-option IS INITIAL.
          <ls_range>-option = COND #( WHEN <ls_range>-high IS INITIAL THEN 'EQ' ELSE 'BT' ).
        ENDIF.

        IF lv_length > 0 AND <ls_range>-option <> 'CP' AND <ls_range>-option <> 'NP'.
          <ls_range>-low  = alpha_in( iv_value = <ls_range>-low  iv_length = lv_length ).
          <ls_range>-high = alpha_in( iv_value = <ls_range>-high iv_length = lv_length ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    DELETE ct_filters WHERE range IS INITIAL.
  ENDMETHOD.


  METHOD alpha_in.
    rv_value = condense( iv_value ).
    IF rv_value IS INITIAL OR rv_value CN '0123456789' OR strlen( rv_value ) >= iv_length.
      RETURN.
    ENDIF.

    rv_value = repeat( val = `0` occ = iv_length - strlen( rv_value ) ) && rv_value.
  ENDMETHOD.


  METHOD sort_export_data.
    IF it_sort IS NOT INITIAL.
      DATA(lt_sort) = it_sort.
      LOOP AT lt_sort ASSIGNING FIELD-SYMBOL(<ls_sort>).
        <ls_sort>-name = to_upper( <ls_sort>-name ).
      ENDLOOP.

      TRY.
          SORT ct_data BY (lt_sort).
          RETURN.
        CATCH cx_sy_dyn_table_ill_comp_val.
          "Field sort không hợp lệ --> dùng sort mặc định
      ENDTRY.
    ENDIF.

    " Giống sort mặc định của màn hình (zcl_ce_mapim_implement=>response)
    SORT ct_data BY PONo
                    POItem
                    SortOrder
                    GRPostingDate
                    MatDoc
                    MatDocItem
                    InvoicePostingDate
                    Inv
                    InvItem.
  ENDMETHOD.


  METHOD get_today.
    TRY.
        DATA(lv_now) = utclong_current( ).
        DATA(lv_time_zone) = cl_abap_context_info=>get_user_time_zone( ).
        CONVERT UTCLONG lv_now TIME ZONE lv_time_zone INTO DATE rv_date.
      CATCH cx_abap_context_info_error.
        CLEAR rv_date.
    ENDTRY.

    IF rv_date IS INITIAL.
      rv_date = cl_abap_context_info=>get_system_date( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zce_mapim DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zce_mapim IMPLEMENTATION.

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
