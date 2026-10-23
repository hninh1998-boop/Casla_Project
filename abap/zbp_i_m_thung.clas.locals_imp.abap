CLASS lhc_ManageFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In process
      END OF file_status.

    " Thứ tự cột của template upload (dòng 1 = header, dòng 2 = hướng dẫn, dữ liệu từ dòng 3)
    TYPES: BEGIN OF ty_file_upload,
             Type            TYPE string,
             SoKhsx          TYPE string,
             SoThung         TYPE string,
             Material        TYPE string,
             Batch           TYPE string,
             Quantity        TYPE string,
             StorageLocation TYPE string,
             Customer        TYPE string,
             NgayNhapKho     TYPE string,
             Tem             TYPE string,
             KhoiLuong       TYPE string,
           END OF ty_file_upload.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ManageFile RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ManageFile.

    METHODS downloadTemplate FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~downloadTemplate.

    METHODS uploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~uploadExcel.

    METHODS setStatusToOpen FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ManageFile~setStatusToOpen.

    METHODS getExcelData FOR DETERMINE ON SAVE
      IMPORTING keys FOR ManageFile~getExcelData.

    METHODS parse_date
      IMPORTING iv_value       TYPE string
      RETURNING VALUE(rv_date) TYPE d.

    METHODS parse_so_khsx
      IMPORTING iv_value          TYPE string
      RETURNING VALUE(rv_so_khsx) TYPE ztb_d_thung-so_khsx.

    METHODS parse_tem
      IMPORTING iv_value      TYPE string
      RETURNING VALUE(rv_tem) TYPE ztb_d_thung-tem.

ENDCLASS.

CLASS lhc_ManageFile IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


  METHOD earlynumbering_create.
    LOOP AT entities
               ASSIGNING FIELD-SYMBOL(<f_entities>)
               WHERE uuid IS NOT INITIAL.

      APPEND CORRESPONDING #( <f_entities> ) TO mapped-managefile.

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
                 TO reported-managefile.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft )
                 TO failed-managefile.

          EXIT.
      ENDTRY.

      APPEND VALUE #( %cid      = <f_entities>-%cid
                      %key      = <f_entities>-%key
                      %is_draft = <f_entities>-%is_draft )
       TO mapped-managefile.
    ENDLOOP.
  ENDMETHOD.


  METHOD downloadTemplate.
    " Template được sinh ở frontend (ExcelJS) sau khi action chạy xong
  ENDMETHOD.


  METHOD uploadExcel.
    DATA lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_mn_file TYPE TABLE FOR CREATE zi_m_thung,
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

    MODIFY ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY ManageFile
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


  METHOD setStatusToOpen.
    READ ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY ManageFile
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
      FROM ztb_m_thung
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt1.

    SELECT SINGLE MAX( zcount )
      FROM ztb_m_thungd
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt2.

    lv_next = COND i( WHEN lv_cnt1 >= lv_cnt2 THEN lv_cnt1 + 1 ELSE lv_cnt2 + 1 ).

    MODIFY ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY ManageFile
        UPDATE FIELDS ( status zcount )
        WITH VALUE #( FOR ls_file IN lt_file ( %tky   = ls_file-%tky
                                               status = file_status-open
                                               zcount = lv_next ) ).
  ENDMETHOD.


  METHOD getExcelData.
    DATA: lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_file_c TYPE TABLE FOR CREATE zi_m_thung\\ManageFile\_datafile,
          ls_file_c LIKE LINE OF lt_file_c.

    " ── 1. Read parent instance ───────────────────────────────────
    READ ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY ManageFile
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
          lv_material TYPE string,
          lv_quantity TYPE ztb_d_thung-quantity,
          lt_check    TYPE zcl_thung_implement=>tt_data.

    LOOP AT lt_file INTO DATA(ls_file).
      " Bỏ qua dòng trống
      IF ls_file-Type IS INITIAL AND ls_file-SoThung IS INITIAL AND ls_file-Material IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_index = lv_index + 1.

      lv_material = to_upper( condense( ls_file-Material ) ).
      IF lv_material IS NOT INITIAL AND lv_material CO '0123456789'.
        lv_material = |{ lv_material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
      ENDIF.

      " Số lượng: số thập phân dec(13,3), làm tròn 3 chữ số (20,1234 → 20,123); nhận cả dấu phẩy thập phân
      CLEAR lv_quantity.
      TRY.
          lv_quantity = round( val = CONV decfloat34( replace( val  = condense( ls_file-Quantity )
                                                               sub  = ','
                                                               with = '.' ) )
                               dec = 3 ).
        CATCH cx_sy_conversion_error.
          CLEAR lv_quantity.
      ENDTRY.

      ls_file_c = VALUE #(
          %tky    = <f_file>-%tky
          %target = VALUE #( (
          %cid    = |CID_D_{ lv_index }|

          Type            = to_upper( condense( ls_file-Type ) )
          SoKhsx          = parse_so_khsx( ls_file-SoKhsx )
          SoThung         = to_upper( condense( ls_file-SoThung ) )
          Material        = lv_material
          Batch           = condense( ls_file-Batch )
          Quantity        = lv_quantity
          StorageLocation = to_upper( condense( ls_file-StorageLocation ) )
          Customer        = to_upper( condense( ls_file-Customer ) )
          NgayNhapKho     = parse_date( ls_file-NgayNhapKho )
          Tem             = parse_tem( ls_file-Tem )
          " Khối lượng: text tự do, không kiểm tra
          KhoiLuong       = condense( ls_file-KhoiLuong )
        ) )
      ).

      APPEND ls_file_c TO lt_file_c.

      " Dữ liệu để kiểm tra ngay khi upload (cùng thứ tự với lt_file_c)
      DATA(ls_target) = ls_file_c-%target[ 1 ].
      APPEND VALUE #( uuidfile         = <f_file>-Uuid
                      type             = ls_target-Type
                      so_khsx          = ls_target-SoKhsx
                      so_thung         = ls_target-SoThung
                      material         = ls_target-Material
                      batch            = ls_target-Batch
                      quantity         = ls_target-Quantity
                      storage_location = ls_target-StorageLocation
                      customer         = ls_target-Customer
                      ngay_nhap_kho    = ls_target-NgayNhapKho
                      tem              = ls_target-Tem
                      khoi_luong       = ls_target-KhoiLuong ) TO lt_check.

      CLEAR ls_file_c.
    ENDLOOP.

    IF lt_file_c IS INITIAL.
      RETURN.
    ENDIF.

    " ── 3b. Kiểm tra lỗi ngay khi upload (không ghi dữ liệu) ──────
    " Lúc bấm Ghi dữ liệu sẽ kiểm tra lại, vì dữ liệu trong bảng có thể đã thay đổi
    zcl_thung_implement=>post( EXPORTING iv_check_only = abap_true
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
    MODIFY ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY ManageFile
      CREATE BY \_datafile
      FIELDS (
        Type
        SoKhsx
        SoThung
        Material
        Batch
        Quantity
        StorageLocation
        Customer
        NgayNhapKho
        Tem
        KhoiLuong
        Messagetype
        Message
      )
      WITH lt_file_c
      MAPPED   DATA(lt_mapped_create)
      REPORTED DATA(lt_mapped_reported)
      FAILED   DATA(lt_failed_create).

    " ── 5. Header: có dòng lỗi → In process (P), không có lỗi → giữ Not process (M)
    IF line_exists( lt_check[ messagetype = 'E' ] ).
      MODIFY ENTITIES OF zi_m_thung IN LOCAL MODE
        ENTITY ManageFile
        UPDATE FIELDS ( Status )
        WITH VALUE #( ( %tky   = <f_file>-%tky
                        Status = file_status-inprocess ) )
        FAILED   DATA(lt_failed_status)
        REPORTED DATA(lt_reported_status).
    ENDIF.
  ENDMETHOD.


  METHOD parse_date.
    DATA: lv_day   TYPE string,
          lv_month TYPE string,
          lv_year  TYPE string.

    DATA(lv_value) = condense( iv_value ).

    IF lv_value IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_value CO '0123456789' AND strlen( lv_value ) <= 6.
      " Excel serial date
      rv_date = CONV d( '18991230' ) + CONV i( lv_value ).

    ELSEIF strlen( lv_value ) >= 10 AND substring( val = lv_value off = 4 len = 1 ) = '-'.
      " YYYY-MM-DD
      rv_date = substring( val = lv_value off = 0 len = 4 )
             && substring( val = lv_value off = 5 len = 2 )
             && substring( val = lv_value off = 8 len = 2 ).

    ELSE.
      " DD/MM/YYYY
      REPLACE ALL OCCURRENCES OF '.' IN lv_value WITH '/'.
      REPLACE ALL OCCURRENCES OF '-' IN lv_value WITH '/'.
      SPLIT lv_value AT '/' INTO lv_day lv_month lv_year.

      IF strlen( lv_year ) > 4.
        lv_year = substring( val = lv_year off = 0 len = 4 ).
      ENDIF.

      IF strlen( lv_day ) BETWEEN 1 AND 2 AND strlen( lv_month ) BETWEEN 1 AND 2 AND strlen( lv_year ) = 4.
        rv_date = |{ lv_year }{ lv_month WIDTH = 2 ALIGN = RIGHT PAD = '0' }{ lv_day WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
      ENDIF.
    ENDIF.

    " Ngày không hợp lệ → để trống, lúc Post sẽ báo lỗi
    IF CONV i( rv_date ) = 0.
      CLEAR rv_date.
    ENDIF.
  ENDMETHOD.


  METHOD parse_so_khsx.
    " Giữ đúng dạng user nhập SO/SOITEM (vd 10001234/10): bỏ khoảng trắng và số 0 đầu của từng phần
    DATA: lv_so   TYPE string,
          lv_item TYPE string.

    DATA(lv_value) = to_upper( replace( val = iv_value sub = ` ` with = `` occ = 0 ) ).

    IF lv_value NS '/'.
      SHIFT lv_value LEFT DELETING LEADING '0'.
      rv_so_khsx = lv_value.
      RETURN.
    ENDIF.

    SPLIT lv_value AT '/' INTO lv_so lv_item.
    SHIFT lv_so   LEFT DELETING LEADING '0'.
    SHIFT lv_item LEFT DELETING LEADING '0'.

    rv_so_khsx = |{ lv_so }/{ lv_item }|.
  ENDMETHOD.


  METHOD parse_tem.
    DATA(lv_value) = to_upper( condense( iv_value ) ).

    IF lv_value IS INITIAL.
      RETURN.
    ENDIF.

    " KHÔNG TEM / K → K ; CÓ TEM / C / X → C
    IF lv_value(1) = 'K'.
      rv_tem = zcl_thung_implement=>tem-no.
    ELSEIF lv_value(1) = 'C' OR lv_value = 'X'.
      rv_tem = zcl_thung_implement=>tem-yes.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_DataFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In Process
      END OF file_status.

    " DataFile có action riêng nên framework vẫn gọi global authorization cho entity này
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DataFile RESULT result.

    METHODS PostConfirm FOR MODIFY
      IMPORTING keys FOR ACTION DataFile~PostConfirm RESULT result.

ENDCLASS.

CLASS lhc_DataFile IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


  METHOD PostConfirm.
    DATA lt_data TYPE zcl_thung_implement=>tt_data.

    " ── 1. SELECT ────────────────────────────────────────────────
    " Xử lý theo thùng nên lấy toàn bộ dòng chưa thành công của file, không chỉ dòng được chọn
    SELECT FROM ztb_d_thung
      FIELDS *
      FOR ALL ENTRIES IN @keys
      WHERE uuidfile    =  @keys-uuidfile
        AND messagetype <> 'S'
      INTO TABLE @lt_data.

    IF lt_data IS INITIAL.
      RETURN.
    ENDIF.

    " ── 2. Validate + ghi ZTB_CUSTOM_HU ──────────────────────────
    zcl_thung_implement=>post( CHANGING ct_data = lt_data ).

    " ── 3. Update status từng dòng ───────────────────────────────
    MODIFY ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY DataFile
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

    MODIFY ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY ManageFile
      UPDATE FIELDS ( status )
      WITH VALUE #( (
        %tky-uuid = lt_data[ 1 ]-uuidfile
        %is_draft = if_abap_behv=>mk-off
        status    = lv_new_status
      ) )
      FAILED   DATA(lt_hdr_failed)
      REPORTED DATA(lt_hdr_reported).

    " ── 5. Result ────────────────────────────────────────────────
    READ ENTITIES OF zi_m_thung IN LOCAL MODE
      ENTITY DataFile
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result ( %tky   = ls_result-%tky
                                                   %param = ls_result ) ).
  ENDMETHOD.

ENDCLASS.
