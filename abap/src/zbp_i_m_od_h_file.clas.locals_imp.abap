CLASS lcl_const DEFINITION.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In process
        error     TYPE c LENGTH 1 VALUE 'E', "Error
        success   TYPE c LENGTH 1 VALUE 'S', "Success
      END OF file_status,

      BEGIN OF msg_type,
        error     TYPE c LENGTH 1 VALUE 'E',
        scheduled TYPE c LENGTH 1 VALUE 'J',
        success   TYPE c LENGTH 1 VALUE 'S',
      END OF msg_type.

    CONSTANTS job_template TYPE c LENGTH 30 VALUE 'ZAJT_M_OD_HEAD'.
    CONSTANTS job_param_id TYPE c LENGTH 32 VALUE 'HDR_ID'.
ENDCLASS.


CLASS lhc_ManageFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR ManageFile RESULT result.

    METHODS uploadExcel FOR MODIFY
       keys FOR ACTION ManageFile~uploadExcel.

    METHODS setStatusOpen FOR DETERMINE ON MODIFY
       keys FOR ManageFile~setStatusOpen.

    METHODS validateFile FOR VALIDATE ON SAVE
       keys FOR ManageFile~validateFile.

ENDCLASS.

CLASS lhc_ManageFile IMPLEMENTATION.

  METHOD get_global_authorizations.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    result-%delete = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  METHOD uploadExcel.
    READ TABLE keys ASSIGNING FIELD-SYMBOL(<key>) INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF <key>-%param-filecontent IS INITIAL.
      APPEND VALUE #( %cid = <key>-%cid
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = `Excel content is mandatory` ) )
        TO reported-managefile.
      RETURN.
    ENDIF.

    TRY.
        DATA(rows) = zcl_m_od_h_parser=>parse( <key>-%param-filecontent ).
      CATCH zcx_m_od_h INTO DATA(parse_error).
        APPEND VALUE #( %cid = <key>-%cid
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = parse_error->text ) )
          TO reported-managefile.
        RETURN.
    ENDTRY.

    MODIFY ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY ManageFile
        CREATE FIELDS ( FileName FileMimeType Attachment Status )
        WITH VALUE #( ( %cid         = <key>-%cid
                        FileName     = <key>-%param-filename
                        FileMimeType = <key>-%param-mimetype
                        Attachment   = <key>-%param-filecontent
                        Status       = lcl_const=>file_status-open ) )
      ENTITY ManageFile
        CREATE BY \_DataFile
        FIELDS ( Od PlanGiDate IncoVers Incoterm IncoLoc1 IncoLoc2
                 NhaCungCapVanTai PhanLoaiPtvt SoLuongPtvt BienSoXe
                 SoContainer SoSeal TareWeight Booking NgayTauChay NgayGioXuatHang
                 CutOffTime GhiChuGiaoHang TyGiaLoNoiDia
                 HasPlanGiDate HasIncoVers HasIncoterm HasIncoLoc1 HasIncoLoc2
                 HasNhaCungCapVanTai HasPhanLoaiPtvt HasSoLuongPtvt
                 HasBienSoXe HasSoContainer HasSoSeal HasTareWeight HasBooking
                 HasNgayTauChay HasNgayGioXuatHang HasCutOffTime HasGhiChuGiaoHang
                 HasTyGiaLoNoiDia )
        WITH VALUE #( ( %cid_ref = <key>-%cid
          %target = VALUE #( FOR row IN rows
            ( %cid                = row-cid
              Od                  = row-od
              PlanGiDate          = row-plan_gi_date
              IncoVers            = row-inco_vers
              Incoterm            = row-incoterm
              IncoLoc1            = row-inco_loc1
              IncoLoc2            = row-inco_loc2
              NhaCungCapVanTai    = row-nha_cung_cap_van_tai
              PhanLoaiPtvt        = row-phan_loai_ptvt
              SoLuongPtvt         = row-so_luong_ptvt
              BienSoXe            = row-bien_so_xe
              SoContainer         = row-so_container
              SoSeal              = row-so_seal
              TareWeight          = row-tare_weight
              Booking             = row-booking
              NgayTauChay         = row-ngay_tau_chay
              NgayGioXuatHang     = row-ngay_gio_xuat_hang
              CutOffTime          = row-cut_off_time
              GhiChuGiaoHang      = row-ghi_chu_giao_hang
              TyGiaLoNoiDia       = row-ty_gia_lo_noi_dia
              HasPlanGiDate       = row-has_plan_gi_date
              HasIncoVers         = row-has_inco_vers
              HasIncoterm         = row-has_incoterm
              HasIncoLoc1         = row-has_inco_loc1
              HasIncoLoc2         = row-has_inco_loc2
              HasNhaCungCapVanTai = row-has_nha_cung_cap_van_tai
              HasPhanLoaiPtvt     = row-has_phan_loai_ptvt
              HasSoLuongPtvt      = row-has_so_luong_ptvt
              HasBienSoXe         = row-has_bien_so_xe
              HasSoContainer      = row-has_so_container
              HasSoSeal           = row-has_so_seal
              HasTareWeight       = row-has_tare_weight
              HasBooking          = row-has_booking
              HasNgayTauChay      = row-has_ngay_tau_chay
              HasNgayGioXuatHang  = row-has_ngay_gio_xuat_hang
              HasCutOffTime       = row-has_cut_off_time
              HasGhiChuGiaoHang   = row-has_ghi_chu_giao_hang
              HasTyGiaLoNoiDia    = row-has_ty_gia_lo_noi_dia ) ) ) )
      FAILED   DATA(create_failed)
      REPORTED DATA(create_reported).

    APPEND LINES OF create_failed-managefile   TO failed-managefile.
    APPEND LINES OF create_failed-datafile     TO failed-datafile.
    APPEND LINES OF create_reported-managefile TO reported-managefile.
    APPEND LINES OF create_reported-datafile   TO reported-datafile.
  ENDMETHOD.

  METHOD setStatusOpen.
    READ ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY ManageFile
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(files).

    DELETE files WHERE Status IS NOT INITIAL.
    IF files IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY ManageFile
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR file IN files
          ( %tky            = file-%tky
            Status          = lcl_const=>file_status-open
            %control-Status = if_abap_behv=>mk-on ) ).
  ENDMETHOD.

  METHOD validateFile.
    READ ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY ManageFile
        FIELDS ( FileName ) WITH CORRESPONDING #( keys )
      RESULT DATA(files).

    LOOP AT files INTO DATA(file) WHERE FileName IS INITIAL.
      APPEND VALUE #( %tky = file-%tky ) TO failed-managefile.
      APPEND VALUE #( %tky              = file-%tky
                      %element-FileName = if_abap_behv=>mk-on
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = `Excel file name is mandatory` ) )
        TO reported-managefile.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_DataFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR DataFile RESULT result.

    METHODS PostConfirm FOR MODIFY
       keys FOR ACTION DataFile~PostConfirm RESULT result.

    METHODS validateRow FOR VALIDATE ON SAVE
       keys FOR DataFile~validateRow.

ENDCLASS.

CLASS lhc_DataFile IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-PostConfirm = if_abap_behv=>mk-on.
      result-%action-PostConfirm = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD PostConfirm.
    READ ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY DataFile
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(rows)
      FAILED   DATA(read_failed)
      REPORTED DATA(read_reported).

    APPEND LINES OF read_failed-datafile   TO failed-datafile.
    APPEND LINES OF read_reported-datafile TO reported-datafile.

    IF rows IS INITIAL.
      RETURN.
    ENDIF.

    " 1. Đánh dấu các dòng con là đã lên lịch
    MODIFY ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY DataFile
        UPDATE FIELDS ( MessageType Message )
        WITH VALUE #( FOR row IN rows
          ( %tky                 = row-%tky
            MessageType          = lcl_const=>msg_type-scheduled
            Message              = `Scheduled for background processing`
            %control-MessageType = if_abap_behv=>mk-on
            %control-Message     = if_abap_behv=>mk-on ) )
      FAILED   DATA(update_failed)
      REPORTED DATA(update_reported).

    APPEND LINES OF update_failed-datafile   TO failed-datafile.
    APPEND LINES OF update_reported-datafile TO reported-datafile.

    " 2. Lấy key của các file cha (distinct)
    READ ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY DataFile BY \_ManageFile
        FROM CORRESPONDING #( keys )
      RESULT DATA(parents).

    SORT parents BY Uuid.
    DELETE ADJACENT DUPLICATES FROM parents COMPARING Uuid.

    " 3. Chuyển file cha sang In Process
    MODIFY ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY ManageFile
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR p IN parents
          ( %tky            = p-%tky
            Status          = lcl_const=>file_status-inprocess
            %control-Status = if_abap_behv=>mk-on ) )
      FAILED   DATA(parent_failed)
      REPORTED DATA(parent_reported).

    APPEND LINES OF parent_failed-managefile   TO failed-managefile.
    APPEND LINES OF parent_reported-managefile TO reported-managefile.

    " 4. Trả về trạng thái sau cập nhật
    READ ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY DataFile
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(updated_rows).

    result = VALUE #( FOR r IN updated_rows
      ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD validateRow.
    READ ENTITIES OF zi_m_od_h_file IN LOCAL MODE
      ENTITY DataFile
        FIELDS ( Od PlanGiDate IncoVers Incoterm IncoLoc1 IncoLoc2
                 NhaCungCapVanTai PhanLoaiPtvt SoLuongPtvt BienSoXe
                 SoContainer SoSeal TareWeight Booking NgayTauChay NgayGioXuatHang
                 CutOffTime GhiChuGiaoHang TyGiaLoNoiDia )
        WITH CORRESPONDING #( keys )
      RESULT DATA(rows).

    IF rows IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM I_DeliveryDocument WITH PRIVILEGED ACCESS
      FIELDS DeliveryDocument
      FOR ALL ENTRIES IN @rows
      WHERE DeliveryDocument = @rows-Od
      INTO TABLE @DATA(existing_ods).

    LOOP AT rows INTO DATA(row).
      IF row-Od IS INITIAL.
        APPEND VALUE #( %tky = row-%tky ) TO failed-datafile.
        APPEND VALUE #( %tky        = row-%tky
                        %element-Od = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = `OD is mandatory` ) )
          TO reported-datafile.
        CONTINUE.
      ENDIF.

      IF NOT line_exists( existing_ods[ DeliveryDocument = row-Od ] ).
        APPEND VALUE #( %tky = row-%tky ) TO failed-datafile.
        APPEND VALUE #( %tky        = row-%tky
                        %element-Od = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |OD { row-Od ALPHA = OUT } does not exist| ) )
          TO reported-datafile.
        CONTINUE.
      ENDIF.

      IF row-PlanGiDate IS INITIAL AND row-IncoVers IS INITIAL
         AND row-Incoterm IS INITIAL AND row-IncoLoc1 IS INITIAL
         AND row-IncoLoc2 IS INITIAL AND row-NhaCungCapVanTai IS INITIAL
         AND row-PhanLoaiPtvt IS INITIAL AND row-SoLuongPtvt IS INITIAL
         AND row-BienSoXe IS INITIAL AND row-SoContainer IS INITIAL
         AND row-SoSeal IS INITIAL AND row-TareWeight IS INITIAL
         AND row-Booking IS INITIAL AND row-NgayTauChay IS INITIAL
         AND row-NgayGioXuatHang IS INITIAL AND row-CutOffTime IS INITIAL
         AND row-GhiChuGiaoHang IS INITIAL AND row-TyGiaLoNoiDia IS INITIAL.
        APPEND VALUE #( %tky = row-%tky ) TO failed-datafile.
        APPEND VALUE #( %tky = row-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = `At least one data field must be supplied` ) )
          TO reported-datafile.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lsc_ZI_M_OD_H_FILE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_M_OD_H_FILE IMPLEMENTATION.

  METHOD save_modified.
    TYPES: BEGIN OF ty_job,
             uuid_file TYPE sysuuid_x16,
             uuid      TYPE sysuuid_x16,
           END OF ty_job.
    DATA jobs TYPE SORTED TABLE OF ty_job WITH UNIQUE KEY uuid_file.

    " Gom distinct file -> mỗi file một job
    LOOP AT update-datafile ASSIGNING FIELD-SYMBOL(<row>)
         WHERE MessageType = lcl_const=>msg_type-scheduled.
      INSERT VALUE #( uuid_file = <row>-UuidFile
                      uuid      = <row>-Uuid ) INTO TABLE jobs.
    ENDLOOP.

    IF jobs IS INITIAL.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD DATA(start_timestamp).

    LOOP AT jobs INTO DATA(job).
      TRY.
          cl_apj_rt_api=>schedule_job(
            EXPORTING
              iv_job_template_name   = CONV  cl_apj_rt_api=>ty_template_name( lcl_const=>job_template )
              iv_job_text            = |Mass Upload OD Header { start_timestamp TIMESTAMP = ISO }|
              is_start_info          = VALUE #( timestamp = cl_abap_tstmp=>add(
                                                  tstmp = start_timestamp secs = 1 ) )
              is_end_info            = VALUE #( type = 'NUM' max_iterations = 1 )
              is_scheduling_info     = VALUE #( periodic_value = 1
                                                test_mode      = abap_false
                                                timezone       = 'UTC' )
              it_job_parameter_value = VALUE #(
                ( name    = lcl_const=>job_param_id
                  t_value = VALUE #( ( sign = 'I' option = 'EQ' low = job-uuid_file ) ) ) ) ).
        CATCH cx_apj_rt INTO DATA(job_error).
          APPEND VALUE #( Uuid     = job-uuid
                          UuidFile = job-uuid_file
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = job_error->get_longtext( ) ) )
            TO reported-datafile.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup_finalize.
    RETURN.
  ENDMETHOD.

ENDCLASS.
