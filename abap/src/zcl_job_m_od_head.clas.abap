CLASS zcl_job_m_od_head DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
ENDCLASS.



CLASS ZCL_JOB_M_OD_HEAD IMPLEMENTATION.


  METHOD if_apj_rt_exec_object~execute.
    LOOP AT it_parameters INTO DATA(parameter).
      SELECT * FROM ztb_m_od_h_data
        WITH PRIVILEGED ACCESS
        WHERE uuid_file = @parameter-low
          AND message_type = 'J'
        INTO TABLE @DATA(rows).
      CHECK rows IS NOT INITIAL.

      DATA api_rows TYPE zcl_call_api_ud_od_hdr=>tt_header.
      CLEAR api_rows.

      LOOP AT rows INTO DATA(row).
        APPEND VALUE #( Uuid                = row-uuid
                        UuidFile            = row-uuid_file
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
                        HasTyGiaLoNoiDia    = row-has_ty_gia_lo_noi_dia ) TO api_rows.
      ENDLOOP.

      zcl_call_api_ud_od_hdr=>update_header( CHANGING ct_data = api_rows ).

      MODIFY ENTITIES OF zi_m_od_h_file
        ENTITY DataFile
        UPDATE FIELDS ( MessageType Message )
        WITH VALUE #( FOR api_row IN api_rows
          ( Uuid        = api_row-Uuid
            UuidFile    = api_row-UuidFile
            MessageType = api_row-MessageType
            Message     = api_row-Message ) )
        FAILED DATA(update_failed)
        REPORTED DATA(update_reported).

      DATA(file_status) = COND #( WHEN line_exists( api_rows[ MessageType = 'E' ] )
                                  THEN 'E' ELSE 'D' ).
      DATA(file_message) = COND string( WHEN file_status = 'D'
        THEN `All ODs were processed successfully`
        ELSE `Processing completed with errors` ).

      MODIFY ENTITIES OF zi_m_od_h_file
        ENTITY ManageFile
        UPDATE FIELDS ( Status Message )
        WITH VALUE #( ( Uuid    = rows[ 1 ]-uuid_file
                        Status  = file_status
                        Message = file_message ) )
        FAILED DATA(file_failed)
        REPORTED DATA(file_reported).

      COMMIT ENTITIES.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #( (
      selname        = 'HDR_ID'
      kind           = if_apj_dt_exec_object=>select_option
      datatype       = 'C'
      length         = 32
      param_text     = 'Upload UUID'
      changeable_ind = abap_true ) ).
  ENDMETHOD.
ENDCLASS.
