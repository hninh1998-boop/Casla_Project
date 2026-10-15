CLASS zcl_zbom_rp_line_item DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

ENDCLASS.



CLASS ZCL_ZBOM_RP_LINE_ITEM IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    " Không cần requested element nào từ DB
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lv_index TYPE i.
*    DATA: lt_professor_data TYPE STANDARD TABLE OF zc_zbom_rp WITH DEFAULT KEY.
*
*    lt_professor_data = CORRESPONDING #( it_original_data ).
*
*    LOOP AT lt_professor_data ASSIGNING FIELD-SYMBOL(<fs>).
*      lv_index += 1.
*      ASSIGN COMPONENT 'LINEITEM' OF STRUCTURE <fs> TO FIELD-SYMBOL(<lv_line>).
*      IF sy-subrc = 0.
*        <lv_line> = lv_index.
*      ENDIF.
*    ENDLOOP.
*
*    ct_calculated_data = CORRESPONDING #( lt_professor_data ).

    LOOP AT ct_calculated_data ASSIGNING FIELD-SYMBOL(<fs>).
      lv_index += 1.
      ASSIGN COMPONENT 'LINEITEM' OF STRUCTURE <fs> TO FIELD-SYMBOL(<lv_line>).
      IF sy-subrc = 0.
        <lv_line> = lv_index.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
