CLASS lhc_zc_masschange_product_orde DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zc_masschange_product_order RESULT result.

*    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
*      IMPORTING REQUEST requested_authorizations FOR zc_MASSCHANGE_PRODUCT_ORDER RESULT result.

*    METHODS create FOR MODIFY
*      IMPORTING entities FOR CREATE zc_MASSCHANGE_PRODUCT_ORDER.
*
*    METHODS update FOR MODIFY
*      IMPORTING entities FOR UPDATE zc_MASSCHANGE_PRODUCT_ORDER.
*
*    METHODS delete FOR MODIFY
*      IMPORTING keys FOR DELETE zc_MASSCHANGE_PRODUCT_ORDER.

    METHODS read FOR READ
      IMPORTING keys FOR READ zc_masschange_product_order RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK zc_masschange_product_order.
    METHODS downloadtemplate FOR MODIFY
      IMPORTING keys FOR ACTION zc_masschange_product_order~downloadtemplate RESULT result.

    METHODS excelupload FOR MODIFY
      IMPORTING keys FOR ACTION zc_masschange_product_order~excelupload.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zc_masschange_product_order RESULT result.
    METHODS setdeliverycomplete FOR MODIFY
      IMPORTING keys FOR ACTION zc_masschange_product_order~setdeliverycomplete.


ENDCLASS.

CLASS lhc_zc_masschange_product_orde IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

*  METHOD get_global_authorizations.
*  ENDMETHOD.

*  METHOD create.
*  ENDMETHOD.
*
*  METHOD update.
*  ENDMETHOD.
*
*  METHOD delete.
*  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD downloadtemplate.
    TYPES:
      BEGIN OF ty_file_up_gen,
        manufacturingorder       TYPE string,
        mfgorderplannedstartdate TYPE string,
        mfgorderplannedenddate   TYPE string,
        yy1_so_may_ord           TYPE string,
        yy1_thu_tu_ord           TYPE string,
        yy1_materialname_ord     TYPE string,
      END OF ty_file_up_gen,

      ty_t_file_up_gen TYPE STANDARD TABLE OF ty_file_up_gen WITH EMPTY KEY.

    TYPES: BEGIN OF ty_range_option,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE string,
             high   TYPE string,
           END OF ty_range_option,


           tt_ranges TYPE TABLE OF ty_range_option,

           tt_data   TYPE TABLE OF zc_masschange_product_order.

    DATA lt_file TYPE STANDARD TABLE OF ty_file_up_gen WITH DEFAULT KEY.

    "XCOライブラリを使用したExcelファイルの書き込み
    DATA(lo_write_access) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_worksheet) = lo_write_access->get_workbook(
        )->worksheet->at_position( 1 ).

    DATA(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
                               )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
                               )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'F' )
                               )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
                               )->get_pattern( ).

    TYPES: BEGIN OF ty_item,
             manufacturingorder TYPE zc_masschange_product_order-manufacturingorder,
           END OF ty_item.

    TYPES ty_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    READ TABLE keys INDEX 1 INTO DATA(k).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA: lt_items TYPE ty_items.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json = k-%param-json_string
      CHANGING
        data = lt_items
    ).

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<fs>).
      " Chuẩn hóa ManufacturingOrder
      <fs>-manufacturingorder = |{ <fs>-manufacturingorder ALPHA = IN }|.
    ENDLOOP.

    SELECT * FROM zc_masschange_product_order
      FOR ALL ENTRIES IN @lt_items
      WHERE manufacturingorder = @lt_items-manufacturingorder
      INTO TABLE @DATA(lt_data).

    "ヘッダの設定（すべての項目はstring型）
    lt_file = VALUE #(
************Line One
                       (
                       manufacturingorder       = 'Production Order'
                       mfgorderplannedstartdate = 'Ngày bắt đầu'
                       mfgorderplannedenddate   = 'Ngày kết thúc'
                       yy1_so_may_ord           = 'Số máy'
                       yy1_thu_tu_ord           = 'Số thứ tự'
                       yy1_materialname_ord     = 'Tên thành phẩm'
                       ) ).

    LOOP AT lt_data INTO DATA(ls_data).
      "add by hieudc7 format dạng date
      DATA:lv_mfgorderplannedstartdate TYPE string,
           lv_mfgorderplannedenddate   TYPE string.
      lv_mfgorderplannedstartdate = |{ ls_data-mfgorderplannedstartdate+6(2) }.{ ls_data-mfgorderplannedstartdate+4(2) }.{ ls_data-mfgorderplannedstartdate+0(4) }|.
      lv_mfgorderplannedenddate = |{ ls_data-mfgorderplannedenddate+6(2) }.{ ls_data-mfgorderplannedenddate+4(2) }.{ ls_data-mfgorderplannedenddate+0(4) }|.

      APPEND VALUE ty_file_up_gen(
        manufacturingorder       = |{ ls_data-manufacturingorder ALPHA = OUT }|
        mfgorderplannedstartdate = lv_mfgorderplannedstartdate
        mfgorderplannedenddate   = lv_mfgorderplannedenddate
        yy1_so_may_ord           = ls_data-yy1_so_may_ord
        yy1_thu_tu_ord           = ls_data-yy1_thu_tu_ord
        yy1_materialname_ord     = ls_data-yy1_materialname_ord
      ) TO lt_file.
    ENDLOOP.
    lo_worksheet->select( lo_selection_pattern
        )->row_stream(
        )->operation->write_from( REF #( lt_file )
        )->execute( ).

    DATA(lv_file_content) = lo_write_access->get_file_content( ).

    result = VALUE #( FOR key IN keys (
                      %cid   = key-%cid
                      %param = VALUE #( filecontent   = lv_file_content
                                        filename      = 'MassChangeProductionOrderTemplate'
                                        fileextension = 'xlsx'
                                        mimetype      = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' )
                      ) ).

  ENDMETHOD.


  METHOD excelupload.
    DATA: lv_success   TYPE abap_bool VALUE abap_true,
          lv_error_msg TYPE string,
          lv_line      TYPE string,
          lt_lines     TYPE STANDARD TABLE OF string.


    TYPES:
      BEGIN OF ty_file_upload,
        manufacturingorder       TYPE i_manufacturingorder-manufacturingorder,
        mfgorderplannedstartdate TYPE string,
        mfgorderplannedenddate   TYPE string,
        yy1_so_may_ord           TYPE string,
        yy1_thu_tu_ord           TYPE string,
        yy1_materialname_ord     TYPE string,


      END OF ty_file_upload,

      ty_t_file_upload TYPE STANDARD TABLE OF ty_file_upload WITH EMPTY KEY.

    DATA lv_file_content TYPE xstring.
    DATA lt_sheet_data   TYPE STANDARD TABLE OF ty_file_upload.
    READ TABLE keys INDEX 1 INTO DATA(key).

    " Lấy file content từ parameter
    lv_file_content = VALUE #( keys[ 1 ]-%param-filecontent OPTIONAL ).

    " Kiểm tra file có rỗng không
    IF lv_file_content IS INITIAL.
      reported-zc_masschange_product_order = VALUE #(
        ( %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = 'File Excel không được để trống' ) )
      ).
      RETURN.
    ENDIF.

    " Đọc Excel file
    TRY.
        DATA(lo_document) = xco_cp_xlsx=>document->for_file_content( lv_file_content )->read_access( ).
        DATA(lo_worksheet) = lo_document->get_workbook( )->worksheet->at_position( 1 ).

        " Định nghĩa vùng đọc dữ liệu (A3:F999 - bỏ header row 1-2)
        DATA(o_sel_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
          )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )  "
          )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( 'F' )  "
          )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( 2 )       " Row 2: Bỏ qua header
          )->get_pattern( ).

        " Đọc dữ liệu vào internal table
        lo_worksheet->select( o_sel_pattern
          )->row_stream(
          )->operation->write_to( REF #( lt_sheet_data )
          )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->execute( ).

      CATCH cx_root INTO DATA(lx_excel).
        reported-zc_masschange_product_order = VALUE #(
          ( %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = |Lỗi đọc file Excel: { lx_excel->get_text( ) }| ) )
        ).
        RETURN.
    ENDTRY.

    " Kiểm tra có dữ liệu không
    IF lt_sheet_data IS INITIAL.
      reported-zc_masschange_product_order = VALUE #(
        ( %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = 'File Excel không có dữ liệu' ) )
      ).
      RETURN.
    ENDIF.

    DATA: lw_checkdate TYPE string.
    DATA: lw_error TYPE zde_check.
    LOOP AT lt_sheet_data ASSIGNING FIELD-SYMBOL(<fs>).
      DATA(lw_index) = sy-tabix.

      <fs>-manufacturingorder = |{ <fs>-manufacturingorder ALPHA = IN }|.

      <fs>-mfgorderplannedstartdate = <fs>-mfgorderplannedstartdate .
      <fs>-mfgorderplannedenddate = <fs>-mfgorderplannedenddate .

      " YY1_MaterialName_ORD là Text (50); dài hơn thì API từ chối cả batch
      IF strlen( <fs>-yy1_materialname_ord ) > 50.
        lw_error = 'X'.
        lv_error_msg = lv_error_msg && |Dòng { lw_index + 1 }: Tên thành phẩm dài quá 50 ký tự. |.
      ENDIF.

*      lw_checkdate =  <fs>-mfgorderplannedstartdate .
*      TRY.
*          cl_abap_datfm=>conv_date_ext_to_int(
*            EXPORTING
*              im_datext   = lw_checkdate
*              im_datfmdes = '5'
*            IMPORTING
*              ex_datint   = DATA(lw_date1)
*          ).
*        CATCH cx_abap_datfm_no_date cx_abap_datfm_invalid_date cx_abap_datfm_format_unknown cx_abap_datfm_ambiguous INTO DATA(oref).
*          lw_error = 'X'.
*          lv_error_msg = lv_error_msg && |Line { lw_index }: Ngày bắt đầu Invalid!|.
*      ENDTRY.
*
*      lw_checkdate =  <fs>-mfgorderplannedenddate .
*      TRY.
*          cl_abap_datfm=>conv_date_ext_to_int(
*            EXPORTING
*              im_datext   = lw_checkdate
*              im_datfmdes = '5'
*            IMPORTING
*              ex_datint   = lw_date1
*          ).
*        CATCH cx_abap_datfm_no_date cx_abap_datfm_invalid_date cx_abap_datfm_format_unknown cx_abap_datfm_ambiguous INTO oref.
*          lw_error = 'X'.
*          lv_error_msg = lv_error_msg && |Line { lw_index }: Ngày kết thúc Invalid!|.
*      ENDTRY.

      SELECT SINGLE manufacturingorder, productionplant
    FROM i_manufacturingorder
    WHERE manufacturingorder = @<fs>-manufacturingorder
    INTO @DATA(ls_pltcheck).
      IF sy-subrc = 0.
        DATA: lv_plant TYPE werks_d,
              lv_sloc  TYPE lgort_d.

        lv_plant = ls_pltcheck-productionplant.
        AUTHORITY-CHECK OBJECT 'M_MRES_WWA'
          ID 'ACTVT' FIELD '03'
          ID 'WERKS' FIELD lv_plant.
        IF sy-subrc NE 0.
          lw_error = 'X'.
          lv_error_msg = lv_error_msg && |You are not authorization Plant { ls_pltcheck-productionplant } /  Manufacturing Order { ls_pltcheck-manufacturingorder }|.
        ENDIF.
      ENDIF.

    ENDLOOP.


    IF lw_error IS NOT INITIAL.
      APPEND VALUE #(
         %cid = key-%cid
         %msg = new_message_with_text(
         severity = if_abap_behv_message=>severity-error
         text     = |Lỗi: { lv_error_msg }|
         )
      ) TO reported-zc_masschange_product_order.

      APPEND INITIAL LINE TO failed-zc_masschange_product_order ASSIGNING FIELD-SYMBOL(<lf_failed>).
      <lf_failed>-%cid = key-%cid.
      RETURN.
    ENDIF.

    " ========================================
    " PART 2: VALIDATE VÀ CHUẨN BỊ DỮ LIỆU UPDATE
    " ========================================

    " Xóa dòng trống (nếu có)
    DELETE lt_sheet_data WHERE manufacturingorder IS INITIAL.

    " Đọc dữ liệu hiện tại từ DB để so sánh
    IF lt_sheet_data IS NOT INITIAL.
      SELECT * FROM zc_masschange_product_order
        FOR ALL ENTRIES IN @lt_sheet_data
        WHERE manufacturingorder     = @lt_sheet_data-manufacturingorder
        INTO TABLE @DATA(lt_db_data).
    ENDIF.

*   get Etag
    DATA: lt_od TYPE zcl_productionorderlongtext=>tt_productionorderlongtext.
    LOOP AT lt_sheet_data INTO DATA(ls_excel).
      APPEND INITIAL LINE TO lt_od ASSIGNING FIELD-SYMBOL(<fs_od>).
      <fs_od>-orderid = ls_excel-manufacturingorder.
    ENDLOOP.
    CALL METHOD zcl_productionorderlongtext=>get_longtext
      EXPORTING
        i_selectfield              = 'ManufacturingOrder'
      CHANGING
        ct_productionorderlongtext = lt_od.

    " Call API để update dữ liệu
    DATA: lw_username    TYPE string,
          lw_password    TYPE string,
          lv_json_header TYPE string,
          lv_json_item   TYPE string,
          lw_json_body   TYPE string,
          e_response     TYPE string,
          lv_response    TYPE string,
          lv_url         TYPE string,
          lv_url_get     TYPE string,
          e_code         TYPE i.
    DATA: lw_date  TYPE zde_date,
          lw_count TYPE int4.
    DATA: lw_count1 TYPE i.
    DATA: lw_api_str TYPE string.
    DATA: lw_thu_tu_ord TYPE string.
    DATA: lv_skipped TYPE string.

    SELECT SINGLE * FROM ztb_api_auth
      WHERE systemid = 'CASLA'
          INTO @DATA(ls_api_auth).

    lw_username = ls_api_auth-api_user.
    lw_password = ls_api_auth-api_password.

*      DATA(lw_Ngaydkxuathang) = zcl_utility=>to_json_date( iv_date = ls_ZC_CR_OD_2-ngayxuat ).
*      DATA(lw_ngaythu) = zcl_utility=>to_json_date( iv_date = ls_ZC_CR_OD_2-ngaythu ).

    lw_api_str = '/sap/opu/odata/sap/API_PRODUCTION_ORDER_2_SRV/$batch'.
    lv_url = |https://{ ls_api_auth-api_url }{ lw_api_str }|.
    TRY.
        lw_json_body =
          |--batch_123\r\n|
          && |Content-Type: multipart/mixed; boundary=changeset\r\n|
          && |Odata-Version: 2.0\r\n|
          && |Odata-MaxVersion: 2.0\r\n\r\n|.
        lw_count = 1.
        LOOP AT lt_sheet_data INTO ls_excel.
          READ TABLE lt_db_data INTO DATA(ls_db)
            WITH KEY manufacturingorder = ls_excel-manufacturingorder.
          IF sy-subrc <> 0.
            lv_skipped = lv_skipped && |{ ls_excel-manufacturingorder } (không tìm thấy lệnh); |.
            CONTINUE.
          ENDIF.
          IF ls_excel-mfgorderplannedstartdate IS INITIAL.
            ls_excel-mfgorderplannedstartdate = ls_db-mfgorderplannedstartdate.
          ENDIF.
          IF ls_excel-mfgorderplannedenddate IS INITIAL.
            ls_excel-mfgorderplannedenddate = ls_db-mfgorderplannedenddate.
          ENDIF.
          IF ls_excel-yy1_so_may_ord IS INITIAL.
            ls_excel-yy1_so_may_ord = ls_db-yy1_so_may_ord.
          ENDIF.
          IF ls_excel-yy1_thu_tu_ord IS INITIAL.
            ls_excel-yy1_thu_tu_ord = ls_db-yy1_thu_tu_ord.
          ENDIF.
**********************************************************************
*namnh214 fix 28/4
          CLEAR lw_thu_tu_ord.
          lw_thu_tu_ord = COND #( WHEN ls_excel-yy1_thu_tu_ord = '00'
                                THEN ``
                                ELSE |{ ls_excel-yy1_thu_tu_ord }| ).
**********************************************************************
          "add by hieudc7
          DATA:lv_mfgorderplannedstartdate TYPE d,
               lv_mfgorderplannedenddate   TYPE d.
          lv_mfgorderplannedstartdate = |{ ls_excel-mfgorderplannedstartdate+6(4) }{ ls_excel-mfgorderplannedstartdate+3(2) }{ ls_excel-mfgorderplannedstartdate+0(2) }|.
          lv_mfgorderplannedenddate = |{ ls_excel-mfgorderplannedenddate+6(4) }{ ls_excel-mfgorderplannedenddate+3(2) }{ ls_excel-mfgorderplannedenddate+0(2) }|.


          DATA(lw_mfgorderplannedstartdate) = zcl_utility=>to_json_date( iv_date = lv_mfgorderplannedstartdate ).
          DATA(lw_mfgorderplannedenddate) = zcl_utility=>to_json_date( iv_date = lv_mfgorderplannedenddate ).
          READ TABLE lt_od INTO DATA(ls_od)
            WITH KEY orderid = ls_excel-manufacturingorder.
          IF sy-subrc <> 0 OR ls_od-etag IS INITIAL.
            lv_skipped = lv_skipped && |{ ls_excel-manufacturingorder } (không lấy được etag); |.
            CONTINUE.
          ENDIF.
          " Escape ký tự đặc biệt (" và \) để không làm hỏng JSON của batch
          DATA(lw_materialname) = escape( val    = ls_excel-yy1_materialname_ord
                                          format = cl_abap_format=>e_json_string ).
          lw_count += 1.
          lw_json_body = lw_json_body && |--changeset\r\n| && |Content-Type: application/http\r\n|
          && |Content-Transfer-Encoding: binary\r\n|
          && |Content-ID: { lw_count } \r\n\r\n|
          && |PATCH A_ProductionOrder_2(|
          && |'{ ls_excel-manufacturingorder }') HTTP/1.1\r\n|
          && |Content-Type: application/json\r\n|
          && |If-match: { ls_od-etag } \r\n\r\n|
          && |\{ |
          && |"MfgOrderPlannedEndDate": "{ lw_mfgorderplannedenddate }",|
*          && |"MfgOrderPlannedStartDate": "{ lw_mfgorderplannedstartdate }", |
*        && |"YY1_So_May_ORD": "{ ls_excel-yy1_so_may_ord }",|
*          && |"YY1_Thu_Tu_ORD": "{ ls_excel-yy1_thu_tu_ord }"|
**********************************************************************
*namnh214 fix 28/4
          && |"MfgOrderPlannedStartDate": "{ lw_mfgorderplannedstartdate }" |
          && COND #( WHEN ls_excel-yy1_so_may_ord IS INITIAL
            THEN ``
            ELSE |,"YY1_So_May_ORD": "{ ls_excel-yy1_so_may_ord }"| )
          && COND #( WHEN lw_thu_tu_ord IS INITIAL
            THEN ``
            ELSE |,"YY1_Thu_Tu_ORD": "{ lw_thu_tu_ord }"| )
          && COND #( WHEN lw_materialname IS INITIAL
            THEN ``
            ELSE |,"YY1_MaterialName_ORD": "{ lw_materialname }"| )
***********************************************************
          && | \}|
          && |\r\n\r\n|.
        ENDLOOP.

        lw_json_body = lw_json_body && |--changeset--\r\n| && |--batch_123--|.

        DATA(lo_http_destination_batch) =
          cl_http_destination_provider=>create_by_url( lv_url ).
        DATA(lo_web_http_client_batch) =
          cl_web_http_client_manager=>create_by_http_destination( lo_http_destination_batch ).
        DATA(lo_web_http_request_batch) = lo_web_http_client_batch->get_http_request( ).
        lo_web_http_request_batch->set_header_fields( VALUE #(
           ( name = 'DataServiceVersion' value = '2.0' )
           ( name = 'Accept'             value = 'application/json' )
        ) ).

        lo_web_http_request_batch->set_authorization_basic( i_username = lw_username i_password = lw_password ).
*          lo_web_http_request->set_content_type( |application/json| ).
        lo_web_http_request_batch->set_header_field( i_name = 'Accept' i_value = 'multipart/mixed' ).
        lo_web_http_request_batch->set_content_type( |multipart/mixed; boundary=batch_123| ).
        lo_web_http_request_batch->set_header_field( i_name = 'x-csrf-token' i_value = 'Fetch' ).
        DATA(lo_response_batch) = lo_web_http_client_batch->execute( i_method = if_web_http_client=>get ).
        DATA(lv_token_batch)    = lo_response_batch->get_header_field( 'x-csrf-token' ).

        lo_web_http_request_batch->set_header_field( i_name = 'x-csrf-token' i_value = lv_token_batch ).

        lo_web_http_request_batch->set_text( lw_json_body ).
        "set request method and execute request
        DATA(lo_web_http_response) = lo_web_http_client_batch->execute( if_web_http_client=>post ).
        lv_response = lo_web_http_response->get_text( ).

        /ui2/cl_json=>deserialize(
          EXPORTING
            json = lv_response
          CHANGING
            data = e_response ).
        DATA(lv_status) = lo_web_http_response->get_status( ).
        e_code = lv_status-code.

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error.

    ENDTRY.

    SPLIT lv_response AT cl_abap_char_utilities=>newline INTO TABLE lt_lines.

    LOOP AT lt_lines INTO lv_line.
      " Kiểm tra HTTP status
      IF lv_line CS 'HTTP/1.1 400'
      OR lv_line CS 'HTTP/1.1 404'
      OR lv_line CS 'HTTP/1.1 412'
      OR lv_line CS 'HTTP/1.1 500'
      OR lv_line CS 'HTTP/1.1 422'.
        lv_success = abap_false.
      ENDIF.

      IF lv_line CS 'message'.
*          FIND REGEX 'message\s*:\s*"([^"]+)"' IN lv_line SUBMATCHES lv_error_msg.
        FIND REGEX '<message[^>]*>([^<]+)</message>'
         IN lv_line
         SUBMATCHES lv_error_msg.
      ENDIF.
    ENDLOOP.


    IF lv_success = abap_true.
      APPEND VALUE #(
       %cid = key-%cid
       %msg = new_message_with_text(
       severity = COND #( WHEN lv_skipped IS INITIAL
                          THEN if_abap_behv_message=>severity-success
                          ELSE if_abap_behv_message=>severity-warning )
       text     = COND #( WHEN lv_skipped IS INITIAL
                          THEN |Update thành công.|
                          ELSE |Các dòng không được update: { lv_skipped }| )
       )
      ) TO reported-zc_masschange_product_order.

      lv_error_msg = 'Update thành công.'.
    ELSE.
      APPEND VALUE #(
         %cid = key-%cid
         %msg = new_message_with_text(
         severity = if_abap_behv_message=>severity-error
         text     = |Lỗi: { lv_error_msg }|
         )
      ) TO reported-zc_masschange_product_order.

      APPEND INITIAL LINE TO failed-zc_masschange_product_order ASSIGNING <lf_failed>.
      <lf_failed>-%cid = key-%cid.
    ENDIF.

  ENDMETHOD.


  METHOD get_global_authorizations.
  ENDMETHOD.



  METHOD setdeliverycomplete.
    LOOP AT keys INTO DATA(k).

      MODIFY ENTITY i_productionordertp
       UPDATE FIELDS (
                    iscompletelydelivered
                  )
  WITH VALUE #(
      (
      %key-productionorder        = k-manufacturingorder
      %data-iscompletelydelivered = 'X'
      )
      )
  FAILED FINAL(failed_1)
  REPORTED FINAL(reported_1).

      IF failed_1 IS NOT INITIAL.
        APPEND VALUE #(
          %tky = k-%tky
          %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = |Lỗi khi set Delivery Completed cho { k-manufacturingorder }|
          )
        ) TO reported-zc_masschange_product_order.

        CONTINUE.
      ELSE.
        APPEND VALUE #(
         %tky = k-%tky
         %msg = new_message_with_text(
         severity = if_abap_behv_message=>severity-success
         text     = |Đã đánh dấu hoàn thành Manufacturing Order|
         )
        ) TO reported-zc_masschange_product_order.
      ENDIF.


    ENDLOOP.

  ENDMETHOD.


ENDCLASS.

CLASS lsc_zc_masschange_product_orde DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zc_masschange_product_orde IMPLEMENTATION.

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
