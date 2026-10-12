CLASS lsc_ZI_M_PR_2 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_M_PR_2 IMPLEMENTATION.

  METHOD save_modified.
    " Kiểm tra có DataFile nào được update messagetype = 'J' không
    IF update-datafilepr2 IS NOT INITIAL.

      " Tìm records có messagetype = 'J'
      LOOP AT update-datafilepr2 ASSIGNING FIELD-SYMBOL(<upd>)
        WHERE messagetype = 'J'.

        DATA(lv_found) = abap_true.
        DATA(lv_uuidfile) = <upd>-uuidfile.
        EXIT.
      ENDLOOP.

      IF lv_found = abap_true.
        " ── Schedule Job ở đây — ngoài RAP LUW ──
        DATA(lv_job_text) = CONV cl_apj_rt_api=>ty_job_text( update-datafilepr2[ 1 ]-Message ).
        GET TIME STAMP FIELD DATA(ls_ts).

        TRY.
            cl_apj_rt_api=>schedule_job(
              EXPORTING
                iv_job_template_name   = 'ZJT_PR_2'
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
            ) TO reported-datafilepr2.
        ENDTRY.
      ENDIF.
    ENDIF.
  ENDMETHOD.
























  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.


































CLASS lhc_ManageFilePR2 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ManageFilePR2 RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ManageFilePR2.

    METHODS downloadFilePR2 FOR MODIFY
      IMPORTING keys FOR ACTION ManageFilePR2~downloadFilePR2 RESULT result.

    METHODS downloadTemplatePR2 FOR MODIFY
      IMPORTING keys FOR ACTION ManageFilePR2~downloadTemplatePR2.

    METHODS uploadExcelPR2 FOR MODIFY
      IMPORTING keys FOR ACTION ManageFilePR2~uploadExcelPR2.

    METHODS setStatusToOpenPR2 FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ManageFilePR2~setStatusToOpenPR2.

    METHODS getExcelDataPR2 FOR DETERMINE ON SAVE
      IMPORTING keys FOR ManageFilePR2~getExcelDataPR2.

ENDCLASS.

CLASS lhc_ManageFilePR2 IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.






















  METHOD earlynumbering_create.
    zcl_pr_2_implement=>earlynumbering_create( EXPORTING entities = entities
                                               CHANGING  mapped   = mapped
                                                         reported = reported
                                                         failed   = failed ).
  ENDMETHOD.





















  METHOD downloadFilePR2.
  ENDMETHOD.


















  METHOD downloadTemplatePR2.
  ENDMETHOD.





















  METHOD uploadExcelPR2.
    zcl_pr_2_implement=>uploadexcelpr2( EXPORTING keys       = keys
                                        IMPORTING et_mn_file = DATA(lt_mn_file) ).
    IF lt_mn_file IS NOT INITIAL.
      MODIFY ENTITIES OF zi_m_pr_2 IN LOCAL MODE
        ENTITY ManageFilePR2
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
























  METHOD setStatusToOpenPR2.
    READ ENTITIES OF zi_m_pr_2 IN LOCAL MODE
    ENTITY ManageFilePR2
    FIELDS ( status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_file).

    "If Status is already set, do nothing
    DELETE lt_file WHERE status IS NOT INITIAL.
    DELETE lt_file WHERE status = 'X'.

    CHECK lt_file IS NOT INITIAL.

    zcl_pr_2_implement=>setstatustoopenpr2( IMPORTING ev_next = DATA(lv_next) ).

    MODIFY ENTITIES OF zi_m_pr_2 IN LOCAL MODE
    ENTITY ManageFilePR2
    UPDATE FIELDS ( status zcount )
    WITH VALUE #( FOR ls_file IN lt_file
        ( %tky   = ls_file-%tky
          status = zcl_pr_2_top=>file_status-open
          zcount = lv_next ) ).
  ENDMETHOD.
























  METHOD getExcelDataPR2.
    " ── 1. Read parent instance ───────────────────────────────────
    READ ENTITIES OF zi_m_pr_2 IN LOCAL MODE
      ENTITY ManageFilePR2
      ALL FIELDS WITH
      CORRESPONDING #( keys )
      RESULT FINAL(lt_record).
    IF lt_record IS INITIAL.
      RETURN.
    ENDIF.

    FINAL(lv_filecontent) = lt_record[ 1 ]-attachment.
    CHECK sy-subrc = 0.

    " ── 2. Get Data File Create ────────────────────────────────
    zcl_pr_2_implement=>get_file_create( EXPORTING iv_filecontent = lv_filecontent
                                                   it_record      = lt_record
                                         IMPORTING et_file_c      = DATA(lt_file_c) ).
    IF lt_file_c IS INITIAL.
      RETURN.
    ENDIF.

    " ── 3. Create DataFile records ────────────────────────────────
    MODIFY ENTITIES OF zi_m_pr_2 IN LOCAL MODE
      ENTITY ManageFilePR2
      CREATE BY \_datafile
      FIELDS ( Type
               PurchaseRequisition
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
               RequisitionerName

               message
               messagetype )
      WITH lt_file_c
      MAPPED   DATA(lt_mapped_create)
      REPORTED DATA(lt_mapped_reported)
      FAILED   DATA(lt_failed_create).
  ENDMETHOD.

ENDCLASS.








































CLASS lhc_DataFilePR1 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DataFilePR2 RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DataFilePR2 RESULT result.

    METHODS PostConfirm FOR MODIFY
      IMPORTING keys FOR ACTION DataFilePR2~PostConfirm RESULT result.

    METHODS setJob FOR MODIFY
      IMPORTING keys FOR ACTION DataFilePR2~setJob RESULT result.

    METHODS setStatusToUpdate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR DataFilePR2~setStatusToUpdate.

ENDCLASS.

CLASS lhc_DataFilePR1 IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.


















  METHOD get_global_authorizations.
  ENDMETHOD.

















  METHOD PostConfirm.
    " ── 1. SELECT ────────────────────────────────────────────────
    SELECT * FROM ztb_d_pr_2
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @keys
      WHERE uuid = @keys-uuid
        AND messagetype NE 'S'
      INTO TABLE @DATA(lt_data).

    IF lt_data IS INITIAL.
      RETURN.
    ENDIF.

    "── 2. Process API ─────────────────────────────────────────────────
    zcl_pr_2_implement=>processing_api( CHANGING ct_data = lt_data ).

    " ── 3. Update status ─────────────────────────────────────
    MODIFY ENTITIES OF zi_m_pr_2 IN LOCAL MODE
      ENTITY DataFilePR2
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
    zcl_pr_2_implement=>get_new_status( EXPORTING it_data       = lt_data
                                        IMPORTING ev_new_status = DATA(lv_new_status) ).

    MODIFY ENTITIES OF zi_m_pr_2 IN LOCAL MODE
      ENTITY ManageFilePR2
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
    SELECT * FROM ztb_d_pr_2
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
    MODIFY ENTITIES OF zi_m_pr_2 IN LOCAL MODE
      ENTITY DataFilePR2
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
    READ ENTITIES OF zi_m_pr_2 IN LOCAL MODE
      ENTITY DataFilePR2
      FIELDS ( Uuidfile )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_data).

    IF lt_data IS NOT INITIAL.
      MODIFY ENTITIES OF zi_m_pr_2 IN LOCAL MODE
        ENTITY ManageFilePR2
        UPDATE FIELDS ( status )
        WITH VALUE #( (
          %tky-uuid = lt_data[ 1 ]-Uuidfile
          %is_draft = if_abap_behv=>mk-off
          status    = zcl_pr_2_top=>file_status-inprocess
        ) )
        FAILED   DATA(lt_hdr_failed)
        REPORTED DATA(lt_hdr_reported).
    ENDIF.
  ENDMETHOD.





















  METHOD setStatusToUpdate.
  ENDMETHOD.

ENDCLASS.
