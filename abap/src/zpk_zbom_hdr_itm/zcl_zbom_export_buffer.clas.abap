CLASS zcl_zbom_export_buffer DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_export_request,
             bomcategory TYPE zde_bomcat,
             search_text TYPE c LENGTH 255,
             ranges      TYPE zcl_zbom_export_sel=>tt_filter_range,
           END OF ty_export_request.

    CLASS-METHODS set_request
      IMPORTING is_request TYPE ty_export_request.

    " Chỉ gọi được ở save phase: INSERT và schedule_job đều là DML, các
    " phase khác của RAP (action, check_before_save) sẽ dump.
    CLASS-METHODS schedule_pending_jobs
      EXPORTING ev_error      TYPE abap_boolean
                ev_error_text TYPE string.

    CLASS-METHODS clear_buffer.

  PRIVATE SECTION.
    CLASS-DATA gs_request TYPE ty_export_request.
    CLASS-DATA gv_filled  TYPE abap_boolean.
ENDCLASS.


CLASS zcl_zbom_export_buffer IMPLEMENTATION.

  METHOD set_request.
    gs_request = is_request.
    gv_filled  = abap_true.
  ENDMETHOD.

  METHOD clear_buffer.
    CLEAR: gs_request, gv_filled.
  ENDMETHOD.

  METHOD schedule_pending_jobs.
    CLEAR: ev_error, ev_error_text.

    IF gv_filled = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_batch_id) = cl_system_uuid=>create_uuid_c32_static( ).
    GET TIME STAMP FIELD DATA(lv_now).

    INSERT ztb_zbom_exp_bat FROM @( VALUE #(
      batch_id    = lv_batch_id
      bomcategory = gs_request-bomcategory
      search_text = gs_request-search_text
      uname       = sy-uname
      created_at  = lv_now
      status      = 'N' ) ).

    DATA lt_flt TYPE STANDARD TABLE OF ztb_zbom_exp_flt WITH EMPTY KEY.
    LOOP AT gs_request-ranges INTO DATA(ls_range).
      APPEND VALUE #( batch_id   = lv_batch_id
                      seq        = sy-tabix
                      field_name = ls_range-field_name
                      sign_      = ls_range-sign
                      opt        = ls_range-option
                      low        = ls_range-low
                      high       = ls_range-high ) TO lt_flt.
    ENDLOOP.

    IF lt_flt IS NOT INITIAL.
      INSERT ztb_zbom_exp_flt FROM TABLE @lt_flt.
    ENDIF.

    DATA: job_template_name TYPE cl_apj_rt_api=>ty_template_name VALUE 'ZAJT_ZBOM_EXPORT',
          job_start_info    TYPE cl_apj_rt_api=>ty_start_info,
          job_parameters    TYPE cl_apj_rt_api=>tt_job_parameter_value,
          job_parameter     TYPE cl_apj_rt_api=>ty_job_parameter_value,
          range_value       TYPE cl_apj_rt_api=>ty_value_range,
          job_name          TYPE cl_apj_rt_api=>ty_jobname,
          job_count         TYPE cl_apj_rt_api=>ty_jobcount.

    job_start_info-start_immediately = abap_true.

    range_value-sign   = 'I'.
    range_value-option = 'EQ'.
    range_value-low    = lv_batch_id.
    job_parameter-name = 'BATCH_ID'.
    APPEND range_value TO job_parameter-t_value.
    APPEND job_parameter TO job_parameters.

    TRY.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = job_template_name
            iv_job_text            = |ZBOM Excel Export { sy-uname }|
            is_start_info          = job_start_info
            it_job_parameter_value = job_parameters
          IMPORTING
            ev_jobname             = job_name
            ev_jobcount            = job_count ).
      CATCH cx_apj_rt INTO DATA(lx_error).
        ev_error      = abap_true.
        ev_error_text = lx_error->get_text( ).
        " Không schedule được -> xóa request vừa insert để không để lại
        " dòng mồ côi không job nào xử lý.
        DELETE FROM ztb_zbom_exp_flt WHERE batch_id = @lv_batch_id.
        DELETE FROM ztb_zbom_exp_bat WHERE batch_id = @lv_batch_id.
    ENDTRY.

    clear_buffer( ).
  ENDMETHOD.

ENDCLASS.

