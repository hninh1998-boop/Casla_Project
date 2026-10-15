CLASS zcl_call_api_kbom_rp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-DATA : code TYPE i.
    CLASS-DATA: reason TYPE string.
    CLASS-METHODS: call_api
      IMPORTING
        iv_body          TYPE string OPTIONAL
        iv_endpoint      TYPE string
        iv_method        TYPE string
      RETURNING
        VALUE(rv_result) TYPE string.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CALL_API_KBOM_RP IMPLEMENTATION.


  METHOD call_api.
    DATA: lv_url  TYPE string,
          lv_pref TYPE string.

    TRY.
        DATA(lv_host) = cl_abap_context_info=>get_system_url( ).
        SPLIT lv_host AT '.' INTO lv_host lv_pref.
        CONCATENATE lv_host `-api` `.` lv_pref INTO lv_host.
      CATCH cx_abap_context_info_error.
    ENDTRY.

    lv_url = |https://{ lv_host }{ iv_endpoint }|.
    TRY.
        DATA(lo_http_destination) = cl_http_destination_provider=>create_by_url( i_url = lv_url ).
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( i_destination = lo_http_destination ).

        lo_http_client->get_http_request( )->set_header_fields( VALUE #(
          ( name = 'Accept' value = 'application/json' )
          ( name = 'x-csrf-token' value = 'fetch' )
          ( name = 'DataServiceVersion' value = '2.0' )
          ( name = 'config_authType'    value = 'Basic' )
        ) ).

        DATA: lv_username TYPE string,
              lv_password TYPE string.

        SELECT SINGLE * FROM ztb_api_auth INTO @DATA(ls_api_auth).
        IF sy-subrc EQ 0.
          lv_username = ls_api_auth-api_user.
          lv_password = ls_api_auth-api_password.
        ENDIF.

        lo_http_client->get_http_request( )->set_header_field(
            i_name = 'username'
            i_value = lv_username ).
        lo_http_client->get_http_request( )->set_header_field(
            i_name = 'password'
            i_value = lv_password ).
        lo_http_client->get_http_request( )->set_authorization_basic(
            i_username = lv_username
            i_password = lv_password ).
        lo_http_client->get_http_request( )->set_version(
            version = if_web_http_request=>co_protocol_version_1_1 ).

        DATA(lo_web_http_response) = lo_http_client->execute( if_web_http_client=>get ).
        DATA(xcrsf_token) = lo_web_http_response->get_header_field( i_name = 'x-csrf-token' ).

        DATA(lv_response) = lo_web_http_response->get_text( ).

        IF xcrsf_token IS NOT INITIAL.
          lo_http_client->get_http_request( )->set_header_field(
            i_name = 'x-csrf-token'
            i_value = xcrsf_token ).
        ENDIF.

        "*-- Set body & headers
        lo_http_client->get_http_request( )->set_text( iv_body ).
        lo_http_client->get_http_request( )->set_header_field(
            i_name = 'Accept'
            i_value = 'application/json' ).
        lo_http_client->get_http_request( )->set_header_field(
            i_name = 'Content-Type'
            i_value = 'application/json' ).

        IF iv_method = 'PATCH' OR iv_method = 'DELETE'.
          lo_http_client->get_http_request( )->set_header_field( i_name = 'If-Match' i_value = '*' ).
        ENDIF.

        "*-- Execute
        DATA(lo_response) = SWITCH #( iv_method
          WHEN 'POST'   THEN lo_http_client->execute( if_web_http_client=>post )
          WHEN 'PUT'    THEN lo_http_client->execute( if_web_http_client=>put )
          WHEN 'PATCH'  THEN lo_http_client->execute( if_web_http_client=>patch )
          WHEN 'DELETE' THEN lo_http_client->execute( if_web_http_client=>delete )
          ELSE               lo_http_client->execute( if_web_http_client=>get ) ).

        code   = lo_response->get_status( )-code.
        reason = lo_response->get_status( )-reason.
        DATA(lv_body) = lo_response->get_text( ).

      CATCH cx_root INTO DATA(lx_exception).
    ENDTRY.

    rv_result = COND #( WHEN lv_body IS NOT INITIAL THEN lv_body ELSE `` ).

  ENDMETHOD.
ENDCLASS.
