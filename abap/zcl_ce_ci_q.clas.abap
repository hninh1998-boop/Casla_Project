CLASS zcl_ce_ci_q DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    " Query cho màn hình ngoài (zce_ci_h) và màn hình chi tiết (zce_ci_i)
    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.

    " Lọc theo range của các key (đọc 1 dòng sau khi Save, hoặc filter trên bảng)
    CLASS-METHODS filter_items
      IMPORTING it_filters TYPE if_rap_query_filter=>tt_name_range_pairs
      CHANGING  ct_items   TYPE zcl_ce_ci_f01=>tt_item.

    " Sort + paging + count dùng chung cho cả 2 entity
    CLASS-METHODS respond
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
      CHANGING  ct_data     TYPE STANDARD TABLE.
ENDCLASS.



CLASS zcl_ce_ci_q IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    DATA lt_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    TRY.
        lt_filters = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filters.
    ENDTRY.

    CASE io_request->get_entity_id( ).
      WHEN 'ZCE_CI_H'.
        DATA(lt_headers) = zcl_ce_ci_f01=>get_headers( lt_filters ).
        respond( EXPORTING io_request  = io_request
                           io_response = io_response
                 CHANGING  ct_data     = lt_headers ).

      WHEN 'ZCE_CI_I'.
        " Màn hình chi tiết luôn đi từ 1 (hoặc vài) Pro-forma invoice
        DATA lr_proformainvoice TYPE zcl_ce_ci_top=>ry_string.
        READ TABLE lt_filters INTO DATA(ls_filter) WITH KEY name = 'PROFORMAINVOICE'.
        IF sy-subrc = 0.
          lr_proformainvoice = CORRESPONDING #( ls_filter-range ).
        ENDIF.

        DATA lt_items TYPE zcl_ce_ci_f01=>tt_item.
        IF lr_proformainvoice IS NOT INITIAL.
          lt_items = zcl_ce_ci_f01=>get_items( lr_proformainvoice ).
          filter_items( EXPORTING it_filters = lt_filters
                        CHANGING  ct_items   = lt_items ).
        ENDIF.

        respond( EXPORTING io_request  = io_request
                           io_response = io_response
                 CHANGING  ct_data     = lt_items ).
    ENDCASE.

  ENDMETHOD.


  METHOD filter_items.

    LOOP AT it_filters INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'BILLINGITEM'.
          DATA(lr_item) = CORRESPONDING zcl_ce_ci_top=>ry_string( ls_filter-range ).
          DELETE ct_items WHERE BillingItem NOT IN lr_item.
        WHEN 'BATCH'.
          DATA(lr_batch) = CORRESPONDING zcl_ce_ci_top=>ry_string( ls_filter-range ).
          DELETE ct_items WHERE Batch NOT IN lr_batch.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD respond.

    DATA(lv_total) = lines( ct_data ).

    " RAP bắt buộc provider phải đọc sort / paging khi request có yêu cầu → luôn đọc trước
    DATA(lt_sort)  = io_request->get_sort_elements( ).
    DATA(lv_skip)  = io_request->get_paging( )->get_offset( ).
    DATA(lv_top)   = io_request->get_paging( )->get_page_size( ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( CONV int8( lv_total ) ).
    ENDIF.

    IF NOT io_request->is_data_requested( ).
      RETURN.
    ENDIF.

    " Sort
    DATA lt_sort_order TYPE abap_sortorder_tab.
    LOOP AT lt_sort INTO DATA(ls_sort).
      APPEND VALUE #( name       = ls_sort-element_name
                      descending = ls_sort-descending ) TO lt_sort_order.
    ENDLOOP.
    IF lt_sort_order IS NOT INITIAL.
      SORT ct_data BY (lt_sort_order).
    ENDIF.

    " Paging
    IF lv_top = if_rap_query_paging=>page_size_unlimited.
      lv_top = lv_total.
    ENDIF.

    IF lv_skip > 0.
      DELETE ct_data TO lv_skip.
    ENDIF.
    IF lv_top < lines( ct_data ).
      DELETE ct_data FROM lv_top + 1.
    ENDIF.

    io_response->set_data( ct_data ).

  ENDMETHOD.
ENDCLASS.
