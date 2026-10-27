CLASS lhc_ManageFileOD DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In process
      END OF file_status.

    " Thứ tự cột của template upload (dòng 1 = header, dòng 2 = hướng dẫn, dữ liệu từ dòng 3)
    TYPES: BEGIN OF ty_file_upload,
             SoThung  TYPE string,
             Delivery TYPE string,
           END OF ty_file_upload.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ManageFileOD RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ManageFileOD.

    METHODS downloadTemplateOD FOR MODIFY
      IMPORTING keys FOR ACTION ManageFileOD~downloadTemplateOD.

    METHODS uploadExcelOD FOR MODIFY
      IMPORTING keys FOR ACTION ManageFileOD~uploadExcelOD.

    METHODS setStatusToOpenOD FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ManageFileOD~setStatusToOpenOD.

    METHODS getExcelDataOD FOR DETERMINE ON SAVE
      IMPORTING keys FOR ManageFileOD~getExcelDataOD.

ENDCLASS.

CLASS lhc_ManageFileOD IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


  METHOD earlynumbering_create.
    LOOP AT entities
               ASSIGNING FIELD-SYMBOL(<f_entities>)
               WHERE uuid IS NOT INITIAL.

      APPEND CORRESPONDING #( <f_entities> ) TO mapped-managefileod.

    ENDLOOP.

    DATA(lt_file) = entities.

    DELETE lt_file WHERE uuid IS NOT INITIAL.

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.


    LOOP AT lt_file ASSIGNING <f_entities>.

      TRY.
          <f_entities>-uuid = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
        CATCH cx_uuid_error.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft
          )
                 TO reported-managefileod.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft )
                 TO failed-managefileod.

          EXIT.
      ENDTRY.

      APPEND VALUE #( %cid      = <f_entities>-%cid
                      %key      = <f_entities>-%key
                      %is_draft = <f_entities>-%is_draft )
       TO mapped-managefileod.
    ENDLOOP.
  ENDMETHOD.


  METHOD downloadTemplateOD.
    " Template được sinh ở frontend (ExcelJS) sau khi action chạy xong
  ENDMETHOD.


  METHOD uploadExcelOD.
    DATA lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_mn_file TYPE TABLE FOR CREATE zi_m_od,
          ls_mn_file LIKE LINE OF lt_mn_file.

    READ TABLE keys ASSIGNING FIELD-SYMBOL(<k>) INDEX 1.

    CHECK sy-subrc = 0.

    IF <k>-%param-filecontent IS INITIAL.
      RETURN.
    ENDIF.

    ls_mn_file-attachment = <k>-%param-filecontent.
    ls_mn_file-filename   = <k>-%param-filename.
    ls_mn_file-mimetype   = <k>-%param-mimetype.

    FINAL(lv_filecontent) = <k>-%param-filecontent.

    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = lv_filecontent )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_file ) ).

    lo_execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
               )->if_xco_xlsx_ra_operation~execute( ).

    IF lt_file IS NOT INITIAL.
      DELETE lt_file INDEX 1. "Delete Line 1
      DELETE lt_file INDEX 1. "Delete Line 2
    ENDIF.

    ls_mn_file-Countline = lines( lt_file ).
    APPEND ls_mn_file TO lt_mn_file.

    MODIFY ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY ManageFileOD
      CREATE AUTO FILL CID FIELDS (
                        status
                        attachment
                        mimetype
                        filename
                        countline
                        createdbyuser
                        createddate
                        changedbyuser
                        changeddate
                      ) WITH lt_mn_file
      MAPPED DATA(lt_mapped_create)
      REPORTED DATA(lt_reported_create)
      FAILED DATA(lt_failed_create).
  ENDMETHOD.


  METHOD setStatusToOpenOD.
    READ ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY ManageFileOD
        FIELDS ( status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file).

    "If Status is already set, do nothing
    DELETE lt_file WHERE status IS NOT INITIAL.

    CHECK lt_file IS NOT INITIAL.

    DATA lv_cnt1 TYPE i.
    DATA lv_cnt2 TYPE i.
    DATA lv_next TYPE i.

    " lấy max không cộng sẵn
    SELECT SINGLE MAX( zcount )
      FROM ztb_m_od
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt1.

    SELECT SINGLE MAX( zcount )
      FROM ztb_m_odd
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt2.

    lv_next = COND i( WHEN lv_cnt1 >= lv_cnt2 THEN lv_cnt1 + 1 ELSE lv_cnt2 + 1 ).

    MODIFY ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY ManageFileOD
        UPDATE FIELDS ( status zcount )
        WITH VALUE #( FOR ls_file IN lt_file ( %tky   = ls_file-%tky
                                               status = file_status-open
                                               zcount = lv_next ) ).
  ENDMETHOD.


  METHOD getExcelDataOD.
    DATA: lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_file_c TYPE TABLE FOR CREATE zi_m_od\\ManageFileOD\_datafile,
          ls_file_c LIKE LINE OF lt_file_c.

    " ── 1. Read parent instance ───────────────────────────────────
    READ ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY ManageFileOD
      ALL FIELDS WITH
      CORRESPONDING #( keys )
      RESULT FINAL(lt_record).

    IF lt_record IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE lt_record ASSIGNING FIELD-SYMBOL(<f_file>) INDEX 1.

    IF <f_file>-attachment IS INITIAL.
      RETURN.
    ENDIF.

    " ── 2. Parse Excel ────────────────────────────────────────────
    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content(
                       iv_file_content = <f_file>-attachment
                     )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).
    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_file ) ).

    lo_execute->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->if_xco_xlsx_ra_operation~execute( ).

    " Bỏ header row + dòng hướng dẫn
    IF lt_file IS NOT INITIAL.
      DELETE lt_file INDEX 1.
      DELETE lt_file INDEX 1.
    ENDIF.

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.

    " ── 3. Chuẩn hóa dữ liệu & build DataFile ─────────────────────
    DATA: lv_index    TYPE i,
          lv_delivery TYPE ztb_d_od-delivery,
          lt_check    TYPE zcl_thung_implement=>tt_data_od.

    LOOP AT lt_file INTO DATA(ls_file).
      " Bỏ qua dòng trống
      IF ls_file-SoThung IS INITIAL AND ls_file-Delivery IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_index = lv_index + 1.

      lv_delivery = condense( ls_file-Delivery ).
      lv_delivery = |{ lv_delivery ALPHA = IN }|.

      ls_file_c = VALUE #(
          %tky    = <f_file>-%tky
          %target = VALUE #( (
          %cid     = |CID_OD_{ lv_index }|
          SoThung  = to_upper( condense( ls_file-SoThung ) )
          Delivery = lv_delivery
        ) )
      ).

      APPEND ls_file_c TO lt_file_c.

      " Dữ liệu để kiểm tra ngay khi upload (cùng thứ tự với lt_file_c)
      APPEND VALUE #( uuidfile = <f_file>-Uuid
                      so_thung = ls_file_c-%target[ 1 ]-SoThung
                      delivery = ls_file_c-%target[ 1 ]-Delivery ) TO lt_check.

      CLEAR ls_file_c.
    ENDLOOP.

    IF lt_file_c IS INITIAL.
      RETURN.
    ENDIF.

    " ── 3b. Kiểm tra lỗi ngay khi upload (không ghi dữ liệu) ──────
    zcl_thung_implement=>post_od( EXPORTING iv_check_only = abap_true
                                  CHANGING  ct_data       = lt_check ).

    LOOP AT lt_file_c ASSIGNING FIELD-SYMBOL(<lfs_file_c>).
      DATA(lv_tabix) = sy-tabix.
      READ TABLE lt_check INTO DATA(ls_check) INDEX lv_tabix.
      IF sy-subrc = 0.
        <lfs_file_c>-%target[ 1 ]-Messagetype = ls_check-messagetype.
        <lfs_file_c>-%target[ 1 ]-Message     = ls_check-message.
      ENDIF.
    ENDLOOP.

    " ── 4. Create DataFile records ────────────────────────────────
    MODIFY ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY ManageFileOD
      CREATE BY \_datafile
      FIELDS (
        SoThung
        Delivery
        Messagetype
        Message
      )
      WITH lt_file_c
      MAPPED   DATA(lt_mapped_create)
      REPORTED DATA(lt_mapped_reported)
      FAILED   DATA(lt_failed_create).

    " ── 5. Header: có dòng lỗi → In process (P), không có lỗi → giữ Not process (M)
    IF line_exists( lt_check[ messagetype = 'E' ] ).
      MODIFY ENTITIES OF zi_m_od IN LOCAL MODE
        ENTITY ManageFileOD
        UPDATE FIELDS ( Status )
        WITH VALUE #( ( %tky   = <f_file>-%tky
                        Status = file_status-inprocess ) )
        FAILED   DATA(lt_failed_status)
        REPORTED DATA(lt_reported_status).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_DataFileOD DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In Process
      END OF file_status.

    " DataFileOD có action riêng nên framework vẫn gọi global authorization cho entity này
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DataFileOD RESULT result.

    METHODS PostConfirmOD FOR MODIFY
      IMPORTING keys FOR ACTION DataFileOD~PostConfirmOD RESULT result.

ENDCLASS.

CLASS lhc_DataFileOD IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


  METHOD PostConfirmOD.
    DATA lt_data TYPE zcl_thung_implement=>tt_data_od.

    " ── 1. SELECT ────────────────────────────────────────────────
    " Kiểm tra theo thùng nên lấy toàn bộ dòng chưa thành công của file, không chỉ dòng được chọn
    SELECT FROM ztb_d_od
      FIELDS *
      FOR ALL ENTRIES IN @keys
      WHERE uuidfile    =  @keys-uuidfile
        AND messagetype <> 'S'
      INTO TABLE @lt_data.

    IF lt_data IS INITIAL.
      RETURN.
    ENDIF.

    " ── 2. Validate + ghi lệnh xuất hàng vào ZTB_CUSTOM_HU ───────
    zcl_thung_implement=>post_od( CHANGING ct_data = lt_data ).

    " ── 3. Update status từng dòng ───────────────────────────────
    MODIFY ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY DataFileOD
      UPDATE FIELDS ( messagetype message )
      WITH VALUE #( FOR ls_data IN lt_data (
        %tky-uuid     = ls_data-uuid
        %tky-uuidfile = ls_data-uuidfile
        messagetype   = ls_data-messagetype
        message       = ls_data-message
      ) )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " ── 4. Update parent status ──────────────────────────────────
    DATA(lv_new_status) = COND #( WHEN line_exists( lt_data[ messagetype = 'E' ] )
                                  THEN file_status-inprocess    " P = In process
                                  ELSE file_status-completed ). " D = Done

    MODIFY ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY ManageFileOD
      UPDATE FIELDS ( status )
      WITH VALUE #( (
        %tky-uuid = lt_data[ 1 ]-uuidfile
        %is_draft = if_abap_behv=>mk-off
        status    = lv_new_status
      ) )
      FAILED   DATA(lt_hdr_failed)
      REPORTED DATA(lt_hdr_reported).

    " ── 5. Result ────────────────────────────────────────────────
    READ ENTITIES OF zi_m_od IN LOCAL MODE
      ENTITY DataFileOD
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result ( %tky   = ls_result-%tky
                                                   %param = ls_result ) ).
  ENDMETHOD.

ENDCLASS.
