CLASS zcl_zbom_buffer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES tt_zbom TYPE STANDARD TABLE OF ztb_zbom_explode WITH DEFAULT KEY.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_instance) TYPE REF TO zcl_zbom_buffer.

    CLASS-METHODS set_buffer
      IMPORTING it_data TYPE tt_zbom.

    CLASS-METHODS get_buffer
      RETURNING VALUE(rt_data) TYPE tt_zbom.

    CLASS-METHODS clear_buffer.

    CLASS-METHODS update_to_db
      RETURNING VALUE(rv_subrc) TYPE sysubrc.
  PROTECTED SECTION.

  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO zcl_zbom_buffer.
    CLASS-DATA mt_buffer TYPE tt_zbom.
ENDCLASS.



CLASS ZCL_ZBOM_BUFFER IMPLEMENTATION.


  METHOD get_instance.
    IF go_instance IS NOT BOUND.
      CREATE OBJECT go_instance.
    ENDIF.
    ro_instance = go_instance.
  ENDMETHOD.


  METHOD set_buffer.
    mt_buffer = it_data.
  ENDMETHOD.


  METHOD get_buffer.
    rt_data = mt_buffer.
  ENDMETHOD.


  METHOD clear_buffer.
    CLEAR mt_buffer.
  ENDMETHOD.


  METHOD update_to_db.
    IF mt_buffer IS INITIAL.
      rv_subrc = 4.
      RETURN.
    ENDIF.

    MODIFY ztb_zbom_explode FROM TABLE @mt_buffer.
    rv_subrc = sy-subrc.

    IF rv_subrc = 0.

    ENDIF.
  ENDMETHOD.
ENDCLASS.
