CLASS zcl_ce_sales_da_xlsx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    " Sinh file xlsx "BÁO CÁO DOANH THU BÁN HÀNG" theo template (document/template.xlsx)
    " xlsx = file zip chứa các file XML → tự viết XML rồi nén bằng cl_abap_zip
    CLASS-METHODS build
      IMPORTING it_data            TYPE zcl_ce_sales_da_f01=>tt_result
                iv_company_name    TYPE string
                iv_company_address TYPE string
                iv_subtitle        TYPE string
      RETURNING VALUE(rv_xlsx)     TYPE xstring.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_num TYPE p LENGTH 16 DECIMALS 6.

    " Index trong <cellXfs> của styles.xml
    CONSTANTS: BEGIN OF gc_style,
                 company     TYPE i VALUE 1,
                 address     TYPE i VALUE 2,
                 title       TYPE i VALUE 3,
                 subtitle    TYPE i VALUE 4,
                 header      TYPE i VALUE 5,
                 text        TYPE i VALUE 6,
                 text_center TYPE i VALUE 7,
                 date        TYPE i VALUE 8,
                 number      TYPE i VALUE 9,
                 integer     TYPE i VALUE 10,
                 rate        TYPE i VALUE 11,
               END OF gc_style.

    " Header chiếm 2 dòng (dòng dưới là các cột con của LOẠI ĐÁ)
    CONSTANTS gc_header_row TYPE i VALUE 7.

    CLASS-METHODS sheet_xml
      IMPORTING it_data            TYPE zcl_ce_sales_da_f01=>tt_result
                iv_company_name    TYPE string
                iv_company_address TYPE string
                iv_subtitle        TYPE string
      RETURNING VALUE(rv_xml)      TYPE string.

    CLASS-METHODS header_rows
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

    CLASS-METHODS date_cell
      IMPORTING iv_col        TYPE string
                iv_row        TYPE i
                iv_style      TYPE i
                iv_value      TYPE d
      RETURNING VALUE(rv_xml) TYPE string.

    " Cột Loại đá: có đánh dấu thì hiện "x"
    CLASS-METHODS mark_cell
      IMPORTING iv_col        TYPE string
                iv_row        TYPE i
                iv_value      TYPE csequence
      RETURNING VALUE(rv_xml) TYPE string.

    " Có tên thì hiện tên, không có thì hiện mã (bỏ số 0 đầu)
    CLASS-METHODS name_or_code
      IMPORTING iv_name        TYPE csequence
                iv_code        TYPE csequence
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS to_utf8
      IMPORTING iv_string         TYPE string
      RETURNING VALUE(rv_xstring) TYPE xstring.

ENDCLASS.



CLASS zcl_ce_sales_da_xlsx IMPLEMENTATION.


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
      && |<sheets><sheet name="Báo cáo" sheetId="1" r:id="rId1"/></sheets>|
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
                 content = to_utf8( lv_xml_decl && sheet_xml( it_data            = it_data
                                                              iv_company_name    = iv_company_name
                                                              iv_company_address = iv_company_address
                                                              iv_subtitle        = iv_subtitle ) ) ).

    rv_xlsx = lo_zip->save( ).

  ENDMETHOD.


  METHOD sheet_xml.

    DATA lv_rows TYPE string.

    " ── Row 1-2: Tên + địa chỉ công ty / Row 4: Tiêu đề / Row 5: Từ ngày - đến ngày ──
    lv_rows = |<row r="1" ht="15.75" customHeight="1">|
           && text_cell( iv_col = `A` iv_row = 1 iv_style = gc_style-company iv_value = iv_company_name )
           && |</row>|
           && |<row r="2" ht="15.75" customHeight="1">|
           && text_cell( iv_col = `A` iv_row = 2 iv_style = gc_style-address iv_value = iv_company_address )
           && |</row>|
           && |<row r="4" ht="20.25" customHeight="1">|
           && text_cell( iv_col = `A` iv_row = 4 iv_style = gc_style-title iv_value = `BÁO CÁO DOANH THU BÁN HÀNG` )
           && |</row>|
           && |<row r="5" ht="15.75" customHeight="1">|
           && text_cell( iv_col = `A` iv_row = 5 iv_style = gc_style-subtitle iv_value = iv_subtitle )
           && |</row>|.

    " ── Row 7-8: Header ─────────────────────────────────────
    lv_rows = lv_rows && header_rows( ).

    " ── Data rows ───────────────────────────────────────────
    DATA(lv_row) = gc_header_row + 1.

    LOOP AT it_data INTO DATA(ls_data).
      lv_row += 1.

      DATA(lv_product) = CONV string( ls_data-MaVatTu ).
      SHIFT lv_product LEFT DELETING LEADING '0'.

      lv_rows = lv_rows
             && |<row r="{ lv_row }">|
             && date_cell(   iv_col = `A` iv_row = lv_row iv_style = gc_style-date        iv_value = ls_data-NgayChungTu )
             && text_cell(   iv_col = `B` iv_row = lv_row iv_style = gc_style-text        iv_value = ls_data-SoToKhai )
             && text_cell(   iv_col = `C` iv_row = lv_row iv_style = gc_style-text_center iv_value = ls_data-SoHoaDon )
             && text_cell(   iv_col = `D` iv_row = lv_row iv_style = gc_style-text
                             iv_value = name_or_code( iv_name = ls_data-TenDoiTuongCongNo
                                                      iv_code = ls_data-DoiTuongCongNo ) )
             && text_cell(   iv_col = `E` iv_row = lv_row iv_style = gc_style-text        iv_value = ls_data-SoInv )
             && text_cell(   iv_col = `F` iv_row = lv_row iv_style = gc_style-text        iv_value = lv_product )
             && text_cell(   iv_col = `G` iv_row = lv_row iv_style = gc_style-text        iv_value = ls_data-TenVatTu )
             && text_cell(   iv_col = `H` iv_row = lv_row iv_style = gc_style-text        iv_value = ls_data-DonViTinh )
             && number_cell( iv_col = `I` iv_row = lv_row iv_style = gc_style-number      iv_value = ls_data-SoLuong )
             && number_cell( iv_col = `J` iv_row = lv_row iv_style = gc_style-number      iv_value = ls_data-GiaCongThuc )
             && number_cell( iv_col = `K` iv_row = lv_row iv_style = gc_style-number      iv_value = ls_data-GiaBan )
             && number_cell( iv_col = `L` iv_row = lv_row iv_style = gc_style-number      iv_value = ls_data-ChenhLech )
             && number_cell( iv_col = `M` iv_row = lv_row iv_style = gc_style-number      iv_value = ls_data-GiaInvHaiQuan )
             && number_cell( iv_col = `N` iv_row = lv_row iv_style = gc_style-number      iv_value = ls_data-NgoaiTe )
             " Tỷ giá: số nguyên thì không hiện phần lẻ, có phần lẻ thì hiện đúng số chữ số lẻ thực tế
             && number_cell( iv_col = `O` iv_row = lv_row iv_value = ls_data-TyGia
                             iv_style = COND #( WHEN frac( ls_data-TyGia ) = 0
                                                THEN gc_style-integer
                                                ELSE gc_style-rate ) )
             && number_cell( iv_col = `P` iv_row = lv_row iv_style = gc_style-integer     iv_value = ls_data-ThanhTien )
             && mark_cell(   iv_col = `Q` iv_row = lv_row iv_value = ls_data-LoaiDaSlabE62 )
             && mark_cell(   iv_col = `R` iv_row = lv_row iv_value = ls_data-LoaiDaCutToSizeE62 )
             && mark_cell(   iv_col = `S` iv_row = lv_row iv_value = ls_data-LoaiDaMauBanE62 )
             && mark_cell(   iv_col = `T` iv_row = lv_row iv_value = ls_data-LoaiDaMauTangE62 )
             && mark_cell(   iv_col = `U` iv_row = lv_row iv_value = ls_data-LoaiDaMauTangH21 )
             && mark_cell(   iv_col = `V` iv_row = lv_row iv_value = ls_data-LoaiDaGiaCongE52 )
             && text_cell(   iv_col = `W` iv_row = lv_row iv_style = gc_style-text
                             iv_value = name_or_code( iv_name = ls_data-TenQuocGiaDen
                                                      iv_code = ls_data-QuocGiaDen ) )
             && |</row>|.
    ENDLOOP.

    DATA(lv_filter_row) = gc_header_row + 1.

    rv_xml = |<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|
          " ── Ẩn gridline, cố định header + các cột đến Tên vật tư ──
          && |<sheetViews><sheetView showGridLines="0" workbookViewId="0">|
          && |<pane xSplit="7" ySplit="{ lv_filter_row }" topLeftCell="H{ lv_filter_row + 1 }" activePane="bottomRight" state="frozen"/>|
          && |</sheetView></sheetViews>|
          && |<sheetFormatPr defaultRowHeight="12.75"/>|
          " ── Column widths ──
          && |<cols>|
          && |<col min="1" max="1" width="20.5" customWidth="1"/>|
          && |<col min="2" max="3" width="22" customWidth="1"/>|
          && |<col min="4" max="4" width="30" customWidth="1"/>|
          && |<col min="5" max="6" width="19" customWidth="1"/>|
          && |<col min="7" max="7" width="32" customWidth="1"/>|
          && |<col min="8" max="8" width="14" customWidth="1"/>|
          && |<col min="9" max="9" width="19" customWidth="1"/>|
          && |<col min="10" max="10" width="22" customWidth="1"/>|
          && |<col min="11" max="11" width="18" customWidth="1"/>|
          && |<col min="12" max="13" width="22" customWidth="1"/>|
          && |<col min="14" max="14" width="17.5" customWidth="1"/>|
          && |<col min="15" max="15" width="14" customWidth="1"/>|
          && |<col min="16" max="16" width="19" customWidth="1"/>|
          && |<col min="17" max="23" width="22" customWidth="1"/>|
          && |</cols>|
          && |<sheetData>{ lv_rows }</sheetData>|
          && |<autoFilter ref="A{ lv_filter_row }:W{ lv_row }"/>|
          " ── Header: các cột thường merge 2 dòng, LOẠI ĐÁ merge ngang 6 cột con ──
          && |<mergeCells count="18">|
          && |<mergeCell ref="A7:A8"/><mergeCell ref="B7:B8"/><mergeCell ref="C7:C8"/><mergeCell ref="D7:D8"/>|
          && |<mergeCell ref="E7:E8"/><mergeCell ref="F7:F8"/><mergeCell ref="G7:G8"/><mergeCell ref="H7:H8"/>|
          && |<mergeCell ref="I7:I8"/><mergeCell ref="J7:J8"/><mergeCell ref="K7:K8"/><mergeCell ref="L7:L8"/>|
          && |<mergeCell ref="M7:M8"/><mergeCell ref="N7:N8"/><mergeCell ref="O7:O8"/><mergeCell ref="P7:P8"/>|
          && |<mergeCell ref="Q7:V7"/><mergeCell ref="W7:W8"/>|
          && |</mergeCells>|
          && |</worksheet>|.

  ENDMETHOD.


  METHOD header_rows.

    DATA(lv_top)    = gc_header_row.
    DATA(lv_bottom) = gc_header_row + 1.

    " Dòng trên: tên cột
    rv_xml = |<row r="{ lv_top }" ht="21.75" customHeight="1">|
          && text_cell( iv_col = `A` iv_row = lv_top iv_style = gc_style-header iv_value = `NGÀY CHỨNG TỪ` )
          && text_cell( iv_col = `B` iv_row = lv_top iv_style = gc_style-header iv_value = `SỐ TỜ KHAI` )
          && text_cell( iv_col = `C` iv_row = lv_top iv_style = gc_style-header iv_value = `SỐ HÓA ĐƠN` )
          && text_cell( iv_col = `D` iv_row = lv_top iv_style = gc_style-header iv_value = `ĐỐI TƯỢNG CÔNG NỢ` )
          && text_cell( iv_col = `E` iv_row = lv_top iv_style = gc_style-header iv_value = `SỐ INV` )
          && text_cell( iv_col = `F` iv_row = lv_top iv_style = gc_style-header iv_value = `MÃ VẬT TƯ` )
          && text_cell( iv_col = `G` iv_row = lv_top iv_style = gc_style-header iv_value = `TÊN VẬT TƯ` )
          && text_cell( iv_col = `H` iv_row = lv_top iv_style = gc_style-header iv_value = `ĐƠN VỊ TÍNH` )
          && text_cell( iv_col = `I` iv_row = lv_top iv_style = gc_style-header iv_value = `SỐ LƯỢNG` )
          && text_cell( iv_col = `J` iv_row = lv_top iv_style = gc_style-header iv_value = `GIÁ CÔNG THỨC` )
          && text_cell( iv_col = `K` iv_row = lv_top iv_style = gc_style-header iv_value = `GIÁ BÁN` )
          && text_cell( iv_col = `L` iv_row = lv_top iv_style = gc_style-header iv_value = `CHÊNH LỆCH` )
          && text_cell( iv_col = `M` iv_row = lv_top iv_style = gc_style-header iv_value = `GIÁ INV HẢI QUAN` )
          && text_cell( iv_col = `N` iv_row = lv_top iv_style = gc_style-header iv_value = `NGOẠI TỆ` )
          && text_cell( iv_col = `O` iv_row = lv_top iv_style = gc_style-header iv_value = `TỶ GIÁ` )
          && text_cell( iv_col = `P` iv_row = lv_top iv_style = gc_style-header iv_value = `THÀNH TIỀN` )
          && text_cell( iv_col = `Q` iv_row = lv_top iv_style = gc_style-header iv_value = `LOẠI ĐÁ` )
          && text_cell( iv_col = `R` iv_row = lv_top iv_style = gc_style-header )
          && text_cell( iv_col = `S` iv_row = lv_top iv_style = gc_style-header )
          && text_cell( iv_col = `T` iv_row = lv_top iv_style = gc_style-header )
          && text_cell( iv_col = `U` iv_row = lv_top iv_style = gc_style-header )
          && text_cell( iv_col = `V` iv_row = lv_top iv_style = gc_style-header )
          && text_cell( iv_col = `W` iv_row = lv_top iv_style = gc_style-header iv_value = `QUỐC GIA ĐẾN` )
          && |</row>|

          " Dòng dưới: ô trống của các cột merge (để có viền) + cột con của LOẠI ĐÁ
          && |<row r="{ lv_bottom }" ht="45" customHeight="1">|
          && text_cell( iv_col = `A` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `B` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `C` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `D` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `E` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `F` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `G` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `H` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `I` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `J` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `K` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `L` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `M` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `N` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `O` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `P` iv_row = lv_bottom iv_style = gc_style-header )
          && text_cell( iv_col = `Q` iv_row = lv_bottom iv_style = gc_style-header iv_value = `SLAB (E62)` )
          && text_cell( iv_col = `R` iv_row = lv_bottom iv_style = gc_style-header iv_value = `CUT TO SIZE (E62)` )
          && text_cell( iv_col = `S` iv_row = lv_bottom iv_style = gc_style-header iv_value = `MẪU BÁN (E62)` )
          && text_cell( iv_col = `T` iv_row = lv_bottom iv_style = gc_style-header iv_value = `MẪU TẶNG (E62)` )
          && text_cell( iv_col = `U` iv_row = lv_bottom iv_style = gc_style-header iv_value = `MẪU TẶNG (H21)` )
          && text_cell( iv_col = `V` iv_row = lv_bottom iv_style = gc_style-header iv_value = `GIA CÔNG (E52)` )
          && text_cell( iv_col = `W` iv_row = lv_bottom iv_style = gc_style-header )
          && |</row>|.

  ENDMETHOD.


  METHOD styles_xml.

    " Muốn đổi màu / font / viền thì sửa ở đây. Thứ tự <xf> trong <cellXfs> phải khớp gc_style
    DATA(lv_border) = |borderId="1" applyBorder="1"|.
    DATA(lv_data)   = |fontId="0" fillId="0" xfId="0" { lv_border }|.

    rv_xml = |<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|

          && |<numFmts count="2"><numFmt numFmtId="164" formatCode="###,###,###,###"/>|
          && |<numFmt numFmtId="165" formatCode="#,##0.#####"/></numFmts>|

          " fontId: 0 = dữ liệu, 1 = tên công ty, 2 = địa chỉ / từ ngày - đến ngày, 3 = tiêu đề, 4 = header
          && |<fonts count="5">|
          && |<font><sz val="10"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="12"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><sz val="12"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="16"/><color rgb="FF006020"/><name val="Times New Roman"/><family val="1"/></font>|
          && |<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Times New Roman"/><family val="1"/></font>|
          && |</fonts>|

          " fillId: 0, 1 = bắt buộc của Excel, 2 = nền xanh của header
          && |<fills count="3">|
          && |<fill><patternFill patternType="none"/></fill>|
          && |<fill><patternFill patternType="gray125"/></fill>|
          && |<fill><patternFill patternType="solid"><fgColor rgb="FF2E75B6"/><bgColor indexed="64"/></patternFill></fill>|
          && |</fills>|

          " borderId: 0 = không viền, 1 = viền mỏng 4 cạnh
          && |<borders count="2">|
          && |<border><left/><right/><top/><bottom/><diagonal/></border>|
          && |<border><left style="thin"><color auto="1"/></left><right style="thin"><color auto="1"/></right>|
          && |<top style="thin"><color auto="1"/></top><bottom style="thin"><color auto="1"/></bottom><diagonal/></border>|
          && |</borders>|

          && |<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>|

          " numFmtId: 4 = #,##0.00   14 = ngày   49 = text   164 = ###,###,###,###   165 = #,##0.#####
          && |<cellXfs count="12">|
          " 0: mặc định
          && |<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>|
          " 1: company
          && |<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">|
          && |<alignment horizontal="left" vertical="center"/></xf>|
          " 2: address
          && |<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">|
          && |<alignment horizontal="left" vertical="center"/></xf>|
          " 3: title
          && |<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">|
          && |<alignment horizontal="left"/></xf>|
          " 4: subtitle
          && |<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">|
          && |<alignment horizontal="left"/></xf>|
          " 5: header
          && |<xf numFmtId="0" fontId="4" fillId="2" xfId="0" { lv_border } applyFont="1" applyFill="1" applyAlignment="1">|
          && |<alignment horizontal="center" vertical="center" wrapText="1"/></xf>|
          " 6: text
          && |<xf numFmtId="49" { lv_data } applyNumberFormat="1"/>|
          " 7: text_center
          && |<xf numFmtId="49" { lv_data } applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center"/></xf>|
          " 8: date
          && |<xf numFmtId="14" { lv_data } applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left"/></xf>|
          " 9: number
          && |<xf numFmtId="4" { lv_data } applyNumberFormat="1"/>|
          " 10: integer
          && |<xf numFmtId="164" { lv_data } applyNumberFormat="1"/>|
          " 11: rate
          && |<xf numFmtId="165" { lv_data } applyNumberFormat="1"/>|
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


  METHOD date_cell.

    IF iv_value IS INITIAL.
      rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }"/>|.
      RETURN.
    ENDIF.

    " Excel lưu ngày dạng số ngày tính từ 30.12.1899
    DATA(lv_serial) = iv_value - CONV d( '18991230' ).

    rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }"><v>{ lv_serial }</v></c>|.

  ENDMETHOD.


  METHOD mark_cell.

    rv_xml = text_cell( iv_col   = iv_col
                        iv_row   = iv_row
                        iv_style = gc_style-text_center
                        iv_value = COND string( WHEN iv_value IS NOT INITIAL THEN `x` ) ).

  ENDMETHOD.


  METHOD name_or_code.

    IF iv_name IS NOT INITIAL.
      rv_text = iv_name.
      RETURN.
    ENDIF.

    rv_text = iv_code.
    SHIFT rv_text LEFT DELETING LEADING '0'.

  ENDMETHOD.


  METHOD to_utf8.

    rv_xstring = cl_abap_conv_codepage=>create_out( )->convert( iv_string ).

  ENDMETHOD.
ENDCLASS.
