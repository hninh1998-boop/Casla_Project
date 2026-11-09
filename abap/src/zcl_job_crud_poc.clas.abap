CLASS zcl_job_crud_poc DEFINITION
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

    "! = abap_true khi đang chạy trong execute( ) của job.
    "! save_modified dùng cờ này để không schedule job lồng nhau.
    CLASS-DATA gv_running TYPE abap_boolean READ-ONLY.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_JOB_CRUD_POC IMPLEMENTATION.


  METHOD if_apj_rt_exec_object~execute.
    " Báo cho saver (save_modified) biết đang chạy trong job
    " → không schedule job mới (tránh job tự sinh job vô hạn)
    gv_running = abap_true.

    DATA lv_has_open TYPE abap_boolean.

    LOOP AT it_parameters INTO DATA(ls_param) WHERE selname = 'HDR_ID'.
      " ── 1. SELECT: chỉ lấy các dòng đang chờ job ('J') ──────────────
      SELECT * FROM ztb_d_crud_poc
        WITH PRIVILEGED ACCESS
        WHERE uuidfile    = @ls_param-low
          AND messagetype = 'J'
        INTO TABLE @DATA(lt_data).

      IF lt_data IS INITIAL.
        CONTINUE.
      ENDIF.

      " ── 2. Xử lý I/M/D — sau bước này không còn dòng nào = 'J' ─────
      zcl_crud_poc_implement=>process( CHANGING ct_data = lt_data ).

      " ── 3. Update status từng dòng ─────────────────────────────────
      MODIFY ENTITIES OF zi_m_crud_poc
        ENTITY datafile
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

      " ── 4. Update parent status theo toàn bộ dòng con của file ────
      CLEAR lv_has_open.
      SELECT SINGLE @abap_true FROM ztb_d_crud_poc
        WITH PRIVILEGED ACCESS
        WHERE uuidfile    =  @ls_param-low
          AND messagetype <> 'S'
        INTO @lv_has_open.

      DATA(lv_new_status) = COND #(
        WHEN lv_has_open = abap_true
        THEN file_status-inprocess    " P = In process
        ELSE file_status-completed    " D = Done
      ).

      MODIFY ENTITIES OF zi_m_crud_poc
        ENTITY managefile
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

    gv_running = abap_false.
  ENDMETHOD.


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


  METHOD if_oo_adt_classrun~main.

    "Test
    DATA: lv_low(255) VALUE 'FA163EF80C7E1FD192F2F2093EFE6B60'.
    TRY.
        NEW zcl_job_crud_poc( )->if_apj_rt_exec_object~execute(
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
