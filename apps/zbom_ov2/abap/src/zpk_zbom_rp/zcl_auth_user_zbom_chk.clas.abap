CLASS zcl_auth_user_zbom_chk DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_AUTH_USER_ZBOM_CHK IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DELETE FROM ztb_zbom_auth.

    INSERT ztb_zbom_auth FROM @( VALUE #(
      uname = 'CB9980000130'
*      edit_allowed = abap_true
*      delete_allowed = abap_true
*      add_allowed = ABAP_false
    ) ).

    COMMIT WORK AND WAIT.
  ENDMETHOD.
ENDCLASS.
