CLASS lhc_ZBOMHeader DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR ZBOMHeader RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ ZBOMHeader RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK ZBOMHeader.

    METHODS rba_Item FOR READ
      IMPORTING keys_rba FOR READ ZBOMHeader\_Item FULL result_requested RESULT result LINK association_links.

    METHODS cba_Item FOR MODIFY
      IMPORTING entities_cba FOR CREATE ZBOMHeader\_Item.

    METHODS detailViewList FOR MODIFY
      IMPORTING keys FOR ACTION ZBOMHeader~detailViewList RESULT result.

    METHODS scheduleExcelExport FOR MODIFY
      IMPORTING keys FOR ACTION ZBOMHeader~scheduleExcelExport.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ZBOMHeader RESULT result.

ENDCLASS.

CLASS lhc_ZBOMHeader IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-scheduleExcelExport = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZBOM_EXP'
        ID 'ACTVT'    FIELD '16'
        ID 'ZBOMFUNC' FIELD 'EXPORT'.

      result-%action-scheduleExcelExport = COND #(
        WHEN sy-subrc = 0
        THEN if_abap_behv=>auth-allowed
        ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD rba_Item.
  ENDMETHOD.

  METHOD cba_Item.
  ENDMETHOD.

  METHOD detailViewList.
  ENDMETHOD.


  METHOD scheduleExcelExport.
    " Quyền đã check ở get_global_authorizations (object ZBOM_EXP).
    " FilterRanges: mỗi range 5 field ngăn bởi '|', các range ngăn bởi ';':
    " FieldName|Sign|Option|Low|High.
    " Ở đây chỉ lưu bộ lọc; việc chọn header do job làm qua
    " zcl_zbom_export_sel, nên UI không phải chờ tải header.
    DATA ls_request TYPE zcl_zbom_export_buffer=>ty_export_request.

    LOOP AT keys INTO DATA(ls_key).
      ls_request-search_text = ls_key-%param-SearchString.

      SPLIT ls_key-%param-FilterRanges AT ';' INTO TABLE DATA(lt_rows).
      LOOP AT lt_rows INTO DATA(lv_row).
        IF lv_row IS INITIAL.
          CONTINUE.
        ENDIF.

        SPLIT lv_row AT '|' INTO TABLE DATA(lt_fields).

        " Range không có 'high' thì đoạn rỗng cuối bị mất, nên chỉ đòi
        " 4 field đầu (field/sign/option/low) rồi bù cho đủ 5.
        IF lines( lt_fields ) < 4.
          CONTINUE.
        ENDIF.
        WHILE lines( lt_fields ) < 5.
          APPEND `` TO lt_fields.
        ENDWHILE.

        APPEND VALUE #( field_name = lt_fields[ 1 ]
                        sign       = lt_fields[ 2 ]
                        option     = lt_fields[ 3 ]
                        low        = lt_fields[ 4 ]
                        high       = lt_fields[ 5 ] ) TO ls_request-ranges.

        IF to_upper( CONV string( lt_fields[ 1 ] ) ) = 'BILLOFMATERIALCATEGORY'.
          ls_request-bomcategory = lt_fields[ 4 ].
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    zcl_zbom_export_buffer=>set_request( ls_request ).
  ENDMETHOD.




ENDCLASS.

CLASS lhc_ZBOMItem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS read FOR READ
      IMPORTING keys FOR READ ZBOMItem RESULT result.

    METHODS rba_Header FOR READ
      IMPORTING keys_rba FOR READ ZBOMItem\_Header FULL result_requested RESULT result LINK association_links.

ENDCLASS.

CLASS lhc_ZBOMItem IMPLEMENTATION.

  METHOD read.
  ENDMETHOD.

  METHOD rba_Header.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZCE_ZBOM_HEADER DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZCE_ZBOM_HEADER IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    DATA(lv_sysubrc) = zcl_zbom_buffer=>update_to_db( ).   " dòng cũ, giữ nguyên

    zcl_zbom_export_buffer=>schedule_pending_jobs(
      IMPORTING
        ev_error      = DATA(lv_error)
        ev_error_text = DATA(lv_error_text)
    ).
    " save() 'must not fail' và không có failed/reported dùng được cho
    " ZBOMHeader -> không báo lỗi lên UI được từ đây. lv_error/lv_error_text
    " chỉ để debug/log (TODO: ghi Application Log).
  ENDMETHOD.

  METHOD cleanup.
    zcl_zbom_export_buffer=>clear_buffer( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.


