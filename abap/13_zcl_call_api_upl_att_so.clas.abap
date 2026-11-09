CLASS zcl_call_api_upl_att_so DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_result,
             ok         TYPE abap_bool,
             doc_number TYPE string,
             message    TYPE string,
           END OF ty_result.

    "! Gắn 1 file vào Sales Order:
    "! 1. Client riêng: GET GetAllOriginals -> check SO đã có file cùng tên chưa
    "! 2. Client mới  : GET service root (fetch CSRF token) -> POST AttachmentContentSet (Slug = tên file)
    "!    Tách client vì query string của GET (…?BusinessObjectTypeName…&$format=json) bị giữ lại
    "!    trong request -> POST lỗi "SystemQueryOptions that are not allowed for this Request Type"
    CLASS-METHODS upload_attachment
      IMPORTING iv_sales_order   TYPE clike
                iv_file_name     TYPE string
                iv_mime_type     TYPE string
                iv_content       TYPE xstring
      RETURNING VALUE(rs_result) TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_service_root TYPE string VALUE `/sap/opu/odata/sap/API_CV_ATTACHMENT_SRV/`.
    CONSTANTS c_bo_type      TYPE string VALUE `BUS2032`.

    " --- JSON GetAllOriginals: {"d":{"results":[{ "FileName": ... }]}}
    TYPES: BEGIN OF ty_original,
             filename TYPE string,
           END OF ty_original,
           tt_original TYPE STANDARD TABLE OF ty_original WITH EMPTY KEY,
           BEGIN OF ty_originals_d,
             results TYPE tt_original,
           END OF ty_originals_d,
           BEGIN OF ty_originals,
             d TYPE ty_originals_d,
           END OF ty_originals.

    " --- JSON POST response: {"d":{"DocumentInfoRecordDocNumber": ...}}
    TYPES: BEGIN OF ty_created_d,
             documentinforecorddocnumber TYPE string,
             filename                    TYPE string,
           END OF ty_created_d,
           BEGIN OF ty_created,
             d TYPE ty_created_d,
           END OF ty_created.

    " --- JSON lỗi OData V2
    TYPES: BEGIN OF ty_error_message,
             value TYPE string,
           END OF ty_error_message,
           BEGIN OF ty_error_detail_item,
             code     TYPE string,
             message  TYPE string,
             severity TYPE string,
           END OF ty_error_detail_item,
           tt_error_detail_item TYPE STANDARD TABLE OF ty_error_detail_item WITH EMPTY KEY,
           BEGIN OF ty_inner_error,
             errordetails TYPE tt_error_detail_item,
           END OF ty_inner_error,
           BEGIN OF ty_error_v2_detail,
             code       TYPE string,
             message    TYPE ty_error_message,
             innererror TYPE ty_inner_error,
           END OF ty_error_v2_detail,
           BEGIN OF ty_error_v2_response,
             error TYPE ty_error_v2_detail,
           END OF ty_error_v2_response.

    CLASS-METHODS create_client
      EXPORTING eo_client     TYPE REF TO if_web_http_client
                ev_message    TYPE string
      RETURNING VALUE(rv_ok)  TYPE abap_bool.

    "! Danh sách tên file đang gắn trên SO (GetAllOriginals)
    CLASS-METHODS get_file_names
      IMPORTING iv_so_key        TYPE clike
      EXPORTING et_file_names    TYPE string_table
                ev_message       TYPE string
      RETURNING VALUE(rv_ok)     TYPE abap_bool.

    CLASS-METHODS close_client
      IMPORTING io_client TYPE REF TO if_web_http_client.

    CLASS-METHODS error_text
      IMPORTING iv_response       TYPE string
      RETURNING VALUE(rv_message) TYPE string.
ENDCLASS.



CLASS zcl_call_api_upl_att_so IMPLEMENTATION.

  METHOD upload_attachment.
    DATA lo_client     TYPE REF TO if_web_http_client.
    DATA lv_so         TYPE c LENGTH 10.
    DATA lt_file_names TYPE string_table.
    DATA ls_created    TYPE ty_created.

    lv_so = iv_sales_order.
    lv_so = |{ lv_so ALPHA = IN }|.        " LinkedSAPObjectKey: đủ 10 ký tự
    DATA(lv_so_out) = |{ lv_so ALPHA = OUT }|.

    " 1. SO đã có file cùng tên -> không post trùng
    IF get_file_names( EXPORTING iv_so_key     = lv_so
                       IMPORTING et_file_names = lt_file_names
                                 ev_message    = rs_result-message ) = abap_false.
      RETURN.
    ENDIF.

    IF line_exists( lt_file_names[ table_line = iv_file_name ] ).
      rs_result-message = |SO { lv_so_out } đã có file { iv_file_name }, không post trùng|.
      RETURN.
    ENDIF.

    " 2. Client mới: fetch CSRF token + POST trên cùng session cookie
    IF create_client( IMPORTING eo_client  = lo_client
                                ev_message = rs_result-message ) = abap_false.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( i_uri_path = c_service_root ).
        lo_request->set_header_field( i_name = 'x-csrf-token' i_value = 'fetch' ).

        DATA(lo_fetch)      = lo_client->execute( i_method = if_web_http_client=>get ).
        DATA(lv_fetch_code) = lo_fetch->get_status( )-code.
        DATA(lv_token)      = lo_fetch->get_header_field( i_name = 'x-csrf-token' ).

        IF lv_fetch_code <> 200 OR lv_token IS INITIAL.
          rs_result-message = |Không lấy được CSRF token - HTTP { lv_fetch_code }: | &&
                              |{ error_text( lo_fetch->get_text( ) ) }|.
        ELSE.
          lo_request->set_uri_path( i_uri_path = |{ c_service_root }AttachmentContentSet| ).
          lo_request->set_header_field( i_name = 'x-csrf-token'           i_value = lv_token ).
          lo_request->set_header_field( i_name = 'Slug'                   i_value = iv_file_name ).
          lo_request->set_header_field( i_name = 'BusinessObjectTypeName' i_value = c_bo_type ).
          lo_request->set_header_field( i_name = 'LinkedSAPObjectKey'     i_value = CONV #( lv_so ) ).
          lo_request->set_content_type( iv_mime_type ).
          lo_request->set_binary( iv_content ).

          DATA(lo_post)      = lo_client->execute( i_method = if_web_http_client=>post ).
          DATA(lv_post_code) = lo_post->get_status( )-code.
          DATA(lv_post_body) = lo_post->get_text( ).

          IF lv_post_code = 201 OR lv_post_code = 200.
            /ui2/cl_json=>deserialize( EXPORTING json = lv_post_body
                                       CHANGING  data = ls_created ).
            rs_result-ok         = abap_true.
            rs_result-doc_number = ls_created-d-documentinforecorddocnumber.
            rs_result-message    = |Đã gắn file vào SO { lv_so_out } | &&
                                   |(Doc. No. { rs_result-doc_number })|.
          ELSE.
            rs_result-message = |Post file lỗi - HTTP { lv_post_code }: { error_text( lv_post_body ) }|.
          ENDIF.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        rs_result-ok      = abap_false.
        rs_result-message = |Lỗi gọi API: { lx_error->get_text( ) }|.
    ENDTRY.

    close_client( lo_client ).
  ENDMETHOD.


  METHOD get_file_names.
    DATA lo_client    TYPE REF TO if_web_http_client.
    DATA ls_originals TYPE ty_originals.

    CLEAR: et_file_names, ev_message.

    IF create_client( IMPORTING eo_client  = lo_client
                                ev_message = ev_message ) = abap_false.
      RETURN.
    ENDIF.

    TRY.
        lo_client->get_http_request( )->set_uri_path(
          i_uri_path = |{ c_service_root }GetAllOriginals| &&
                       |?BusinessObjectTypeName='{ c_bo_type }'| &&
                       |&LinkedSAPObjectKey='{ iv_so_key }'&$format=json| ).

        DATA(lo_get)  = lo_client->execute( i_method = if_web_http_client=>get ).
        DATA(lv_code) = lo_get->get_status( )-code.
        DATA(lv_body) = lo_get->get_text( ).

        IF lv_code = 200.
          /ui2/cl_json=>deserialize( EXPORTING json = lv_body
                                     CHANGING  data = ls_originals ).
          et_file_names = VALUE #( FOR ls_original IN ls_originals-d-results ( ls_original-filename ) ).
          rv_ok = abap_true.
        ELSE.
          ev_message = |Đọc file đính kèm của SO { iv_so_key ALPHA = OUT } lỗi - HTTP { lv_code }: | &&
                       |{ error_text( lv_body ) }|.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        ev_message = |Lỗi gọi API GetAllOriginals: { lx_error->get_text( ) }|.
    ENDTRY.

    close_client( lo_client ).
  ENDMETHOD.


  METHOD close_client.
    IF io_client IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        io_client->close( ).
      CATCH cx_web_http_client_error ##NO_HANDLER.
        " Không ảnh hưởng kết quả đã post
    ENDTRY.
  ENDMETHOD.


  METHOD create_client.
    CLEAR: eo_client, ev_message.

    TRY.
        " Giữ convention của team: <tenant>.s4hana.cloud.sap -> <tenant>-api.s4hana.cloud.sap
        DATA(lv_host) = cl_abap_context_info=>get_system_url( ).
        SPLIT lv_host AT '.' INTO DATA(lv_tenant) DATA(lv_suffix).

        SELECT SINGLE api_user, api_password
          FROM ztb_api_auth
          INTO @DATA(ls_auth).
        IF sy-subrc <> 0.
          ev_message = `Chưa cấu hình user gọi API trong bảng ZTB_API_AUTH`.
          RETURN.
        ENDIF.

        DATA(lo_destination) = cl_http_destination_provider=>create_by_url(
                                 i_url = |https://{ lv_tenant }-api.{ lv_suffix }| ).
        eo_client = cl_web_http_client_manager=>create_by_http_destination( i_destination = lo_destination ).
        eo_client->accept_cookies( i_allow = abap_true ).

        DATA(lo_request) = eo_client->get_http_request( ).
        lo_request->set_authorization_basic( i_username = CONV string( ls_auth-api_user )
                                             i_password = CONV string( ls_auth-api_password ) ).
        lo_request->set_version( version = if_web_http_request=>co_protocol_version_1_1 ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

        rv_ok = abap_true.

      CATCH cx_root INTO DATA(lx_error).
        ev_message = |Không tạo được kết nối API: { lx_error->get_text( ) }|.
        rv_ok = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD error_text.
    IF iv_response IS INITIAL.
      rv_message = `API không trả về nội dung`.
      RETURN.
    ENDIF.

    " Lỗi OData V2: chi tiết nằm ở innererror-errordetails, message ngoài thường chung chung
    TRY.
        DATA(ls_error) = VALUE ty_error_v2_response( ).
        /ui2/cl_json=>deserialize( EXPORTING json = iv_response
                                   CHANGING  data = ls_error ).

        DATA lt_details TYPE string_table.
        LOOP AT ls_error-error-innererror-errordetails INTO DATA(ls_detail)
             WHERE message IS NOT INITIAL.
          APPEND |[{ ls_detail-code }] { ls_detail-message }| TO lt_details.
        ENDLOOP.

        IF lt_details IS NOT INITIAL.
          rv_message = concat_lines_of( table = lt_details sep = ` | ` ).
          RETURN.
        ENDIF.

        IF ls_error-error-message-value IS NOT INITIAL.
          rv_message = |[{ ls_error-error-code }] { ls_error-error-message-value }|.
          RETURN.
        ENDIF.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    rv_message = iv_response.
  ENDMETHOD.

ENDCLASS.
