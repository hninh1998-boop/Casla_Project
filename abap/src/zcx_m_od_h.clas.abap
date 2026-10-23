CLASS zcx_m_od_h DEFINITION PUBLIC INHERITING FROM cx_no_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA text TYPE string READ-ONLY.
    METHODS constructor IMPORTING text TYPE string.
ENDCLASS.



CLASS ZCX_M_OD_H IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( ).
    me->text = text.
  ENDMETHOD.
ENDCLASS.
