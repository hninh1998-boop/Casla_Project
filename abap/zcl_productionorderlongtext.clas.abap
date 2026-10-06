CLASS zcl_productionorderlongtext DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_productionorderlongtext,
             OrderID TYPE aufnr,
             text    TYPE string,
             etag TYPE string,
           END OF ty_productionorderlongtext,
           tt_productionorderlongtext TYPE STANDARD TABLE OF ty_productionorderlongtext.
    CLASS-METHODS: get_longtext
      IMPORTING
        i_selectfield TYPE string OPTIONAL
      CHANGING
        ct_productionorderlongtext TYPE tt_productionorderlongtext.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PRODUCTIONORDERLONGTEXT IMPLEMENTATION.


  METHOD get_longtext.
    TYPES: BEGIN OF ty_metadata,
             id   TYPE string,
             uri  TYPE string,
             type TYPE string,
             etag TYPE string,
           END OF ty_metadata.

    TYPES: BEGIN OF ty_result,
             __metadata         TYPE ty_metadata,
             ManufacturingOrder TYPE aufnr,
             OrderLongText      TYPE string,
           END OF ty_result.

    TYPES: ty_results TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    TYPES: BEGIN OF ty_d,
             __count TYPE string,
             results TYPE ty_results,
           END OF ty_d.

    TYPES: BEGIN OF ty_root,
             d TYPE ty_d,
           END OF ty_root.

*       DATA: ls_data TYPE ty_root.

    SELECT SINGLE * FROM ztb_api_auth
        WHERE systemid = 'CASLA'
     INTO @DATA(ls_api_auth).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA: lw_username TYPE string,
          lw_password TYPE string,
          ls_response TYPE ty_root,
          lw_selectfield TYPE string.
    lw_username = ls_api_auth-api_user.
    lw_password = ls_api_auth-api_password.

    DATA: lo_http_client TYPE REF TO if_web_http_client.
    DATA: response TYPE string.
    DATA: ls_odata_return TYPE zst_odata_return.
    DATA(lv_filter) = ``.

    LOOP AT ct_productionorderlongtext INTO DATA(ls_longtext).
      IF sy-tabix = 1.
        lv_filter = |ManufacturingOrder eq '{ ls_longtext-OrderID }'|.
      ELSE.
        lv_filter = lv_filter && | or ManufacturingOrder eq '{ ls_longtext-OrderID }'|.
      ENDIF.
    ENDLOOP.

    " Encode filter để tránh lỗi token
    DATA(lv_filter_enc) = cl_web_http_utility=>escape_url( lv_filter ).

    if i_selectfield is not initial.
      lw_selectfield = i_selectfield.
    else.
      lw_selectfield = 'ManufacturingOrder,OrderLongText'.
    endif.

    DATA(lv_url) =
      |https://{ ls_api_auth-api_url }/sap/opu/odata/sap/API_PRODUCTION_ORDER_2_SRV/A_ProductionOrder_2?|
      && |$top=5000|
      && |&$filter={ lv_filter_enc }|
      && |&$select={ lw_selectfield }|
      && |&$inlinecount=allpages|.
*    TRY.
    DATA(lo_http_destination) =
         cl_http_destination_provider=>create_by_url( lv_url ).
    "create HTTP client by destination
    DATA(lo_web_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_http_destination ) .

    "adding headers
    DATA(lo_web_http_request) = lo_web_http_client->get_http_request( ).
    lo_web_http_request->set_header_fields( VALUE #(
     (  name = 'DataServiceVersion' value = '2.0' )
    (  name = 'Accept' value = 'application/json' )
     ) ).
    lo_web_http_request->set_authorization_basic( i_username = lw_username i_password = lw_password ).
    lo_web_http_request->set_content_type( |application/json| ).
    lo_web_http_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

    DATA(lo_response) = lo_web_http_client->execute( i_method = if_web_http_client=>get ).
    DATA(lv_token)    = lo_response->get_header_field( 'x-csrf-token' ).
    lo_web_http_request->set_header_field( i_name = 'x-csrf-token' i_value = lv_token ).

    DATA(lv_response) = lo_response->get_text( ).

    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_response
      CHANGING  data = ls_response ).

    LOOP AT ls_response-d-results INTO DATA(ls_result).
*      DATA(lw_manufacturingorder) = escape( val    = ls_result-manufacturingorder
*                               format = cl_abap_format=>l_in ).
        " THÊM SỐ 0 vào đầu cho đủ 12 ký tự
      DATA(lw_manufacturingorder) = |{ ls_result-manufacturingorder  ALPHA = IN WIDTH = 12 }|.

      READ TABLE ct_productionorderlongtext ASSIGNING FIELD-SYMBOL(<ls_longtext_entry>)
        WITH KEY OrderID = lw_manufacturingorder.
      IF sy-subrc = 0.
        <ls_longtext_entry>-text = ls_result-OrderLongText.
        <ls_longtext_entry>-etag = ls_result-__metadata-etag.
      ENDIF.
    ENDLOOP.
*      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error.
*        DATA(lw_error) = sy-msgid && sy-msgno && sy-msgty && sy-msgv1 && sy-msgv2 && sy-msgv3 && sy-msgv4.
    "error handling
*    ENDTRY.
  ENDMETHOD.
ENDCLASS.
