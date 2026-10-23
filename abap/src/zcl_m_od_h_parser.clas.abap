CLASS zcl_m_od_h_parser DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES BEGIN OF ty_row.
    TYPES cid TYPE string.
    TYPES od TYPE string.
    TYPES plan_gi_date TYPE string.
    TYPES inco_vers TYPE string.
    TYPES incoterm TYPE string.
    TYPES inco_loc1 TYPE string.
    TYPES inco_loc2 TYPE string.
    TYPES nha_cung_cap_van_tai TYPE string.
    TYPES phan_loai_ptvt TYPE string.
    TYPES so_luong_ptvt TYPE string.
    TYPES bien_so_xe TYPE string.
    TYPES so_container TYPE string.
    TYPES so_seal TYPE string.
    TYPES tare_weight TYPE string.
    TYPES booking TYPE string.
    TYPES ngay_tau_chay TYPE string.
    TYPES ngay_gio_xuat_hang TYPE string.
    TYPES cut_off_time TYPE string.
    TYPES ghi_chu_giao_hang TYPE string.
    TYPES ty_gia_lo_noi_dia TYPE string.
    TYPES has_plan_gi_date TYPE abap_boolean.
    TYPES has_inco_vers TYPE abap_boolean.
    TYPES has_incoterm TYPE abap_boolean.
    TYPES has_inco_loc1 TYPE abap_boolean.
    TYPES has_inco_loc2 TYPE abap_boolean.
    TYPES has_nha_cung_cap_van_tai TYPE abap_boolean.
    TYPES has_phan_loai_ptvt TYPE abap_boolean.
    TYPES has_so_luong_ptvt TYPE abap_boolean.
    TYPES has_bien_so_xe TYPE abap_boolean.
    TYPES has_so_container TYPE abap_boolean.
    TYPES has_so_seal TYPE abap_boolean.
    TYPES has_tare_weight TYPE abap_boolean.
    TYPES has_booking TYPE abap_boolean.
    TYPES has_ngay_tau_chay TYPE abap_boolean.
    TYPES has_ngay_gio_xuat_hang TYPE abap_boolean.
    TYPES has_cut_off_time TYPE abap_boolean.
    TYPES has_ghi_chu_giao_hang TYPE abap_boolean.
    TYPES has_ty_gia_lo_noi_dia TYPE abap_boolean.
    TYPES END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    CLASS-METHODS parse IMPORTING iv_content TYPE xstring RETURNING VALUE(rt_rows) TYPE tt_row
      RAISING zcx_m_od_h.
  PRIVATE SECTION.
    CONSTANTS c_header_rows TYPE i VALUE 3.
    CONSTANTS c_max_rows TYPE i VALUE 1000.
    CLASS-METHODS parse_date IMPORTING iv_value TYPE string RETURNING VALUE(rv_value) TYPE string.
ENDCLASS.



CLASS ZCL_M_OD_H_PARSER IMPLEMENTATION.


  METHOD parse.
    TYPES BEGIN OF ty_input.
    TYPES od TYPE string.
    TYPES plan_gi_date TYPE string.
    TYPES incoterm TYPE string.
    TYPES inco_loc1 TYPE string.
    TYPES nha_cung_cap_van_tai TYPE string.
    TYPES phan_loai_ptvt TYPE string.
    TYPES so_luong_ptvt TYPE string.
    TYPES bien_so_xe TYPE string.
    TYPES so_container TYPE string.
    TYPES so_seal TYPE string.
    TYPES tare_weight TYPE string.
    TYPES booking TYPE string.
    TYPES ngay_tau_chay TYPE string.
    TYPES ngay_gio_xuat_hang TYPE string.
    TYPES cut_off_time TYPE string.
    TYPES ghi_chu_giao_hang TYPE string.
    TYPES ty_gia_lo_noi_dia TYPE string.
    TYPES END OF ty_input.
    DATA inputs TYPE STANDARD TABLE OF ty_input WITH EMPTY KEY.

    TRY.
        DATA(xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = iv_content )->read_access( ).
        DATA(sheet) = xlsx->get_workbook( )->worksheet->at_position( 1 ).
        DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
        DATA(execute) = sheet->select( pattern )->row_stream( )->operation->write_to( REF #( inputs ) ).
        execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_m_od_h EXPORTING text = |Cannot read Excel: { error->get_text( ) }|.
    ENDTRY.

    DO c_header_rows TIMES.
      IF inputs IS NOT INITIAL.
        DELETE inputs INDEX 1.
      ENDIF.
    ENDDO.

    DATA ods      TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_od    TYPE vbeln.
    DATA lv_index TYPE i.

    LOOP AT inputs INTO DATA(input).
      lv_index = sy-tabix.

      IF input-od IS INITIAL
         AND input-plan_gi_date IS INITIAL
         AND input-incoterm IS INITIAL
         AND input-inco_loc1 IS INITIAL
         AND input-nha_cung_cap_van_tai IS INITIAL
         AND input-phan_loai_ptvt IS INITIAL
         AND input-so_luong_ptvt IS INITIAL
         AND input-bien_so_xe IS INITIAL
         AND input-so_container IS INITIAL
         AND input-so_seal IS INITIAL
         AND input-tare_weight IS INITIAL
         AND input-booking IS INITIAL
         AND input-ngay_tau_chay IS INITIAL
         AND input-ngay_gio_xuat_hang IS INITIAL
         AND input-cut_off_time IS INITIAL
         AND input-ghi_chu_giao_hang IS INITIAL
         AND input-ty_gia_lo_noi_dia IS INITIAL.
        CONTINUE.
      ENDIF.

      IF input-od IS INITIAL.
        RAISE EXCEPTION TYPE zcx_m_od_h
          EXPORTING
            text = |OD is mandatory at Excel row { lv_index + c_header_rows }|.
      ENDIF.

      CLEAR lv_od.
      lv_od = input-od.
      DATA(lv_od_alpha) = |{ lv_od ALPHA = IN }|.

      IF line_exists( ods[ table_line = lv_od_alpha ] ).
        RAISE EXCEPTION TYPE zcx_m_od_h
          EXPORTING
            text = |Duplicate OD { input-od } at Excel row { lv_index + c_header_rows }|.
      ENDIF.
      INSERT lv_od_alpha INTO TABLE ods.

      APPEND VALUE #( cid                      = |ROW_{ lv_index }|
                      od                       = lv_od_alpha
                      plan_gi_date             = parse_date( input-plan_gi_date )
                      incoterm                 = input-incoterm
                      inco_loc1                = input-inco_loc1
                      nha_cung_cap_van_tai     = input-nha_cung_cap_van_tai
                      phan_loai_ptvt           = input-phan_loai_ptvt
                      so_luong_ptvt            = input-so_luong_ptvt
                      bien_so_xe               = input-bien_so_xe
                      so_container             = input-so_container
                      so_seal                  = input-so_seal
                      tare_weight              = input-tare_weight
                      booking                  = input-booking
                      ngay_tau_chay            = parse_date( input-ngay_tau_chay )
                      ngay_gio_xuat_hang       = input-ngay_gio_xuat_hang
                      cut_off_time             = input-cut_off_time
                      ghi_chu_giao_hang        = input-ghi_chu_giao_hang
                      ty_gia_lo_noi_dia        = input-ty_gia_lo_noi_dia
                      has_plan_gi_date         = xsdbool( input-plan_gi_date IS NOT INITIAL )
                      has_incoterm             = xsdbool( input-incoterm IS NOT INITIAL )
                      has_inco_loc1            = xsdbool( input-inco_loc1 IS NOT INITIAL )
                      has_nha_cung_cap_van_tai = xsdbool( input-nha_cung_cap_van_tai IS NOT INITIAL )
                      has_phan_loai_ptvt       = xsdbool( input-phan_loai_ptvt IS NOT INITIAL )
                      has_so_luong_ptvt        = xsdbool( input-so_luong_ptvt IS NOT INITIAL )
                      has_bien_so_xe           = xsdbool( input-bien_so_xe IS NOT INITIAL )
                      has_so_container         = xsdbool( input-so_container IS NOT INITIAL )
                      has_so_seal              = xsdbool( input-so_seal IS NOT INITIAL )
                      has_tare_weight          = xsdbool( input-tare_weight IS NOT INITIAL )
                      has_booking              = xsdbool( input-booking IS NOT INITIAL )
                      has_ngay_tau_chay        = xsdbool( input-ngay_tau_chay IS NOT INITIAL )
                      has_ngay_gio_xuat_hang   = xsdbool( input-ngay_gio_xuat_hang IS NOT INITIAL )
                      has_cut_off_time         = xsdbool( input-cut_off_time IS NOT INITIAL )
                      has_ghi_chu_giao_hang    = xsdbool( input-ghi_chu_giao_hang IS NOT INITIAL )
                      has_ty_gia_lo_noi_dia    = xsdbool( input-ty_gia_lo_noi_dia IS NOT INITIAL ) ) TO rt_rows.
    ENDLOOP.

    IF rt_rows IS INITIAL.
      RAISE EXCEPTION TYPE zcx_m_od_h EXPORTING text = 'Excel contains no OD rows'.
    ENDIF.
    IF lines( rt_rows ) > c_max_rows.
      RAISE EXCEPTION TYPE zcx_m_od_h
        EXPORTING
          text = |Excel exceeds the maximum of { c_max_rows } ODs|.
    ENDIF.
  ENDMETHOD.


  METHOD parse_date.
    CONSTANTS c_epoch      TYPE d VALUE '18991230'.  "base cho serial >= 61
    CONSTANTS c_epoch_pre  TYPE d VALUE '18991231'.  "base cho serial <= 59
    CONSTANTS c_max_serial TYPE i VALUE 2958465.     "9999-12-31

    DATA lv_serial TYPE i.
    DATA lv_date   TYPE d.

    CHECK iv_value IS NOT INITIAL.

    DATA(lv_value) = condense( iv_value ).
    rv_value = lv_value.   "mặc định: giữ nguyên những gì user gõ

    " 1) Đã là DD/MM/YYYY -> giữ nguyên
    IF strlen( lv_value ) = 10
       AND lv_value+0(2) CO '0123456789'
       AND lv_value+2(1) = '/'
       AND lv_value+3(2) CO '0123456789'
       AND lv_value+5(1) = '/'
       AND lv_value+6(4) CO '0123456789'.
      RETURN.
    ENDIF.

    " 2) DD.MM.YYYY hoặc DD-MM-YYYY -> chuẩn hoá dấu phân cách
    IF strlen( lv_value ) = 10
       AND lv_value+0(2) CO '0123456789'
       AND ( lv_value+2(1) = '.' OR lv_value+2(1) = '-' )
       AND lv_value+3(2) CO '0123456789'
       AND lv_value+5(1) = lv_value+2(1)
       AND lv_value+6(4) CO '0123456789'.
      rv_value = |{ lv_value+0(2) }/{ lv_value+3(2) }/{ lv_value+6(4) }|.
      RETURN.
    ENDIF.

    " 3) YYYY-MM-DD (ISO)
    IF strlen( lv_value ) = 10
       AND lv_value+0(4) CO '0123456789'
       AND lv_value+4(1) = '-'
       AND lv_value+5(2) CO '0123456789'
       AND lv_value+7(1) = '-'
       AND lv_value+8(2) CO '0123456789'.
      rv_value = |{ lv_value+8(2) }/{ lv_value+5(2) }/{ lv_value+0(4) }|.
      RETURN.
    ENDIF.

    " 4) YYYYMMDD
    IF strlen( lv_value ) = 8 AND lv_value CO '0123456789'.
      rv_value = |{ lv_value+6(2) }/{ lv_value+4(2) }/{ lv_value+0(4) }|.
      RETURN.
    ENDIF.

    " 5) Excel serial number (46023, hoặc 46023.5 nếu ô là datetime)
    DATA(lv_num) = lv_value.
    IF lv_num CS '.'.
      SPLIT lv_num AT '.' INTO lv_num DATA(lv_frac).
    ENDIF.

    IF lv_num CO '0123456789' AND strlen( lv_num ) BETWEEN 1 AND 7.
      lv_serial = lv_num.
      IF lv_serial >= 61 AND lv_serial <= c_max_serial.
        lv_date  = c_epoch + lv_serial.
        rv_value = |{ lv_date+6(2) }/{ lv_date+4(2) }/{ lv_date+0(4) }|.
      ELSEIF lv_serial >= 1 AND lv_serial <= 59.
        lv_date  = c_epoch_pre + lv_serial.
        rv_value = |{ lv_date+6(2) }/{ lv_date+4(2) }/{ lv_date+0(4) }|.
      ENDIF.
      RETURN.
    ENDIF.

    " 6) Text tự do -> giữ nguyên (rv_value đã gán ở đầu method)
  ENDMETHOD.
ENDCLASS.
