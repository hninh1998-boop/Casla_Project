CLASS zcl_ce_ci_text_buffer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_ci_text TYPE STANDARD TABLE OF ztb_ci_text WITH EMPTY KEY.

    CLASS-METHODS set_data
      IMPORTING
        it_data TYPE tt_ci_text.

    CLASS-METHODS get_data
      EXPORTING
        et_data TYPE tt_ci_text.

    CLASS-METHODS clear_data.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA: gt_ci_text TYPE tt_ci_text.

ENDCLASS.



CLASS zcl_ce_ci_text_buffer IMPLEMENTATION.


  METHOD set_data.
    gt_ci_text = it_data.
  ENDMETHOD.


  METHOD clear_data.
    CLEAR: gt_ci_text.
  ENDMETHOD.


  METHOD get_data.
    et_data = gt_ci_text.
  ENDMETHOD.
ENDCLASS.
