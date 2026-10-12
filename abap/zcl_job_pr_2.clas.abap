CLASS zcl_job_pr_2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_apj_dt_exec_object .
    INTERFACES if_apj_rt_exec_object .
    INTERFACES if_oo_adt_classrun .

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
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_JOB_PR_2 IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
     ( selname = 'HDR_ID'
       kind = if_apj_dt_exec_object=>select_option
       datatype = 'C'
       length = 50
       param_text = 'HDR ID'
       changeable_ind = abap_true )
   ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    LOOP AT it_parameters INTO DATA(ls_param).
      " ── 1. SELECT ────────────────────────────────────────────────
      SELECT * FROM ztb_d_pr_2
        WITH PRIVILEGED ACCESS
        WHERE uuidfile = @ls_param-low
          AND messagetype NE 'S'
        INTO TABLE @DATA(lt_data).

      IF lt_data IS INITIAL.
        RETURN.
      ENDIF.

      "── 2. Process API ─────────────────────────────────────────────────
      zcl_pr_2_implement=>processing_api( CHANGING ct_data = lt_data ).

      " ── 3. Update status ─────────────────────────────────────
      MODIFY ENTITIES OF zi_m_pr_2
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

      COMMIT WORK AND WAIT.

      " ── 4. Update parent status ─────────────────────────────────────
      zcl_pr_2_implement=>get_new_status( EXPORTING it_data       = lt_data
                                          IMPORTING ev_new_status = DATA(lv_new_status) ).

      MODIFY ENTITIES OF zi_m_pr_2
        ENTITY ManageFilePR2
        UPDATE FIELDS ( status )
        WITH VALUE #( (
          %tky-uuid = lt_data[ 1 ]-uuidfile
          %is_draft = if_abap_behv=>mk-off
          status    = lv_new_status
        ) )
        FAILED   DATA(lt_hdr_failed)
        REPORTED DATA(lt_hdr_reported).

      COMMIT WORK AND WAIT.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    "Test
    DATA: lv_low(255) VALUE 'FA163EF80C7E1FD192F2F2093EFE6B60'.
    TRY.
        NEW zcl_job_pr_2( )->if_apj_rt_exec_object~execute(
            it_parameters = VALUE #(
                ( selname = 'HDR_ID'
                  kind = if_apj_dt_exec_object=>select_option
                  sign = 'I'
                  option = 'EQ'
                  low = lv_low )
            )
        ).
      CATCH cx_apj_rt_content.
        "handle exception
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
