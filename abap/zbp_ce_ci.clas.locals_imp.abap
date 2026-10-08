CLASS lhc_zce_ci DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR zce_ci RESULT result.

    METHODS read FOR READ
       keys FOR READ zce_ci RESULT result.

    METHODS lock FOR LOCK
       keys FOR LOCK zce_ci.

    METHODS btnPrintPDF FOR MODIFY
       keys FOR ACTION zce_ci~btnPrintPDF RESULT result.
    METHODS PDFPackingList FOR MODIFY
       keys FOR ACTION zce_ci~PDFPackingList RESULT result.

ENDCLASS.

CLASS lhc_zce_ci IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD btnPrintPDF.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "1. Get data
    DATA: lt_filters         TYPE if_rap_query_filter=>tt_name_range_pairs,
          lr_proformainvoice TYPE zcl_ce_ci_top=>ry_string,
          lt_keys_pdf        TYPE zcl_ce_ci_top=>tt_key_pdf.

    LOOP AT keys INTO DATA(ls_key_d).
      APPEND INITIAL LINE TO lr_proformainvoice ASSIGNING FIELD-SYMBOL(<lfs_proformainvoice>).
      <lfs_proformainvoice>-sign = 'I'.
      <lfs_proformainvoice>-option = 'EQ'.
      <lfs_proformainvoice>-low = ls_key_d-%key-ProFormaInvoice.

      APPEND INITIAL LINE TO lt_keys_pdf ASSIGNING FIELD-SYMBOL(<lfs_keys_pdf>).
      <lfs_keys_pdf>-proformainvoice = ls_key_d-%key-ProFormaInvoice.
      <lfs_keys_pdf>-Item            = ls_key_d-%key-Item.
    ENDLOOP.

    SORT lr_proformainvoice BY low.
    DELETE ADJACENT DUPLICATES FROM lr_proformainvoice COMPARING low.

    lt_filters = VALUE #( ( name = 'PROFORMAINVOICE' range = CORRESPONDING #( lr_proformainvoice ) ) ).

    zcl_ce_ci_f01=>main(
      EXPORTING
        it_filters  = lt_filters
        it_keys_pdf = lt_keys_pdf
      IMPORTING
        et_result  = DATA(lt_data)
    ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "2. Gen adobe
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "2.1. Implement data (group data theo header là proformainvoice)
    DATA: lt_data_xml       TYPE STANDARD TABLE OF xstring,
          lv_lot            TYPE string,
          lv_table2         TYPE string,
          lv_table3         TYPE string,
          lv_total_quantity TYPE fkimg,
          lv_total_amount   TYPE zce_ci-Amount.

    LOOP AT lt_data INTO DATA(ls_grp) GROUP BY ( ProFormaInvoice = ls_grp-ProFormaInvoice )
        INTO DATA(ls_data_grp).

      "Sub3
      READ TABLE lt_data INTO DATA(ls_data_sub3) WITH KEY ProFormaInvoice = ls_data_grp-ProFormaInvoice.
      IF sy-subrc = 0.
        DATA(lv_toci) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-ToCI ).
        DATA(lv_addci) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-AddCI ).
        DATA(lv_telci)  = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-TelCI ).
        DATA(lv_invoice) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-Invoice ).
        DATA(lv_dateci) = zcl_utility_ninhnh=>convert_date_to_ddmmmyy( iv_date = ls_data_sub3-DateCI ).
        DATA(lv_po) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_sub3-po ) ).
      ENDIF.

      DATA(lv_sub3) =
        |<Sub3>|
            && |<DataTo>|
                && |To: { lv_toci }|
            && |</DataTo>|
            && |<DataAddCI>|
                && |Add.: { lv_addci }|
            && |</DataAddCI>|
            && |<DataTelCI>|
                && |Tel: { lv_telci }|
            && |</DataTelCI>|
            && |<DataInvoice>|
                && |{ lv_invoice }|
            && |</DataInvoice>|
            && |<DataDateCI>|
                && |{ lv_dateci }|
            && |</DataDateCI>|
            && |<DataDateCI>|
                && |{ lv_dateci }|
            && |</DataDateCI>|
            && |<DataPO>|
                && |{ lv_po }|
            && |</DataPO>|
        && |</Sub3>|.


      "Sub4
      CLEAR: lv_lot.
      LOOP AT GROUP ls_data_grp INTO DATA(ls_member_lot).
        IF ls_member_lot-lot IS INITIAL.
          CONTINUE.
        ENDIF.
        DATA(lv_lot_esc) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_member_lot-lot ).
        lv_lot = COND #( WHEN lv_lot IS INITIAL
                         THEN lv_lot_esc
                         ELSE |{ lv_lot }&#10;{ lv_lot_esc }| ).
      ENDLOOP.

      CLEAR: lv_table2,
             lv_total_quantity,
             lv_total_amount.
      LOOP AT GROUP ls_data_grp INTO DATA(ls_member_table2).
        DATA(lv_aztid)     = zcl_utility_ninhnh=>escape_xml( iv_text = ls_member_table2-aztid ).
        DATA(lv_quantity)  = zcl_utility_ninhnh=>format_number_trim( iv_value = ls_member_table2-Quantity ).
        DATA(lv_unitprice) = zcl_utility_ninhnh=>format_number_trim( iv_value = ls_member_table2-UnitPrice ).
        DATA(lv_amount)    = zcl_utility_ninhnh=>format_number_trim( iv_value = ls_member_table2-Amount ).
        lv_total_quantity  = lv_total_quantity + ls_member_table2-Quantity.
        lv_total_amount    = lv_total_amount + ls_member_table2-Amount.

        lv_table2 = |{ lv_table2 }|
            && |<Row2>|
                && |<Cell1>|
                    && |{ lv_po }|
                && |</Cell1>|
                && |<Cell2>|
                    && |{ lv_aztid }|
                && |</Cell2>|
                && |<Cell3>|
                    && |223637|
                && |</Cell3>|
                && |<Cell4>|
                    && |{ lv_quantity }|
                && |</Cell4>|
                && |<Cell5>|
                    && |{ ls_member_table2-TransactionCurrency } { lv_unitprice }|
                && |</Cell5>|
                && |<Cell6>|
                    && |{ ls_member_table2-TransactionCurrency } { lv_amount }|
                && |</Cell6>|
            && |</Row2>|.
      ENDLOOP.
      lv_total_quantity = zcl_utility_ninhnh=>format_number_trim( iv_value = lv_total_quantity ).
      lv_total_amount   = zcl_utility_ninhnh=>format_number_trim( iv_value = lv_total_amount ).

      CLEAR: lv_table3.
      READ TABLE lt_data INTO DATA(ls_data_table3) WITH KEY ProFormaInvoice = ls_data_grp-ProFormaInvoice.
      IF sy-subrc = 0.
        DATA(lv_vesselname) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-VesselName ).
        DATA(lv_etd) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-etd ).
        DATA(lv_eta) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-eta ).
        DATA(lv_containerno) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-ContainerNo ).
        DATA(lv_PortOfLoading) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-PortOfLoading ) ).
        DATA(lv_PortOfDestination) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-PortOfDestination ) ).
        DATA(lv_PriceTerm) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-PriceTerm ) ).
        DATA(lv_HTSCode) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-HTSCode ).
        DATA(lv_CountryOfOrigin) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-CountryOfOrigin ) ).
        DATA(lv_QuartzSlabs) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-QuartzSlabs ).
      ENDIF.
      lv_table3 =
        |<Row6>|
            && |<Cell2>|
                && |{ lv_vesselname }|
            && |</Cell2>|
        && |</Row6>|
        && |<Row7>|
            && |<Cell2>|
                && |{ lv_etd }|
            && |</Cell2>|
        && |</Row7>|
        && |<Row8>|
            && |<Cell2>|
                && |{ lv_eta }|
            && |</Cell2>|
        && |</Row8>|
        && |<Row9>|
            && |<Cell2>|
                && |{ lv_containerno }|
            && |</Cell2>|
        && |</Row9>|
        && |<Row10>|
            && |<Cell2>|
                && |{ lv_PortOfLoading }|
            && |</Cell2>|
        && |</Row10>|
        && |<Row11>|
            && |<Cell2>|
                && |{ lv_PortOfDestination }|
            && |</Cell2>|
        && |</Row11>|
        && |<Row12>|
            && |<Cell2>|
                && |{ lv_PriceTerm }|
            && |</Cell2>|
        && |</Row12>|
        && |<Row13>|
            && |<Cell2>|
                && |{ lv_HTSCode }|
            && |</Cell2>|
        && |</Row13>|
        && |<Row14>|
            && |<Cell2>|
                && |{ lv_CountryOfOrigin }|
            && |</Cell2>|
        && |</Row14>|
        && |<Row15>|
            && |<Cell2>|
                && |{ lv_QuartzSlabs }|
            && |</Cell2>|
        && |</Row15>|.

      DATA(lv_sub4) =
        |<Sub4>|
            && |<Table1>|
                && |<Row1>|
                    && |<DataLOT>|
                        && |{ lv_lot }|
                    && |</DataLOT>|
                && |</Row1>|
                && |<Row3>|
                    && |<Sub4.1>|
                        && |<Table2>|
                            && |{ lv_table2 }|
                            && |<Row3>|
                                && |<Cell3>|
                                    && |{ lv_total_quantity }|
                                && |</Cell3>|
                                && |<Cell5>|
                                    && |{ ls_member_table2-TransactionCurrency } { lv_total_amount }|
                                && |</Cell5>|
                            && |</Row3>|
                        && |</Table2>|
                    && |</Sub4.1>|
                && |</Row3>|
                && |<Row4>|
                    && |<Sub4.2>|
                        && |<Table3>|
                            && |{ lv_table3 }|
                        && |</Table3>|
                    && |</Sub4.2>|
                && |</Row4>|
            && |</Table1>|
        && |</Sub4>|.


      "Add data to form
      DATA(lv_form) =
        |<?xml version="1.0" encoding="UTF-8"?>|
        && |<form>|
            && |{ lv_sub3 }|
            && |{ lv_sub4 }|
        && |</form>|.

      "Decode data
      DATA(lv_encode) = cl_web_http_utility=>encode_x_base64(
        cl_web_http_utility=>encode_utf8( lv_form )
        ).
      DATA(lv_decode) = cl_web_http_utility=>decode_x_base64( lv_encode ).

      lt_data_xml = VALUE #( BASE lt_data_xml ( lv_decode ) ).
    ENDLOOP.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "2.2. Get Template
    SELECT SINGLE FROM zcore_tb_temppdf
    FIELDS file_content
    WHERE id = 'zci_pdf'
    INTO @DATA(lv_xdp).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "2.3. Print PDF
    DATA(lo_merge_pdf) = cl_rspo_pdf_merger=>create_instance( ).

    LOOP AT lt_data_xml INTO DATA(ls_data_xml).
      TRY.
          cl_fp_ads_util=>render_pdf(
            EXPORTING
              iv_xml_data     = ls_data_xml "test
              iv_xdp_layout   = CONV xstring( lv_xdp )
              iv_locale       = 'de_DE'
              is_options      = VALUE #( embed_fonts = 'X' )
            IMPORTING
              ev_pdf          = DATA(lv_pdf)
              ev_pages        = DATA(lv_pages)
              ev_trace_string = DATA(lv_trace_string)
          ).
          "Add
          lo_merge_pdf->add_document( lv_pdf ).
        CATCH cx_fp_ads_util INTO DATA(lx_err).
          DATA(lv_err) = lx_err->get_longtext( ).
      ENDTRY.
    ENDLOOP.

    TRY.
        DATA(lv_pdf_base64) = cl_web_http_utility=>encode_x_base64(
            lo_merge_pdf->merge_documents( )
         ).
      CATCH cx_rspo_pdf_merger INTO DATA(lx_merge_err).
        DATA(lv_merge_err) = lx_merge_err->get_longtext( ).
    ENDTRY.


    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "3. Display result
    LOOP AT keys INTO DATA(ls_key_r).
      APPEND INITIAL LINE TO result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-%tky = ls_key_r-%tky.
      <lfs_result>-%param-FileContent = lv_pdf_base64.
      <lfs_result>-%param-FileName = |CI_{ ls_key_r-ProFormaInvoice }_{ sy-datum }_{ sy-uzeit }|.
      <lfs_result>-%param-FileExtension = 'pdf'.
      <lfs_result>-%param-MimeType = 'application/pdf'.
    ENDLOOP.
  ENDMETHOD.

  METHOD PDFPackingList.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "1. Get data
    DATA: lt_filters         TYPE if_rap_query_filter=>tt_name_range_pairs,
          lr_proformainvoice TYPE zcl_ce_ci_top=>ry_string,
          lt_keys_pdf        TYPE zcl_ce_ci_top=>tt_key_pdf.

    LOOP AT keys INTO DATA(ls_key_d).
      APPEND INITIAL LINE TO lr_proformainvoice ASSIGNING FIELD-SYMBOL(<lfs_proformainvoice>).
      <lfs_proformainvoice>-sign = 'I'.
      <lfs_proformainvoice>-option = 'EQ'.
      <lfs_proformainvoice>-low = ls_key_d-%key-ProFormaInvoice.

      APPEND INITIAL LINE TO lt_keys_pdf ASSIGNING FIELD-SYMBOL(<lfs_keys_pdf>).
      <lfs_keys_pdf>-proformainvoice = ls_key_d-%key-ProFormaInvoice.
      <lfs_keys_pdf>-Item            = ls_key_d-%key-Item.
    ENDLOOP.

    SORT lr_proformainvoice BY low.
    DELETE ADJACENT DUPLICATES FROM lr_proformainvoice COMPARING low.

    lt_filters = VALUE #( ( name = 'PROFORMAINVOICE' range = CORRESPONDING #( lr_proformainvoice ) ) ).

    zcl_ce_ci_f01=>main(
      EXPORTING
        it_filters  = lt_filters
        it_keys_pdf = lt_keys_pdf
      IMPORTING
        et_result  = DATA(lt_data)
    ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "2. Gen adobe
    "2.1. Implement data (group data theo header là proformainvoice)
    DATA: lt_data_xml      TYPE STANDARD TABLE OF xstring,
          lv_lot           TYPE string,
          lv_table2        TYPE string,
          lv_table3        TYPE string,
          lv_total_pcs     TYPE fkimg,
          lv_total_package TYPE string,
          lv_tabix         TYPE i.

    LOOP AT lt_data INTO DATA(ls_grp) GROUP BY ( ProFormaInvoice = ls_grp-ProFormaInvoice )
        INTO DATA(ls_data_grp).
      "Sub3
      READ TABLE lt_data INTO DATA(ls_data_sub3) WITH KEY ProFormaInvoice = ls_data_grp-ProFormaInvoice.
      IF sy-subrc = 0.
        DATA(lv_toci) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-ToCI ).
        DATA(lv_addci) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-AddCI ).
        DATA(lv_telci)  = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-TelCI ).
        DATA(lv_invoice) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_sub3-Invoice ).
        DATA(lv_dateci) = zcl_utility_ninhnh=>convert_date_to_ddmmmyy( iv_date = ls_data_sub3-DateCI ).
        DATA(lv_po) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_sub3-po ) ).
      ENDIF.

      DATA(lv_sub3) =
        |<Sub3>|
            && |<DataTo>|
                && |To: { lv_toci }|
            && |</DataTo>|
            && |<DataAddCI>|
                && |Add.: { lv_addci }|
            && |</DataAddCI>|
            && |<DataTelCI>|
                && |Tel: { lv_telci }|
            && |</DataTelCI>|
            && |<DataInvoice>|
                && |{ lv_invoice }|
            && |</DataInvoice>|
            && |<DataDateCI>|
                && |{ lv_dateci }|
            && |</DataDateCI>|
            && |<DataDateCI>|
                && |{ lv_dateci }|
            && |</DataDateCI>|
            && |<DataPO>|
                && |{ lv_po }|
            && |</DataPO>|
        && |</Sub3>|.

      "Sub4
      CLEAR: lv_lot.
      LOOP AT GROUP ls_data_grp INTO DATA(ls_member_lot).
        IF ls_member_lot-lot IS INITIAL.
          CONTINUE.
        ENDIF.
        DATA(lv_lot_esc) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_member_lot-lot ).
        lv_lot = COND #( WHEN lv_lot IS INITIAL
                         THEN lv_lot_esc
                         ELSE |{ lv_lot }&#10;{ lv_lot_esc }| ).
      ENDLOOP.

      CLEAR: lv_table2,
             lv_total_pcs,
             lv_total_package,
             lv_tabix.
      LOOP AT GROUP ls_data_grp INTO DATA(ls_member_table2).
        lv_tabix          += 1.
        DATA(lv_aztid)    = zcl_utility_ninhnh=>escape_xml( iv_text = ls_member_table2-aztid ).
        DATA(lv_pcs)      = zcl_utility_ninhnh=>format_number_trim( iv_value = ls_member_table2-Quantity ).
        DATA(lv_lot_item) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_member_table2-lot ).
        lv_total_pcs      = lv_total_pcs + ls_member_table2-Quantity.

        lv_table2 = |{ lv_table2 }|
            && |<Row2>|
                && |<Cell1>|
                    && |{ lv_tabix }|
                && |</Cell1>|
                && |<Cell2>|
                    && |{ lv_aztid }|
                && |</Cell2>|
                && |<Cell3>|
                    && |{ ls_member_table2-SizeL }|
                && |</Cell3>|
                && |<Cell4>|
                    && |{ ls_member_table2-SizeW }|
                && |</Cell4>|
                && |<Cell5>|
                    && |{ ls_member_table2-SizeH }|
                && |</Cell5>|
                && |<Cell6>|
*                    && |SQM - chưa có logic|
                && |</Cell6>|
                && |<Cell7>|
                    && |{ lv_pcs }|
                && |</Cell7>|
                && |<Cell8>|
*                    && |Net weight - chưa có logic|
                && |</Cell8>|
                && |<Cell9>|
*                    && |Gross weight - chưa có logic|
                && |</Cell9>|
                && |<Cell10>|
                    && |{ lv_lot_item }|
                && |</Cell10>|
            && |</Row2>|.
      ENDLOOP.
      DATA(lv_total_pcs_string) = zcl_utility_ninhnh=>format_number_trim( iv_value = lv_total_pcs ).
      lv_total_package = |TOTAL: { lv_tabix } { COND string( WHEN lv_tabix = 1 THEN 'PACKAGE' ELSE 'PACKAGES' ) }|.

      CLEAR: lv_table3.
      READ TABLE lt_data INTO DATA(ls_data_table3) WITH KEY ProFormaInvoice = ls_data_grp-ProFormaInvoice.
      IF sy-subrc = 0.
        DATA(lv_vesselname) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-VesselName ).
        DATA(lv_etd) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-etd ).
        DATA(lv_eta) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-eta ).
        DATA(lv_containerno) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-ContainerNo ).
        DATA(lv_PortOfLoading) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-PortOfLoading ) ).
        DATA(lv_PortOfDestination) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-PortOfDestination ) ).
        DATA(lv_PriceTerm) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-PriceTerm ) ).
        DATA(lv_HTSCode) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-HTSCode ).
        DATA(lv_CountryOfOrigin) = zcl_utility_ninhnh=>escape_xml( iv_text = CONV string( ls_data_table3-CountryOfOrigin ) ).
        DATA(lv_QuartzSlabs) = zcl_utility_ninhnh=>escape_xml( iv_text = ls_data_table3-QuartzSlabs ).
      ENDIF.
      lv_table3 =
        |<Row6>|
            && |<Cell2>|
                && |{ lv_vesselname }|
            && |</Cell2>|
        && |</Row6>|
        && |<Row7>|
            && |<Cell2>|
                && |{ lv_etd }|
            && |</Cell2>|
        && |</Row7>|
        && |<Row8>|
            && |<Cell2>|
                && |{ lv_eta }|
            && |</Cell2>|
        && |</Row8>|
        && |<Row9>|
            && |<Cell2>|
                && |{ lv_containerno }|
            && |</Cell2>|
        && |</Row9>|
        && |<Row10>|
            && |<Cell2>|
                && |{ lv_PortOfLoading }|
            && |</Cell2>|
        && |</Row10>|
        && |<Row11>|
            && |<Cell2>|
                && |{ lv_PortOfDestination }|
            && |</Cell2>|
        && |</Row11>|
        && |<Row12>|
            && |<Cell2>|
                && |{ lv_PriceTerm }|
            && |</Cell2>|
        && |</Row12>|
        && |<Row13>|
            && |<Cell2>|
                && |{ lv_HTSCode }|
            && |</Cell2>|
        && |</Row13>|
        && |<Row14>|
            && |<Cell2>|
                && |{ lv_CountryOfOrigin }|
            && |</Cell2>|
        && |</Row14>|
        && |<Row15>|
            && |<Cell2>|
                && |{ lv_QuartzSlabs }|
            && |</Cell2>|
        && |</Row15>|.

      DATA(lv_sub4) =
        |<Sub4>|
            && |<Table1>|
                && |<Row1>|
                    && |<DataLOT>|
                        && |{ lv_lot }|
                    && |</DataLOT>|
                && |</Row1>|
                && |<Row3>|
                    && |<Sub4.1>|
                        && |<Table2>|
                            && |{ lv_table2 }|
                            && |<Row3>|
                                && |<Cell1>|
                                    && |{ lv_total_package }|
                                && |</Cell1>|
                                && |<Cell6>|
                                    && |{ lv_total_pcs_string }|
                                && |</Cell6>|
                            && |</Row3>|
                        && |</Table2>|
                    && |</Sub4.1>|
                && |</Row3>|
                && |<Row4>|
                    && |<Sub4.2>|
                        && |<Table3>|
                            && |{ lv_table3 }|
                        && |</Table3>|
                    && |</Sub4.2>|
                && |</Row4>|
            && |</Table1>|
        && |</Sub4>|.

      "Add data to form
      DATA(lv_form) =
        |<?xml version="1.0" encoding="UTF-8"?>|
        && |<form>|
            && |{ lv_sub3 }|
            && |{ lv_sub4 }|
        && |</form>|.

      "Decode data
      DATA(lv_encode) = cl_web_http_utility=>encode_x_base64(
        cl_web_http_utility=>encode_utf8( lv_form )
        ).
      DATA(lv_decode) = cl_web_http_utility=>decode_x_base64( lv_encode ).

      lt_data_xml = VALUE #( BASE lt_data_xml ( lv_decode ) ).
    ENDLOOP.

    "2.2. Get Template
    SELECT SINGLE FROM zcore_tb_temppdf
    FIELDS file_content
    WHERE id = 'zpl_pdf'
    INTO @DATA(lv_xdp).

    "2.3. Print PDF
    DATA(lo_merge_pdf) = cl_rspo_pdf_merger=>create_instance( ).

    LOOP AT lt_data_xml INTO DATA(ls_data_xml).
      TRY.
          cl_fp_ads_util=>render_pdf(
            EXPORTING
              iv_xml_data     = ls_data_xml "test
              iv_xdp_layout   = CONV xstring( lv_xdp )
              iv_locale       = 'de_DE'
              is_options      = VALUE #( embed_fonts = 'X' )
            IMPORTING
              ev_pdf          = DATA(lv_pdf)
              ev_pages        = DATA(lv_pages)
              ev_trace_string = DATA(lv_trace_string)
          ).
          "Add
          lo_merge_pdf->add_document( lv_pdf ).
        CATCH cx_fp_ads_util INTO DATA(lx_err).
          DATA(lv_err) = lx_err->get_longtext( ).
      ENDTRY.
    ENDLOOP.

    TRY.
        DATA(lv_pdf_base64) = cl_web_http_utility=>encode_x_base64(
            lo_merge_pdf->merge_documents( )
         ).
      CATCH cx_rspo_pdf_merger INTO DATA(lx_merge_err).
        DATA(lv_merge_err) = lx_merge_err->get_longtext( ).
    ENDTRY.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "3. Display result
    LOOP AT keys INTO DATA(ls_key_r).
      APPEND INITIAL LINE TO result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-%tky = ls_key_r-%tky.
      <lfs_result>-%param-FileContent = lv_pdf_base64.
      <lfs_result>-%param-FileName = |PL_{ ls_key_r-ProFormaInvoice }_{ sy-datum }_{ sy-uzeit }|.
      <lfs_result>-%param-FileExtension = 'pdf'.
      <lfs_result>-%param-MimeType = 'application/pdf'.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZCE_CI DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZCE_CI IMPLEMENTATION.

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
