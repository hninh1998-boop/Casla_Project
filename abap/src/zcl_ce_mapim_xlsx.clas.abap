CLASS zcl_ce_mapim_xlsx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    " Sinh file xlsx "Mapping hóa đơn - chứng từ kho" (cùng cột / thứ tự / định dạng với file FE xuất trước đây)
    " xlsx = file zip chứa các file XML → tự viết XML rồi nén bằng cl_abap_zip
    CLASS-METHODS build
      IMPORTING it_data        TYPE zcl_ce_mapim_implement=>tt_result
      RETURNING VALUE(rv_xlsx) TYPE xstring.

    " MappingHoaDonChungTuKho_D-M-YYYY (giống tên file FE cũ: ngày dạng vi-VN, '/' đổi thành '-')
    CLASS-METHODS file_name
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_name) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_num TYPE p LENGTH 16 DECIMALS 6.

    " Kiểu hiển thị của cột
    CONSTANTS: BEGIN OF gc_kind,
                 text     TYPE c LENGTH 1 VALUE 'T', " giữ nguyên
                 number   TYPE c LENGTH 1 VALUE 'N', " số chứng từ: bỏ số 0 đầu (giống ALPHA output của OData)
                 unit     TYPE c LENGTH 1 VALUE 'U', " đơn vị tính: mã nội bộ → mã hiển thị (giống CUNIT output của OData)
                 date     TYPE c LENGTH 1 VALUE 'D',
                 quantity TYPE c LENGTH 1 VALUE 'Q',
                 amount   TYPE c LENGTH 1 VALUE 'A', " số tiền: đổi sang số tiền thực theo số lẻ của tiền tệ
               END OF gc_kind.

    TYPES: BEGIN OF ty_column,
             field    TYPE string, " field của zce_mapim
             label    TYPE string,
             kind     TYPE c LENGTH 1,
             width    TYPE i,
             currency TYPE string, " field tiền tệ của cột amount
           END OF ty_column,
           tt_column TYPE STANDARD TABLE OF ty_column WITH EMPTY KEY.

    " Index trong <cellXfs> của styles.xml
    CONSTANTS: BEGIN OF gc_style,
                 header  TYPE i VALUE 1,
                 date    TYPE i VALUE 2,
                 qty_int TYPE i VALUE 3,
                 qty_dec TYPE i VALUE 4,
                 amount  TYPE i VALUE 5,
               END OF gc_style.

    CONSTANTS gc_sheet_name TYPE string VALUE `SAPUI5 Export`.

    TYPES: BEGIN OF ty_currency,
             currency TYPE waers,
             factor   TYPE decfloat34,
           END OF ty_currency,
           tt_currency TYPE HASHED TABLE OF ty_currency WITH UNIQUE KEY currency.

    TYPES: BEGIN OF ty_unit,
             unit TYPE meins,
             text TYPE string,
           END OF ty_unit,
           tt_unit TYPE HASHED TABLE OF ty_unit WITH UNIQUE KEY unit.

    CLASS-METHODS columns
      RETURNING VALUE(rt_columns) TYPE tt_column.

    CLASS-METHODS sheet_xml
      IMPORTING it_data       TYPE zcl_ce_mapim_implement=>tt_result
                it_columns    TYPE tt_column
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS styles_xml
      RETURNING VALUE(rv_xml) TYPE string.

    " Số lẻ của tiền tệ (I_Currency-Decimals) → hệ số đổi số tiền nội bộ (luôn 2 số lẻ) sang số tiền thực
    " vd. VND: 0 số lẻ → 10000.00 nội bộ = 1,000,000 VND
    CLASS-METHODS get_currencies
      IMPORTING it_data              TYPE zcl_ce_mapim_implement=>tt_result
      RETURNING VALUE(rt_currencies) TYPE tt_currency.

    " Đơn vị tính nội bộ → mã hiển thị theo ngôn ngữ đăng nhập (vd. ST → PC)
    CLASS-METHODS get_units
      IMPORTING it_data         TYPE zcl_ce_mapim_implement=>tt_result
      RETURNING VALUE(rt_units) TYPE tt_unit.

    CLASS-METHODS text_cell
      IMPORTING iv_ref        TYPE string
                iv_style      TYPE i DEFAULT 0
                iv_value      TYPE simple
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS number_cell
      IMPORTING iv_ref        TYPE string
                iv_style      TYPE i
                iv_value      TYPE decfloat34
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS strip_leading_zeros
      IMPORTING iv_value       TYPE simple
      RETURNING VALUE(rv_text) TYPE string.

    " 1 → A, 27 → AA
    CLASS-METHODS col_letter
      IMPORTING iv_index         TYPE i
      RETURNING VALUE(rv_letter) TYPE string.

    CLASS-METHODS to_utf8
      IMPORTING iv_string         TYPE string
      RETURNING VALUE(rv_xstring) TYPE xstring.

ENDCLASS.



CLASS zcl_ce_mapim_xlsx IMPLEMENTATION.


  METHOD build.

    DATA(lt_columns) = columns( ).
    DATA(lv_last_col) = col_letter( lines( lt_columns ) ).
    DATA(lv_last_row) = lines( it_data ) + 1.

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
      && |<sheets><sheet name="{ gc_sheet_name }" sheetId="1" r:id="rId1"/></sheets>|
      && |<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">|
      && |'{ gc_sheet_name }'!$A$1:${ lv_last_col }${ lv_last_row }</definedName></definedNames>|
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
                 content = to_utf8( lv_xml_decl && sheet_xml( it_data    = it_data
                                                              it_columns = lt_columns ) ) ).

    rv_xlsx = lo_zip->save( ).

  ENDMETHOD.


  METHOD file_name.
    rv_name = |MappingHoaDonChungTuKho_{ CONV i( iv_date+6(2) ) }-{ CONV i( iv_date+4(2) ) }-{ iv_date(4) }|.
  ENDMETHOD.


  METHOD columns.
    " Đúng thứ tự + tên hiển thị như file FE xuất trước đây; cột mới thêm vào cuối
    rt_columns = VALUE #(
      ( field = `COMPANYCODE`                   label = `Company Code`                     kind = gc_kind-text     width = 12 )
      ( field = `INVOICINGPARTY`                label = `Invoicing party`                  kind = gc_kind-number   width = 14 )
      ( field = `INVOICINGPARTYNAME`            label = `Invoicing party name`             kind = gc_kind-text     width = 28 )
      ( field = `INVOICEPOSTINGDATE`            label = `INV Posting Date`                 kind = gc_kind-date     width = 14 )
      ( field = `INVOICENO`                     label = `E-Invoice`                        kind = gc_kind-text     width = 16 )
      ( field = `INV`                           label = `Invoice Doc`                      kind = gc_kind-number   width = 14 )
      ( field = `INVITEM`                       label = `Invoice Doc Item`                 kind = gc_kind-number   width = 12 )
      ( field = `GRPOSTINGDATE`                 label = `GR Posting Date`                  kind = gc_kind-date     width = 14 )
      ( field = `MATDOC`                        label = `GR Doc`                           kind = gc_kind-number   width = 14 )
      ( field = `MATDOCITEM`                    label = `GR Doc Item`                      kind = gc_kind-number   width = 12 )
      ( field = `GRQTY`                         label = `GR Qty`                           kind = gc_kind-quantity width = 12 )
      ( field = `INVOICEQTY`                    label = `INV Qty`                          kind = gc_kind-quantity width = 12 )
      ( field = `ALLOCATEDQTY`                  label = `Allocated Qty`                    kind = gc_kind-quantity width = 12 )
      ( field = `GROPENQTY`                     label = `GR Open Qty`                      kind = gc_kind-quantity width = 12 )
      ( field = `INVOPENQTY`                    label = `INV Open Qty`                     kind = gc_kind-quantity width = 12 )
      ( field = `ITEMTEXT`                      label = `Item Text`                        kind = gc_kind-text     width = 24 )
      ( field = `HEADERTEXT`                    label = `Header Text`                      kind = gc_kind-text     width = 24 )
      ( field = `MATERIALCODE`                  label = `Material Code`                    kind = gc_kind-number   width = 16 )
      ( field = `MATERIALDESCRIPTION`           label = `Material Description`             kind = gc_kind-text     width = 28 )
      ( field = `ORDERPRICEUNIT`                label = `Order Price Unit`                 kind = gc_kind-unit     width = 12 )
      ( field = `GRCATEGORY`                    label = `GR Category`                      kind = gc_kind-text     width = 12 )
      ( field = `IVCATEGORY`                    label = `INV Category`                     kind = gc_kind-text     width = 12 )
      ( field = `GRAMOUNTCOMCODE`               label = `GR Amount ComCode`                kind = gc_kind-amount   width = 16 currency = `LOCACURRENCYKEY` )
      ( field = `GRAMOUNTTRANSCODE`             label = `GR Amount TransCode`              kind = gc_kind-amount   width = 16 currency = `TRANSCUR` )
      ( field = `TRANSCUR`                      label = `TransCur`                         kind = gc_kind-text     width = 10 )
      ( field = `JE`                            label = `INV Journal Entry`                kind = gc_kind-number   width = 14 )
      ( field = `INVOICEAMOUNTCOMCODE`          label = `INV Amount ComCode`               kind = gc_kind-amount   width = 16 currency = `LOCACURRENCYKEY` )
      ( field = `INVOICEAMOUNTTRANS`            label = `INV Amount Trans`                 kind = gc_kind-amount   width = 16 currency = `CURRENCY` )
      ( field = `INVNETPRICETRANSCUR`           label = `INV Net price TransCur`           kind = gc_kind-amount   width = 16 currency = `TRANSCUR` )
      ( field = `CURRENCY`                      label = `Currency`                         kind = gc_kind-text     width = 10 )
      ( field = `GRFULLYINVOICED`               label = `GR Fully Invoiced`                kind = gc_kind-text     width = 14 )
      ( field = `IVFULLYINVOICED`               label = `IV Fully Invoiced`                kind = gc_kind-text     width = 14 )
      ( field = `POFULLYINVOICED`               label = `PO fully invoiced`                kind = gc_kind-text     width = 14 )
      ( field = `STORAGELOCATION`               label = `Storage Location`                 kind = gc_kind-text     width = 14 )
      ( field = `PLANT`                         label = `Plant`                            kind = gc_kind-text     width = 10 )
      ( field = `PONO`                          label = `PO No`                            kind = gc_kind-number   width = 14 )
      ( field = `POITEM`                        label = `PO Item`                          kind = gc_kind-number   width = 10 )
      ( field = `PONETPRICE`                    label = `PO Net Price`                     kind = gc_kind-amount   width = 14 currency = `POCURRENCY` )
      ( field = `POCURRENCY`                    label = `PO Currency`                      kind = gc_kind-text     width = 12 )
      ( field = `POSUPPLIER`                    label = `PO Supplier`                      kind = gc_kind-number   width = 14 )
      ( field = `POSUPPLIERNAME`                label = `PO Supplier Name`                 kind = gc_kind-text     width = 28 )
      ( field = `GHICHU`                        label = `Ghi chú`                          kind = gc_kind-text     width = 24 )
      ( field = `GRBASEDINV`                    label = `GR-based INV`                     kind = gc_kind-text     width = 14 )
      ( field = `DELIVERYDOC`                   label = `Delivery Doc`                     kind = gc_kind-number   width = 14 )
      ( field = `DELIVERYITEM`                  label = `Delivery Item`                    kind = gc_kind-number   width = 12 )
      ( field = `POTYPE`                        label = `PO Type`                          kind = gc_kind-text     width = 10 )
      ( field = `GRFISCALYEAR`                  label = `GR Fiscal year`                   kind = gc_kind-text     width = 12 )
      ( field = `INVFISCALYEAR`                 label = `Invoice Fiscal year`              kind = gc_kind-text     width = 14 )
      ( field = `ALLOCATEDGRAMOUNTCOMCODE`      label = `Allocated GR Amount ComCode`      kind = gc_kind-amount   width = 20 currency = `LOCACURRENCYKEY` )
      ( field = `ALLOCATEDGRAMOUNTTRANSCODE`    label = `Allocated GR Amount TransCode`    kind = gc_kind-amount   width = 20 currency = `TRANSCUR` )
      ( field = `ALLOCATEDINVOICEAMOUNTCOMCODE` label = `Allocated Invoice Amount ComCode` kind = gc_kind-amount   width = 22 currency = `LOCACURRENCYKEY` )
      ( field = `ALLOCATEDINVOICEAMOUNTTRANS`   label = `Allocated Invoice Amount Trans`   kind = gc_kind-amount   width = 22 currency = `CURRENCY` )
      "Dev/NinhNH/ZMapIM/Add Batch + Valuation type - FS v2 - 04.11.2026
      ( field = `BATCH`                         label = `Batch`                            kind = gc_kind-text     width = 14 )
      ( field = `VALUATIONTYPE`                 label = `Valuation Type`                   kind = gc_kind-text     width = 14 )
    ).
  ENDMETHOD.


  METHOD sheet_xml.

    DATA: lt_rows TYPE string_table,
          lv_row  TYPE string,
          lv_ref  TYPE string,
          lv_dec  TYPE decfloat34.

    DATA(lt_currencies) = get_currencies( it_data ).
    DATA(lt_units)      = get_units( it_data ).

    " Chữ cái của từng cột tính 1 lần
    DATA(lt_letters) = VALUE string_table( FOR n = 1 UNTIL n > lines( it_columns ) ( col_letter( n ) ) ).

    " ── Row 1: Header ───────────────────────────────────────
    lv_row = |<row r="1">|.
    LOOP AT it_columns ASSIGNING FIELD-SYMBOL(<ls_col>).
      DATA(lv_header_index) = sy-tabix.
      lv_row = lv_row && text_cell( iv_ref   = |{ lt_letters[ lv_header_index ] }1|
                                    iv_style = gc_style-header
                                    iv_value = <ls_col>-label ).
    ENDLOOP.
    lv_row = lv_row && |</row>|.
    APPEND lv_row TO lt_rows.

    " ── Data rows (ô trống thì bỏ qua, không ghi <c>) ────────
    DATA(lv_row_no) = 1.
    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      lv_row_no += 1.
      lv_row = |<row r="{ lv_row_no }">|.

      LOOP AT it_columns ASSIGNING <ls_col>.
        DATA(lv_col_index) = sy-tabix.
        ASSIGN COMPONENT <ls_col>-field OF STRUCTURE <ls_data> TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        " Ô trống: bỏ qua (số lượng / số tiền = 0 vẫn ghi 0 như file FE cũ)
        IF <lv_value> IS INITIAL
           AND <ls_col>-kind <> gc_kind-quantity
           AND <ls_col>-kind <> gc_kind-amount.
          CONTINUE.
        ENDIF.

        lv_ref = |{ lt_letters[ lv_col_index ] }{ lv_row_no }|.

        CASE <ls_col>-kind.
          WHEN gc_kind-date.
            " Excel lưu ngày dạng số ngày tính từ 30.12.1899
            DATA(lv_date) = CONV d( <lv_value> ).
            DATA(lv_serial) = CONV i( lv_date - CONV d( '18991230' ) ).
            lv_row = lv_row && number_cell( iv_ref   = lv_ref
                                            iv_style = gc_style-date
                                            iv_value = CONV decfloat34( lv_serial ) ).

          WHEN gc_kind-quantity.
            lv_dec = <lv_value>.
            " Số nguyên → #,##0 ; có phần lẻ → #,##0.### (giống file FE cũ)
            lv_row = lv_row && number_cell( iv_ref   = lv_ref
                                            iv_style = COND #( WHEN frac( lv_dec ) = 0
                                                               THEN gc_style-qty_int
                                                               ELSE gc_style-qty_dec )
                                            iv_value = lv_dec ).

          WHEN gc_kind-amount.
            lv_dec = <lv_value>.
            ASSIGN COMPONENT <ls_col>-currency OF STRUCTURE <ls_data> TO FIELD-SYMBOL(<lv_currency>).
            IF sy-subrc = 0.
              READ TABLE lt_currencies ASSIGNING FIELD-SYMBOL(<ls_currency>)
                WITH TABLE KEY currency = <lv_currency>.
              IF sy-subrc = 0.
                lv_dec = lv_dec * <ls_currency>-factor.
              ENDIF.
            ENDIF.
            lv_row = lv_row && number_cell( iv_ref   = lv_ref
                                            iv_style = gc_style-amount
                                            iv_value = lv_dec ).

          WHEN gc_kind-number.
            lv_row = lv_row && text_cell( iv_ref = lv_ref iv_value = strip_leading_zeros( <lv_value> ) ).

          WHEN gc_kind-unit.
            DATA(lv_unit_text) = CONV string( <lv_value> ).
            READ TABLE lt_units ASSIGNING FIELD-SYMBOL(<ls_unit>) WITH TABLE KEY unit = <lv_value>.
            IF sy-subrc = 0 AND <ls_unit>-text IS NOT INITIAL.
              lv_unit_text = <ls_unit>-text.
            ENDIF.
            lv_row = lv_row && text_cell( iv_ref = lv_ref iv_value = lv_unit_text ).

          WHEN OTHERS.
            lv_row = lv_row && text_cell( iv_ref = lv_ref iv_value = <lv_value> ).
        ENDCASE.
      ENDLOOP.

      lv_row = lv_row && |</row>|.
      APPEND lv_row TO lt_rows.
    ENDLOOP.

    " ── Column widths ───────────────────────────────────────
    DATA(lv_cols) = |<cols>|.
    LOOP AT it_columns ASSIGNING <ls_col>.
      DATA(lv_width_index) = sy-tabix.
      lv_cols = lv_cols && |<col min="{ lv_width_index }" max="{ lv_width_index }" width="{ <ls_col>-width }" customWidth="1"/>|.
    ENDLOOP.
    lv_cols = lv_cols && |</cols>|.

    DATA(lv_last_col) = lt_letters[ lines( lt_letters ) ].

    rv_xml = |<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|
          " ── Cố định dòng header ──
          && |<sheetViews><sheetView workbookViewId="0">|
          && |<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>|
          && |</sheetView></sheetViews>|
          && |<sheetFormatPr defaultRowHeight="15"/>|
          && lv_cols
          && |<sheetData>{ concat_lines_of( table = lt_rows ) }</sheetData>|
          && |<autoFilter ref="A1:{ lv_last_col }{ lv_row_no }"/>|
          && |</worksheet>|.

  ENDMETHOD.


  METHOD styles_xml.

    " Thứ tự <xf> trong <cellXfs> phải khớp gc_style
    rv_xml = |<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">|

          && |<numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/>|
          && |<numFmt numFmtId="165" formatCode="#,##0.###"/></numFmts>|

          " fontId: 0 = dữ liệu, 1 = header (in đậm)
          && |<fonts count="2">|
          && |<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>|
          && |<font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font>|
          && |</fonts>|

          " fillId 0, 1 = bắt buộc của Excel
          && |<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>|
          && |<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>|
          && |<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>|

          " numFmtId: 3 = #,##0   4 = #,##0.00   164 = dd/mm/yyyy   165 = #,##0.###
          && |<cellXfs count="6">|
          " 0: mặc định
          && |<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>|
          " 1: header
          && |<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>|
          " 2: date
          && |<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>|
          " 3: qty_int
          && |<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>|
          " 4: qty_dec
          && |<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>|
          " 5: amount
          && |<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>|
          && |</cellXfs>|

          && |<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>|
          && |</styleSheet>|.

  ENDMETHOD.


  METHOD get_currencies.

    DATA lt_keys TYPE SORTED TABLE OF waers WITH UNIQUE KEY table_line.

    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      INSERT <ls_data>-LocaCurrencyKey INTO TABLE lt_keys.
      INSERT <ls_data>-TransCur        INTO TABLE lt_keys.
      INSERT <ls_data>-Currency        INTO TABLE lt_keys.
      INSERT <ls_data>-POCurrency      INTO TABLE lt_keys.
    ENDLOOP.
    DELETE lt_keys WHERE table_line IS INITIAL.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM I_Currency
    FIELDS Currency,
           Decimals
    FOR ALL ENTRIES IN @lt_keys
    WHERE Currency = @lt_keys-table_line
    INTO TABLE @DATA(lt_decimals).

    LOOP AT lt_decimals ASSIGNING FIELD-SYMBOL(<ls_decimals>).
      INSERT VALUE #( currency = <ls_decimals>-Currency
                      factor   = CONV decfloat34( 10 ) ** ( 2 - <ls_decimals>-Decimals ) )
        INTO TABLE rt_currencies.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_units.

    DATA lt_keys TYPE SORTED TABLE OF meins WITH UNIQUE KEY table_line.

    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE OrderPriceUnit IS NOT INITIAL.
      INSERT <ls_data>-OrderPriceUnit INTO TABLE lt_keys.
    ENDLOOP.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM I_UnitOfMeasureText
    FIELDS UnitOfMeasure,
           UnitOfMeasureCommercialName
    FOR ALL ENTRIES IN @lt_keys
    WHERE UnitOfMeasure = @lt_keys-table_line
      AND Language      = @sy-langu
    INTO TABLE @DATA(lt_texts).

    LOOP AT lt_texts ASSIGNING FIELD-SYMBOL(<ls_text>).
      INSERT VALUE #( unit = <ls_text>-UnitOfMeasure
                      text = <ls_text>-UnitOfMeasureCommercialName ) INTO TABLE rt_units.
    ENDLOOP.

  ENDMETHOD.


  METHOD text_cell.

    DATA(lv_text) = CONV string( iv_value ).
    IF lv_text IS INITIAL.
      RETURN.
    ENDIF.

    " Bỏ ký tự điều khiển không hợp lệ trong XML (giữ tab / xuống dòng), Excel giới hạn 32767 ký tự / ô
    lv_text = replace( val = lv_text pcre = `[\x00-\x08\x0B\x0C\x0E-\x1F]` with = `` occ = 0 ).
    IF strlen( lv_text ) > 32767.
      lv_text = substring( val = lv_text len = 32767 ).
    ENDIF.

    lv_text = escape( val = lv_text format = cl_abap_format=>e_xml_text ).

    rv_xml = |<c r="{ iv_ref }"|
          && COND string( WHEN iv_style <> 0 THEN | s="{ iv_style }"| )
          && | t="inlineStr"><is><t xml:space="preserve">{ lv_text }</t></is></c>|.

  ENDMETHOD.


  METHOD number_cell.

    " Chuyển về số thập phân thường để không bị ra dạng số mũ (vd. 1E+3), bỏ số 0 thừa sau dấu chấm
    DATA(lv_text) = |{ CONV ty_num( iv_value ) }|.
    IF lv_text CA '.'.
      lv_text = replace( val = lv_text pcre = `\.?0+$` with = `` ).
    ENDIF.

    rv_xml = |<c r="{ iv_ref }" s="{ iv_style }"><v>{ lv_text }</v></c>|.

  ENDMETHOD.


  METHOD strip_leading_zeros.

    rv_text = condense( CONV string( iv_value ) ).
    IF rv_text IS NOT INITIAL AND rv_text CO '0123456789'.
      SHIFT rv_text LEFT DELETING LEADING '0'.
      IF rv_text IS INITIAL.
        rv_text = `0`.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD col_letter.

    DATA(lv_index) = iv_index.
    WHILE lv_index > 0.
      DATA(lv_rem) = ( lv_index - 1 ) MOD 26.
      rv_letter = substring( val = sy-abcde off = lv_rem len = 1 ) && rv_letter.
      lv_index = ( lv_index - 1 ) DIV 26.
    ENDWHILE.

  ENDMETHOD.


  METHOD to_utf8.

    rv_xstring = cl_abap_conv_codepage=>create_out( )->convert( iv_string ).

  ENDMETHOD.
ENDCLASS.
