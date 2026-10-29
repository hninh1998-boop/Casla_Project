CLASS zcl_ce_sales_v3_xlsx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    " Sinh file xlsx "BÁO CÁO BÁN HÀNG" theo template.xlsx
    " xlsx = file zip chứa các file XML → tự viết XML rồi nén bằng cl_abap_zip
    CLASS-METHODS build
      IMPORTING it_data         TYPE zcl_ce_sales_v3=>tt_result
                iv_subtitle     TYPE string
                iv_footer_plant TYPE string
      RETURNING VALUE(rv_xlsx)  TYPE xstring.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_num TYPE p LENGTH 16 DECIMALS 6.

    TYPES: BEGIN OF ty_unit,
             unit TYPE meins,
             text TYPE string,
           END OF ty_unit,
           BEGIN OF ty_currency,
             currency TYPE waers,
             factor   TYPE decfloat34,
           END OF ty_currency.

    " Index trong <cellXfs> của styles.xml
    " Style dòng dữ liệu: +0 = dòng đầu (viền trên liền), +1 = các dòng sau (viền trên chấm)
    CONSTANTS: BEGIN OF gc_style,
                 title      TYPE i VALUE 1,
                 subtitle   TYPE i VALUE 2,
                 line       TYPE i VALUE 3,
                 header     TYPE i VALUE 4,
                 center     TYPE i VALUE 5,
                 text       TYPE i VALUE 7,
                 num0       TYPE i VALUE 9,
                 num2       TYPE i VALUE 11,
                 num3       TYPE i VALUE 13,
                 total_text TYPE i VALUE 15,
                 total_num0 TYPE i VALUE 16,
                 total_num2 TYPE i VALUE 17,
                 total_num3 TYPE i VALUE 18,
               END OF gc_style.

    CONSTANTS gc_header_row TYPE i VALUE 4.
    CONSTANTS gc_sheet_name TYPE string VALUE `Báo cáo bán hàng`.

    CLASS-DATA gt_unit     TYPE HASHED TABLE OF ty_unit WITH UNIQUE KEY unit.
    CLASS-DATA gt_currency TYPE HASHED TABLE OF ty_currency WITH UNIQUE KEY currency.

    " Đọc trước text ĐVT (dạng hiển thị, vd. ST → PC) và số lẻ của tiền tệ
    CLASS-METHODS prepare
      IMPORTING it_data TYPE zcl_ce_sales_v3=>tt_result.

    CLASS-METHODS sheet_xml
      IMPORTING it_data         TYPE zcl_ce_sales_v3=>tt_result
                iv_subtitle     TYPE string
                iv_footer_plant TYPE string
      RETURNING VALUE(rv_xml)   TYPE string.

    CLASS-METHODS header_row
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS styles_xml
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS text_cell
      IMPORTING iv_col        TYPE string
                iv_row        TYPE i
                iv_style      TYPE i
                iv_value      TYPE csequence OPTIONAL
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS number_cell
      IMPORTING iv_col        TYPE string
                iv_row        TYPE i
                iv_style      TYPE i
                iv_value      TYPE numeric
      RETURNING VALUE(rv_xml) TYPE string.

    " Dòng tổng: công thức SUM, kèm giá trị đã tính sẵn để mở file là thấy số
    CLASS-METHODS sum_cell
      IMPORTING iv_col        TYPE string
                iv_row        TYPE i
                iv_style      TYPE i
                iv_first_row  TYPE i
                iv_last_row   TYPE i
                iv_value      TYPE numeric
      RETURNING VALUE(rv_xml) TYPE string.

    " Số tiền nội bộ của SAP → số tiền hiển thị (VND lưu 2 số lẻ nội bộ → nhân 100)
    CLASS-METHODS amount
      IMPORTING iv_amount       TYPE numeric
                iv_currency     TYPE waers
      RETURNING VALUE(rv_value) TYPE ty_num.

    CLASS-METHODS unit_text
      IMPORTING iv_unit        TYPE meins
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS to_utf8
      IMPORTING iv_string         TYPE string
      RETURNING VALUE(rv_xstring) TYPE xstring.

ENDCLASS.



CLASS zcl_ce_sales_v3_xlsx IMPLEMENTATION.


  METHOD build.

    prepare( it_data ).

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

    " Print_Titles: in lặp lại dòng header (dòng 4) ở mọi trang
    DATA(lv_workbook) = lv_xml_decl
      && |<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"|
      && | xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">|
      && |<bookViews><workbookView/></bookViews>|
      && |<sheets><sheet name="{ gc_sheet_name }" sheetId="1" r:id="rId1"/></sheets>|
      && |<definedNames><definedName name="_xlnm.Print_Titles" localSheetId="0">|
      && |'{ gc_sheet_name }'!${ gc_header_row }:${ gc_header_row }</definedName></definedNames>|
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
                 content = to_utf8( lv_xml_decl && sheet_xml( it_data         = it_data
                                                              iv_subtitle     = iv_subtitle
                                                              iv_footer_plant = iv_footer_plant ) ) ).

    rv_xlsx = lo_zip->save( ).

  ENDMETHOD.


  METHOD prepare.

    DATA lr_unit     TYPE RANGE OF meins.
    DATA lr_currency TYPE RANGE OF waers.

    CLEAR: gt_unit, gt_currency.

    LOOP AT it_data INTO DATA(ls_data).
      IF ls_data-donvitinh IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_data-donvitinh ) TO lr_unit.
      ENDIF.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_data-currencyusd )         TO lr_currency.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_data-companycodecurrency ) TO lr_currency.
    ENDLOOP.
    SORT lr_unit BY low.
    DELETE ADJACENT DUPLICATES FROM lr_unit COMPARING low.
    SORT lr_currency BY low.
    DELETE ADJACENT DUPLICATES FROM lr_currency COMPARING low.

    IF lr_unit IS NOT INITIAL.
      SELECT unitofmeasure, unitofmeasurecommercialname
        FROM i_unitofmeasuretext
        WHERE unitofmeasure IN @lr_unit
          AND language      =  @sy-langu
        INTO TABLE @DATA(lt_unit).
      gt_unit = VALUE #( FOR ls_unit IN lt_unit
                         ( unit = ls_unit-unitofmeasure
                           text = condense( CONV string( ls_unit-unitofmeasurecommercialname ) ) ) ).
    ENDIF.

    IF lr_currency IS NOT INITIAL.
      SELECT currency, decimals
        FROM i_currency
        WHERE currency IN @lr_currency
        INTO TABLE @DATA(lt_currency).
      gt_currency = VALUE #( FOR ls_currency IN lt_currency
                             ( currency = ls_currency-currency
                               factor   = ipow( base = CONV decfloat34( 10 )
                                                exp  = 2 - ls_currency-decimals ) ) ).
    ENDIF.

  ENDMETHOD.


  METHOD sheet_xml.

    DATA lv_rows      TYPE string.
    DATA lv_sum_qty   TYPE ty_num.
    DATA lv_sum_usd   TYPE ty_num.
    DATA lv_sum_vnd   TYPE ty_num.
    DATA lv_sum_cogs  TYPE ty_num.

    " ── Row 1: Tiêu đề / Row 2: Kỳ báo cáo / Row 3: đường kẻ dưới ──
    lv_rows = |<row r="1" ht="38.25" customHeight="1">|
           && text_cell( iv_col = `A` iv_row = 1 iv_style = gc_style-title iv_value = `BÁO CÁO BÁN HÀNG` )
           && |</row>|
           && |<row r="2" ht="25.5" customHeight="1">|
           && text_cell( iv_col = `A` iv_row = 2 iv_style = gc_style-subtitle iv_value = iv_subtitle )
           && |</row>|
           && |<row r="3" ht="20.25" customHeight="1">|.
    LOOP AT VALUE string_table( ( `A` ) ( `B` ) ( `C` ) ( `D` ) ( `E` ) ( `F` )
                                ( `G` ) ( `H` ) ( `I` ) ( `J` ) ( `K` ) ) INTO DATA(lv_col).
      lv_rows = lv_rows && text_cell( iv_col = lv_col iv_row = 3 iv_style = gc_style-line ).
    ENDLOOP.
    lv_rows = lv_rows && |</row>|.

    " ── Row 4: Header ───────────────────────────────────────
    lv_rows = lv_rows && header_row( ).

    " ── Data rows ───────────────────────────────────────────
    DATA(lv_first_row) = gc_header_row + 1.
    DATA(lv_row)       = gc_header_row.

    LOOP AT it_data INTO DATA(ls_data).
      lv_row += 1.

      " Dòng đầu viền trên liền, các dòng sau viền chấm
      DATA(lv_off) = COND i( WHEN lv_row = lv_first_row THEN 0 ELSE 1 ).

      DATA(lv_usd)  = amount( iv_amount = ls_data-doanhthuusd iv_currency = ls_data-currencyusd ).
      DATA(lv_vnd)  = amount( iv_amount = ls_data-doanhthuvnd iv_currency = ls_data-companycodecurrency ).
      DATA(lv_cogs) = amount( iv_amount = ls_data-giavonvnd   iv_currency = ls_data-companycodecurrency ).

      lv_sum_qty  += ls_data-soluong.
      lv_sum_usd  += lv_usd.
      lv_sum_vnd  += lv_vnd.
      lv_sum_cogs += lv_cogs.

      lv_rows = lv_rows
             && |<row r="{ lv_row }" ht="22.5" customHeight="1">|
             && number_cell( iv_col = `A` iv_row = lv_row iv_style = gc_style-center + lv_off iv_value = ls_data-stt )
             && text_cell(   iv_col = `B` iv_row = lv_row iv_style = gc_style-center + lv_off iv_value = ls_data-tennhamay )
             && text_cell(   iv_col = `C` iv_row = lv_row iv_style = gc_style-text + lv_off   iv_value = ls_data-mahang )
             && text_cell(   iv_col = `D` iv_row = lv_row iv_style = gc_style-text + lv_off   iv_value = ls_data-tenhang )
             && text_cell(   iv_col = `E` iv_row = lv_row iv_style = gc_style-center + lv_off
                             iv_value = unit_text( ls_data-donvitinh ) )
             && text_cell(   iv_col = `F` iv_row = lv_row iv_style = gc_style-text + lv_off   iv_value = ls_data-loaihang )
             " Số lượng: số nguyên thì không hiện phần lẻ, có phần lẻ thì hiện 3 số lẻ
             && number_cell( iv_col = `G` iv_row = lv_row iv_value = ls_data-soluong
                             iv_style = COND #( WHEN frac( ls_data-soluong ) = 0
                                                THEN gc_style-num0 + lv_off
                                                ELSE gc_style-num3 + lv_off ) )
             && number_cell( iv_col = `H` iv_row = lv_row iv_style = gc_style-num2 + lv_off   iv_value = lv_usd )
             && number_cell( iv_col = `I` iv_row = lv_row iv_style = gc_style-num0 + lv_off   iv_value = lv_vnd )
             && number_cell( iv_col = `J` iv_row = lv_row iv_style = gc_style-num0 + lv_off   iv_value = lv_cogs )
             && text_cell(   iv_col = `K` iv_row = lv_row iv_style = gc_style-text + lv_off   iv_value = ls_data-thitruongxuatkhau )
             && |</row>|.
    ENDLOOP.

    DATA(lv_last_row)  = lv_row.
    DATA(lv_total_row) = lv_row + 1.

    " ── Dòng tổng cộng ──────────────────────────────────────
    lv_rows = lv_rows
           && |<row r="{ lv_total_row }" ht="29.25" customHeight="1">|
           && text_cell( iv_col = `A` iv_row = lv_total_row iv_style = gc_style-total_text )
           && text_cell( iv_col = `B` iv_row = lv_total_row iv_style = gc_style-total_text )
           && text_cell( iv_col = `C` iv_row = lv_total_row iv_style = gc_style-total_text )
           && text_cell( iv_col = `D` iv_row = lv_total_row iv_style = gc_style-total_text )
           && text_cell( iv_col = `E` iv_row = lv_total_row iv_style = gc_style-total_text )
           && text_cell( iv_col = `F` iv_row = lv_total_row iv_style = gc_style-total_text )
           && sum_cell(  iv_col = `G` iv_row = lv_total_row iv_first_row = lv_first_row iv_last_row = lv_last_row
                         iv_value = lv_sum_qty
                         iv_style = COND #( WHEN frac( lv_sum_qty ) = 0
                                            THEN gc_style-total_num0
                                            ELSE gc_style-total_num3 ) )
           && sum_cell(  iv_col = `H` iv_row = lv_total_row iv_first_row = lv_first_row iv_last_row = lv_last_row
                         iv_style = gc_style-total_num2 iv_value = lv_sum_usd )
           && sum_cell(  iv_col = `I` iv_row = lv_total_row iv_first_row = lv_first_row iv_last_row = lv_last_row
                         iv_style = gc_style-total_num0 iv_value = lv_sum_vnd )
           && sum_cell(  iv_col = `J` iv_row = lv_total_row iv_first_row = lv_first_row iv_last_row = lv_last_row
                         iv_style = gc_style-total_num0 iv_value = lv_sum_cogs )
           && text_cell( iv_col = `K` iv_row = lv_total_row iv_style = gc_style-total_text )
           && |</row>|.

    " ── Footer (FS): trái = <Plant> / <Mã báo cáo> - <Ngày in>, phải = Trang: Page/Pages, font 8 nghiêng ──
    DATA(lv_today)  = cl_abap_context_info=>get_system_date( ).
    DATA(lv_plant)  = escape( val = iv_footer_plant format = cl_abap_format=>e_xml_text ).
    DATA(lv_footer) = |&amp;L&amp;"Times New Roman,Italic"&amp;8{ lv_plant }&#10;|
                   && |ZPR_SALES_V3 - { lv_today+6(2) }/{ lv_today+4(2) }/{ lv_today(4) }|
                   && |&amp;R&amp;"Times New Roman,Italic"&amp;8Trang: &amp;P/&amp;N|.

    rv_xml = |<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|
          " Vừa 1 trang theo chiều ngang khi in
          && |<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>|
          " ── Cố định header ──
          && |<sheetViews><sheetView zoomScale="90" zoomScaleNormal="90" workbookViewId="0">|
          && |<pane ySplit="{ gc_header_row }" topLeftCell="A{ lv_first_row }" activePane="bottomLeft" state="frozen"/>|
          && |</sheetView></sheetViews>|
          && |<sheetFormatPr defaultRowHeight="15.75"/>|
          " ── Column widths (giống template) ──
          && |<cols>|
          && |<col min="1" max="1" width="6.43" customWidth="1"/>|
          && |<col min="2" max="2" width="18.29" customWidth="1"/>|
          && |<col min="3" max="3" width="20.29" customWidth="1"/>|
          && |<col min="4" max="4" width="39.71" customWidth="1"/>|
          && |<col min="5" max="5" width="10.29" customWidth="1"/>|
          && |<col min="6" max="6" width="40.57" customWidth="1"/>|
          && |<col min="7" max="7" width="13.14" customWidth="1"/>|
          && |<col min="8" max="9" width="19" customWidth="1"/>|
          && |<col min="10" max="10" width="18.71" customWidth="1"/>|
          && |<col min="11" max="11" width="29.71" customWidth="1"/>|
          && |</cols>|
          && |<sheetData>{ lv_rows }</sheetData>|
          && |<autoFilter ref="A{ gc_header_row }:K{ lv_last_row }"/>|
          && |<mergeCells count="2"><mergeCell ref="A1:K1"/><mergeCell ref="A2:K2"/></mergeCells>|
          " ── In ấn (FS): A4 ngang, lề trái 2cm, trên / dưới / phải 1.5cm ──
          && |<pageMargins left="0.79" right="0.59" top="0.59" bottom="0.59" header="0.3" footer="0.3"/>|
          && |<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>|
          && |<headerFooter><oddFooter>{ lv_footer }</oddFooter></headerFooter>|
          && |</worksheet>|.

  ENDMETHOD.


  METHOD header_row.

    DATA(lv_row) = gc_header_row.

    rv_xml = |<row r="{ lv_row }" ht="36" customHeight="1">|
          && text_cell( iv_col = `A` iv_row = lv_row iv_style = gc_style-header iv_value = `STT` )
          && text_cell( iv_col = `B` iv_row = lv_row iv_style = gc_style-header iv_value = `Tên nhà máy` )
          && text_cell( iv_col = `C` iv_row = lv_row iv_style = gc_style-header iv_value = `Mã hàng` )
          && text_cell( iv_col = `D` iv_row = lv_row iv_style = gc_style-header iv_value = `Tên hàng` )
          && text_cell( iv_col = `E` iv_row = lv_row iv_style = gc_style-header iv_value = `ĐVT` )
          && text_cell( iv_col = `F` iv_row = lv_row iv_style = gc_style-header iv_value = `Loại hàng` )
          && text_cell( iv_col = `G` iv_row = lv_row iv_style = gc_style-header iv_value = `Số lượng` )
          && text_cell( iv_col = `H` iv_row = lv_row iv_style = gc_style-header iv_value = |Doanh thu\nUSD| )
          && text_cell( iv_col = `I` iv_row = lv_row iv_style = gc_style-header iv_value = |Doanh thu\nVND| )
          && text_cell( iv_col = `J` iv_row = lv_row iv_style = gc_style-header iv_value = |Giá vốn\nVND| )
          && text_cell( iv_col = `K` iv_row = lv_row iv_style = gc_style-header iv_value = `Thị trường xuất khẩu` )
          && |</row>|.

  ENDMETHOD.


  METHOD styles_xml.

    " Muốn đổi màu / font / viền thì sửa ở đây. Thứ tự <xf> trong <cellXfs> phải khớp gc_style
    " Định dạng số kiểu Accounting của template: số 0 hiện "-"
    DATA(lv_acc0) = |_(* #,##0_);_(* (#,##0);_(* &quot;-&quot;??_);_(@_)|.
    DATA(lv_acc2) = |_(* #,##0.00_);_(* (#,##0.00);_(* &quot;-&quot;??_);_(@_)|.
    DATA(lv_acc3) = |_(* #,##0.000_);_(* (#,##0.000);_(* &quot;-&quot;??_);_(@_)|.

    " Dòng dữ liệu: borderId 3 = dòng đầu, 4 = các dòng sau
    DATA(lv_first) = |fontId="0" fillId="0" borderId="3" xfId="0" applyBorder="1"|.
    DATA(lv_next)  = |fontId="0" fillId="0" borderId="4" xfId="0" applyBorder="1"|.
    DATA(lv_total) = |fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"|.

    rv_xml = |<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|

          && |<numFmts count="3">|
          && |<numFmt numFmtId="164" formatCode="{ lv_acc0 }"/>|
          && |<numFmt numFmtId="165" formatCode="{ lv_acc2 }"/>|
          && |<numFmt numFmtId="166" formatCode="{ lv_acc3 }"/>|
          && |</numFmts>|

          " fontId: 0 = dữ liệu, 1 = tiêu đề, 2 = header / dòng tổng, 3 = kỳ báo cáo
          && |<fonts count="4">|
          && |<font><sz val="12"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="16"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="12"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><sz val="16"/><name val="Times New Roman"/><family val="1"/></font>|
          && |</fonts>|

          " fillId: 0, 1 = bắt buộc của Excel, 2 = nền vàng của header / dòng tổng
          && |<fills count="3">|
          && |<fill><patternFill patternType="none"/></fill>|
          && |<fill><patternFill patternType="gray125"/></fill>|
          && |<fill><patternFill patternType="solid"><fgColor rgb="FFFFFF00"/><bgColor indexed="64"/></patternFill></fill>|
          && |</fills>|

          " borderId: 0 = không viền, 1 = viền mỏng 4 cạnh, 2 = chỉ viền dưới,
          "           3 = dòng dữ liệu đầu (dưới chấm), 4 = dòng dữ liệu sau (trên / dưới chấm)
          && |<borders count="5">|
          && |<border><left/><right/><top/><bottom/><diagonal/></border>|
          && |<border><left style="thin"><color indexed="64"/></left><right style="thin"><color indexed="64"/></right>|
          && |<top style="thin"><color indexed="64"/></top><bottom style="thin"><color indexed="64"/></bottom><diagonal/></border>|
          && |<border><left/><right/><top/><bottom style="thin"><color indexed="64"/></bottom><diagonal/></border>|
          && |<border><left style="thin"><color indexed="64"/></left><right style="thin"><color indexed="64"/></right>|
          && |<top style="thin"><color indexed="64"/></top><bottom style="dotted"><color indexed="64"/></bottom><diagonal/></border>|
          && |<border><left style="thin"><color indexed="64"/></left><right style="thin"><color indexed="64"/></right>|
          && |<top style="dotted"><color indexed="64"/></top><bottom style="dotted"><color indexed="64"/></bottom><diagonal/></border>|
          && |</borders>|

          && |<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>|

          && |<cellXfs count="19">|
          " 0: mặc định
          && |<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>|
          " 1: title
          && |<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center"/></xf>|
          " 2: subtitle
          && |<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center"/></xf>|
          " 3: line
          && |<xf numFmtId="0" fontId="0" fillId="0" borderId="2" xfId="0" applyBorder="1"/>|
          " 4: header
          && |<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center" wrapText="1"/></xf>|
          " 5-6: center
          && |<xf numFmtId="49" { lv_first } applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>|
          && |<xf numFmtId="49" { lv_next } applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>|
          " 7-8: text
          && |<xf numFmtId="49" { lv_first } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          && |<xf numFmtId="49" { lv_next } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          " 9-10: num0
          && |<xf numFmtId="164" { lv_first } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          && |<xf numFmtId="164" { lv_next } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          " 11-12: num2
          && |<xf numFmtId="165" { lv_first } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          && |<xf numFmtId="165" { lv_next } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          " 13-14: num3
          && |<xf numFmtId="166" { lv_first } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          && |<xf numFmtId="166" { lv_next } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          " 15: total_text
          && |<xf numFmtId="0" { lv_total }/>|
          " 16-18: total_num0 / total_num2 / total_num3
          && |<xf numFmtId="164" { lv_total } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          && |<xf numFmtId="165" { lv_total } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          && |<xf numFmtId="166" { lv_total } applyNumberFormat="1" applyAlignment="1"><alignment vertical="center"/></xf>|
          && |</cellXfs>|

          && |<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>|
          && |</styleSheet>|.

  ENDMETHOD.


  METHOD text_cell.

    IF iv_value IS INITIAL.
      rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }"/>|.
      RETURN.
    ENDIF.

    DATA(lv_text) = escape( val    = CONV string( iv_value )
                            format = cl_abap_format=>e_xml_text ).

    rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }" t="inlineStr"><is><t xml:space="preserve">{ lv_text }</t></is></c>|.

  ENDMETHOD.


  METHOD number_cell.

    " Chuyển về số thập phân thường để không bị ra dạng số mũ (vd. 1E+3)
    DATA(lv_value) = CONV ty_num( iv_value ).

    rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }"><v>{ lv_value }</v></c>|.

  ENDMETHOD.


  METHOD sum_cell.

    DATA(lv_value) = CONV ty_num( iv_value ).

    rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }">|
          && |<f>SUM({ iv_col }{ iv_first_row }:{ iv_col }{ iv_last_row })</f><v>{ lv_value }</v></c>|.

  ENDMETHOD.


  METHOD amount.

    " Không tìm thấy tiền tệ → coi như 2 số lẻ (giữ nguyên)
    DATA(lv_factor) = VALUE decfloat34( gt_currency[ currency = iv_currency ]-factor DEFAULT 1 ).

    rv_value = CONV decfloat34( iv_amount ) * lv_factor.

  ENDMETHOD.


  METHOD unit_text.

    " Không có text → hiện mã nội bộ
    rv_text = VALUE #( gt_unit[ unit = iv_unit ]-text DEFAULT CONV string( iv_unit ) ).

  ENDMETHOD.


  METHOD to_utf8.

    rv_xstring = cl_abap_conv_codepage=>create_out( )->convert( iv_string ).

  ENDMETHOD.
ENDCLASS.
