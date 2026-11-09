CLASS zcl_job_upl_att_so DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_param_id   TYPE c LENGTH 8 VALUE 'ATT_ID'.
    CONSTANTS c_in_process TYPE c LENGTH 1 VALUE 'P'.
    CONSTANTS c_success    TYPE c LENGTH 1 VALUE 'S'.
    CONSTANTS c_error      TYPE c LENGTH 1 VALUE 'E'.

    METHODS process_file IMPORTING iv_uuid TYPE sysuuid_x16.
ENDCLASS.



CLASS zcl_job_upl_att_so IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( ( selname        = c_param_id
                                  kind           = if_apj_dt_exec_object=>select_option
                                  datatype       = 'C'
                                  length         = 32
                                  param_text     = 'Attachment UUID'
                                  changeable_ind = abap_true ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    DATA lt_uuid TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    DATA lv_uuid TYPE sysuuid_x16.

    LOOP AT it_parameters INTO DATA(ls_param) WHERE selname = c_param_id.
      lv_uuid = ls_param-low.
      INSERT lv_uuid INTO TABLE lt_uuid.
    ENDLOOP.

    LOOP AT lt_uuid INTO lv_uuid.
      process_file( lv_uuid ).
    ENDLOOP.
  ENDMETHOD.


  METHOD process_file.
    DATA lv_now TYPE timestampl.

    " Đọc từng file một để không giữ nhiều nội dung file trong bộ nhớ
    SELECT SINGLE uuid, file_name, sales_order, mime_type, attachment, post_result
      FROM ztb_upl_att_so
      WHERE uuid = @iv_uuid
      INTO @DATA(ls_row).
    IF sy-subrc <> 0 OR ls_row-post_result <> c_in_process.
      RETURN.
    ENDIF.

    DATA(ls_api) = zcl_call_api_upl_att_so=>upload_attachment(
                     iv_sales_order = ls_row-sales_order
                     iv_file_name   = CONV #( ls_row-file_name )
                     iv_mime_type   = CONV #( ls_row-mime_type )
                     iv_content     = ls_row-attachment ).

    GET TIME STAMP FIELD lv_now.

    MODIFY ENTITIES OF zi_upl_att_so
      ENTITY UploadAttachment
        UPDATE FIELDS ( PostResult Message AttDocNumber PostedAt )
        WITH VALUE #( ( Uuid         = ls_row-uuid
                        PostResult   = COND #( WHEN ls_api-ok = abap_true THEN c_success ELSE c_error )
                        Message      = ls_api-message
                        AttDocNumber = ls_api-doc_number
                        PostedAt     = lv_now ) ).

    " Commit từng file -> user bấm Go là thấy tiến độ
    COMMIT ENTITIES.
  ENDMETHOD.

ENDCLASS.
