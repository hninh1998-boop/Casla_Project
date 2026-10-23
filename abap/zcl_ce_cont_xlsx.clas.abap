CLASS zcl_ce_cont_xlsx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Sinh file xlsx "Tem KH đóng cont" theo template (TemKHDongCont_Tuan42_12-10-2026 - v8.xlsx)
    " xlsx = file zip chứa các file XML → tự viết XML rồi nén bằng cl_abap_zip
    " Format giữ đúng như bản export FE (ExcelJS) trước đây
    CLASS-METHODS build
      IMPORTING it_data        TYPE zcl_ce_cont_top=>tt_result
                iv_today       TYPE d
      RETURNING VALUE(rv_xlsx) TYPE xstring.

    " TemKHDongCont_Tuan<tuần>_<ngày>-<tháng>-<năm>
    CLASS-METHODS file_name
      IMPORTING iv_today       TYPE d
      RETURNING VALUE(rv_name) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_num TYPE p LENGTH 16 DECIMALS 6.
    TYPES ty_height TYPE p LENGTH 8 DECIMALS 2.

    " Cột trên file excel, theo đúng thứ tự trên template v8 (B → AC)
    TYPES: BEGIN OF ty_col,
             field  TYPE string,
             label  TYPE string,
             width  TYPE i,
             format TYPE c LENGTH 1, " S = text, Z = text bỏ số 0 đầu, Q = số lượng, D = ngày
             center TYPE abap_bool,
             wrap   TYPE abap_bool,
             merge  TYPE abap_bool,
             letter TYPE string,
           END OF ty_col,
           tt_col TYPE STANDARD TABLE OF ty_col WITH EMPTY KEY.

    " Khối ô đang gộp của 1 cột
    TYPES: BEGIN OF ty_merge,
             col_index TYPE i,
             start_row TYPE i,
             prev      TYPE string,
           END OF ty_merge,
           tt_merge TYPE STANDARD TABLE OF ty_merge WITH EMPTY KEY.

    " Khối ô wrapText đã gộp → cần tính lại chiều cao dòng
    TYPES: BEGIN OF ty_wrap_block,
             field     TYPE string,
             width     TYPE i,
             start_row TYPE i,
             end_row   TYPE i,
           END OF ty_wrap_block,
           tt_wrap_block TYPE STANDARD TABLE OF ty_wrap_block WITH EMPTY KEY.

    TYPES: BEGIN OF ty_row_height,
             row    TYPE i,
             height TYPE ty_height,
           END OF ty_row_height,
           tt_row_height TYPE HASHED TABLE OF ty_row_height WITH UNIQUE KEY row.

    TYPES: BEGIN OF ty_week,
             week TYPE i,
             from TYPE string,
             to   TYPE string,
           END OF ty_week.

    " Index trong <cellXfs> của styles.xml
    CONSTANTS: BEGIN OF gc_style,
                 dept        TYPE i VALUE 1,
                 company     TYPE i VALUE 2,
                 week        TYPE i VALUE 3,
                 header      TYPE i VALUE 4,
                 text        TYPE i VALUE 5,
                 text_wrap   TYPE i VALUE 6,
                 text_center TYPE i VALUE 7,
                 qty_int     TYPE i VALUE 8,
                 qty_dec     TYPE i VALUE 9,
                 date        TYPE i VALUE 10,
               END OF gc_style.

    CONSTANTS gc_dept_name TYPE string VALUE `PHÒNG KD-XNK`.
    CONSTANTS gc_header_row TYPE i VALUE 4.
    CONSTANTS gc_first_col TYPE i VALUE 2. " B (cột A ẩn)

    " Chiều cao dòng (pt): mặc định 1 dòng, và mỗi dòng chữ khi wrapText (font size 10)
    CONSTANTS gc_default_height TYPE ty_height VALUE 15.
    CONSTANTS gc_line_height TYPE ty_height VALUE '13.5'.

    CLASS-METHODS get_columns
      RETURNING VALUE(rt_cols) TYPE tt_col.

    CLASS-METHODS week_info
      IMPORTING iv_today       TYPE d
      RETURNING VALUE(rs_week) TYPE ty_week.

    CLASS-METHODS sheet_xml
      IMPORTING it_data       TYPE zcl_ce_cont_top=>tt_result
                iv_today      TYPE d
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS title_rows
      IMPORTING it_data       TYPE zcl_ce_cont_top=>tt_result
                it_cols       TYPE tt_col
                iv_today      TYPE d
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS data_cell
      IMPORTING is_data       TYPE zce_cont
                is_col        TYPE ty_col
                iv_row        TYPE i
      RETURNING VALUE(rv_xml) TYPE string.

    " Chốt khối đang gộp của 1 cột: gộp ô từ start_row đến dòng liền trước iv_end_row
    CLASS-METHODS close_block
      IMPORTING is_col         TYPE ty_col
                iv_start_row   TYPE i
                iv_end_row     TYPE i
      CHANGING  ct_merge_refs  TYPE string_table
                ct_wrap_blocks TYPE tt_wrap_block.

    " Excel không tự giãn chiều cao dòng theo ô đã gộp → với ô wrapText gộp nhiều dòng
    " mà tổng chiều cao các dòng không đủ chứa nội dung thì tăng chiều cao các dòng đó
    CLASS-METHODS fit_merged_row_heights
      IMPORTING it_data           TYPE zcl_ce_cont_top=>tt_result
                it_cols           TYPE tt_col
                it_wrap_blocks    TYPE tt_wrap_block
                iv_first_data_row TYPE i
      RETURNING VALUE(rt_heights) TYPE tt_row_height.

    " Ước lượng (thiên cao) chiều cao cần để hiển thị hết 1 ô wrapText trong cột rộng iv_width
    CLASS-METHODS estimate_height
      IMPORTING iv_text          TYPE string
                iv_width         TYPE i
      RETURNING VALUE(rv_height) TYPE ty_height.

    " Chiều cao 1 dòng nếu chỉ tính các ô wrapText không bị gộp (iv_exclude là cột đã gộp)
    CLASS-METHODS own_row_height
      IMPORTING is_data          TYPE zce_cont
                it_cols          TYPE tt_col
                iv_exclude       TYPE string
      RETURNING VALUE(rv_height) TYPE ty_height.

    " Khoá nhóm để gộp ô: đã có SỐ CONT → nhóm theo SỐ CONT; chưa có SỐ CONT nhưng
    " đã có OD → nhóm theo OD; không có cả hai → "" (dòng này không gộp với ai)
    CLASS-METHODS merge_group_key
      IMPORTING is_data       TYPE zce_cont
      RETURNING VALUE(rv_key) TYPE string.

    CLASS-METHODS get_value
      IMPORTING is_data         TYPE zce_cont
                iv_field        TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    " Bỏ số 0 đầu của các field kiểu SO/Item/DO (toàn số 0 → để trống)
    CLASS-METHODS strip_zeros
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS text_cell
      IMPORTING iv_ref        TYPE string
                iv_style      TYPE i
                iv_value      TYPE string OPTIONAL
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS styles_xml
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS col_letter
      IMPORTING iv_index         TYPE i
      RETURNING VALUE(rv_letter) TYPE string.

    CLASS-METHODS to_utf8
      IMPORTING iv_string         TYPE string
      RETURNING VALUE(rv_xstring) TYPE xstring.

ENDCLASS.



CLASS zcl_ce_cont_xlsx IMPLEMENTATION.


  METHOD build.

    DATA(lv_xml_decl) = |<?xml version="1.0" encoding="UTF-8" standalone="yes"?>|.

    DATA(lv_content_types) = lv_xml_decl
      && |<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">|
      && |<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>|
      && |<Default Extension="xml" ContentType="application/xml"/>|
      && |<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>|
      && |<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>|
      && |<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>|
      && |</Types>|.

    DATA(lv_rels) = lv_xml_decl
      && |<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">|
      && |<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>|
      && |</Relationships>|.

    DATA(lv_workbook) = lv_xml_decl
      && |<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"|
      && | xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">|
      && |<bookViews><workbookView/></bookViews>|
      && |<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>|
      && |</workbook>|.

    DATA(lv_workbook_rels) = lv_xml_decl
      && |<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">|
      && |<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>|
      && |<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>|
      && |</Relationships>|.

    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = '[Content_Types].xml'        content = to_utf8( lv_content_types ) ).
    lo_zip->add( name = '_rels/.rels'                content = to_utf8( lv_rels ) ).
    lo_zip->add( name = 'xl/workbook.xml'            content = to_utf8( lv_workbook ) ).
    lo_zip->add( name = 'xl/_rels/workbook.xml.rels' content = to_utf8( lv_workbook_rels ) ).
    lo_zip->add( name = 'xl/styles.xml'              content = to_utf8( lv_xml_decl && styles_xml( ) ) ).
    lo_zip->add( name = 'xl/worksheets/sheet1.xml'
                 content = to_utf8( lv_xml_decl && sheet_xml( it_data  = it_data
                                                              iv_today = iv_today ) ) ).

    rv_xlsx = lo_zip->save( ).

  ENDMETHOD.


  METHOD file_name.

    DATA(ls_week) = week_info( iv_today ).

    " Ngày / tháng không có số 0 đầu (giống toLocaleDateString("vi-VN") của bản FE)
    rv_name = |TemKHDongCont_Tuan{ ls_week-week }_|
           && |{ CONV i( iv_today+6(2) ) }-{ CONV i( iv_today+4(2) ) }-{ iv_today(4) }|.

  ENDMETHOD.


  METHOD get_columns.

    rt_cols = VALUE #(
      ( field = `Ngay`                       label = `Thứ/ Ngày`                          width = 10 format = 'D' merge = abap_true )
      ( field = `GioGoiContVeNM`             label = `Giờ gọi cont về NM`                 width = 12 format = 'S' merge = abap_true )
      ( field = `SoCont`                     label = `SỐ CONT`                            width = 12 format = 'S' merge = abap_true )
      ( field = `SoChi`                      label = `SỐ CHÌ`                             width = 10 format = 'S' merge = abap_true )
      ( field = `NgayTauChay`                label = `Ngày tàu chạy`                      width = 12 format = 'S' merge = abap_true )
      ( field = `Booking`                    label = `Số Booking`                         width = 12 format = 'S' merge = abap_true )
      ( field = `ThoiGianCatMang`            label = `Thời gian cắt máng`                 width = 12 format = 'S' merge = abap_true )
      ( field = `GhiChuGiaoHang`             label = `Phương thức đóng hàng & phối thùng` width = 42 format = 'S' merge = abap_true wrap = abap_true )
      ( field = `SO`                         label = `Số SO`                              width = 12 format = 'Z' center = abap_true )
      ( field = `SOItem`                     label = `Item`                               width = 8  format = 'Z' center = abap_true )
      ( field = `SoKH`                       label = `SỐ KH`                              width = 14 format = 'S' )
      ( field = `MaHang`                     label = `Mã hàng`                            width = 14 format = 'Z' )
      ( field = `TenHang`                    label = `TÊN TÚI`                            width = 14 format = 'S' )
      ( field = `SoLuongTrenLenhXuatHang`    label = `Số lượng trên lệnh xuất hàng`       width = 16 format = 'Q' center = abap_true )
      ( field = `Cont`                       label = `Cont`                               width = 10 format = 'S' merge = abap_true )
      ( field = `NhaCungCapVanTai`           label = `Nhà cung cấp VT`                    width = 14 format = 'S' merge = abap_true wrap = abap_true )
      ( field = `DiaDiemDongHangContName`    label = `Địa điểm đóng hàng`                 width = 16 format = 'S' merge = abap_true )
      ( field = `PlantName`                  label = `Plant`                              width = 16 format = 'S' merge = abap_true )
      ( field = `SoLenhXuatHang`             label = `Số lệnh xuất hàng (OD)`             width = 14 format = 'Z' center = abap_true merge = abap_true )
      ( field = `SoLenhXuatHangItem`         label = `OD item`                            width = 8  format = 'Z' center = abap_true )
      ( field = `SoLuongChuaLenLenhXuatHang` label = `Số lượng chưa lên lệnh xuất hàng`   width = 16 format = 'Q' center = abap_true )
      ( field = `KichThhuocTui`              label = `Kich thước túi`                     width = 12 format = 'S' )
      ( field = `LoaiMang`                   label = `Loại màng`                          width = 12 format = 'S' )
      ( field = `LoaiManh`                   label = `Loại manh`                          width = 12 format = 'S' )
      ( field = `LoaiTui`                    label = `Loại túi`                           width = 12 format = 'S' )
      ( field = `TrangThaiOD`                label = `Trạng thái OD`                      width = 14 format = 'S' )
      ( field = `KeHoachDongCont`            label = `Kế hoạch đóng cont`                 width = 14 format = 'S' )
      ( field = `GhiChuKhac`                 label = `Ghi chú khác`                       width = 20 format = 'S' wrap = abap_true ) ).

    LOOP AT rt_cols ASSIGNING FIELD-SYMBOL(<ls_col>).
      <ls_col>-letter = col_letter( gc_first_col + sy-tabix - 1 ).
    ENDLOOP.

  ENDMETHOD.


  METHOD week_info.

    " Tuần hiện tại (Thứ 2 → Thứ 7) theo ngày export
    " Thứ trong tuần: 0 = Chủ nhật ... 6 = Thứ 7 (07.01.1900 là Chủ nhật)
    DATA(lv_weekday) = ( iv_today - CONV d( '19000107' ) ) MOD 7.
    DATA(lv_day) = COND i( WHEN lv_weekday = 0 THEN 7 ELSE lv_weekday ).

    DATA(lv_monday) = CONV d( iv_today - ( lv_day - 1 ) ).
    DATA(lv_saturday) = CONV d( lv_monday + 5 ).

    DATA(lv_jan1) = CONV d( |{ lv_monday(4) }0101| ).
    DATA(lv_jan1_weekday) = ( lv_jan1 - CONV d( '19000107' ) ) MOD 7.

    rs_week-week = ( ( lv_monday - lv_jan1 ) + lv_jan1_weekday + 1 + 6 ) DIV 7.
    rs_week-from = |{ lv_monday+6(2) }.{ lv_monday+4(2) }|.
    rs_week-to   = |{ lv_saturday+6(2) }.{ lv_saturday+4(2) }|.

  ENDMETHOD.


  METHOD sheet_xml.

    DATA lt_cell_rows   TYPE string_table.
    DATA lt_merge_refs  TYPE string_table.
    DATA lt_wrap_blocks TYPE tt_wrap_block.
    DATA lt_merges      TYPE tt_merge.
    DATA lt_continued   TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.

    DATA(lt_cols) = get_columns( ).
    DATA(lv_last_letter) = lt_cols[ lines( lt_cols ) ]-letter.
    DATA(lv_first_data_row) = gc_header_row + 1.

    " ── Dòng 1-3: Phòng ban / Tên công ty / Tên nhà máy / Tuần ──
    " ── Dòng 4: Header ──
    DATA(lv_rows) = title_rows( it_data  = it_data
                                it_cols  = lt_cols
                                iv_today = iv_today ).

    " ── Dữ liệu ──
    " Gộp ô các dòng liên tiếp cùng "nhóm" (xem merge_group_key). Trong cùng nhóm, cột nào có
    " cùng giá trị (kể cả cùng để trống) thì gộp; khác nhóm thì luôn tách riêng dù giá trị trùng.
    " Cột OD: các dòng liền nhau cùng OD thì gộp (kể cả khi đã có SỐ CONT)
    LOOP AT lt_cols INTO DATA(ls_col) WHERE merge = abap_true.
      APPEND VALUE #( col_index = sy-tabix start_row = lv_first_data_row ) TO lt_merges.
    ENDLOOP.

    DATA(lv_row) = lv_first_data_row.
    DATA lv_prev_key TYPE string.

    LOOP AT it_data INTO DATA(ls_data).
      DATA(lv_index) = sy-tabix.

      DATA(lv_key) = merge_group_key( ls_data ).
      DATA(lv_same_group) = xsdbool( lv_index > 1 AND lv_key IS NOT INITIAL AND lv_key = lv_prev_key ).

      CLEAR lt_continued.
      LOOP AT lt_merges ASSIGNING FIELD-SYMBOL(<ls_merge>).
        ls_col = lt_cols[ <ls_merge>-col_index ].
        IF lv_same_group = abap_true
           AND get_value( is_data = ls_data iv_field = ls_col-field ) = <ls_merge>-prev.
          INSERT <ls_merge>-col_index INTO TABLE lt_continued.
        ELSE.
          close_block( EXPORTING is_col         = ls_col
                                 iv_start_row   = <ls_merge>-start_row
                                 iv_end_row     = lv_row
                       CHANGING  ct_merge_refs  = lt_merge_refs
                                 ct_wrap_blocks = lt_wrap_blocks ).
          <ls_merge>-start_row = lv_row.
        ENDIF.
      ENDLOOP.

      DATA(lv_cells) = ``.
      LOOP AT lt_cols INTO ls_col.
        IF line_exists( lt_continued[ table_line = sy-tabix ] ).
          " Dòng thuộc cùng 1 giá trị với dòng trên → để trống, sẽ được gộp ô
          lv_cells = lv_cells && text_cell( iv_ref   = |{ ls_col-letter }{ lv_row }|
                                            iv_style = COND #( WHEN ls_col-wrap = abap_true THEN gc_style-text_wrap
                                                               WHEN ls_col-center = abap_true THEN gc_style-text_center
                                                               ELSE gc_style-text ) ).
        ELSE.
          lv_cells = lv_cells && data_cell( is_data = ls_data
                                            is_col  = ls_col
                                            iv_row  = lv_row ).
        ENDIF.
      ENDLOOP.
      APPEND lv_cells TO lt_cell_rows.

      LOOP AT lt_merges ASSIGNING <ls_merge>.
        <ls_merge>-prev = get_value( is_data = ls_data iv_field = lt_cols[ <ls_merge>-col_index ]-field ).
      ENDLOOP.
      lv_prev_key = lv_key.
      lv_row += 1.
    ENDLOOP.

    LOOP AT lt_merges ASSIGNING <ls_merge>.
      close_block( EXPORTING is_col         = lt_cols[ <ls_merge>-col_index ]
                             iv_start_row   = <ls_merge>-start_row
                             iv_end_row     = lv_row
                   CHANGING  ct_merge_refs  = lt_merge_refs
                             ct_wrap_blocks = lt_wrap_blocks ).
    ENDLOOP.

    DATA(lt_heights) = fit_merged_row_heights( it_data           = it_data
                                               it_cols           = lt_cols
                                               it_wrap_blocks    = lt_wrap_blocks
                                               iv_first_data_row = lv_first_data_row ).

    LOOP AT lt_cell_rows INTO lv_cells.
      DATA(lv_data_row) = lv_first_data_row + sy-tabix - 1.
      READ TABLE lt_heights INTO DATA(ls_height) WITH TABLE KEY row = lv_data_row.
      IF sy-subrc = 0.
        lv_rows = lv_rows && |<row r="{ lv_data_row }" ht="{ ls_height-height }" customHeight="1">{ lv_cells }</row>|.
      ELSE.
        lv_rows = lv_rows && |<row r="{ lv_data_row }">{ lv_cells }</row>|.
      ENDIF.
    ENDLOOP.

    " ── Độ rộng cột: cột A ẩn ──
    DATA(lv_cols) = |<col min="1" max="1" width="3" hidden="1" customWidth="1"/>|.
    LOOP AT lt_cols INTO ls_col.
      DATA(lv_col_index) = gc_first_col + sy-tabix - 1.
      lv_cols = lv_cols && |<col min="{ lv_col_index }" max="{ lv_col_index }" width="{ ls_col-width }" customWidth="1"/>|.
    ENDLOOP.

    " ── Gộp ô: phòng ban (B1:C3), tên công ty / nhà máy / tuần (D:cột cuối), dữ liệu ──
    DATA(lt_all_merges) = VALUE string_table( ( |B1:C3| )
                                              ( |D1:{ lv_last_letter }1| )
                                              ( |D2:{ lv_last_letter }2| )
                                              ( |D3:{ lv_last_letter }3| ) ).
    APPEND LINES OF lt_merge_refs TO lt_all_merges.

    DATA(lv_merge_cells) = ``.
    LOOP AT lt_all_merges INTO DATA(lv_ref).
      lv_merge_cells = lv_merge_cells && |<mergeCell ref="{ lv_ref }"/>|.
    ENDLOOP.

    rv_xml = |<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|
          && |<sheetFormatPr defaultRowHeight="15"/>|
          && |<cols>{ lv_cols }</cols>|
          && |<sheetData>{ lv_rows }</sheetData>|
          && |<mergeCells count="{ lines( lt_all_merges ) }">{ lv_merge_cells }</mergeCells>|
          && |</worksheet>|.

  ENDMETHOD.


  METHOD title_rows.

    DATA(ls_week) = week_info( iv_today ).

    DATA(lv_company) = COND string( WHEN it_data IS NOT INITIAL THEN it_data[ 1 ]-CompanyCodeName ).
    DATA(lv_plant)   = COND string( WHEN it_data IS NOT INITIAL THEN it_data[ 1 ]-DiaDiemDongHangContName ).
    DATA(lv_week)    = |Tuần { ls_week-week } (từ ngày { ls_week-from }-{ ls_week-to })|.

    " Dòng 1-3: cột B-C là Phòng ban (gộp 3 dòng), cột D → cột cuối là Tên công ty / Tên nhà máy / Tuần
    DO 3 TIMES.
      DATA(lv_row) = sy-index.
      DATA(lv_style) = COND i( WHEN lv_row = 3 THEN gc_style-week ELSE gc_style-company ).
      DATA(lv_value) = SWITCH string( lv_row WHEN 1 THEN lv_company
                                             WHEN 2 THEN lv_plant
                                             ELSE lv_week ).

      rv_xml = rv_xml && |<row r="{ lv_row }">|
             && text_cell( iv_ref   = |B{ lv_row }|
                           iv_style = gc_style-dept
                           iv_value = COND #( WHEN lv_row = 1 THEN gc_dept_name ) )
             && text_cell( iv_ref = |C{ lv_row }| iv_style = gc_style-dept ).

      LOOP AT it_cols INTO DATA(ls_col) FROM 3.
        rv_xml = rv_xml && text_cell( iv_ref   = |{ ls_col-letter }{ lv_row }|
                                      iv_style = lv_style
                                      iv_value = COND #( WHEN sy-tabix = 3 THEN lv_value ) ).
      ENDLOOP.

      rv_xml = rv_xml && |</row>|.
    ENDDO.

    " Dòng 4: Header
    rv_xml = rv_xml && |<row r="{ gc_header_row }" ht="30" customHeight="1">|.
    LOOP AT it_cols INTO ls_col.
      rv_xml = rv_xml && text_cell( iv_ref   = |{ ls_col-letter }{ gc_header_row }|
                                    iv_style = gc_style-header
                                    iv_value = ls_col-label ).
    ENDLOOP.
    rv_xml = rv_xml && |</row>|.

  ENDMETHOD.


  METHOD data_cell.

    DATA(lv_ref) = |{ is_col-letter }{ iv_row }|.

    CASE is_col-format.
      WHEN 'Q'.
        " Số lượng: làm tròn 3 số lẻ; chỉ dùng format có phần lẻ khi giá trị thực sự có số lẻ
        ASSIGN COMPONENT is_col-field OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_quantity>).
        DATA(lv_number) = CONV ty_num( round( val = CONV decfloat34( <lv_quantity> ) dec = 3 ) ).
        rv_xml = |<c r="{ lv_ref }" s="{ COND i( WHEN frac( lv_number ) <> 0
                                                  THEN gc_style-qty_dec
                                                  ELSE gc_style-qty_int ) }"><v>{ lv_number }</v></c>|.

      WHEN 'D'.
        ASSIGN COMPONENT is_col-field OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_date>).
        IF <lv_date> IS INITIAL.
          rv_xml = text_cell( iv_ref = lv_ref iv_style = gc_style-text ).
        ELSE.
          " Excel lưu ngày dạng số ngày tính từ 30.12.1899
          rv_xml = |<c r="{ lv_ref }" s="{ gc_style-date }"><v>{ CONV d( <lv_date> ) - CONV d( '18991230' ) }</v></c>|.
        ENDIF.

      WHEN OTHERS.
        DATA(lv_text) = get_value( is_data = is_data iv_field = is_col-field ).
        IF is_col-format = 'Z'.
          lv_text = strip_zeros( lv_text ).
        ENDIF.
        rv_xml = text_cell( iv_ref   = lv_ref
                            iv_value = lv_text
                            iv_style = COND #( WHEN is_col-wrap = abap_true   THEN gc_style-text_wrap
                                               WHEN is_col-center = abap_true THEN gc_style-text_center
                                               ELSE gc_style-text ) ).
    ENDCASE.

  ENDMETHOD.


  METHOD close_block.

    IF iv_end_row - iv_start_row <= 1.
      RETURN.
    ENDIF.

    APPEND |{ is_col-letter }{ iv_start_row }:{ is_col-letter }{ iv_end_row - 1 }| TO ct_merge_refs.

    IF is_col-wrap = abap_true.
      APPEND VALUE #( field     = is_col-field
                      width     = is_col-width
                      start_row = iv_start_row
                      end_row   = iv_end_row - 1 ) TO ct_wrap_blocks.
    ENDIF.

  ENDMETHOD.


  METHOD fit_merged_row_heights.

    DATA lt_own TYPE STANDARD TABLE OF ty_height WITH EMPTY KEY.

    LOOP AT it_wrap_blocks INTO DATA(ls_block).
      CLEAR lt_own.
      DATA(lv_own_total) = CONV ty_height( 0 ).

      DATA(lv_row) = ls_block-start_row.
      WHILE lv_row <= ls_block-end_row.
        DATA(lv_own) = own_row_height( is_data    = it_data[ lv_row - iv_first_data_row + 1 ]
                                       it_cols    = it_cols
                                       iv_exclude = ls_block-field ).
        APPEND lv_own TO lt_own.
        lv_own_total += lv_own.
        lv_row += 1.
      ENDWHILE.

      DATA(lv_needed) = estimate_height(
                          iv_text  = get_value( is_data  = it_data[ ls_block-start_row - iv_first_data_row + 1 ]
                                                iv_field = ls_block-field )
                          iv_width = ls_block-width ).
      IF lv_needed <= lv_own_total.
        CONTINUE.
      ENDIF.

      DATA(lv_extra) = CONV ty_height( ( lv_needed - lv_own_total ) / lines( lt_own ) ).
      LOOP AT lt_own INTO lv_own.
        DATA(lv_height_row) = ls_block-start_row + sy-tabix - 1.
        DELETE TABLE rt_heights WITH TABLE KEY row = lv_height_row.
        INSERT VALUE #( row = lv_height_row height = lv_own + lv_extra ) INTO TABLE rt_heights.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD estimate_height.

    IF iv_text IS INITIAL.
      rv_height = gc_default_height.
      RETURN.
    ENDIF.

    DATA(lv_chars_per_line) = nmax( val1 = 1 val2 = iv_width * 12 DIV 10 ).
    DATA(lv_newline) = cl_abap_char_utilities=>newline.

    DATA(lv_text) = replace( val  = iv_text
                             sub  = cl_abap_char_utilities=>cr_lf
                             with = lv_newline
                             occ  = 0 ).

    SPLIT lv_text AT lv_newline INTO TABLE DATA(lt_lines).
    " SPLIT bỏ đoạn rỗng cuối cùng → text kết thúc bằng xuống dòng vẫn tính thêm 1 dòng
    IF substring( val = lv_text off = strlen( lv_text ) - 1 ) = lv_newline.
      APPEND `` TO lt_lines.
    ENDIF.

    DATA lv_lines TYPE i.
    LOOP AT lt_lines INTO DATA(lv_line).
      lv_lines += nmax( val1 = 1 val2 = ( strlen( lv_line ) + lv_chars_per_line - 1 ) DIV lv_chars_per_line ).
    ENDLOOP.

    rv_height = lv_lines * gc_line_height + 3.
    IF rv_height < gc_default_height.
      rv_height = gc_default_height.
    ENDIF.

  ENDMETHOD.


  METHOD own_row_height.

    rv_height = gc_default_height.

    LOOP AT it_cols INTO DATA(ls_col) WHERE wrap = abap_true AND field <> iv_exclude.
      DATA(lv_height) = estimate_height( iv_text  = get_value( is_data = is_data iv_field = ls_col-field )
                                         iv_width = ls_col-width ).
      IF lv_height > rv_height.
        rv_height = lv_height.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD merge_group_key.

    IF is_data-SoCont IS NOT INITIAL.
      rv_key = |C\|{ is_data-SoCont }|.
    ELSEIF is_data-SoLenhXuatHang IS NOT INITIAL.
      rv_key = |O\|{ is_data-SoLenhXuatHang }|.
    ENDIF.

  ENDMETHOD.


  METHOD get_value.

    ASSIGN COMPONENT iv_field OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_value>).
    IF sy-subrc = 0 AND <lv_value> IS NOT INITIAL.
      rv_value = <lv_value>.
    ENDIF.

  ENDMETHOD.


  METHOD strip_zeros.

    rv_text = condense( iv_value ).
    IF rv_text IS INITIAL OR rv_text CN '0123456789'.
      RETURN.
    ENDIF.

    SHIFT rv_text LEFT DELETING LEADING '0'.

  ENDMETHOD.


  METHOD text_cell.

    IF iv_value IS INITIAL.
      rv_xml = |<c r="{ iv_ref }" s="{ iv_style }"/>|.
      RETURN.
    ENDIF.

    " Bỏ các ký tự điều khiển không hợp lệ trong XML (tránh file bị lỗi khi mở)
    DATA(lv_text) = replace( val  = iv_value
                             pcre = `[\x00-\x08\x0B\x0C\x0E-\x1F]`
                             with = ``
                             occ  = 0 ).

    lv_text = escape( val    = lv_text
                      format = cl_abap_format=>e_xml_text ).

    rv_xml = |<c r="{ iv_ref }" s="{ iv_style }" t="inlineStr"><is><t xml:space="preserve">{ lv_text }</t></is></c>|.

  ENDMETHOD.


  METHOD styles_xml.

    " Muốn đổi màu / font / viền thì sửa ở đây. Thứ tự <xf> trong <cellXfs> phải khớp gc_style
    DATA(lv_data) = |fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"|.

    rv_xml = |<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|

          && |<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.###"/></numFmts>|

          " fontId: 0 = dữ liệu, 1 = phòng ban, 2 = tên công ty / nhà máy (đỏ), 3 = tuần, 4 = header
          && |<fonts count="5">|
          && |<font><sz val="10"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="12"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="14"/><color rgb="FFFF0000"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="13"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="10"/><name val="Times New Roman"/><family val="1"/></font>|
          && |</fonts>|

          " fillId: 0, 1 = bắt buộc của Excel, 2 = nền xám của header
          && |<fills count="3">|
          && |<fill><patternFill patternType="none"/></fill>|
          && |<fill><patternFill patternType="gray125"/></fill>|
          && |<fill><patternFill patternType="solid"><fgColor rgb="FFF2F2F2"/><bgColor indexed="64"/></patternFill></fill>|
          && |</fills>|

          " borderId: 0 = không viền, 1 = viền mỏng 4 cạnh, 2 = chỉ viền dưới (dòng tuần)
          && |<borders count="3">|
          && |<border><left/><right/><top/><bottom/><diagonal/></border>|
          && |<border><left style="thin"><color auto="1"/></left><right style="thin"><color auto="1"/></right>|
          && |<top style="thin"><color auto="1"/></top><bottom style="thin"><color auto="1"/></bottom><diagonal/></border>|
          && |<border><left/><right/><top/><bottom style="thin"><color auto="1"/></bottom><diagonal/></border>|
          && |</borders>|

          && |<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>|

          " numFmtId: 3 = #,##0   14 = ngày   164 = #,##0.###
          && |<cellXfs count="11">|
          " 0: mặc định
          && |<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>|
          " 1: dept
          && |<xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center" wrapText="1"/></xf>|
          " 2: company / plant
          && |<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center"/></xf>|
          " 3: week
          && |<xf numFmtId="0" fontId="3" fillId="0" borderId="2" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center"/></xf>|
          " 4: header
          && |<xf numFmtId="0" fontId="4" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center" wrapText="1"/></xf>|
          " 5: text
          && |<xf numFmtId="0" { lv_data }><alignment horizontal="left" vertical="center"/></xf>|
          " 6: text_wrap
          && |<xf numFmtId="0" { lv_data }><alignment horizontal="left" vertical="center" wrapText="1"/></xf>|
          " 7: text_center
          && |<xf numFmtId="0" { lv_data }><alignment horizontal="center" vertical="center"/></xf>|
          " 8: qty_int
          && |<xf numFmtId="3" { lv_data } applyNumberFormat="1"><alignment horizontal="center" vertical="center"/></xf>|
          " 9: qty_dec
          && |<xf numFmtId="164" { lv_data } applyNumberFormat="1"><alignment horizontal="center" vertical="center"/></xf>|
          " 10: date
          && |<xf numFmtId="14" { lv_data } applyNumberFormat="1"><alignment horizontal="left" vertical="center"/></xf>|
          && |</cellXfs>|

          && |<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>|
          && |</styleSheet>|.

  ENDMETHOD.


  METHOD col_letter.

    CONSTANTS lc_alphabet TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZ`.

    DATA(lv_index) = iv_index.
    WHILE lv_index > 0.
      DATA(lv_remainder) = ( lv_index - 1 ) MOD 26.
      rv_letter = substring( val = lc_alphabet off = lv_remainder len = 1 ) && rv_letter.
      lv_index = ( lv_index - 1 ) DIV 26.
    ENDWHILE.

  ENDMETHOD.


  METHOD to_utf8.

    rv_xstring = cl_abap_conv_codepage=>create_out( )->convert( iv_string ).

  ENDMETHOD.
ENDCLASS.
