CLASS zcl_utility DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_parsed,
             operator TYPE string,
             value    TYPE string,
             unit     TYPE string,
             price    TYPE string,
           END OF ty_parsed.
    CLASS-METHODS:
      last_day_of_month IMPORTING
                          i_date TYPE d
                        EXPORTING
                          e_date TYPE d.
    CLASS-METHODS parse_rule
      IMPORTING iv_rule          TYPE string
      RETURNING VALUE(rs_parsed) TYPE ty_parsed.

    CLASS-METHODS check_rule
      IMPORTING
                iv_value        TYPE string   " ví dụ: '70cm'
                iv_rule         TYPE string   " rule gốc, ví dụ '>=65cm'
      RETURNING VALUE(rv_match) TYPE abap_bool.

    CLASS-METHODS: to_json_date
      IMPORTING iv_date             TYPE zde_date
      RETURNING VALUE(rv_json_date) TYPE string.

    CLASS-METHODS: to_json_date_1
      IMPORTING iv_date             TYPE zde_date
      RETURNING VALUE(rv_json_date) TYPE string.

    CLASS-METHODS: to_api_date
      IMPORTING iv_date             TYPE zde_date
      RETURNING VALUE(rv_json_date) TYPE string.

    CLASS-METHODS tzntstmpl_to_iso8601
      IMPORTING iv_tzntstmpl  TYPE tzntstmpl
      RETURNING VALUE(rv_iso) TYPE string.

    CLASS-METHODS get_current_date
      RETURNING VALUE(rv_date) TYPE zde_date.

    CLASS-METHODS get_current_timestamp
      RETURNING
        VALUE(rv_timestamp) TYPE timestampl.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_UTILITY IMPLEMENTATION.


  METHOD to_json_date_1.
    DATA: lv_tsl      TYPE timestampl,
          lv_epoch    TYPE timestampl VALUE '19700101000000',
          lv_diff     TYPE decfloat34,
          lv_ms       TYPE p LENGTH 16 DECIMALS 0,
          lv_date_adj TYPE d.

    " B0: Trừ 1 ngày theo nghiệp vụ (ME23N +1)
    lv_date_adj = iv_date - 1.

    " B1: Convert DATS + TIME thành UTC timestamp (safe point)
    CONVERT DATE lv_date_adj TIME '120000'
            INTO TIME STAMP lv_tsl TIME ZONE 'UTC'.

    " B2: Số giây từ epoch
    lv_diff = cl_abap_tstmp=>subtract(
      tstmp1 = lv_tsl
      tstmp2 = lv_epoch ).

    " B3: Chuyển sang mili giây
    lv_ms = lv_diff * 1000.

    " B4: Format theo JSON OData
    rv_json_date = |/Date({ lv_ms })/|.

  ENDMETHOD.


  METHOD get_current_timestamp.
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).

    CONVERT DATE lv_date TIME lv_time
            INTO TIME STAMP rv_timestamp
            TIME ZONE 'UTC-7'.
  ENDMETHOD.


  METHOD get_current_date.
    " Lấy ngày hiện tại theo múi giờ của user (dạng ABAP date)
    rv_date = xco_cp=>sy->moment(
                  xco_cp_time=>time_zone->user )->date->as(
                  xco_cp_time=>format->abap )->value.
  ENDMETHOD.


  METHOD last_day_of_month.
    DATA: lw_year  TYPE zde_numc4,
          lw_month TYPE zde_numc2.
    lw_year = i_date(4).
    lw_month = i_date+4(2).

    DATA(lo_date) = xco_cp=>sy->date( )->overwrite(
     iv_year  = lw_year
     iv_month = lw_month
     iv_day = 1 ).

    " 2) Compute the 1st of next month and then subtract one day:
    e_date = lo_date->overwrite( iv_day   = 1 )->add( iv_month = 1 )->subtract( iv_day   = 1 )->as( xco_cp_time=>format->abap )->value.

  ENDMETHOD.


  METHOD check_rule.
    " Parse string rule thành cấu trúc
    DATA(ls_parsed) = parse_rule( iv_rule ).

    " Parse value input: tách số + đơn vị
    DATA lv_num  TYPE string.
    DATA lv_unit TYPE string.

    FIND PCRE '^([0-9]+(?:\.[0-9]+)?)([A-Za-z]+)?$'
         IN iv_value
         SUBMATCHES lv_num lv_unit.

    IF sy-subrc <> 0.
      rv_match = abap_false.
      RETURN.
    ENDIF.

    " Nếu đơn vị không khớp thì fail
    IF ls_parsed-unit IS NOT INITIAL AND lv_unit <> ls_parsed-unit AND lv_unit IS NOT INITIAL.
      rv_match = abap_false.
      RETURN.
    ENDIF.

    DATA lv_input TYPE decfloat34.
    DATA lv_rule  TYPE decfloat34.

    TRY.
        lv_input = iv_value.
        lv_rule  = ls_parsed-value.
      CATCH cx_sy_conversion_no_number.
        rv_match = abap_false.
        RETURN.
    ENDTRY.
    CASE ls_parsed-operator.
      WHEN '='.
        rv_match = xsdbool( lv_input = lv_rule ).
      WHEN '>='.
        rv_match = xsdbool( lv_input >= lv_rule ).
      WHEN '<='.
        rv_match = xsdbool( lv_input <= lv_rule ).
      WHEN '>'.
        rv_match = xsdbool( lv_input > lv_rule ).
      WHEN '<'.
        rv_match = xsdbool( lv_input < lv_rule ).
      WHEN OTHERS.
        rv_match = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD to_json_date.
    DATA: lv_tsl   TYPE timestampl,
          lv_epoch TYPE timestampl VALUE '19700101000000',
          lv_diff  TYPE decfloat34,
          lv_ms    TYPE p LENGTH 16 DECIMALS 0.

    " B1: Convert DATS + TIME thành UTC timestamp
    CONVERT DATE iv_date TIME '000000'
            INTO TIME STAMP lv_tsl TIME ZONE 'UTC'.

    " B2: Số giây từ epoch 1970-01-01
    lv_diff = cl_abap_tstmp=>subtract( tstmp1 = lv_tsl
                                       tstmp2 = lv_epoch ).

    " B3: Chuyển sang mili giây (bigint)
    lv_ms = lv_diff * 1000.

    " B4: Format theo JSON OData
    rv_json_date = |/Date({ lv_ms })/|.

  ENDMETHOD.


  METHOD to_api_date.
    DATA: lv_timestamp_utc TYPE string.

    lv_timestamp_utc = iv_date && '000000'.

    "👉 Format ISO 8601 (YYYY-MM-DDTHH:MM:SS.000Z)"
    rv_json_date = |{ lv_timestamp_utc+0(4) }-{ lv_timestamp_utc+4(2) }-{ lv_timestamp_utc+6(2) }T{ lv_timestamp_utc+8(2) }:{ lv_timestamp_utc+10(2) }:{ lv_timestamp_utc+12(2) }.000Z|.

  ENDMETHOD.


  METHOD tzntstmpl_to_iso8601.
    DATA(lv_str) = |{ iv_tzntstmpl DECIMALS = 7 }|.
    REPLACE ALL OCCURRENCES OF '.' IN lv_str WITH ''.
    rv_iso = |{ lv_str+0(4) }-{ lv_str+4(2) }-{ lv_str+6(2) }T{ lv_str+8(2) }:{ lv_str+10(2) }:{ lv_str+12(2) }.{ lv_str+14(6) }Z|.
  ENDMETHOD.


  METHOD parse_rule.
    " Khai báo biến tạm để hứng submatches
    DATA lv_op   TYPE string.
    DATA lv_val  TYPE string.
    DATA lv_unit TYPE string.

    " Regex PCRE: nhóm 1 = operator, nhóm 2 = số, nhóm 3 = đơn vị
    FIND PCRE '^(>=|<=|=|>|<)([0-9]+(?:\.[0-9]+)?)([A-Za-z]+)?$'
         IN iv_rule
         SUBMATCHES lv_op lv_val lv_unit.

    IF sy-subrc = 0.
      rs_parsed-operator = lv_op.
      rs_parsed-value    = lv_val.
      rs_parsed-unit     = lv_unit.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
