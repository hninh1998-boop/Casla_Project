CLASS zcl_cont_sortorder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.



CLASS ZCL_CONT_SORTORDER IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    " Không filter -> lấy toàn bộ data mọi Plant
    DATA(lt_filters) = VALUE if_rap_query_filter=>tt_name_range_pairs( ).

    zcl_ce_cont_f01=>main(
      EXPORTING
        it_filters = lt_filters
      IMPORTING
        et_result  = DATA(lt_result)
    ).

    IF lt_result IS INITIAL.
      out->write( 'Không có dữ liệu.' ).
      RETURN.
    ENDIF.

    " Sắp theo đúng thứ tự mặc định hiện tại (khi SortOrder đang = 0 hết) để gán
    " SortOrder ban đầu khớp với thứ tự đang hiển thị, tránh xáo trộn bất ngờ.
    SORT lt_result BY SoCont DESCENDING
                      SoChi DESCENDING
                      Cont DESCENDING
                      SoLenhXuatHang DESCENDING
                      SoLenhXuatHangItem
                      so
                      soitem.

    DATA lt_existing TYPE STANDARD TABLE OF ztb_cont_text.
    SELECT * FROM ztb_cont_text INTO TABLE @lt_existing.

    DATA lt_upsert TYPE STANDARD TABLE OF ztb_cont_text.
    LOOP AT lt_result INTO DATA(ls_row).
      DATA(lv_tabix) = sy-tabix.

      READ TABLE lt_existing INTO DATA(ls_ex)
        WITH KEY so = ls_row-so so_item = ls_row-SOItem
                 so_lenh = ls_row-SoLenhXuatHang so_lenh_item = ls_row-SoLenhXuatHangItem.

      APPEND INITIAL LINE TO lt_upsert ASSIGNING FIELD-SYMBOL(<fs>).
      IF sy-subrc = 0.
        <fs> = ls_ex. " dòng đã tồn tại -> giữ nguyên field khác, chỉ đổi sort_order
      ELSE.
        <fs>-client       = sy-mandt.
        <fs>-so           = ls_row-so.
        <fs>-so_item      = ls_row-SOItem.
        <fs>-so_lenh      = ls_row-SoLenhXuatHang.
        <fs>-so_lenh_item = ls_row-SoLenhXuatHangItem.
      ENDIF.
      <fs>-sort_order = lv_tabix * 1000.
      <fs>-changed_by = sy-uname.
      <fs>-changed_at = utclong_current( ).
    ENDLOOP.

    MODIFY ztb_cont_text FROM TABLE @lt_upsert.
    IF sy-subrc = 0.
      COMMIT WORK AND WAIT.
      out->write( |Đã seed SortOrder cho { lines( lt_upsert ) } dòng (toàn bộ Plant)| ).
    ELSE.
      ROLLBACK WORK.
      out->write( 'MODIFY thất bại' ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
