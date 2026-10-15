CLASS lhc_ZI_ZBOM_AUTH DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_zbom_auth RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_zbom_auth RESULT result.

    METHODS CheckAuth FOR MODIFY
      IMPORTING keys FOR ACTION zi_zbom_auth~CheckAuth RESULT result.

ENDCLASS.

CLASS lhc_ZI_ZBOM_AUTH IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
*  AUTHORITY-CHECK OBJECT 'ZBOM_MASS'
*    ID 'ACTVT' FIELD '02'.
*  DATA(lv_edit) = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
*                           ELSE if_abap_behv=>auth-unauthorized ).
*
*  AUTHORITY-CHECK OBJECT 'ZBOM_MASS'
*    ID 'ACTVT' FIELD '06'.
*  DATA(lv_delete) = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
*                              ELSE if_abap_behv=>auth-unauthorized ).
*
*  AUTHORITY-CHECK OBJECT 'ZBOM_MASS'
*    ID 'ACTVT' FIELD '01'.
*  DATA(lv_add) = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
*                           ELSE if_abap_behv=>auth-unauthorized ).
*
*  result = VALUE #(
*    %action-EditMassChange   = lv_edit
*    %action-DeleteMassChange = lv_delete
*    %action-AddMassChange    = lv_add
*    %action-MassChange       = lv_add
*  ).
  ENDMETHOD.

  METHOD CheckAuth.
*    SELECT SINGLE edit_allowed, delete_allowed, add_allowed
*      FROM ztb_zbom_auth
*      WHERE uname = @sy-uname
*      INTO @DATA(ls_auth).
*
*    IF sy-subrc <> 0.
*      " User không có trong bảng → không có quyền gì
*      ls_auth = VALUE #( edit_allowed = abap_false
*                         delete_allowed = abap_false
*                         add_allowed = abap_false ).
*    ENDIF.
*
*    APPEND VALUE #(
*      %cid   = keys[ 1 ]-%cid
*      %param = VALUE #(
*        EditAllowed   = ls_auth-edit_allowed
*        DeleteAllowed = ls_auth-delete_allowed
*        AddAllowed    = ls_auth-add_allowed
*      )
*    ) TO result.
  ENDMETHOD.

ENDCLASS.
