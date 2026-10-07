CLASS zcl_ce_cont_text_buffer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_cont_text TYPE STANDARD TABLE OF ztb_cont_text.

    CLASS-METHODS set_data
      IMPORTING
        it_data TYPE tt_cont_text.

    CLASS-METHODS get_data
      EXPORTING
        et_data TYPE tt_cont_text.

    CLASS-METHODS clear_data.


  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA: gt_cont_text TYPE tt_cont_text.

ENDCLASS.



CLASS ZCL_CE_CONT_TEXT_BUFFER IMPLEMENTATION.


  METHOD set_data.
    gt_cont_text = it_data.
  ENDMETHOD.


  METHOD clear_data.
    CLEAR: gt_cont_text.
  ENDMETHOD.


  METHOD get_data.
    et_data = gt_cont_text.
  ENDMETHOD.
ENDCLASS.
