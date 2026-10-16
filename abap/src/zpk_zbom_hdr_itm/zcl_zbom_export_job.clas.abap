CLASS zcl_zbom_export_job DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    CONSTANTS selection_name TYPE c LENGTH 8 VALUE 'BATCH_ID'.

    " Số header xử lý trong MỘT job (một mail).
    CONSTANTS chunk_size TYPE i VALUE 5000.

    " Số header mỗi task song song. 5000 / 50 = 100 task. Số task KHÔNG quyết
    " định tải hệ thống; tải do max_parallel / max_percentage bên dưới quyết định.
    CONSTANTS task_size TYPE i VALUE 50.

    " Giới hạn song song: tối đa 8 task chạy cùng lúc VÀ không quá 25% số
    " dialog process dành cho aRFC (framework lấy giới hạn chặt hơn). Task chạy
    " trên dialog process, cùng loại với người dùng Fiori; mặc định của
    " CL_ABAP_PARALLEL là 50% và gần như không giới hạn số task đồng thời.
    CONSTANTS max_parallel   TYPE i VALUE 8.
    CONSTANTS max_percentage TYPE i VALUE 25.

    " Thời gian tối đa cho MỘT task (giây). Task 50 header bình thường ~30 s,
    " giá trị này chỉ để chặn treo: mặc định lấy max runtime của session, trong
    " background job có thể là vô hạn, khi đó 1 task treo làm cả job chờ mãi.
    CONSTANTS task_timeout TYPE i VALUE 1800.

    " File CSV của từng chunk lưu vào OneDrive qua Microsoft Graph, không gửi
    " đính kèm qua mail (file > 25 MB bị mail server chặn). Kết nối qua
    " communication arrangement của scenario ZCS_ZBOM_GRAPH (OAuth 2.0 client
    " credentials, app Entra "SAP S4 ZBOM Export", path prefix /v1.0).
    CONSTANTS graph_scenario TYPE if_com_management=>ty_cscn_id VALUE 'ZCS_ZBOM_GRAPH'.
    CONSTANTS graph_service  TYPE if_com_management=>ty_cscn_outb_srv_id VALUE 'ZOS_ZBOM_GRAPH_REST'.

    " OneDrive của anh Đoàn Văn Bách (app chỉ được cấp quyền ghi vào site này)
    " và folder "EXPLODE BOM-PUBLIC" trong đó. Mỗi lần export tạo 1 folder con.
    CONSTANTS graph_site_id   TYPE string
      VALUE 'ctcpcasablanca-my.sharepoint.com,640c6d67-f532-47f3-bc6f-e06c22422cca,8170d8d3-4fd4-45ca-8548-f39bf145fbfc'.
    CONSTANTS graph_parent_id TYPE string VALUE '01FMB4WI5RYKZJK52C5ZDLMTKYATAKD4M3'.

    " Giờ đặt tên folder: created_at lưu theo UTC, người dùng ở Việt Nam.
    CONSTANTS folder_time_zone TYPE c LENGTH 6 VALUE 'UTC+7'.

    TYPES tt_zce_zbom_detail TYPE STANDARD TABLE OF zce_zbom_detail WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_drive_item,
             id      TYPE string,
             name    TYPE string,
             web_url TYPE string,
           END OF ty_drive_item.

    METHODS process
      IMPORTING iv_batch_id TYPE ztb_zbom_exp_bat-batch_id
      EXPORTING et_log      TYPE string_table.

    METHODS explode_and_get_items
      IMPORTING it_headers       TYPE zcl_zbom_export_sel=>tt_headers
      EXPORTING et_items         TYPE tt_zce_zbom_detail
                ev_fallback      TYPE i
                ev_fallback_info TYPE string.

    METHODS build_csv
      IMPORTING it_items      TYPE tt_zce_zbom_detail
      RETURNING VALUE(rv_csv) TYPE xstring.

    METHODS build_folder_name
      IMPORTING iv_uname       TYPE syuname
                iv_created_at  TYPE timestampl
      RETURNING VALUE(rv_name) TYPE string.

    METHODS graph_request
      IMPORTING iv_method       TYPE if_web_http_client=>method
                iv_path         TYPE string
                iv_json         TYPE string OPTIONAL
                iv_binary       TYPE xstring OPTIONAL
                iv_content_type TYPE string OPTIONAL
      EXPORTING ev_status       TYPE i
                ev_body         TYPE string.

    METHODS create_folder
      IMPORTING iv_name        TYPE string
      EXPORTING es_folder      TYPE ty_drive_item
                ev_error       TYPE string.

    METHODS upload_file
      IMPORTING iv_folder_id    TYPE string
                iv_file_name    TYPE string
                iv_content      TYPE xstring
      RETURNING VALUE(rv_error) TYPE string.

    METHODS create_view_link
      IMPORTING iv_folder_id  TYPE string
      RETURNING VALUE(rv_url) TYPE string.

    METHODS send_mail
      IMPORTING iv_uname   TYPE syuname
                iv_subject TYPE string
                iv_body    TYPE string.

    METHODS schedule_next_chunk
      IMPORTING iv_batch_id     TYPE ztb_zbom_exp_bat-batch_id
      RETURNING VALUE(rv_error) TYPE string.
ENDCLASS.


CLASS zcl_zbom_export_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname        = selection_name
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'C'
        length         = 32
        param_text     = 'Export batch ID'
        changeable_ind = abap_true ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    DATA lv_batch_id TYPE ztb_zbom_exp_bat-batch_id.

    LOOP AT it_parameters INTO DATA(ls_parameter) WHERE selname = selection_name.
      lv_batch_id = ls_parameter-low.
    ENDLOOP.

    IF lv_batch_id IS INITIAL.
      RETURN.
    ENDIF.

    process( iv_batch_id = lv_batch_id ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    " Chạy tay để chẩn đoán: lấy batch_id từ ztb_zbom_exp_bat, điền vào đây, F9.
    " Lưu ý: nó xử lý ĐÚNG MỘT chunk rồi schedule job thật cho chunk kế tiếp.
    DATA lv_batch_id TYPE ztb_zbom_exp_bat-batch_id VALUE ''.

    IF lv_batch_id IS INITIAL.
      out->write( 'Điền batch_id (bảng ztb_zbom_exp_bat) vào lv_batch_id rồi chạy lại.' ).
      RETURN.
    ENDIF.

    process( EXPORTING iv_batch_id = lv_batch_id
             IMPORTING et_log      = DATA(lt_log) ).

    LOOP AT lt_log INTO DATA(lv_line).
      out->write( lv_line ).
    ENDLOOP.

    COMMIT WORK.
  ENDMETHOD.


  METHOD process.
    CLEAR et_log.

    SELECT SINGLE * FROM ztb_zbom_exp_bat
      WHERE batch_id = @iv_batch_id
      INTO @DATA(ls_batch).
    IF sy-subrc <> 0.
      APPEND |Không tìm thấy batch { iv_batch_id }| TO et_log.
      RETURN.
    ENDIF.

    IF ls_batch-chunk_no IS INITIAL.
      " ===== Lần chạy đầu của batch: chốt danh sách header một lần =====
      SELECT * FROM ztb_zbom_exp_flt
        WHERE batch_id = @iv_batch_id
        ORDER BY seq
        INTO TABLE @DATA(lt_flt).

      DATA lt_ranges TYPE zcl_zbom_export_sel=>tt_filter_range.
      LOOP AT lt_flt INTO DATA(ls_flt).
        APPEND VALUE #( field_name = ls_flt-field_name
                        sign       = ls_flt-sign_
                        option     = ls_flt-opt
                        low        = ls_flt-low
                        high       = ls_flt-high ) TO lt_ranges.
        APPEND |Filter: { ls_flt-field_name } { ls_flt-sign_ }{ ls_flt-opt } | &&
               |'{ ls_flt-low }' '{ ls_flt-high }'| TO et_log.
      ENDLOOP.

      APPEND |BOM category: { ls_batch-bomcategory }, | &&
             |search: '{ ls_batch-search_text }'| TO et_log.

      DATA lt_unmapped TYPE string_table.

      DATA(lt_headers_all) = NEW zcl_zbom_export_sel( )->select_headers(
        EXPORTING it_ranges          = lt_ranges
                  iv_bomcategory     = CONV string( ls_batch-bomcategory )
                  iv_search          = CONV string( ls_batch-search_text )
        IMPORTING et_unmapped_fields = lt_unmapped ).

      IF lt_unmapped IS NOT INITIAL.
        APPEND |Bộ lọc có trường chưa hỗ trợ: | &&
               |{ concat_lines_of( table = lt_unmapped sep = `, ` ) }| TO et_log.
        UPDATE ztb_zbom_exp_bat SET status = 'E' WHERE batch_id = @iv_batch_id.
        COMMIT WORK.
        RETURN.
      ENDIF.

      APPEND |Header chọn được: { lines( lt_headers_all ) }| TO et_log.

      IF lt_headers_all IS INITIAL.
        UPDATE ztb_zbom_exp_bat SET status = 'D' WHERE batch_id = @iv_batch_id.
        COMMIT WORK.
        RETURN.
      ENDIF.

      DATA lt_hdr_db TYPE STANDARD TABLE OF ztb_zbom_exp_hdr WITH EMPTY KEY.
      LOOP AT lt_headers_all INTO DATA(ls_src).
        APPEND VALUE #(
          batch_id                   = iv_batch_id
          seq                        = sy-tabix
          billofmaterial             = ls_src-BillOfMaterial
          billofmaterialcategory     = ls_src-BillOfMaterialCategory
          material                   = ls_src-Material
          plant                      = ls_src-Plant
          billofmaterialvariantusage = ls_src-BillOfMaterialVariantUsage
          salesorder                 = ls_src-SalesOrder
          salesorderitem             = ls_src-SalesOrderItem
          requiredquantityheader     = ls_src-RequiredQuantityHeader
        ) TO lt_hdr_db.
      ENDLOOP.
      INSERT ztb_zbom_exp_hdr FROM TABLE @lt_hdr_db.

      ls_batch-chunk_no = 1.
      UPDATE ztb_zbom_exp_bat
        SET chunk_no = @ls_batch-chunk_no,
            status   = 'R'
        WHERE batch_id = @iv_batch_id.
      COMMIT WORK.
    ENDIF.

    " ===== Xử lý chunk hiện tại =====
    SELECT COUNT(*) FROM ztb_zbom_exp_hdr
      WHERE batch_id = @iv_batch_id
      INTO @DATA(lv_total).

    " Chia lên: ABAP chia số nguyên là LÀM TRÒN, không cắt, nên phải ceil.
    DATA(lv_chunk_total) = CONV i( ceil( lv_total / CONV decfloat34( chunk_size ) ) ).
    DATA(lv_from)        = ( ls_batch-chunk_no - 1 ) * chunk_size + 1.
    DATA(lv_to)          = ls_batch-chunk_no * chunk_size.

    SELECT * FROM ztb_zbom_exp_hdr
      WHERE batch_id = @iv_batch_id
        AND seq     >= @lv_from
        AND seq     <= @lv_to
      ORDER BY seq
      INTO TABLE @DATA(lt_hdr_chunk).

    APPEND |Chunk { ls_batch-chunk_no }/{ lv_chunk_total }: seq { lv_from }..{ lv_to }, | &&
           |lấy được { lines( lt_hdr_chunk ) } header (tổng { lv_total })| TO et_log.

    IF lt_hdr_chunk IS INITIAL.
      UPDATE ztb_zbom_exp_bat SET status = 'D' WHERE batch_id = @iv_batch_id.
      DELETE FROM ztb_zbom_exp_hdr WHERE batch_id = @iv_batch_id.
      COMMIT WORK.
      RETURN.
    ENDIF.

    DATA lt_headers TYPE zcl_zbom_export_sel=>tt_headers.
    LOOP AT lt_hdr_chunk INTO DATA(ls_hdr).
      APPEND VALUE #(
        BillOfMaterial             = ls_hdr-billofmaterial
        BillOfMaterialCategory     = ls_hdr-billofmaterialcategory
        Material                   = ls_hdr-material
        Plant                      = ls_hdr-plant
        BillOfMaterialVariantUsage = ls_hdr-billofmaterialvariantusage
        SalesOrder                 = ls_hdr-salesorder
        SalesOrderItem             = ls_hdr-salesorderitem
        RequiredQuantityHeader     = ls_hdr-requiredquantityheader
      ) TO lt_headers.
    ENDLOOP.

    " ===== Folder OneDrive của batch: chunk đầu tạo, các chunk sau dùng lại =====
    " Tạo trước khi explode: không kết nối được OneDrive thì dừng ngay, khỏi
    " explode vô ích.
    IF ls_batch-folder_id IS INITIAL.
      create_folder( EXPORTING iv_name   = build_folder_name( iv_uname      = ls_batch-uname
                                                              iv_created_at = ls_batch-created_at )
                     IMPORTING es_folder = DATA(ls_folder)
                               ev_error  = DATA(lv_folder_error) ).
      IF lv_folder_error IS NOT INITIAL.
        APPEND |Không tạo được folder OneDrive: { lv_folder_error }| TO et_log.
        send_mail( iv_uname   = ls_batch-uname
                   iv_subject = |ZBOM Excel Export - LOI|
                   iv_body    = |<p>Khong tao duoc folder tren OneDrive, export bi dung.</p>| &&
                                |<p>{ escape( val = lv_folder_error format = cl_abap_format=>e_html_text ) }</p>| ).
        UPDATE ztb_zbom_exp_bat SET status = 'E' WHERE batch_id = @iv_batch_id.
        DELETE FROM ztb_zbom_exp_hdr WHERE batch_id = @iv_batch_id.
        COMMIT WORK.
        RETURN.
      ENDIF.

      ls_batch-folder_id   = ls_folder-id.
      ls_batch-folder_name = ls_folder-name.
      ls_batch-folder_url  = ls_folder-web_url.
      UPDATE ztb_zbom_exp_bat
        SET folder_id   = @ls_batch-folder_id,
            folder_name = @ls_batch-folder_name,
            folder_url  = @ls_batch-folder_url
        WHERE batch_id = @iv_batch_id.
      COMMIT WORK.
      APPEND |Folder OneDrive: { ls_batch-folder_name }| TO et_log.
    ENDIF.

    DATA(lv_t0) = utclong_current( ).

    explode_and_get_items(
      EXPORTING it_headers       = lt_headers
      IMPORTING et_items         = DATA(lt_items)
                ev_fallback      = DATA(lv_fallback)
                ev_fallback_info = DATA(lv_fallback_info) ).

    DATA(lv_stats) = |{ lines( lt_headers ) } header, { lines( lt_items ) } dong, | &&
                     |explode { utclong_diff( high = utclong_current( ) low = lv_t0 ) DECIMALS = 0 } s, | &&
                     |task chay lai tuan tu: { lv_fallback }{ lv_fallback_info }|.
    APPEND lv_stats TO et_log.

    " ===== Upload file của chunk, ghi kết quả vào upload_log cho mail cuối =====
    DATA(lv_file_name) = |ZBOM_Explode_{ ls_batch-chunk_no WIDTH = 2 ALIGN = RIGHT PAD = '0' }.csv|.
    DATA lv_result TYPE string.

    IF lt_items IS INITIAL.
      lv_result = |{ lv_file_name }: khong co dong nao, khong tao file|.
    ELSE.
      DATA(lv_csv)          = build_csv( lt_items ).
      DATA(lv_upload_error) = upload_file( iv_folder_id = CONV #( ls_batch-folder_id )
                                           iv_file_name = lv_file_name
                                           iv_content   = lv_csv ).
      DATA(lv_size_mb) = xstrlen( lv_csv ) / CONV decfloat34( 1048576 ).
      lv_result = COND #(
        WHEN lv_upload_error IS INITIAL
        THEN |{ lv_file_name }: OK, { lines( lt_items ) } dong, { lv_size_mb DECIMALS = 1 } MB|
        ELSE |{ lv_file_name }: LOI upload - { lv_upload_error }| ).
    ENDIF.
    APPEND lv_result TO et_log.

    " Log của các chunk trước + chunk này. Cột giới hạn 1333 ký tự, quá thì
    " cắt phần cuối (mail vẫn có link folder để xem đủ file).
    DATA(lv_upload_log) = CONV string( ls_batch-upload_log ).
    lv_upload_log = COND #( WHEN lv_upload_log IS INITIAL THEN lv_result
                            ELSE |{ lv_upload_log }{ cl_abap_char_utilities=>newline }{ lv_result }| ).
    IF strlen( lv_upload_log ) > 1333.
      lv_upload_log = substring( val = lv_upload_log len = 1333 ).
    ENDIF.
    ls_batch-upload_log = lv_upload_log.
    UPDATE ztb_zbom_exp_bat SET upload_log = @ls_batch-upload_log WHERE batch_id = @iv_batch_id.
    COMMIT WORK.

    " ===== Nối chunk kế tiếp =====
    IF ls_batch-chunk_no < lv_chunk_total.
      UPDATE ztb_zbom_exp_bat
        SET chunk_no = @( ls_batch-chunk_no + 1 )
        WHERE batch_id = @iv_batch_id.
      " COMMIT trước khi schedule: job kế tiếp có thể khởi động ngay và
      " phải đọc được chunk_no mới.
      COMMIT WORK.

      DATA(lv_err) = schedule_next_chunk( iv_batch_id ).
      IF lv_err IS INITIAL.
        APPEND |Đã schedule chunk { ls_batch-chunk_no + 1 }| TO et_log.
        RETURN.
      ENDIF.

      APPEND |Không schedule được chunk sau: { lv_err }| TO et_log.
      UPDATE ztb_zbom_exp_bat SET status = 'E' WHERE batch_id = @iv_batch_id.
      COMMIT WORK.
      " Vẫn báo cho user những file đã lên OneDrive.
      lv_upload_log = |{ lv_upload_log }{ cl_abap_char_utilities=>newline }| &&
                      |Khong chay duoc phan { ls_batch-chunk_no + 1 }/{ lv_chunk_total }: { lv_err }|.
    ELSE.
      UPDATE ztb_zbom_exp_bat SET status = 'D' WHERE batch_id = @iv_batch_id.
      DELETE FROM ztb_zbom_exp_hdr WHERE batch_id = @iv_batch_id.
      COMMIT WORK.
      APPEND 'Xong toàn bộ batch.' TO et_log.
    ENDIF.

    " ===== Job cuối (hoặc bị dừng giữa chừng): mail link folder cho user =====
    DATA(lv_link) = create_view_link( CONV #( ls_batch-folder_id ) ).
    IF lv_link IS INITIAL.
      lv_link = ls_batch-folder_url.
    ENDIF.

    " Mail HTML: tên folder là link (link Graph rất dài), mỗi file một dòng.
    DATA(lv_log_html) = escape( val = lv_upload_log format = cl_abap_format=>e_html_text ).
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_log_html WITH `<br>`.
    send_mail(
      iv_uname   = ls_batch-uname
      iv_subject = |ZBOM Excel Export - { ls_batch-folder_name }|
      iv_body    = |<p>ZBOM Excel export da xong { ls_batch-chunk_no }/{ lv_chunk_total } phan.</p>| &&
                   |<p>Folder OneDrive: <a href="{ escape( val = lv_link format = cl_abap_format=>e_html_attr ) }">| &&
                   |{ escape( val = ls_batch-folder_name format = cl_abap_format=>e_html_text ) }</a></p>| &&
                   |<p>Ket qua tung file:<br>{ lv_log_html }</p>| ).
  ENDMETHOD.


  METHOD schedule_next_chunk.
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
    range_value-low    = iv_batch_id.
    job_parameter-name = selection_name.
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
        rv_error = lx_error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD explode_and_get_items.
    DATA lt_in   TYPE cl_abap_parallel=>t_in_inst_tab.
    DATA lt_out  TYPE cl_abap_parallel=>t_out_inst_tab.
    DATA ls_out  TYPE cl_abap_parallel=>t_out_inst.
    DATA lt_orig TYPE STANDARD TABLE OF REF TO zcl_zbom_export_task WITH EMPTY KEY.
    DATA lo_back TYPE REF TO zcl_zbom_export_task.

    CLEAR: et_items, ev_fallback, ev_fallback_info.

    " Chia header thành từng nhóm task_size, mỗi nhóm là một task.
    DATA(lv_count) = lines( it_headers ).
    DATA(lv_from)  = 1.

    WHILE lv_from <= lv_count.
      DATA(lv_to) = nmin( val1 = lv_from + task_size - 1 val2 = lv_count ).

      DATA(lo_task) = NEW zcl_zbom_export_task(
        it_headers = VALUE #( FOR i = lv_from THEN i + 1 UNTIL i > lv_to
                              ( it_headers[ i ] ) )
        iv_offset  = lv_from - 1 ).

      APPEND lo_task TO lt_in.
      APPEND lo_task TO lt_orig.
      lv_from = lv_to + 1.
    ENDWHILE.

    NEW cl_abap_parallel( p_num_tasks  = max_parallel
                          p_percentage = max_percentage
                          p_timeout    = task_timeout )->run_inst(
      EXPORTING p_in_tab  = lt_in
      IMPORTING p_out_tab = lt_out ).

    " Theo tài liệu CL_ABAP_PARALLEL: lt_out cùng số dòng, cùng thứ tự với
    " lt_in, INDEX là vị trí task. Task không hoàn thành thì INST rỗng và
    " MESSAGE chứa lý do (timeout, runtime error...). Những task đó chạy lại
    " tuần tự ngay tại đây để không mất dòng.
    LOOP AT lt_orig INTO DATA(lo_orig).
      DATA(lv_index) = sy-tabix.

      CLEAR: ls_out, lo_back.
      READ TABLE lt_out INTO ls_out WITH KEY index = lv_index.
      IF sy-subrc = 0 AND ls_out-inst IS BOUND.
        lo_back = CAST #( ls_out-inst ).
      ENDIF.

      IF lo_back IS BOUND AND lo_back->mv_done = abap_true.
        APPEND LINES OF lo_back->mt_items TO et_items.
      ELSE.
        lo_orig->if_abap_parallel~do( ).
        APPEND LINES OF lo_orig->mt_items TO et_items.
        ev_fallback = ev_fallback + 1.
        ev_fallback_info = |{ ev_fallback_info } [{ lo_orig->mv_offset + 1 }-| &&
                           |{ lo_orig->mv_offset + lines( lo_orig->mt_headers ) }: | &&
                           |{ ls_out-message }]|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_csv.
    DATA lt_lines TYPE string_table.

    " Dòng đầu ép Excel dùng đúng dấu ';' làm delimiter, không phụ thuộc
    " cấu hình vùng miền của Excel người mở file
    APPEND |sep=;| TO lt_lines.
    APPEND |BOM Level;Tree View;Material;Material Description;Plant;BOM Category;Sales Order;Sales Order Item;| &&
           |Required Quantity;Component;Component Description;Component Quantity;| &&
           |Item Category;Item Number;Assembly Indicator;Material Type;Base Unit;| &&
           |Maintenance Status;Valid From;Change Number;Created On;Created By;| &&
           |Changed On;Changed By;Item Spare Part Indicator;Component Scrap in Percent| TO lt_lines.

    " Gom từng dòng vào bảng rồi nối 1 lần ở cuối: nối chuỗi dồn trong vòng
    " lặp có thể phải sao chép lại toàn bộ chuỗi mỗi lần, rất chậm khi file lớn.
    LOOP AT it_items INTO DATA(ls_item).
      APPEND |{ ls_item-BomExplosionLevel };{ ls_item-TreeView };{ ls_item-MaterialHeader };| &&
             |{ ls_item-MaterialDescription };| &&
             |{ ls_item-Plant };{ ls_item-BillOfMaterialCategory };{ ls_item-SalesOrder };| &&
             |{ ls_item-SalesOrderItem };{ ls_item-RequiredQuantityHeader };| &&
             |{ ls_item-BillOfMaterialComponent };{ ls_item-ComponentDescription };| &&
             |{ ls_item-BomCompQuant };{ ls_item-BillOfMaterialItemCategory };| &&
             |{ ls_item-BillOfMaterialItemNumber };{ ls_item-IsAssembly };| &&
             |{ ls_item-MaterialType };{ ls_item-BillOfMaterialItemUnit };| &&
             |{ ls_item-MaintenanceStatus };{ ls_item-ValidityStartDate };| &&
             |{ ls_item-ChangeNumber };{ ls_item-CreatedOn };{ ls_item-CreatedBy };| &&
             |{ ls_item-ChangedOn };{ ls_item-ChangedBy };{ ls_item-IsBomItemSparePart };| &&
             |{ ls_item-ComponentScrapInPercent }| TO lt_lines.
    ENDLOOP.

    DATA(lv_crlf) = cl_abap_char_utilities=>cr_lf.
    DATA(lv_csv)  = concat_lines_of( table = lt_lines sep = lv_crlf ) && lv_crlf.

    rv_csv = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( source = lv_csv ).
  ENDMETHOD.


  METHOD build_folder_name.
    " "ZBOM - <tên user> - yyyyMMdd - HHmmss", giờ Việt Nam lúc bấm export.
    SELECT SINGLE FROM i_businessuserbasic
      FIELDS PersonFullName
      WHERE UserID = @iv_uname
      INTO @DATA(lv_full_name).
    DATA(lv_user) = COND string( WHEN lv_full_name IS NOT INITIAL THEN lv_full_name
                                 ELSE iv_uname ).

    " Ký tự OneDrive không cho dùng trong tên folder.
    lv_user = replace( val = lv_user pcre = `["*:<>?/\\|]` with = ` ` occ = 0 ).
    lv_user = condense( lv_user ).

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    CONVERT TIME STAMP iv_created_at TIME ZONE folder_time_zone INTO DATE lv_date TIME lv_time.

    rv_name = |ZBOM - { lv_user } - { lv_date } - { lv_time }|.
  ENDMETHOD.


  METHOD graph_request.
    " Một lời gọi Microsoft Graph qua communication arrangement của
    " ZCS_ZBOM_GRAPH. iv_path tính từ /v1.0 (path prefix của outbound service).
    CLEAR: ev_status, ev_body.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
          comm_scenario = graph_scenario
          service_id    = graph_service ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( i_uri_path = iv_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        IF iv_json IS NOT INITIAL.
          lo_request->set_content_type( 'application/json' ).
          lo_request->set_text( iv_json ).
        ELSEIF iv_binary IS NOT INITIAL.
          lo_request->set_content_type( iv_content_type ).
          lo_request->set_binary( iv_binary ).
        ENDIF.

        DATA(lo_response) = lo_client->execute( iv_method ).
        ev_status = lo_response->get_status( )-code.
        ev_body   = lo_response->get_text( ).
        lo_client->close( ).
      CATCH cx_root INTO DATA(lx_error).
        ev_status = 0.
        ev_body   = lx_error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD create_folder.
    " Trùng tên (2 lần export trong cùng 1 giây) thì OneDrive tự thêm số.
    CLEAR: es_folder, ev_error.

    graph_request(
      EXPORTING iv_method = if_web_http_client=>post
                iv_path   = |/sites/{ graph_site_id }/drive/items/{ graph_parent_id }/children|
                iv_json   = |\{"name":"{ iv_name }","folder":\{\},| &&
                            |"@microsoft.graph.conflictBehavior":"rename"\}|
      IMPORTING ev_status = DATA(lv_status)
                ev_body   = DATA(lv_body) ).

    IF lv_status <> 200 AND lv_status <> 201.
      ev_error = |HTTP { lv_status }: { lv_body }|.
      RETURN.
    ENDIF.

    /ui2/cl_json=>deserialize( EXPORTING json        = lv_body
                                         pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                               CHANGING  data        = es_folder ).
    IF es_folder-id IS INITIAL.
      ev_error = |Graph không trả về id folder: { lv_body }|.
    ENDIF.
  ENDMETHOD.


  METHOD upload_file.
    " Upload 1 lần (Graph cho phép file tới 250 MB với PUT .../content).
    graph_request(
      EXPORTING iv_method       = if_web_http_client=>put
                iv_path         = |/sites/{ graph_site_id }/drive/items/{ iv_folder_id }:/{ iv_file_name }:/content|
                iv_binary       = iv_content
                iv_content_type = 'text/csv'
      IMPORTING ev_status       = DATA(lv_status)
                ev_body         = DATA(lv_body) ).

    IF lv_status <> 200 AND lv_status <> 201.
      rv_error = |HTTP { lv_status }: { lv_body }|.
    ENDIF.
  ENDMETHOD.


  METHOD create_view_link.
    " Link chỉ xem, ai có link cũng mở được. Lỗi thì trả rỗng, bên gọi dùng
    " webUrl của folder thay thế.
    TYPES: BEGIN OF ty_link,
             web_url TYPE string,
           END OF ty_link,
           BEGIN OF ty_permission,
             link TYPE ty_link,
           END OF ty_permission.
    DATA ls_permission TYPE ty_permission.

    graph_request(
      EXPORTING iv_method = if_web_http_client=>post
                iv_path   = |/sites/{ graph_site_id }/drive/items/{ iv_folder_id }/createLink|
                iv_json   = |\{"type":"view","scope":"anonymous"\}|
      IMPORTING ev_status = DATA(lv_status)
                ev_body   = DATA(lv_body) ).

    IF lv_status <> 200 AND lv_status <> 201.
      RETURN.
    ENDIF.

    /ui2/cl_json=>deserialize( EXPORTING json        = lv_body
                                         pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                               CHANGING  data        = ls_permission ).
    rv_url = ls_permission-link-web_url.
  ENDMETHOD.


  METHOD send_mail.
    " Dùng uname lưu trong batch, KHÔNG dùng sy-uname: job chunk sau do job
    " trước schedule nên sy-uname có thể không còn là người bấm nút.
    SELECT SINGLE FROM i_businessuserbasic
      FIELDS \_WorkplaceAddress-DefaultEmailAddress AS email
      WHERE UserID = @iv_uname
      INTO @DATA(lv_email).

    IF lv_email IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_mail) = cl_bcs_mail_message=>create_instance( ).

        lo_mail->set_sender( CONV #( lv_email ) ).
        lo_mail->add_recipient( iv_address = CONV #( lv_email )
                                iv_copy    = cl_bcs_mail_message=>to ).
        lo_mail->set_subject( CONV #( iv_subject ) ).
        lo_mail->set_main( cl_bcs_mail_textpart=>create_instance(
          iv_content      = iv_body
          iv_content_type = 'text/html' ) ).

        lo_mail->send( ).
        COMMIT WORK.
      CATCH cx_root.
        " File đã nằm trên OneDrive; mail lỗi thì user vẫn vào folder được.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
