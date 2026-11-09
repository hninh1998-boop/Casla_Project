"! Hằng số dùng chung của tool
CLASS lcl_const DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF check_status,
        new   TYPE c LENGTH 1 VALUE 'N',
        ready TYPE c LENGTH 1 VALUE 'R',
        error TYPE c LENGTH 1 VALUE 'E',
      END OF check_status,

      BEGIN OF post_result,
        in_process TYPE c LENGTH 1 VALUE 'P',
        success    TYPE c LENGTH 1 VALUE 'S',
        error      TYPE c LENGTH 1 VALUE 'E',
      END OF post_result.

    CONSTANTS max_file_size TYPE int8         VALUE 10485760. " 10MB
    CONSTANTS stale_seconds TYPE i            VALUE 1800.     " 30 phút: dòng In process quá lâu -> cho post lại
    CONSTANTS not_available TYPE string       VALUE `N/A`.
    CONSTANTS job_template  TYPE c LENGTH 30  VALUE 'ZAJT_UPL_ATT_SO'.
    CONSTANTS job_param_id  TYPE c LENGTH 8   VALUE 'ATT_ID'.

    " Message class ZUPL_ATT_SO, message 000 = "&1&2&3&4" -> text tối đa 200 ký tự
    " (new_message_with_text chỉ giữ được 50 ký tự)
    CONSTANTS msg_class     TYPE symsgid      VALUE 'ZUPL_ATT_SO'.
    CONSTANTS msg_number    TYPE symsgno      VALUE '000'.
ENDCLASS.


"! Hàm tiện ích: tách tên file, mime type, hiển thị dung lượng
CLASS lcl_util DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS get_extension
      IMPORTING iv_file_name  TYPE csequence
      RETURNING VALUE(rv_ext) TYPE string.

    CLASS-METHODS get_mime_type
      IMPORTING iv_file_name   TYPE csequence
                iv_mime_type   TYPE csequence
      RETURNING VALUE(rv_mime) TYPE string.

    CLASS-METHODS get_size_text
      IMPORTING iv_size        TYPE int8
      RETURNING VALUE(rv_text) TYPE string.

    "! Tách "<Số SO>_<Mô tả>.<đuôi>" theo FS; trả về N/A nếu phần SO sai quy tắc
    CLASS-METHODS parse_file_name
      IMPORTING iv_file_name   TYPE csequence
      EXPORTING ev_sales_order TYPE string
                ev_description TYPE string
                et_errors      TYPE string_table.

    CLASS-METHODS to_so_key
      IMPORTING iv_sales_order TYPE csequence
      RETURNING VALUE(rv_key)  TYPE i_salesorder-salesorder.

    CLASS-METHODS is_stale
      IMPORTING iv_posted_at    TYPE timestampl
      RETURNING VALUE(rv_stale) TYPE abap_bool.

    "! Chia text thành 4 biến message (mỗi biến 50 ký tự) cho message &1&2&3&4
    CLASS-METHODS split_text
      IMPORTING iv_text TYPE csequence
      EXPORTING ev_v1   TYPE symsgv
                ev_v2   TYPE symsgv
                ev_v3   TYPE symsgv
                ev_v4   TYPE symsgv.
ENDCLASS.

CLASS lcl_util IMPLEMENTATION.

  METHOD get_extension.
    DATA(lv_name) = CONV string( iv_file_name ).
    DATA(lv_pos) = find( val = lv_name sub = `.` occ = -1 ).
    IF lv_pos >= 0.
      rv_ext = to_lower( substring( val = lv_name off = lv_pos + 1 ) ).
    ENDIF.
  ENDMETHOD.

  METHOD get_mime_type.
    CASE get_extension( iv_file_name ).
      WHEN `pdf`.
        rv_mime = `application/pdf`.
      WHEN `txt`.
        rv_mime = `text/plain`.
      WHEN OTHERS.
        rv_mime = COND #( WHEN iv_mime_type IS NOT INITIAL THEN iv_mime_type
                          ELSE `application/octet-stream` ).
    ENDCASE.
  ENDMETHOD.

  METHOD get_size_text.
    IF iv_size < 1024.
      rv_text = |{ iv_size } B|.
    ELSEIF iv_size < 1048576.
      rv_text = |{ CONV int8( iv_size / 1024 ) } KB|.
    ELSE.
      " Làm tròn 1 số lẻ, bỏ ".0" cho giống FS (1MB, 10MB, 2.5MB)
      DATA(lv_tenths) = CONV int8( iv_size * 10 / 1048576 ).
      rv_text = COND #( WHEN lv_tenths MOD 10 = 0
                        THEN |{ lv_tenths DIV 10 } MB|
                        ELSE |{ lv_tenths DIV 10 }.{ lv_tenths MOD 10 } MB| ).
    ENDIF.
  ENDMETHOD.

  METHOD parse_file_name.
    CLEAR: ev_sales_order, ev_description, et_errors.

    DATA(lv_name) = CONV string( iv_file_name ).
    DATA(lv_ext)  = get_extension( lv_name ).
    DATA(lv_pos)  = find( val = lv_name sub = `.` occ = -1 ).
    DATA(lv_base) = COND string( WHEN lv_pos >= 0 THEN substring( val = lv_name len = lv_pos )
                                 ELSE lv_name ).

    " 1. API không nhận Slug có dấu / ký tự ngoài ASCII
    IF find( val = lv_name pcre = `[^\x20-\x7E]` ) >= 0.
      APPEND `Tên file có dấu tiếng Việt hoặc ký tự đặc biệt` TO et_errors.
    ENDIF.

    " 2. Định dạng file
    IF lv_ext <> `pdf` AND lv_ext <> `txt`.
      DATA(lv_ext_text) = COND string( WHEN lv_ext IS INITIAL THEN `không có đuôi`
                                       ELSE |.{ lv_ext }| ).
      APPEND |Sai định dạng ({ lv_ext_text }), chỉ chấp nhận .pdf/.txt| TO et_errors.
    ENDIF.

    " 3. Cụm trước dấu "_" đầu tiên = Số SO, phần còn lại = mô tả (không có "_" -> mô tả = Số SO)
    DATA lv_so   TYPE string.
    DATA lv_desc TYPE string.
    SPLIT lv_base AT `_` INTO lv_so lv_desc.
    IF lv_desc IS INITIAL.
      lv_desc = lv_so.
    ENDIF.

    IF lv_so IS INITIAL OR lv_so CN `0123456789` OR strlen( lv_so ) > 10.
      APPEND |Sai quy tắc <Số SO>_<Mô tả>: "{ lv_so }" không phải số SO| TO et_errors.
      ev_sales_order = lcl_const=>not_available.
      ev_description = lcl_const=>not_available.
      RETURN.
    ENDIF.

    ev_sales_order = lv_so.
    ev_description = lv_desc.
  ENDMETHOD.

  METHOD to_so_key.
    DATA lv_so TYPE c LENGTH 10.
    lv_so = iv_sales_order.
    rv_key = |{ lv_so ALPHA = IN }|.
  ENDMETHOD.

  METHOD is_stale.
    DATA lv_now TYPE timestampl.

    IF iv_posted_at IS INITIAL.
      rv_stale = abap_true.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD lv_now.
    TRY.
        rv_stale = xsdbool( cl_abap_tstmp=>subtract( tstmp1 = lv_now
                                                     tstmp2 = iv_posted_at ) > lcl_const=>stale_seconds ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_stale = abap_true.
    ENDTRY.
  ENDMETHOD.

  METHOD split_text.
    DATA lt_part TYPE STANDARD TABLE OF symsgv WITH EMPTY KEY.

    CLEAR: ev_v1, ev_v2, ev_v3, ev_v4.
    DATA(lv_rest) = CONV string( iv_text ).

    DO 4 TIMES.
      IF lv_rest IS INITIAL.
        EXIT.
      ENDIF.

      DATA(lv_len) = nmin( val1 = strlen( lv_rest ) val2 = 50 ).
      " Không cắt ngay tại dấu cách: dấu cách ở đầu/cuối biến message bị mất khi ghép &1&2&3&4
      WHILE lv_len > 1
        AND lv_len < strlen( lv_rest )
        AND (    substring( val = lv_rest off = lv_len - 1 len = 1 ) = ` `
              OR substring( val = lv_rest off = lv_len     len = 1 ) = ` ` ).
        lv_len -= 1.
      ENDWHILE.

      APPEND CONV symsgv( substring( val = lv_rest len = lv_len ) ) TO lt_part.
      lv_rest = substring( val = lv_rest off = lv_len ).
    ENDDO.

    ev_v1 = VALUE #( lt_part[ 1 ] OPTIONAL ).
    ev_v2 = VALUE #( lt_part[ 2 ] OPTIONAL ).
    ev_v3 = VALUE #( lt_part[ 3 ] OPTIONAL ).
    ev_v4 = VALUE #( lt_part[ 4 ] OPTIONAL ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_UploadAttachment DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR UploadAttachment RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR UploadAttachment RESULT result.

    METHODS uploadFile FOR MODIFY
      IMPORTING keys FOR ACTION UploadAttachment~uploadFile.

    METHODS checkAttachment FOR MODIFY
      IMPORTING keys FOR ACTION UploadAttachment~checkAttachment RESULT result.

    METHODS postAttachment FOR MODIFY
      IMPORTING keys FOR ACTION UploadAttachment~postAttachment RESULT result.

    METHODS validateFileName FOR VALIDATE ON SAVE
      IMPORTING keys FOR UploadAttachment~validateFileName.

    METHODS msg
      IMPORTING iv_severity   TYPE if_abap_behv_message=>t_severity
                iv_text       TYPE csequence
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.

ENDCLASS.

CLASS lhc_UploadAttachment IMPLEMENTATION.

  METHOD get_global_authorizations.
    " FS: không kiểm tra quyền - ai được gán app thì dùng được
    result-%create                 = if_abap_behv=>auth-allowed.
    result-%update                 = if_abap_behv=>auth-allowed.
    result-%delete                 = if_abap_behv=>auth-allowed.
    result-%action-uploadFile      = if_abap_behv=>auth-allowed.
    result-%action-checkAttachment = if_abap_behv=>auth-allowed.
    result-%action-postAttachment  = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_upl_att_so IN LOCAL MODE
      ENTITY UploadAttachment
        FIELDS ( Status PostResult PostedAt ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).

    " Fiori Elements dùng kết quả này để:
    "  - làm mờ nút khi tất cả dòng được chọn đều không thao tác được
    "  - chọn lẫn: Delete -> "x out of y selected objects have delete restrictions..."
    "               Check/Post -> "x selected objects can't be processed" + Continue Anyway
    LOOP AT lt_rows INTO DATA(ls_row).
      " Đã post thành công hoặc job đang xử lý (chưa treo quá 30 phút) -> khoá
      DATA(lv_locked) = xsdbool(
           ls_row-PostResult = lcl_const=>post_result-success
        OR ( ls_row-PostResult = lcl_const=>post_result-in_process
             AND lcl_util=>is_stale( ls_row-PostedAt ) = abap_false ) ).

      DATA(lv_can_post) = xsdbool( lv_locked = abap_false
                                   AND ls_row-Status = lcl_const=>check_status-ready ).

      APPEND VALUE #( %tky                    = ls_row-%tky
                      %delete                 = COND #( WHEN lv_locked = abap_true
                                                        THEN if_abap_behv=>fc-o-disabled
                                                        ELSE if_abap_behv=>fc-o-enabled )
                      %action-checkAttachment = COND #( WHEN lv_locked = abap_true
                                                        THEN if_abap_behv=>fc-o-disabled
                                                        ELSE if_abap_behv=>fc-o-enabled )
                      %action-postAttachment  = COND #( WHEN lv_can_post = abap_true
                                                        THEN if_abap_behv=>fc-o-enabled
                                                        ELSE if_abap_behv=>fc-o-disabled ) )
        TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD uploadFile.
    DATA lt_create   TYPE TABLE FOR CREATE zi_upl_att_so.
    DATA lt_names    TYPE SORTED TABLE OF ztb_upl_att_so-file_name WITH UNIQUE KEY table_line.
    DATA lt_existing TYPE SORTED TABLE OF ztb_upl_att_so-file_name WITH NON-UNIQUE KEY table_line.
    DATA lt_range    TYPE RANGE OF ztb_upl_att_so-file_name.

    " File Name là key (phân biệt hoa thường) -> lấy các tên đã tồn tại
    lt_range = VALUE #( FOR ls_k IN keys WHERE ( %param-filename IS NOT INITIAL )
                        ( sign = 'I' option = 'EQ' low = ls_k-%param-filename ) ).
    IF lt_range IS NOT INITIAL.
      SELECT file_name FROM ztb_upl_att_so
        WHERE file_name IN @lt_range
        INTO TABLE @lt_existing.
    ENDIF.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      DATA(lv_name)  = <ls_key>-%param-filename.
      DATA(lv_size)  = CONV int8( xstrlen( <ls_key>-%param-filecontent ) ).
      DATA(lv_error) = VALUE string( ).

      IF lv_name IS INITIAL.
        lv_error = `Tên file không được để trống`.
      ELSEIF lv_size = 0.
        lv_error = |File { lv_name } không có nội dung|.
      ELSEIF lv_size > lcl_const=>max_file_size.
        lv_error = |File { lv_name } vượt quá dung lượng tối đa 10MB|.
      ELSEIF line_exists( lt_existing[ table_line = lv_name ] )
          OR line_exists( lt_names[ table_line = lv_name ] ).
        lv_error = |File Name { lv_name } đã tồn tại, không upload trùng|.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %cid = <ls_key>-%cid ) TO failed-uploadattachment.
        APPEND VALUE #( %cid = <ls_key>-%cid
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-error
                                                      iv_text     = lv_error ) )
          TO reported-uploadattachment.
        CONTINUE.
      ENDIF.

      INSERT lv_name INTO TABLE lt_names.
      APPEND VALUE #( %cid         = <ls_key>-%cid
                      FileName     = lv_name
                      MimeType     = lcl_util=>get_mime_type( iv_file_name = lv_name
                                                              iv_mime_type = <ls_key>-%param-mimetype )
                      Attachment   = <ls_key>-%param-filecontent
                      FileSize     = lv_size
                      FileSizeText = lcl_util=>get_size_text( lv_size )
                      Status       = lcl_const=>check_status-new
                      Message      = `Chưa kiểm tra - bấm Check attachment` )
        TO lt_create.
    ENDLOOP.

    IF lt_create IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_upl_att_so IN LOCAL MODE
      ENTITY UploadAttachment
        CREATE FIELDS ( FileName MimeType Attachment FileSize FileSizeText Status Message )
        WITH lt_create
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    APPEND LINES OF ls_mapped-uploadattachment   TO mapped-uploadattachment.
    APPEND LINES OF ls_failed-uploadattachment   TO failed-uploadattachment.
    APPEND LINES OF ls_reported-uploadattachment TO reported-uploadattachment.
  ENDMETHOD.

  METHOD checkAttachment.
    TYPES: BEGIN OF ty_parsed,
             uuid        TYPE sysuuid_x16,
             sales_order TYPE string,
             description TYPE string,
             so_key      TYPE i_salesorder-salesorder,
             errors      TYPE string_table,
           END OF ty_parsed.

    DATA lt_parsed  TYPE SORTED TABLE OF ty_parsed WITH UNIQUE KEY uuid.
    DATA lt_so_keys TYPE SORTED TABLE OF i_salesorder-salesorder WITH UNIQUE KEY table_line.
    DATA lt_update  TYPE TABLE FOR UPDATE zi_upl_att_so.

    READ ENTITIES OF zi_upl_att_so IN LOCAL MODE
      ENTITY UploadAttachment
        FIELDS ( FileName PostResult PostedAt ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows)
      FAILED DATA(ls_read_failed).
    APPEND LINES OF ls_read_failed-uploadattachment TO failed-uploadattachment.

    " 1. Tách tên file, gom danh sách SO cần kiểm tra
    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(ls_parsed) = VALUE ty_parsed( uuid = ls_row-Uuid ).
      lcl_util=>parse_file_name( EXPORTING iv_file_name   = ls_row-FileName
                                 IMPORTING ev_sales_order = ls_parsed-sales_order
                                           ev_description = ls_parsed-description
                                           et_errors      = ls_parsed-errors ).
      IF ls_parsed-sales_order <> lcl_const=>not_available.
        ls_parsed-so_key = lcl_util=>to_so_key( ls_parsed-sales_order ).
        INSERT ls_parsed-so_key INTO TABLE lt_so_keys.
      ENDIF.
      INSERT ls_parsed INTO TABLE lt_parsed.
    ENDLOOP.

    " 2. Chỉ chấp nhận chứng từ Sales Order (I_SalesOrder), không check quyền theo user
    IF lt_so_keys IS NOT INITIAL.
      SELECT FROM I_SalesOrder WITH PRIVILEGED ACCESS
        FIELDS SalesOrder
        FOR ALL ENTRIES IN @lt_so_keys
        WHERE SalesOrder = @lt_so_keys-table_line
        INTO TABLE @DATA(lt_so_found).
    ENDIF.

    " 3. Kết luận Ready / Error cho từng dòng
    LOOP AT lt_rows INTO ls_row.
      IF ls_row-PostResult = lcl_const=>post_result-success
         OR ( ls_row-PostResult = lcl_const=>post_result-in_process
              AND lcl_util=>is_stale( ls_row-PostedAt ) = abap_false ).
        APPEND VALUE #( %tky = ls_row-%tky
                        %msg = msg(
                                 iv_severity = if_abap_behv_message=>severity-warning
                                 iv_text     = |{ ls_row-FileName }: đã post / đang xử lý, không kiểm tra lại| ) )
          TO reported-uploadattachment.
        CONTINUE.
      ENDIF.

      ls_parsed = lt_parsed[ uuid = ls_row-Uuid ].
      IF ls_parsed-sales_order <> lcl_const=>not_available
         AND NOT line_exists( lt_so_found[ SalesOrder = ls_parsed-so_key ] ).
        APPEND |SO { ls_parsed-sales_order } không tồn tại| TO ls_parsed-errors.
      ENDIF.

      DATA(lv_ok) = xsdbool( ls_parsed-errors IS INITIAL ).

      " FE gọi action riêng cho từng dòng -> message theo từng file, ghi rõ lý do
      APPEND VALUE #( %tky = ls_row-%tky
                      %msg = COND #(
                        WHEN lv_ok = abap_true
                          THEN msg( iv_severity = if_abap_behv_message=>severity-success
                                    iv_text     = |{ ls_row-FileName }: hợp lệ - sẵn sàng post| )
                        ELSE msg( iv_severity = if_abap_behv_message=>severity-error
                                  iv_text     = |{ ls_row-FileName }: | &&
                                                |{ concat_lines_of( table = ls_parsed-errors sep = `; ` ) }| ) ) )
        TO reported-uploadattachment.

      APPEND VALUE #( %tky         = ls_row-%tky
                      SalesOrder   = ls_parsed-sales_order
                      Description  = ls_parsed-description
                      Status       = COND #( WHEN lv_ok = abap_true THEN lcl_const=>check_status-ready
                                             ELSE lcl_const=>check_status-error )
                      PostResult   = ''
                      AttDocNumber = ''
                      Message      = COND #( WHEN lv_ok = abap_true THEN `Hợp lệ - sẵn sàng post`
                                             ELSE concat_lines_of( table = ls_parsed-errors sep = `; ` ) ) )
        TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_upl_att_so IN LOCAL MODE
        ENTITY UploadAttachment
          UPDATE FIELDS ( SalesOrder Description Status PostResult AttDocNumber Message )
          WITH lt_update
        FAILED   DATA(ls_upd_failed)
        REPORTED DATA(ls_upd_reported).
      APPEND LINES OF ls_upd_failed-uploadattachment   TO failed-uploadattachment.
      APPEND LINES OF ls_upd_reported-uploadattachment TO reported-uploadattachment.
    ENDIF.

    " Trả kết quả (không đọc field Attachment để tránh load nội dung file)
    READ ENTITIES OF zi_upl_att_so IN LOCAL MODE
      ENTITY UploadAttachment
        FIELDS ( FileName MimeType SalesOrder Description FileSize FileSizeText Status PostResult
                 Message AttDocNumber PostedBy PostedAt CreatedBy CreatedAt
                 LastChangedBy LocalLastChangedAt LastChangedAt )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_after).

    result = VALUE #( FOR ls_after IN lt_after ( %tky = ls_after-%tky %param = ls_after ) ).
  ENDMETHOD.

  METHOD postAttachment.
    DATA lt_update TYPE TABLE FOR UPDATE zi_upl_att_so.
    DATA lv_now    TYPE timestampl.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user) = CONV syuname( cl_abap_context_info=>get_user_technical_name( ) ).

    READ ENTITIES OF zi_upl_att_so IN LOCAL MODE
      ENTITY UploadAttachment
        FIELDS ( FileName Status PostResult PostedAt ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows)
      FAILED DATA(ls_read_failed).
    APPEND LINES OF ls_read_failed-uploadattachment TO failed-uploadattachment.

    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(lv_reason) = COND string(
        WHEN ls_row-Status <> lcl_const=>check_status-ready
          THEN |{ ls_row-FileName }: chưa ở trạng thái Ready, hãy Check attachment trước|
        WHEN ls_row-PostResult = lcl_const=>post_result-success
          THEN |{ ls_row-FileName }: đã post thành công trước đó|
        WHEN ls_row-PostResult = lcl_const=>post_result-in_process
             AND lcl_util=>is_stale( ls_row-PostedAt ) = abap_false
          THEN |{ ls_row-FileName }: đang được xử lý nền| ).

      IF lv_reason IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_row-%tky
                        %msg = msg( iv_severity = if_abap_behv_message=>severity-warning
                                                      iv_text     = lv_reason ) )
          TO reported-uploadattachment.
        CONTINUE.
      ENDIF.

      " Ready + (chưa post / post lỗi / treo quá 30 phút) -> đưa vào job
      APPEND VALUE #( %tky = ls_row-%tky
                      %msg = msg( iv_severity = if_abap_behv_message=>severity-success
                                  iv_text     = |{ ls_row-FileName }: đã đưa vào job nền, | &&
                                                |bấm Go sau ít phút để xem kết quả| ) )
        TO reported-uploadattachment.

      APPEND VALUE #( %tky         = ls_row-%tky
                      PostResult   = lcl_const=>post_result-in_process
                      Message      = `Đang xử lý nền - bấm Go để cập nhật kết quả`
                      AttDocNumber = ''
                      PostedBy     = lv_user
                      PostedAt     = lv_now )
        TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      " Job được lên lịch trong save_modified (lsc_zi_upl_att_so)
      MODIFY ENTITIES OF zi_upl_att_so IN LOCAL MODE
        ENTITY UploadAttachment
          UPDATE FIELDS ( PostResult Message AttDocNumber PostedBy PostedAt )
          WITH lt_update
        FAILED   DATA(ls_upd_failed)
        REPORTED DATA(ls_upd_reported).
      APPEND LINES OF ls_upd_failed-uploadattachment   TO failed-uploadattachment.
      APPEND LINES OF ls_upd_reported-uploadattachment TO reported-uploadattachment.
    ENDIF.

    READ ENTITIES OF zi_upl_att_so IN LOCAL MODE
      ENTITY UploadAttachment
        FIELDS ( FileName MimeType SalesOrder Description FileSize FileSizeText Status PostResult
                 Message AttDocNumber PostedBy PostedAt CreatedBy CreatedAt
                 LastChangedBy LocalLastChangedAt LastChangedAt )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_after).

    result = VALUE #( FOR ls_after IN lt_after ( %tky = ls_after-%tky %param = ls_after ) ).
  ENDMETHOD.

  METHOD validateFileName.
    " Chốt chặn cuối: 2 user upload cùng File Name cùng lúc
    READ ENTITIES OF zi_upl_att_so IN LOCAL MODE
      ENTITY UploadAttachment
        FIELDS ( FileName ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).

    IF lt_rows IS INITIAL.
      RETURN.
    ENDIF.

    SELECT uuid, file_name FROM ztb_upl_att_so
      FOR ALL ENTRIES IN @lt_rows
      WHERE file_name = @lt_rows-FileName
      INTO TABLE @DATA(lt_db).

    LOOP AT lt_rows INTO DATA(ls_row).
      IF line_exists( lt_db[ file_name = ls_row-FileName ] )
         AND NOT line_exists( lt_db[ file_name = ls_row-FileName uuid = ls_row-Uuid ] ).
        APPEND VALUE #( %tky = ls_row-%tky ) TO failed-uploadattachment.
        APPEND VALUE #( %tky              = ls_row-%tky
                        %element-FileName = if_abap_behv=>mk-on
                        %msg              = msg(
                                              iv_severity = if_abap_behv_message=>severity-error
                                              iv_text     = |File Name { ls_row-FileName } đã tồn tại| ) )
          TO reported-uploadattachment.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD msg.
    lcl_util=>split_text( EXPORTING iv_text = iv_text
                          IMPORTING ev_v1   = DATA(lv_v1)
                                    ev_v2   = DATA(lv_v2)
                                    ev_v3   = DATA(lv_v3)
                                    ev_v4   = DATA(lv_v4) ).
    ro_msg = new_message( id       = lcl_const=>msg_class
                          number   = lcl_const=>msg_number
                          severity = iv_severity
                          v1       = lv_v1
                          v2       = lv_v2
                          v3       = lv_v3
                          v4       = lv_v4 ).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_zi_upl_att_so DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.
    METHODS msg
      IMPORTING iv_severity   TYPE if_abap_behv_message=>t_severity
                iv_text       TYPE csequence
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.
ENDCLASS.

CLASS lsc_zi_upl_att_so IMPLEMENTATION.

  METHOD save_modified.
    DATA lt_uuid TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    " Các dòng vừa được action postAttachment chuyển sang In process
    LOOP AT update-uploadattachment ASSIGNING FIELD-SYMBOL(<ls_upd>)
         WHERE %control-PostResult = if_abap_behv=>mk-on
           AND PostResult = lcl_const=>post_result-in_process.
      APPEND <ls_upd>-Uuid TO lt_uuid.
    ENDLOOP.

    IF lt_uuid IS INITIAL.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD DATA(lv_start).

    " 1 lần bấm Post = 1 job, xử lý tuần tự các file đã chọn
    TRY.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = CONV cl_apj_rt_api=>ty_template_name( lcl_const=>job_template )
            iv_job_text            = |Upload Attachment SO { lv_start TIMESTAMP = ISO }|
            is_start_info          = VALUE #( timestamp = cl_abap_tstmp=>add( tstmp = lv_start secs = 1 ) )
            is_end_info            = VALUE #( type = 'NUM' max_iterations = 1 )
            is_scheduling_info     = VALUE #( periodic_value = 1
                                              test_mode      = abap_false
                                              timezone       = 'UTC' )
            it_job_parameter_value = VALUE #(
              ( name    = lcl_const=>job_param_id
                t_value = VALUE #( FOR lv_id IN lt_uuid ( sign = 'I' option = 'EQ' low = lv_id ) ) ) ) ).
      CATCH cx_apj_rt INTO DATA(lx_job).
        " Dòng vẫn In process -> sau 30 phút được phép Post lại
        LOOP AT lt_uuid INTO DATA(lv_uuid).
          APPEND VALUE #( Uuid = lv_uuid
                          %msg = msg(
                                   iv_severity = if_abap_behv_message=>severity-error
                                   iv_text     = |Không lên lịch được job: { lx_job->get_longtext( ) }| ) )
            TO reported-uploadattachment.
        ENDLOOP.
    ENDTRY.
  ENDMETHOD.

  METHOD msg.
    lcl_util=>split_text( EXPORTING iv_text = iv_text
                          IMPORTING ev_v1   = DATA(lv_v1)
                                    ev_v2   = DATA(lv_v2)
                                    ev_v3   = DATA(lv_v3)
                                    ev_v4   = DATA(lv_v4) ).
    ro_msg = new_message( id       = lcl_const=>msg_class
                          number   = lcl_const=>msg_number
                          severity = iv_severity
                          v1       = lv_v1
                          v2       = lv_v2
                          v3       = lv_v3
                          v4       = lv_v4 ).
  ENDMETHOD.

ENDCLASS.
