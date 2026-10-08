CLASS zcl_ce_ci_xlsx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    " Sinh file xlsx Commercial Invoice / Packing List theo mẫu "Form INV,PL khách AT"
    " xlsx = file zip chứa các file XML → tự viết XML rồi nén bằng cl_abap_zip
    " Mỗi Pro-forma Invoice = 1 sheet
    CLASS-METHODS build_ci
      IMPORTING it_data        TYPE zcl_ce_ci_top=>tt_result
      RETURNING VALUE(rv_xlsx) TYPE xstring.

    CLASS-METHODS build_pl
      IMPORTING it_data        TYPE zcl_ce_ci_top=>tt_result
      RETURNING VALUE(rv_xlsx) TYPE xstring.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_num TYPE p LENGTH 16 DECIMALS 3.

    TYPES: BEGIN OF ty_sheet,
             name TYPE string,
             xml  TYPE string, " chưa có thẻ đóng </worksheet>, xem method zip
           END OF ty_sheet.
    TYPES tt_sheet TYPE STANDARD TABLE OF ty_sheet WITH EMPTY KEY.

    TYPES tt_string TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    TYPES: BEGIN OF ty_remark,
             label TYPE string,
             value TYPE string,
           END OF ty_remark.
    TYPES tt_remark TYPE STANDARD TABLE OF ty_remark WITH EMPTY KEY.

    " Index trong <cellXfs> của styles.xml
    CONSTANTS: BEGIN OF gc_style,
                 co_title    TYPE i VALUE 1,  " CASABLANCA VIETNAM JSC
                 co_sub      TYPE i VALUE 2,  " Factory / Head office / Tel
                 doc_title   TYPE i VALUE 3,  " COMMERCIAL INVOICE / PACKING LIST
                 text        TYPE i VALUE 4,
                 text_bold   TYPE i VALUE 5,
                 text_wrap   TYPE i VALUE 6,
                 text_center TYPE i VALUE 7,
                 date_center TYPE i VALUE 8,
                 date_left   TYPE i VALUE 9,
                 tbl_cell    TYPE i VALUE 10, " ô trong bảng: viền, căn giữa
                 tbl_price   TYPE i VALUE 11, " USD #,##0.00 căn giữa
                 tbl_amount  TYPE i VALUE 12, " USD #,##0.00 căn phải
                 tot_text    TYPE i VALUE 13, " dòng TOTAL: đậm
                 tot_amount  TYPE i VALUE 14,
                 box_tl      TYPE i VALUE 15, " khung thông tin ngân hàng
                 box_t       TYPE i VALUE 16,
                 box_tr      TYPE i VALUE 17,
                 box_l       TYPE i VALUE 18,
                 box_r       TYPE i VALUE 19,
                 box_bl      TYPE i VALUE 20,
                 box_b       TYPE i VALUE 21,
                 box_br      TYPE i VALUE 22,
                 sign        TYPE i VALUE 23, " CASABLANCA VIET NAM JSC
               END OF gc_style.

    CONSTANTS gc_excel_epoch TYPE d VALUE '18991230'.
    CONSTANTS gc_item_row    TYPE i VALUE 15. " dòng item đầu tiên của bảng

    CLASS-METHODS ci_sheet_xml
      IMPORTING it_items      TYPE zcl_ce_ci_top=>tt_result
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS pl_sheet_xml
      IMPORTING it_items      TYPE zcl_ce_ci_top=>tt_result
      RETURNING VALUE(rv_xml) TYPE string.

    " Row 1 - 12: tên công ty, tiêu đề, To / Add / Tel, Invoice / Date / PO / LOT
    CLASS-METHODS header_rows
      IMPORTING it_items       TYPE zcl_ce_ci_top=>tt_result
                iv_title       TYPE string
                iv_last_col    TYPE string
                iv_label_col   TYPE string
                iv_value_col   TYPE string
                iv_value_style TYPE i
                iv_date_style  TYPE i
      CHANGING  ct_merge       TYPE tt_string
      RETURNING VALUE(rv_xml)  TYPE string.

    " REMARKS + 12 dòng thông tin vận chuyển
    CLASS-METHODS remark_rows
      IMPORTING is_data       TYPE zce_ci
                iv_height     TYPE string
      CHANGING  cv_row        TYPE i
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS worksheet_xml
      IMPORTING iv_cols       TYPE string
                iv_rows       TYPE string
                it_merge      TYPE tt_string
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS zip
      IMPORTING it_sheets      TYPE tt_sheet
                iv_currency    TYPE csequence
      RETURNING VALUE(rv_xlsx) TYPE xstring.

    CLASS-METHODS styles_xml
      IMPORTING iv_currency   TYPE csequence
      RETURNING VALUE(rv_xml) TYPE string.

    " Logo lấy từ chính template XDP đang dùng để in PDF (zcore_tb_temppdf)
    CLASS-METHODS get_logo
      RETURNING VALUE(rv_logo) TYPE xstring.

    CLASS-METHODS drawing_xml
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS get_lots
      IMPORTING it_items       TYPE zcl_ce_ci_top=>tt_result
      EXPORTING ev_count       TYPE i
      RETURNING VALUE(rv_lots) TYPE string.

    CLASS-METHODS row
      IMPORTING iv_row        TYPE i
                iv_height     TYPE string OPTIONAL
                iv_cells      TYPE string OPTIONAL
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
                iv_value      TYPE ty_num
      RETURNING VALUE(rv_xml) TYPE string.

    " Giá trị toàn số → ô số, còn lại → ô text
    CLASS-METHODS auto_cell
      IMPORTING iv_col        TYPE string
                iv_row        TYPE i
                iv_style      TYPE i
                iv_value      TYPE csequence
      RETURNING VALUE(rv_xml) TYPE string.

    " Các ô trống có style (viền của ô merge, khung) - iv_cols = `CDEF`
    CLASS-METHODS empty_cells
      IMPORTING iv_cols       TYPE string
                iv_row        TYPE i
                iv_style      TYPE i
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS to_utf8
      IMPORTING iv_string         TYPE string
      RETURNING VALUE(rv_xstring) TYPE xstring.

ENDCLASS.



CLASS zcl_ce_ci_xlsx IMPLEMENTATION.


  METHOD build_ci.

    DATA lt_sheets TYPE tt_sheet.
    DATA lt_items  TYPE zcl_ce_ci_top=>tt_result.

    LOOP AT it_data INTO DATA(ls_data) GROUP BY ( proformainvoice = ls_data-ProFormaInvoice )
        INTO DATA(ls_group).
      CLEAR lt_items.
      LOOP AT GROUP ls_group INTO DATA(ls_member).
        APPEND ls_member TO lt_items.
      ENDLOOP.

      APPEND VALUE #( name = |CI { ls_group-proformainvoice ALPHA = OUT }|
                      xml  = ci_sheet_xml( lt_items ) ) TO lt_sheets.
    ENDLOOP.

    IF lt_sheets IS INITIAL.
      RETURN.
    ENDIF.

    rv_xlsx = zip( it_sheets   = lt_sheets
                   iv_currency = it_data[ 1 ]-TransactionCurrency ).

  ENDMETHOD.


  METHOD build_pl.

    DATA lt_sheets TYPE tt_sheet.
    DATA lt_items  TYPE zcl_ce_ci_top=>tt_result.

    LOOP AT it_data INTO DATA(ls_data) GROUP BY ( proformainvoice = ls_data-ProFormaInvoice )
        INTO DATA(ls_group).
      CLEAR lt_items.
      LOOP AT GROUP ls_group INTO DATA(ls_member).
        APPEND ls_member TO lt_items.
      ENDLOOP.

      APPEND VALUE #( name = |PL { ls_group-proformainvoice ALPHA = OUT }|
                      xml  = pl_sheet_xml( lt_items ) ) TO lt_sheets.
    ENDLOOP.

    IF lt_sheets IS INITIAL.
      RETURN.
    ENDIF.

    rv_xlsx = zip( it_sheets   = lt_sheets
                   iv_currency = it_data[ 1 ]-TransactionCurrency ).

  ENDMETHOD.


  METHOD ci_sheet_xml.

    DATA: lt_merge        TYPE tt_string,
          lv_total_qty    TYPE ty_num,
          lv_total_amount TYPE zce_ci-Amount.

    DATA(ls_head) = it_items[ 1 ].

    " ── Row 1 - 12: Header ──────────────────────────────────
    DATA(lv_rows) = header_rows( EXPORTING it_items       = it_items
                                           iv_title       = `COMMERCIAL INVOICE`
                                           iv_last_col    = `G`
                                           iv_label_col   = `F`
                                           iv_value_col   = `G`
                                           iv_value_style = gc_style-text_center
                                           iv_date_style  = gc_style-date_center
                                 CHANGING  ct_merge       = lt_merge ).

    " ── Row 13 - 14: Tiêu đề bảng ───────────────────────────
    lv_rows = lv_rows
      && row( iv_row = 13 iv_height = `22.5` iv_cells =
              text_cell( iv_col = `A` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `PO#` )
           && text_cell( iv_col = `B` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `AZT ID` )
           && text_cell( iv_col = `C` iv_row = 13 iv_style = gc_style-tbl_cell )
           && text_cell( iv_col = `D` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `VENDOR ID` )
           && text_cell( iv_col = `E` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `QUANTITY` )
           && text_cell( iv_col = `F` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `UNIT PRICE (USD/PCS)` )
           && text_cell( iv_col = `G` iv_row = 13 iv_style = gc_style-tbl_cell
                         iv_value = |AMOUNT{ cl_abap_char_utilities=>newline }(USD)| ) )
      && row( iv_row = 14 iv_height = `22.5` iv_cells =
              empty_cells( iv_cols = `ABCD` iv_row = 14 iv_style = gc_style-tbl_cell )
           && text_cell( iv_col = `E` iv_row = 14 iv_style = gc_style-tbl_cell iv_value = `(PCS)` )
           && empty_cells( iv_cols = `FG` iv_row = 14 iv_style = gc_style-tbl_cell ) ).

    APPEND `A13:A14` TO lt_merge.
    APPEND `B13:C14` TO lt_merge.
    APPEND `D13:D14` TO lt_merge.
    APPEND `F13:F14` TO lt_merge.
    APPEND `G13:G14` TO lt_merge.

    " ── Các dòng item ───────────────────────────────────────
    DATA(lv_row) = gc_item_row - 1.
    LOOP AT it_items INTO DATA(ls_item).
      lv_row += 1.

      lv_rows = lv_rows
        && row( iv_row = lv_row iv_height = `33` iv_cells =
                auto_cell(   iv_col = `A` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = ls_item-PO )
             && text_cell(   iv_col = `B` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = ls_item-AZTID )
             && text_cell(   iv_col = `C` iv_row = lv_row iv_style = gc_style-tbl_cell )
             && number_cell( iv_col = `D` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = 223637 )
             && number_cell( iv_col = `E` iv_row = lv_row iv_style = gc_style-tbl_cell
                             iv_value = CONV #( ls_item-Quantity ) )
             && number_cell( iv_col = `F` iv_row = lv_row iv_style = gc_style-tbl_price
                             iv_value = CONV #( ls_item-UnitPrice ) )
             && number_cell( iv_col = `G` iv_row = lv_row iv_style = gc_style-tbl_amount
                             iv_value = CONV #( ls_item-Amount ) ) ).

      APPEND |B{ lv_row }:C{ lv_row }| TO lt_merge.

      lv_total_qty    += ls_item-Quantity.
      lv_total_amount += ls_item-Amount.
    ENDLOOP.

    " ── Dòng TOTAL ──────────────────────────────────────────
    lv_row += 1.
    lv_rows = lv_rows
      && row( iv_row = lv_row iv_height = `25.5` iv_cells =
              text_cell(   iv_col = `A` iv_row = lv_row iv_style = gc_style-tot_text iv_value = `TOTAL` )
           && empty_cells( iv_cols = `BCD` iv_row = lv_row iv_style = gc_style-tot_text )
           && number_cell( iv_col = `E` iv_row = lv_row iv_style = gc_style-tot_text iv_value = lv_total_qty )
           && text_cell(   iv_col = `F` iv_row = lv_row iv_style = gc_style-tot_text )
           && number_cell( iv_col = `G` iv_row = lv_row iv_style = gc_style-tot_amount
                           iv_value = CONV #( lv_total_amount ) ) ).
    APPEND |A{ lv_row }:C{ lv_row }| TO lt_merge.

    " ── In words ────────────────────────────────────────────
    lv_row += 1.
    lv_rows = lv_rows
      && row( iv_row = lv_row iv_height = `21` iv_cells =
              text_cell( iv_col = `A` iv_row = lv_row iv_style = gc_style-text iv_value = `In words:` )
           && text_cell( iv_col = `B` iv_row = lv_row iv_style = gc_style-text_wrap
                         iv_value = zcl_ce_ci_f01=>amount_to_words(
                                      iv_amount   = lv_total_amount
                                      iv_currency = ls_head-TransactionCurrency ) ) ).
    APPEND |B{ lv_row }:G{ lv_row }| TO lt_merge.

    " ── REMARKS ─────────────────────────────────────────────
    lv_row += 2.
    lv_rows = lv_rows && remark_rows( EXPORTING is_data   = ls_head
                                                iv_height = `22.5`
                                      CHANGING  cv_row    = lv_row ).

    " ── Khung thông tin ngân hàng ───────────────────────────
    DATA(lt_bank) = VALUE tt_string(
      ( `Beneficiary Name: Casablanca Vietnam Joint Stock Company` )
      ( `Address: Lot CN-03 Chau Son Industrial Zone, Chau Son Ward, Ninh Binh Province, Vietnam` )
      ( `Advising Bank: Joint Stock Commercial Bank for Investment and development of Vietnam, Hoang Mai Hanoi branch` )
      ( `Bank's Address: 1st and 2nd Floor, CT4 Ecogreen City Building,` )
      ( `South West Kim Giang I, Urban Area, Tan Trieu - Commune, Thanh Tri District, Hanoi City, Vietnam` )
      ( `SWIFT Code: BIDVVNVX` )
      ( `Account number: 1290000056` ) ).

    lv_row += 1.
    LOOP AT lt_bank INTO DATA(lv_bank).
      DATA(lv_index) = sy-tabix.
      lv_row += 1.

      IF lv_index = 1.
        DATA(lv_cells) =
             text_cell(   iv_col = `A` iv_row = lv_row iv_style = gc_style-box_tl )
          && text_cell(   iv_col = `B` iv_row = lv_row iv_style = gc_style-box_t iv_value = lv_bank )
          && empty_cells( iv_cols = `CDEF` iv_row = lv_row iv_style = gc_style-box_t )
          && text_cell(   iv_col = `G` iv_row = lv_row iv_style = gc_style-box_tr ).
      ELSEIF lv_index = lines( lt_bank ).
        lv_cells =
             text_cell(   iv_col = `A` iv_row = lv_row iv_style = gc_style-box_bl )
          && text_cell(   iv_col = `B` iv_row = lv_row iv_style = gc_style-box_b iv_value = lv_bank )
          && empty_cells( iv_cols = `CDEF` iv_row = lv_row iv_style = gc_style-box_b )
          && text_cell(   iv_col = `G` iv_row = lv_row iv_style = gc_style-box_br ).
      ELSE.
        lv_cells =
             text_cell( iv_col = `A` iv_row = lv_row iv_style = gc_style-box_l )
          && text_cell( iv_col = `B` iv_row = lv_row iv_style = gc_style-text iv_value = lv_bank )
          && text_cell( iv_col = `G` iv_row = lv_row iv_style = gc_style-box_r ).
      ENDIF.

      lv_rows = lv_rows && row( iv_row = lv_row iv_height = `21.75` iv_cells = lv_cells ).
    ENDLOOP.

    " ── Chữ ký ──────────────────────────────────────────────
    lv_row += 1.
    lv_rows = lv_rows
      && row( iv_row = lv_row iv_height = `21` iv_cells =
              text_cell( iv_col = `E` iv_row = lv_row iv_style = gc_style-sign
                         iv_value = `CASABLANCA VIET NAM JSC` ) ).
    APPEND |E{ lv_row }:G{ lv_row }| TO lt_merge.

    rv_xml = worksheet_xml(
      iv_cols  = `<col min="1" max="1" width="15.29" customWidth="1"/>`
              && `<col min="2" max="2" width="17.71" customWidth="1"/>`
              && `<col min="3" max="3" width="23.57" customWidth="1"/>`
              && `<col min="4" max="4" width="15.57" customWidth="1"/>`
              && `<col min="5" max="5" width="16.29" customWidth="1"/>`
              && `<col min="6" max="6" width="18" customWidth="1"/>`
              && `<col min="7" max="7" width="29.86" customWidth="1"/>`
      iv_rows  = lv_rows
      it_merge = lt_merge ).

  ENDMETHOD.


  METHOD pl_sheet_xml.

    DATA: lt_merge     TYPE tt_string,
          lv_total_pcs TYPE ty_num,
          lv_package   TYPE i.

    DATA(ls_head) = it_items[ 1 ].

    " ── Row 1 - 12: Header ──────────────────────────────────
    DATA(lv_rows) = header_rows( EXPORTING it_items       = it_items
                                           iv_title       = `PACKING LIST`
                                           iv_last_col    = `K`
                                           iv_label_col   = `G`
                                           iv_value_col   = `I`
                                           iv_value_style = gc_style-text_wrap
                                           iv_date_style  = gc_style-date_left
                                 CHANGING  ct_merge       = lt_merge ).

    " ── Row 13 - 14: Tiêu đề bảng ───────────────────────────
    lv_rows = lv_rows
      && row( iv_row = 13 iv_height = `21.75` iv_cells =
              text_cell( iv_col = `A` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `Package #` )
           && text_cell( iv_col = `B` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `AZT ID` )
           && text_cell( iv_col = `C` iv_row = 13 iv_style = gc_style-tbl_cell )
           && text_cell( iv_col = `D` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `SIZE (MM)` )
           && empty_cells( iv_cols = `EF` iv_row = 13 iv_style = gc_style-tbl_cell )
           && text_cell( iv_col = `G` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `SQM` )
           && text_cell( iv_col = `H` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `PCS` )
           && text_cell( iv_col = `I` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `N.W` )
           && text_cell( iv_col = `J` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `G.W.` )
           && text_cell( iv_col = `K` iv_row = 13 iv_style = gc_style-tbl_cell iv_value = `LOT#:` ) )
      && row( iv_row = 14 iv_height = `21.75` iv_cells =
              empty_cells( iv_cols = `ABC` iv_row = 14 iv_style = gc_style-tbl_cell )
           && text_cell( iv_col = `D` iv_row = 14 iv_style = gc_style-tbl_cell iv_value = `L` )
           && text_cell( iv_col = `E` iv_row = 14 iv_style = gc_style-tbl_cell iv_value = `W` )
           && text_cell( iv_col = `F` iv_row = 14 iv_style = gc_style-tbl_cell iv_value = `H` )
           && empty_cells( iv_cols = `GH` iv_row = 14 iv_style = gc_style-tbl_cell )
           && text_cell( iv_col = `I` iv_row = 14 iv_style = gc_style-tbl_cell iv_value = `(KGS)` )
           && text_cell( iv_col = `J` iv_row = 14 iv_style = gc_style-tbl_cell iv_value = `(KGS)` )
           && text_cell( iv_col = `K` iv_row = 14 iv_style = gc_style-tbl_cell ) ).

    APPEND `A13:A14` TO lt_merge.
    APPEND `B13:C14` TO lt_merge.
    APPEND `D13:F13` TO lt_merge.
    APPEND `G13:G14` TO lt_merge.
    APPEND `H13:H14` TO lt_merge.
    APPEND `K13:K14` TO lt_merge.

    " ── Các dòng item ───────────────────────────────────────
    " SQM / N.W / G.W: chưa có logic → để trống
    DATA(lv_row) = gc_item_row - 1.
    LOOP AT it_items INTO DATA(ls_item).
      lv_row     += 1.
      lv_package += 1.

      lv_rows = lv_rows
        && row( iv_row = lv_row iv_height = `31.5` iv_cells =
                number_cell( iv_col = `A` iv_row = lv_row iv_style = gc_style-tbl_cell
                             iv_value = CONV #( lv_package ) )
             && text_cell(   iv_col = `B` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = ls_item-AZTID )
             && text_cell(   iv_col = `C` iv_row = lv_row iv_style = gc_style-tbl_cell )
             && auto_cell(   iv_col = `D` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = ls_item-SizeL )
             && auto_cell(   iv_col = `E` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = ls_item-SizeW )
             && auto_cell(   iv_col = `F` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = ls_item-SizeH )
             && text_cell(   iv_col = `G` iv_row = lv_row iv_style = gc_style-tbl_cell )
             && number_cell( iv_col = `H` iv_row = lv_row iv_style = gc_style-tbl_cell
                             iv_value = CONV #( ls_item-Quantity ) )
             && empty_cells( iv_cols = `IJ` iv_row = lv_row iv_style = gc_style-tbl_cell )
             && text_cell(   iv_col = `K` iv_row = lv_row iv_style = gc_style-tbl_cell iv_value = ls_item-LOT ) ).

      APPEND |B{ lv_row }:C{ lv_row }| TO lt_merge.

      lv_total_pcs += ls_item-Quantity.
    ENDLOOP.

    " ── Dòng TOTAL ──────────────────────────────────────────
    lv_row += 1.
    lv_rows = lv_rows
      && row( iv_row = lv_row iv_height = `30.75` iv_cells =
              text_cell(   iv_col = `A` iv_row = lv_row iv_style = gc_style-tot_text )
           && text_cell(   iv_col = `B` iv_row = lv_row iv_style = gc_style-tot_text
                           iv_value = |TOTAL: { lv_package } |
                                   && COND string( WHEN lv_package = 1 THEN `PACKAGE` ELSE `PACKAGES` ) )
           && empty_cells( iv_cols = `CDEFG` iv_row = lv_row iv_style = gc_style-tot_text )
           && number_cell( iv_col = `H` iv_row = lv_row iv_style = gc_style-tot_text iv_value = lv_total_pcs )
           && empty_cells( iv_cols = `IJK` iv_row = lv_row iv_style = gc_style-tot_text ) ).
    APPEND |B{ lv_row }:C{ lv_row }| TO lt_merge.

    " ── REMARKS ─────────────────────────────────────────────
    lv_row += 1.
    lv_rows = lv_rows && remark_rows( EXPORTING is_data   = ls_head
                                                iv_height = `27`
                                      CHANGING  cv_row    = lv_row ).

    " ── Chữ ký ──────────────────────────────────────────────
    lv_row += 1.
    lv_rows = lv_rows
      && row( iv_row = lv_row iv_height = `20.1` iv_cells =
              text_cell( iv_col = `F` iv_row = lv_row iv_style = gc_style-sign
                         iv_value = `CASABLANCA VIET NAM JSC` ) ).
    APPEND |F{ lv_row }:K{ lv_row }| TO lt_merge.

    rv_xml = worksheet_xml(
      iv_cols  = `<col min="1" max="1" width="10.14" customWidth="1"/>`
              && `<col min="2" max="2" width="23.57" customWidth="1"/>`
              && `<col min="3" max="3" width="17.29" customWidth="1"/>`
              && `<col min="4" max="6" width="8.29" customWidth="1"/>`
              && `<col min="7" max="7" width="10.86" customWidth="1"/>`
              && `<col min="8" max="8" width="7.86" customWidth="1"/>`
              && `<col min="9" max="9" width="9.57" customWidth="1"/>`
              && `<col min="10" max="10" width="10" customWidth="1"/>`
              && `<col min="11" max="11" width="22.14" customWidth="1"/>`
      iv_rows  = lv_rows
      it_merge = lt_merge ).

  ENDMETHOD.


  METHOD header_rows.

    DATA(ls_head) = it_items[ 1 ].

    DATA lv_lot_count TYPE i.

    DATA(lv_lots) = get_lots( EXPORTING it_items = it_items
                              IMPORTING ev_count = lv_lot_count ).

    " Ô giá trị bên phải: nếu chưa phải cột cuối thì merge tới cột cuối (Packing List)
    DATA(lv_merge_value) = xsdbool( iv_value_col <> iv_last_col ).

    " ── Row 1 - 4: Tên công ty (logo nằm đè lên A1:B4) ──────
    rv_xml =
         row( iv_row = 1 iv_height = `20.25` iv_cells =
              text_cell( iv_col = `C` iv_row = 1 iv_style = gc_style-co_title
                         iv_value = `CASABLANCA VIETNAM JSC` ) )
      && row( iv_row = 2 iv_height = `20.25` iv_cells =
              text_cell( iv_col = `C` iv_row = 2 iv_style = gc_style-co_sub
                         iv_value = `Factory: Lot CN-03, Chau Son Industrial Zone, Chau Son Ward, `
                                 && `Ninh Binh Province, Vietnam` ) )
      && row( iv_row = 3 iv_height = `20.25` iv_cells =
              text_cell( iv_col = `C` iv_row = 3 iv_style = gc_style-co_sub
                         iv_value = `Head office: Casla Tower, 78 Duy Tan Street, Cau Giay Ward, Hanoi, Vietnam` ) )
      && row( iv_row = 4 iv_height = `20.25` iv_cells =
              text_cell( iv_col = `C` iv_row = 4 iv_style = gc_style-co_sub
                         iv_value = `Tel: +84 24.3634.0377 * Fax: +84 24.3634.0257` ) )
      && row( iv_row = 5 iv_height = `15` )

    " ── Row 6: Tiêu đề ──────────────────────────────────────
      && row( iv_row = 6 iv_height = `30` iv_cells =
              text_cell( iv_col = `A` iv_row = 6 iv_style = gc_style-doc_title iv_value = iv_title ) )
      && row( iv_row = 7 iv_height = `17.25` )

    " ── Row 8: To / Invoice ─────────────────────────────────
      && row( iv_row = 8 iv_height = `20.25` iv_cells =
              text_cell( iv_col = `A` iv_row = 8 iv_style = gc_style-text_bold
                         iv_value = |TO:  { ls_head-ToCI }| )
           && text_cell( iv_col = iv_label_col iv_row = 8 iv_style = gc_style-text iv_value = `INVOICE# :` )
           && text_cell( iv_col = iv_value_col iv_row = 8 iv_style = iv_value_style
                         iv_value = ls_head-Invoice ) ).

    " ── Row 9: Add / Date ───────────────────────────────────
    " Địa chỉ dài thì tăng chiều cao dòng để xuống dòng không bị che
    DATA(lv_cells) =
         text_cell( iv_col = `A` iv_row = 9 iv_style = gc_style-text_wrap
                    iv_value = |Add.: { ls_head-AddCI }| )
      && text_cell( iv_col = iv_label_col iv_row = 9 iv_style = gc_style-text iv_value = `DATE:` ).

    IF ls_head-DateCI IS NOT INITIAL.
      " Excel lưu ngày dưới dạng số ngày tính từ 30/12/1899
      DATA(lv_serial) = CONV i( ls_head-DateCI - gc_excel_epoch ).
      lv_cells = lv_cells && number_cell( iv_col = iv_value_col iv_row = 9 iv_style = iv_date_style
                                          iv_value = CONV #( lv_serial ) ).
    ENDIF.

    rv_xml = rv_xml
      && row( iv_row = 9 iv_cells = lv_cells
              iv_height = COND #( WHEN strlen( ls_head-AddCI ) > 55 THEN `36` ELSE `20.25` ) )

    " ── Row 10: Tel / PO ────────────────────────────────────
      && row( iv_row = 10 iv_height = `20.25` iv_cells =
              text_cell( iv_col = `A` iv_row = 10 iv_style = gc_style-text
                         iv_value = |Tel: { ls_head-TelCI }| )
           && text_cell( iv_col = iv_label_col iv_row = 10 iv_style = gc_style-text iv_value = `PO#:` )
           && auto_cell( iv_col = iv_value_col iv_row = 10 iv_style = iv_value_style
                         iv_value = ls_head-PO ) )

    " ── Row 11: LOT (mỗi lot 1 dòng trong cùng 1 ô) ─────────
      && row( iv_row = 11 iv_cells =
              text_cell( iv_col = iv_label_col iv_row = 11 iv_style = gc_style-text iv_value = `LOT#:` )
           && text_cell( iv_col = iv_value_col iv_row = 11 iv_style = iv_value_style iv_value = lv_lots )
              iv_height = COND #( WHEN lv_lot_count > 1 THEN |{ lv_lot_count * 16 }| ELSE `20.25` ) )
      && row( iv_row = 12 iv_height = `15.75` ).

    APPEND |C1:{ iv_last_col }1| TO ct_merge.
    APPEND |C2:{ iv_last_col }2| TO ct_merge.
    APPEND |C3:{ iv_last_col }3| TO ct_merge.
    APPEND |C4:{ iv_last_col }4| TO ct_merge.
    APPEND |A6:{ iv_last_col }6| TO ct_merge.
    APPEND `A9:D9` TO ct_merge.

    IF lv_merge_value = abap_true.
      APPEND |{ iv_value_col }8:{ iv_last_col }8|   TO ct_merge.
      APPEND |{ iv_value_col }9:{ iv_last_col }9|   TO ct_merge.
      APPEND |{ iv_value_col }10:{ iv_last_col }10| TO ct_merge.
      APPEND |{ iv_value_col }11:{ iv_last_col }11| TO ct_merge.
    ENDIF.

  ENDMETHOD.


  METHOD remark_rows.

    " REMARKS / MB/L / HB/L: FS ghi "Điền text" → chưa có nguồn dữ liệu thì để trống
    DATA(lt_remark) = VALUE tt_remark(
      ( label = `REMARKS:` )
      ( label = `1.MB/L#:`               value = is_data-MBL )
      ( label = `2.HB/L#:`               value = is_data-HBL )
      ( label = `3.VESSEL NAME:`         value = is_data-VesselName )
      ( label = `4.ETD:`                 value = is_data-ETD )
      ( label = `5.ETA:`                 value = is_data-ETA )
      ( label = `6.CONTAINER No.:`       value = is_data-ContainerNo )
      ( label = `7.PORT OF LOADING :`    value = is_data-PortOfLoading )
      ( label = `8.PORT OF DESTINATION:` value = is_data-PortOfDestination )
      ( label = `9.PRICE TERM:`          value = is_data-PriceTerm )
      ( label = `10.HTS CODE:`           value = is_data-HTSCode )
      ( label = `11.COUNTRY OF ORIGIN:`  value = is_data-CountryOfOrigin )
      ( label = `12.QUARTZ SLABS`        value = is_data-QuartzSlabs ) ).

    LOOP AT lt_remark INTO DATA(ls_remark).
      cv_row += 1.
      rv_xml = rv_xml
        && row( iv_row = cv_row iv_height = iv_height iv_cells =
                text_cell( iv_col = `A` iv_row = cv_row iv_style = gc_style-text iv_value = ls_remark-label )
             && text_cell( iv_col = `C` iv_row = cv_row iv_style = gc_style-text iv_value = ls_remark-value ) ).
    ENDLOOP.

  ENDMETHOD.


  METHOD worksheet_xml.

    DATA(lv_merges) = REDUCE string( INIT lv_xml = ``
                                     FOR lv_ref IN it_merge
                                     NEXT lv_xml = lv_xml && |<mergeCell ref="{ lv_ref }"/>| ).

    " Chưa đóng </worksheet>: method zip thêm <drawing> (logo) rồi mới đóng
    rv_xml = `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"`
          && ` xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">`
          && `<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>`
          " Mở file ra ở chế độ Page Break Preview như file mẫu
          && `<sheetViews><sheetView showGridLines="0" view="pageBreakPreview"`
          && ` zoomScaleNormal="100" zoomScaleSheetLayoutView="100" workbookViewId="0"/></sheetViews>`
          && `<sheetFormatPr defaultRowHeight="15.75"/>`
          && |<cols>{ iv_cols }</cols>|
          && |<sheetData>{ iv_rows }</sheetData>|
          && |<mergeCells count="{ lines( it_merge ) }">{ lv_merges }</mergeCells>|
          && `<pageMargins left="0.5" right="0.2" top="0.45" bottom="0.45" header="0.3" footer="0.3"/>`
          " In vừa 1 trang A4 theo chiều ngang
          && `<pageSetup paperSize="9" orientation="portrait" fitToWidth="1" fitToHeight="0"/>`.

  ENDMETHOD.


  METHOD zip.

    DATA(lv_xml_decl) = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`.
    DATA(lv_rel_ns)   = `http://schemas.openxmlformats.org/officeDocument/2006/relationships`.
    DATA(lv_pkg_ns)   = `http://schemas.openxmlformats.org/package/2006/relationships`.
    DATA(lv_ct_main)  = `application/vnd.openxmlformats-officedocument.spreadsheetml`.

    DATA(lv_logo)     = get_logo( ).
    DATA(lv_has_logo) = xsdbool( lv_logo IS NOT INITIAL ).

    DATA(lo_zip) = NEW cl_abap_zip( ).

    DATA: lv_ct_sheets      TYPE string,
          lv_wb_sheets      TYPE string,
          lv_wb_rels        TYPE string,
          lv_drawing_rels   TYPE string.

    IF lv_has_logo = abap_true.
      lo_zip->add( name = 'xl/media/logo.png' content = lv_logo ).

      lv_drawing_rels = lv_xml_decl
        && |<Relationships xmlns="{ lv_pkg_ns }">|
        && |<Relationship Id="rId1" Type="{ lv_rel_ns }/image" Target="../media/logo.png"/>|
        && `</Relationships>`.
    ENDIF.

    LOOP AT it_sheets INTO DATA(ls_sheet).
      DATA(lv_no) = sy-tabix.

      DATA(lv_sheet_xml) = lv_xml_decl && ls_sheet-xml.

      IF lv_has_logo = abap_true.
        lv_sheet_xml = lv_sheet_xml && `<drawing r:id="rId1"/>`.

        lo_zip->add( name    = |xl/worksheets/_rels/sheet{ lv_no }.xml.rels|
                     content = to_utf8( lv_xml_decl
                       && |<Relationships xmlns="{ lv_pkg_ns }">|
                       && |<Relationship Id="rId1" Type="{ lv_rel_ns }/drawing"|
                       && | Target="../drawings/drawing{ lv_no }.xml"/>|
                       && `</Relationships>` ) ).
        lo_zip->add( name    = |xl/drawings/drawing{ lv_no }.xml|
                     content = to_utf8( lv_xml_decl && drawing_xml( ) ) ).
        lo_zip->add( name    = |xl/drawings/_rels/drawing{ lv_no }.xml.rels|
                     content = to_utf8( lv_drawing_rels ) ).

        lv_ct_sheets = lv_ct_sheets
          && |<Override PartName="/xl/drawings/drawing{ lv_no }.xml"|
          && ` ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>`.
      ENDIF.

      lo_zip->add( name    = |xl/worksheets/sheet{ lv_no }.xml|
                   content = to_utf8( lv_sheet_xml && `</worksheet>` ) ).

      lv_ct_sheets = lv_ct_sheets
        && |<Override PartName="/xl/worksheets/sheet{ lv_no }.xml"|
        && | ContentType="{ lv_ct_main }.worksheet+xml"/>|.

      DATA(lv_sheet_name) = escape( val = ls_sheet-name format = cl_abap_format=>e_xml_attr ).
      lv_wb_sheets = lv_wb_sheets
        && |<sheet name="{ lv_sheet_name }" sheetId="{ lv_no }" r:id="rId{ lv_no }"/>|.

      lv_wb_rels = lv_wb_rels
        && |<Relationship Id="rId{ lv_no }" Type="{ lv_rel_ns }/worksheet"|
        && | Target="worksheets/sheet{ lv_no }.xml"/>|.
    ENDLOOP.

    DATA(lv_content_types) = lv_xml_decl
      && `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">`
      && `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>`
      && `<Default Extension="xml" ContentType="application/xml"/>`
      && `<Default Extension="png" ContentType="image/png"/>`
      && |<Override PartName="/xl/workbook.xml" ContentType="{ lv_ct_main }.sheet.main+xml"/>|
      && |<Override PartName="/xl/styles.xml" ContentType="{ lv_ct_main }.styles+xml"/>|
      && lv_ct_sheets
      && `</Types>`.

    DATA(lv_rels) = lv_xml_decl
      && |<Relationships xmlns="{ lv_pkg_ns }">|
      && |<Relationship Id="rId1" Type="{ lv_rel_ns }/officeDocument" Target="xl/workbook.xml"/>|
      && `</Relationships>`.

    DATA(lv_workbook) = lv_xml_decl
      && `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"`
      && | xmlns:r="{ lv_rel_ns }">|
      && |<sheets>{ lv_wb_sheets }</sheets>|
      && `</workbook>`.

    DATA(lv_workbook_rels) = lv_xml_decl
      && |<Relationships xmlns="{ lv_pkg_ns }">|
      && lv_wb_rels
      && |<Relationship Id="rId{ lines( it_sheets ) + 1 }" Type="{ lv_rel_ns }/styles" Target="styles.xml"/>|
      && `</Relationships>`.

    lo_zip->add( name = '[Content_Types].xml'        content = to_utf8( lv_content_types ) ).
    lo_zip->add( name = '_rels/.rels'                content = to_utf8( lv_rels ) ).
    lo_zip->add( name = 'xl/workbook.xml'            content = to_utf8( lv_workbook ) ).
    lo_zip->add( name = 'xl/_rels/workbook.xml.rels' content = to_utf8( lv_workbook_rels ) ).
    lo_zip->add( name = 'xl/styles.xml'
                 content = to_utf8( lv_xml_decl && styles_xml( iv_currency ) ) ).

    rv_xlsx = lo_zip->save( ).

  ENDMETHOD.


  METHOD styles_xml.

    " Muốn đổi font / viền / căn lề thì sửa ở đây. Thứ tự <xf> trong <cellXfs> phải khớp gc_style
    DATA(lv_currency) = COND string( WHEN iv_currency IS INITIAL THEN `USD` ELSE iv_currency ).

    DATA(lv_left)   = `<alignment horizontal="left" vertical="center"`.
    DATA(lv_center) = `<alignment horizontal="center" vertical="center"`.
    DATA(lv_right)  = `<alignment horizontal="right" vertical="center"`.
    DATA(lv_plain)  = `fillId="0" xfId="0" applyFont="1" applyAlignment="1"`.
    DATA(lv_grid)   = `fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"`.
    DATA(lv_thin)   = `style="thin"><color auto="1"/>`.

    rv_xml = `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`

          " 164 = số tiền có mã tiền tệ đứng trước, ví dụ: USD 1,234.50
          && |<numFmts count="1"><numFmt numFmtId="164" formatCode="[${ lv_currency }] #,##0.00"/></numFmts>|

          " fontId: 0 = thường, 1 = đậm, 2 = đậm cỡ 10, 3 = tiêu đề (đậm, gạch chân, cỡ 24)
          && `<fonts count="4">`
          && `<font><sz val="12"/><name val="Arial"/></font>`
          && `<font><b/><sz val="12"/><name val="Arial"/></font>`
          && `<font><b/><sz val="10"/><name val="Arial"/></font>`
          && `<font><b/><u/><sz val="24"/><name val="Arial"/></font>`
          && `</fonts>`

          " fillId: 0, 1 = bắt buộc của Excel
          && `<fills count="2">`
          && `<fill><patternFill patternType="none"/></fill>`
          && `<fill><patternFill patternType="gray125"/></fill>`
          && `</fills>`

          " borderId: 0 = không viền, 1 = viền 4 cạnh, 2 - 9 = các cạnh của khung ngân hàng
          && `<borders count="10">`
          && `<border><left/><right/><top/><bottom/><diagonal/></border>`
          && |<border><left { lv_thin }</left><right { lv_thin }</right>|
          && |<top { lv_thin }</top><bottom { lv_thin }</bottom><diagonal/></border>|
          " 2: trái + trên
          && |<border><left { lv_thin }</left><right/><top { lv_thin }</top><bottom/><diagonal/></border>|
          " 3: trên
          && |<border><left/><right/><top { lv_thin }</top><bottom/><diagonal/></border>|
          " 4: phải + trên
          && |<border><left/><right { lv_thin }</right><top { lv_thin }</top><bottom/><diagonal/></border>|
          " 5: trái
          && |<border><left { lv_thin }</left><right/><top/><bottom/><diagonal/></border>|
          " 6: phải
          && |<border><left/><right { lv_thin }</right><top/><bottom/><diagonal/></border>|
          " 7: trái + dưới
          && |<border><left { lv_thin }</left><right/><top/><bottom { lv_thin }</bottom><diagonal/></border>|
          " 8: dưới
          && |<border><left/><right/><top/><bottom { lv_thin }</bottom><diagonal/></border>|
          " 9: phải + dưới
          && |<border><left/><right { lv_thin }</right><top/><bottom { lv_thin }</bottom><diagonal/></border>|
          && `</borders>`

          && `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>`

          " numFmtId: 15 = d-mmm-yy   164 = xem numFmts ở trên
          && `<cellXfs count="24">`
          " 0: mặc định
          && `<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>`
          " 1: co_title
          && |<xf numFmtId="0" fontId="1" borderId="0" { lv_plain }>{ lv_center }/></xf>|
          " 2: co_sub
          && |<xf numFmtId="0" fontId="2" borderId="0" { lv_plain }>{ lv_center } wrapText="1"/></xf>|
          " 3: doc_title
          && |<xf numFmtId="0" fontId="3" borderId="0" { lv_plain }>{ lv_center }/></xf>|
          " 4: text
          && |<xf numFmtId="0" fontId="0" borderId="0" { lv_plain }>{ lv_left }/></xf>|
          " 5: text_bold
          && |<xf numFmtId="0" fontId="1" borderId="0" { lv_plain }>{ lv_left }/></xf>|
          " 6: text_wrap
          && |<xf numFmtId="0" fontId="0" borderId="0" { lv_plain }>{ lv_left } wrapText="1"/></xf>|
          " 7: text_center
          && |<xf numFmtId="0" fontId="0" borderId="0" { lv_plain }>{ lv_center } wrapText="1"/></xf>|
          " 8: date_center
          && |<xf numFmtId="15" fontId="0" borderId="0" { lv_plain } applyNumberFormat="1">{ lv_center }/></xf>|
          " 9: date_left
          && |<xf numFmtId="15" fontId="0" borderId="0" { lv_plain } applyNumberFormat="1">{ lv_left }/></xf>|
          " 10: tbl_cell
          && |<xf numFmtId="0" fontId="0" { lv_grid }>{ lv_center } wrapText="1"/></xf>|
          " 11: tbl_price
          && |<xf numFmtId="164" fontId="0" { lv_grid } applyNumberFormat="1">{ lv_center }/></xf>|
          " 12: tbl_amount
          && |<xf numFmtId="164" fontId="0" { lv_grid } applyNumberFormat="1">{ lv_right }/></xf>|
          " 13: tot_text
          && |<xf numFmtId="0" fontId="1" { lv_grid }>{ lv_center } wrapText="1"/></xf>|
          " 14: tot_amount
          && |<xf numFmtId="164" fontId="1" { lv_grid } applyNumberFormat="1">{ lv_right }/></xf>|
          " 15: box_tl
          && |<xf numFmtId="0" fontId="0" borderId="2" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 16: box_t
          && |<xf numFmtId="0" fontId="0" borderId="3" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 17: box_tr
          && |<xf numFmtId="0" fontId="0" borderId="4" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 18: box_l
          && |<xf numFmtId="0" fontId="0" borderId="5" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 19: box_r
          && |<xf numFmtId="0" fontId="0" borderId="6" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 20: box_bl
          && |<xf numFmtId="0" fontId="0" borderId="7" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 21: box_b
          && |<xf numFmtId="0" fontId="0" borderId="8" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 22: box_br
          && |<xf numFmtId="0" fontId="0" borderId="9" { lv_plain } applyBorder="1">{ lv_left }/></xf>|
          " 23: sign
          && |<xf numFmtId="0" fontId="1" borderId="0" { lv_plain }>{ lv_center }/></xf>|
          && `</cellXfs>`

          && `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>`
          && `</styleSheet>`.

  ENDMETHOD.


  METHOD get_logo.

    " Logo nằm trong XDP dưới dạng <image contentType="image/png">base64</image>
    " Không tìm thấy → file excel không có logo, các phần khác vẫn bình thường
    TRY.
        SELECT SINGLE FROM zcore_tb_temppdf
          FIELDS file_content
          WHERE id = 'zci_pdf'
          INTO @DATA(lv_xdp).
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.

        DATA(lv_xdp_text) = cl_abap_conv_codepage=>create_in( )->convert( CONV xstring( lv_xdp ) ).

        FIND FIRST OCCURRENCE OF PCRE `<image[^>]*image/png[^>]*>([^<]+)</image>`
          IN lv_xdp_text SUBMATCHES DATA(lv_base64).
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.

        REPLACE ALL OCCURRENCES OF PCRE `\s` IN lv_base64 WITH ``.

        rv_logo = cl_web_http_utility=>decode_x_base64( lv_base64 ).

      CATCH cx_root.
        CLEAR rv_logo.
    ENDTRY.

  ENDMETHOD.


  METHOD drawing_xml.

    " Logo 500 x 220 px, đặt ở góc trên trái (A1). ext tính bằng EMU: 1 px = 9525 EMU
    rv_xml = `<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"`
          && ` xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"`
          && ` xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">`
          && `<xdr:oneCellAnchor>`
          && `<xdr:from><xdr:col>0</xdr:col><xdr:colOff>60000</xdr:colOff>`
          && `<xdr:row>0</xdr:row><xdr:rowOff>50000</xdr:rowOff></xdr:from>`
          && `<xdr:ext cx="2000000" cy="880000"/>`
          && `<xdr:pic>`
          && `<xdr:nvPicPr><xdr:cNvPr id="2" name="Logo"/><xdr:cNvPicPr>`
          && `<a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>`
          && `<xdr:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>`
          && `<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="2000000" cy="880000"/></a:xfrm>`
          && `<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr>`
          && `</xdr:pic>`
          && `<xdr:clientData/>`
          && `</xdr:oneCellAnchor>`
          && `</xdr:wsDr>`.

  ENDMETHOD.


  METHOD get_lots.

    DATA lt_lots TYPE tt_string.

    LOOP AT it_items INTO DATA(ls_item) WHERE LOT IS NOT INITIAL.
      IF NOT line_exists( lt_lots[ table_line = ls_item-LOT ] ).
        APPEND ls_item-LOT TO lt_lots.
      ENDIF.
    ENDLOOP.

    ev_count = lines( lt_lots ).
    rv_lots  = concat_lines_of( table = lt_lots sep = cl_abap_char_utilities=>newline ).

  ENDMETHOD.


  METHOD row.

    DATA(lv_height) = COND string( WHEN iv_height IS NOT INITIAL
                                   THEN | ht="{ iv_height }" customHeight="1"| ).

    rv_xml = |<row r="{ iv_row }"{ lv_height }>{ iv_cells }</row>|.

  ENDMETHOD.


  METHOD text_cell.

    IF iv_value IS INITIAL.
      rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }"/>|.
      RETURN.
    ENDIF.

    DATA(lv_text) = escape( val    = CONV string( iv_value )
                            format = cl_abap_format=>e_xml_text ).

    rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }" t="inlineStr">|
          && |<is><t xml:space="preserve">{ lv_text }</t></is></c>|.

  ENDMETHOD.


  METHOD number_cell.

    rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }"><v>{ iv_value }</v></c>|.

  ENDMETHOD.


  METHOD auto_cell.

    DATA(lv_value) = condense( CONV string( iv_value ) ).

    IF lv_value IS NOT INITIAL AND strlen( lv_value ) <= 15 AND lv_value CO '0123456789'.
      rv_xml = |<c r="{ iv_col }{ iv_row }" s="{ iv_style }"><v>{ lv_value }</v></c>|.
    ELSE.
      rv_xml = text_cell( iv_col = iv_col iv_row = iv_row iv_style = iv_style iv_value = lv_value ).
    ENDIF.

  ENDMETHOD.


  METHOD empty_cells.

    DATA(lv_offset) = 0.
    WHILE lv_offset < strlen( iv_cols ).
      rv_xml = rv_xml && |<c r="{ substring( val = iv_cols off = lv_offset len = 1 ) }{ iv_row }" s="{ iv_style }"/>|.
      lv_offset += 1.
    ENDWHILE.

  ENDMETHOD.


  METHOD to_utf8.

    rv_xstring = cl_abap_conv_codepage=>create_out( )->convert( iv_string ).

  ENDMETHOD.
ENDCLASS.
