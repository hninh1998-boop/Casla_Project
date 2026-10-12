CLASS lsc_ZI_M_PR_1 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_M_PR_1 IMPLEMENTATION.

  METHOD save_modified.
    " Kiểm tra có DataFile nào được update messagetype = 'J' không
    IF update-datafilepr1 IS NOT INITIAL.

      " Tìm records có messagetype = 'J'
      LOOP AT update-datafilepr1 ASSIGNING FIELD-SYMBOL(<upd>)
        WHERE messagetype = 'J'.

        DATA(lv_found) = abap_true.
        DATA(lv_uuidfile) = <upd>-uuidfile.
        EXIT.
      ENDLOOP.

      IF lv_found = abap_true.
        " ── Schedule Job ở đây — ngoài RAP LUW ──
        DATA(lv_job_text) = CONV cl_apj_rt_api=>ty_job_text( update-datafilepr1[ 1 ]-Message ).
        GET TIME STAMP FIELD DATA(ls_ts).

        TRY.
            cl_apj_rt_api=>schedule_job(
              EXPORTING
                iv_job_template_name   = 'ZJT_PR_1'
                iv_job_text            = lv_job_text
                is_start_info          = VALUE #(
                    timestamp = cl_abap_tstmp=>add( tstmp = ls_ts secs = 1 )
                )
                is_end_info            = VALUE #( type = 'NUM' max_iterations = 3 )
                is_scheduling_info     = VALUE #(
                  periodic_value = 1
                  test_mode      = abap_false
                  timezone       = 'CET'
                )
                it_job_parameter_value = VALUE #( (
                  name    = 'HDR_ID'
                  t_value = VALUE #( (
                    sign = 'I'  option = 'EQ'  low = lv_uuidfile
                  ) )
                ) )
              IMPORTING
                ev_jobname = DATA(lv_jobname)
            ).

          CATCH cx_apj_rt INTO DATA(lx_apj).
            APPEND VALUE #(
              uuid = <upd>-uuid
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = lx_apj->get_longtext( )
                     )
            ) TO reported-datafilepr1.
        ENDTRY.
      ENDIF.
    ENDIF.
  ENDMETHOD.




























  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
























CLASS lhc_ManageFilePR1 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In process
        error     TYPE c LENGTH 1 VALUE 'E', "Error
        success   TYPE c LENGTH 1 VALUE 'S', "Success
      END OF file_status.

    TYPES: BEGIN OF ty_file_upload,
             Type                     TYPE string,
             PurchaseRequisition      TYPE string,
             PurchaseRequisitionType  TYPE string,
             PurReqnDescription       TYPE string,
             PurReqnHeaderNote        TYPE string,
             PurchaseRequisitionItem  TYPE string,
             Material                 TYPE string,
             RequestedQuantity        TYPE string,
             BaseUnit                 TYPE string,
             Plant                    TYPE string,
             StorageLocation          TYPE string,
             PurchaseRequisitionPrice TYPE string,
             PurReqnPriceQuantity     TYPE string,
             PurReqnItemCurrency      TYPE string,
             PurchasingGroup          TYPE string,
             DeliveryDate             TYPE string,
             RequirementTracking      TYPE string,
             RequestedBy              TYPE string,
           END OF ty_file_upload.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ManageFilePR1 RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ManageFilePR1.

    METHODS downloadFilePR1 FOR MODIFY
      IMPORTING keys FOR ACTION ManageFilePR1~downloadFilePR1 RESULT result.

    METHODS downloadTemplatePR1 FOR MODIFY
      IMPORTING keys FOR ACTION ManageFilePR1~downloadTemplatePR1.

    METHODS uploadExcelPR1 FOR MODIFY
      IMPORTING keys FOR ACTION ManageFilePR1~uploadExcelPR1.

    METHODS setStatusToOpenPR1 FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ManageFilePR1~setStatusToOpenPR1.

    METHODS getExcelDataPR1 FOR DETERMINE ON SAVE
      IMPORTING keys FOR ManageFilePR1~getExcelDataPR1.

ENDCLASS.

CLASS lhc_ManageFilePR1 IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.




















  METHOD earlynumbering_create.
    LOOP AT entities
               ASSIGNING FIELD-SYMBOL(<f_entities>)
               WHERE uuid IS NOT INITIAL.

      APPEND CORRESPONDING #( <f_entities> ) TO mapped-managefilepr1.

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
                 TO reported-managefilepr1.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft )
                 TO failed-managefilepr1.

          EXIT.
      ENDTRY.

      APPEND VALUE #( %cid      = <f_entities>-%cid
                      %key      = <f_entities>-%key
                      %is_draft = <f_entities>-%is_draft )
       TO mapped-managefilepr1.
    ENDLOOP.
  ENDMETHOD.






















  METHOD downloadFilePR1.
  ENDMETHOD.














  METHOD downloadTemplatePR1.
  ENDMETHOD.
















  METHOD uploadExcelPR1.
    DATA lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_mn_file TYPE TABLE FOR CREATE zi_m_pr_1,
          ls_mn_file LIKE LINE OF lt_mn_file,

          lt_file_c  TYPE TABLE FOR CREATE zi_m_pr_1\_datafile,
          ls_file_c  LIKE LINE OF lt_file_c.

    DATA: lt_keys TYPE TABLE FOR READ IMPORT zi_m_pr_1.

    READ TABLE keys ASSIGNING FIELD-SYMBOL(<k>) INDEX 1.

    CHECK sy-subrc = 0.

    IF <k>-%param-filecontent IS INITIAL.
      RETURN.
    ENDIF.

    ls_mn_file-attachment = <k>-%param-filecontent.
    ls_mn_file-filename   = <k>-%param-filename.
    ls_mn_file-mimetype   = <k>-%param-mimetype.

    FINAL(lv_filecontent) = <k>-%param-filecontent.
    "XCOライブラリを使用したExcelファイルの読み取り
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

    DATA: lv_error TYPE abap_boolean VALUE IS INITIAL.

    "Validate...
    IF NOT lv_error = abap_true.
      ls_mn_file-Countline = lines( lt_file ).
      APPEND ls_mn_file TO lt_mn_file.
    ENDIF.

    IF lt_mn_file IS NOT INITIAL.
      MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
        ENTITY ManageFilePR1
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
    ENDIF.
  ENDMETHOD.





















  METHOD setStatusToOpenPR1.
    READ ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY ManageFilePR1
        FIELDS ( status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file).

    "If Status is already set, do nothing
    DELETE lt_file WHERE status IS NOT INITIAL.
    DELETE lt_file WHERE status = 'X'.

    CHECK lt_file IS NOT INITIAL.

    DATA lv_cnt1 TYPE i.
    DATA lv_cnt2 TYPE i.
    DATA lv_next TYPE i.

    " lấy max không cộng sẵn
    SELECT SINGLE MAX( zcount )
      FROM ztb_m_pr_1
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt1.

    SELECT SINGLE MAX( zcount )
      FROM ztb_m_pr_1d
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt2.

    lv_next = COND i( WHEN lv_cnt1 >= lv_cnt2 THEN lv_cnt1 + 1 ELSE lv_cnt2 + 1 ).

    MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY ManageFilePR1
        UPDATE FIELDS ( status zcount )
        WITH VALUE #( FOR ls_file IN lt_file ( %tky   = ls_file-%tky
                                               status = file_status-open
                                               zcount = lv_next ) ).
  ENDMETHOD.




















  METHOD getExcelDataPR1.
    DATA: lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_file_c TYPE TABLE FOR CREATE zi_m_pr_1\\ManageFilePR1\_datafile,
          ls_file_c LIKE LINE OF lt_file_c.

    " ── 1. Read parent instance ───────────────────────────────────
    READ ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY ManageFilePR1
      ALL FIELDS WITH
      CORRESPONDING #( keys )
      RESULT FINAL(lt_record).

    IF lt_record IS INITIAL.
      RETURN.
    ENDIF.

    FINAL(lv_filecontent) = lt_record[ 1 ]-attachment.

    CHECK sy-subrc = 0.

    " ── 2. Parse Excel ────────────────────────────────────────────
    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content(
                       iv_file_content = lv_filecontent
                     )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).
    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_file ) ).

    lo_execute->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->if_xco_xlsx_ra_operation~execute( ).

    " Bỏ header row
    IF lt_file IS NOT INITIAL.
      DELETE lt_file INDEX 1.
      DELETE lt_file INDEX 1.
    ENDIF.

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE lt_record ASSIGNING FIELD-SYMBOL(<f_file>) INDEX 1.

    " ── 3. Process data Raw ───────────────────────────────────────
    DATA: lt_data_file TYPE TABLE OF zi_d_pr_1.

    LOOP AT lt_file INTO DATA(ls_file).
      APPEND INITIAL LINE TO lt_data_file ASSIGNING FIELD-SYMBOL(<lfs_data_file>).

      <lfs_data_file>-Type                    = ls_file-type.
      <lfs_data_file>-PurchaseRequisition     = |{ ls_file-PurchaseRequisition ALPHA = IN }|.
      <lfs_data_file>-PurchaseRequisitionType = ls_file-PurchaseRequisitionType.
      <lfs_data_file>-PurReqnDescription      = ls_file-PurReqnDescription.
      <lfs_data_file>-PurReqnHeaderNote       = ls_file-PurReqnHeaderNote.
      <lfs_data_file>-PurchaseRequisitionItem = |{ ls_file-PurchaseRequisitionItem ALPHA = IN }|.

      IF ls_file-material IS NOT INITIAL.
        <lfs_data_file>-Material = COND #( WHEN ls_file-material CO '0123456789'
                                           THEN |{ ls_file-Material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
                                           ELSE ls_file-material ).
      ENDIF.

      <lfs_data_file>-RequestedQuantity = ls_file-RequestedQuantity.

      DATA(lv_uom_e) = CONV I_UnitOfMeasure-UnitOfMeasure_E( ls_file-BaseUnit ).
      SELECT SINGLE FROM I_UnitOfMeasure
      FIELDS UnitOfMeasure
      WHERE UnitOfMeasure_E = @lv_uom_e
      INTO @<lfs_data_file>-BaseUnit.

      <lfs_data_file>-Plant                    = |{ ls_file-Plant ALPHA = IN }|.
      <lfs_data_file>-StorageLocation          = |{ ls_file-storagelocation ALPHA = IN }|.
      <lfs_data_file>-PurchaseRequisitionPrice = ls_file-PurchaseRequisitionPrice.
      <lfs_data_file>-PurReqnPriceQuantity     = ls_file-PurReqnPriceQuantity.
      <lfs_data_file>-PurReqnItemCurrency      = ls_file-PurReqnItemCurrency.
      <lfs_data_file>-PurchasingGroup          = |{ ls_file-PurchasingGroup ALPHA = IN }|.
      <lfs_data_file>-DeliveryDate             = ls_file-DeliveryDate.
      <lfs_data_file>-RequirementTracking      = ls_file-RequirementTracking.
      <lfs_data_file>-RequestedBy               = ls_file-RequestedBy.

      " ── Validate: Type I bắt buộc phải có Requested By ──────────
      IF <lfs_data_file>-Type = 'I' AND <lfs_data_file>-RequestedBy IS INITIAL.
        <lfs_data_file>-message     = 'Requisitioner Name là bắt buộc khi Type = I'.
        <lfs_data_file>-messagetype = 'E'.
      ENDIF.
    ENDLOOP.

    " ── 4. Xóa duplicate trong file ──────────────────────────────
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT lt_data_file INTO DATA(ls_seen_dup).
      DATA(lv_key) =
        ls_seen_dup-type
        && ls_seen_dup-PurchaseRequisition
        && ls_seen_dup-PurchaseRequisitionType
        && ls_seen_dup-PurReqnDescription
        && ls_seen_dup-PurReqnHeaderNote
        && ls_seen_dup-PurchaseRequisitionItem
        && ls_seen_dup-Material
        && ls_seen_dup-RequestedQuantity
        && ls_seen_dup-BaseUnit
        && ls_seen_dup-Plant
        && ls_seen_dup-StorageLocation
        && ls_seen_dup-PurchaseRequisitionPrice
        && ls_seen_dup-PurReqnPriceQuantity
        && ls_seen_dup-PurReqnItemCurrency
        && ls_seen_dup-PurchasingGroup
        && ls_seen_dup-DeliveryDate
        && ls_seen_dup-RequirementTracking
        && ls_seen_dup-RequestedBy.

      INSERT lv_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        " Trùng → xóa khỏi table
        DELETE lt_data_file.
      ENDIF.
    ENDLOOP.

    IF lt_data_file IS INITIAL.
      RETURN.
    ENDIF.

    " ── 5. Build lt_file_c để create DataFile ────────────────────
    DATA lv_index TYPE i.

    LOOP AT lt_data_file INTO DATA(ls_data_file).
      lv_index = lv_index + 1.

      TRY.
          ls_file_c = VALUE #(
              %tky    = <f_file>-%tky
              %target = VALUE #( (
              %cid    = |CID_D_{ lv_index }|

              Type                      = ls_data_file-Type
              PurchaseRequisition       = ls_data_file-PurchaseRequisition
              PurchaseRequisitionType   = ls_data_file-PurchaseRequisitionType
              PurReqnDescription        = ls_data_file-PurReqnDescription
              PurReqnHeaderNote         = ls_data_file-PurReqnHeaderNote
              PurchaseRequisitionItem   = ls_data_file-PurchaseRequisitionItem
              Material                  = ls_data_file-Material
              RequestedQuantity         = ls_data_file-RequestedQuantity
              BaseUnit                  = ls_data_file-BaseUnit
              Plant                     = ls_data_file-Plant
              StorageLocation           = ls_data_file-StorageLocation
              PurchaseRequisitionPrice  = ls_data_file-PurchaseRequisitionPrice
              PurReqnPriceQuantity      = ls_data_file-PurReqnPriceQuantity
              PurReqnItemCurrency       = ls_data_file-PurReqnItemCurrency
              PurchasingGroup           = ls_data_file-PurchasingGroup
              DeliveryDate              = ls_data_file-DeliveryDate
              RequirementTracking       = ls_data_file-RequirementTracking
              RequestedBy               = ls_data_file-RequestedBy

              message     = ls_data_file-message
              messagetype = ls_data_file-messagetype
            ) )
          ).
        CATCH cx_abap_context_info_error.
          CONTINUE.
      ENDTRY.

      APPEND ls_file_c TO lt_file_c.
      CLEAR ls_file_c.
    ENDLOOP.

    IF lt_file_c IS INITIAL.
      RETURN.
    ENDIF.

    " ── 6. Create DataFile records ────────────────────────────────
    MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY ManageFilePR1
      CREATE BY \_datafile
      FIELDS (
        Type
        PurchaseRequisition
        PurchaseRequisitionType
        PurReqnDescription
        PurReqnHeaderNote
        PurchaseRequisitionItem
        Material
        RequestedQuantity
        BaseUnit
        Plant
        StorageLocation
        PurchaseRequisitionPrice
        PurReqnPriceQuantity
        PurReqnItemCurrency
        PurchasingGroup
        DeliveryDate
        RequirementTracking
        RequestedBy

        message
        messagetype
      )
      WITH lt_file_c
      MAPPED   DATA(lt_mapped_create)
      REPORTED DATA(lt_mapped_reported)
      FAILED   DATA(lt_failed_create).

    " ── 7. Update Status của Header PR1 ───────────────────────────
    " Nếu có ít nhất 1 dòng lỗi (vd: Type I thiếu RequestedBy) → Status = 'P' (In Process, cần sửa lại file)
    " Nếu không có lỗi → Status = 'D' (Done)
    DATA(lv_has_error) = xsdbool( line_exists( lt_data_file[ messagetype = 'E' ] ) ).

    MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY ManageFilePR1
      UPDATE FIELDS ( Status )
      WITH VALUE #( ( %tky   = <f_file>-%tky
                       Status = COND #( WHEN lv_has_error = abap_true THEN 'P' ELSE 'M' ) ) )
      MAPPED   DATA(lt_mapped_update)
      REPORTED DATA(lt_mapped_reported_update)
      FAILED   DATA(lt_failed_update).
  ENDMETHOD.

ENDCLASS.






























CLASS lhc_DataFilePR1 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In Process
        error     TYPE c LENGTH 1 VALUE 'E', "Error
        success   TYPE c LENGTH 1 VALUE 'S', "Success
      END OF file_status.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DataFilePR1 RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DataFilePR1 RESULT result.

    METHODS PostConfirm FOR MODIFY
      IMPORTING keys FOR ACTION DataFilePR1~PostConfirm RESULT result.

    METHODS setJob FOR MODIFY
      IMPORTING keys FOR ACTION DataFilePR1~setJob RESULT result.

    METHODS setStatusToUpdate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR DataFilePR1~setStatusToUpdate.

    TYPES: tt_data TYPE STANDARD TABLE OF ztb_d_pr_1.



ENDCLASS.

CLASS lhc_DataFilePR1 IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.



















  METHOD get_global_authorizations.
  ENDMETHOD.





















  METHOD PostConfirm.
    " ── 1. SELECT ────────────────────────────────────────────────
    SELECT * FROM ztb_d_pr_1
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @keys
      WHERE uuid = @keys-uuid
        AND messagetype NE 'S'
      INTO TABLE @DATA(lt_data).

    IF lt_data IS INITIAL.
      RETURN.
    ENDIF.

    "── 2. Process API ─────────────────────────────────────────────────
    zcl_pr_1_implement=>processing_api( CHANGING ct_data = lt_data ).

    " ── 3. Update status ─────────────────────────────────────
    MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY DataFilePR1
      UPDATE FIELDS ( messagetype message )
      WITH VALUE #( FOR ls_data IN lt_data (
        %tky-uuid     = ls_data-uuid
        %tky-uuidfile = ls_data-uuidfile
        messagetype   = ls_data-messagetype
        message       = ls_data-message
      ) )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " ── 4. Update parent status ─────────────────────────────────────
    zcl_pr_1_implement=>get_new_status( EXPORTING it_data       = lt_data
                                        IMPORTING ev_new_status = DATA(lv_new_status) ).

    MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY ManageFilePR1
      UPDATE FIELDS ( status )
      WITH VALUE #( (
        %tky-uuid = lt_data[ 1 ]-uuidfile
        %is_draft = if_abap_behv=>mk-off
        status    = lv_new_status
      ) )
      FAILED   DATA(lt_hdr_failed)
      REPORTED DATA(lt_hdr_reported).
  ENDMETHOD.























  METHOD setJob.
    SELECT * FROM ztb_d_pr_1
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @keys
      WHERE uuidfile = @keys-uuidfile
        AND messagetype = 'S'
      INTO TABLE @DATA(lt_data_success).

    DATA(lt_keys) = keys.

    LOOP AT lt_data_success INTO DATA(ls_data_success).
      DELETE lt_keys WHERE Uuid = ls_data_success-uuid.
    ENDLOOP.

    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_uuid_c36) = xco_cp_uuid=>format->c36->from_uuid(
                           xco_cp=>uuid( lt_keys[ 1 ]-uuidfile )
                         ).

    lv_uuid_c36 = to_lower( lv_uuid_c36 ).

    GET TIME STAMP FIELD DATA(ls_ts).
    " Chỉ đánh dấu status = 'J' (Job pending)
    MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY DataFilePR1
      UPDATE FIELDS ( messagetype message )
      WITH VALUE #( FOR key IN lt_keys
        ( %tky        = key-%tky
          messagetype = 'J'
          message     = lv_uuid_c36
        )
      )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " Update parent status
    READ ENTITIES OF zi_m_pr_1 IN LOCAL MODE
      ENTITY DataFilePR1
      FIELDS ( Uuidfile )
      WITH CORRESPONDING #( lt_keys )
      RESULT DATA(lt_data).

    IF lt_data IS NOT INITIAL.
      MODIFY ENTITIES OF zi_m_pr_1 IN LOCAL MODE
        ENTITY ManageFilePR1
        UPDATE FIELDS ( status )
        WITH VALUE #( (
          %tky-uuid = lt_data[ 1 ]-Uuidfile
          %is_draft = if_abap_behv=>mk-off
          status    = file_status-inprocess
        ) )
        FAILED   DATA(lt_hdr_failed)
        REPORTED DATA(lt_hdr_reported).
    ENDIF.
  ENDMETHOD.





















  METHOD setStatusToUpdate.
  ENDMETHOD.

























ENDCLASS.
