CLASS lhc_Cont DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Cont RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Cont RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ Cont RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Cont.

    METHODS updContText FOR MODIFY
      IMPORTING keys FOR ACTION Cont~updContText.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE Cont.

ENDCLASS.

CLASS lhc_Cont IMPLEMENTATION.

  METHOD update.
    DATA: lt_cont_text TYPE STANDARD TABLE OF ztb_cont_text.

    " Đọc dữ liệu hiện có để không bị mất field khác khi save() ghi đè cả dòng
    SELECT FROM ztb_cont_text
      FIELDS so, so_item, so_lenh, so_lenh_item, ngay_dong_cont,
             dong_dau_thung, cont, ke_hoach_dong_cont, ghi_chu_khac, ghi_chu_giao_hang, ngay_tau_chay, thoi_gian_cat_mang,
             dia_diem_dong_hang_cont
      FOR ALL ENTRIES IN @entities
      WHERE so           = @entities-so
        AND so_item      = @entities-SOItem
        AND so_lenh      = @entities-SoLenhXuatHang
        AND so_lenh_item = @entities-SoLenhXuatHangItem
      INTO TABLE @DATA(lt_existing).

    LOOP AT entities INTO DATA(ls_entity).
      CHECK ls_entity-%control-SortOrder = if_abap_behv=>mk-on.

      APPEND INITIAL LINE TO lt_cont_text ASSIGNING FIELD-SYMBOL(<lfs_cont_text>).
      <lfs_cont_text>-client       = sy-mandt.
      <lfs_cont_text>-so           = ls_entity-so.
      <lfs_cont_text>-so_item      = ls_entity-SOItem.
      <lfs_cont_text>-so_lenh      = ls_entity-SoLenhXuatHang.
      <lfs_cont_text>-so_lenh_item = ls_entity-SoLenhXuatHangItem.

      READ TABLE lt_existing INTO DATA(ls_existing)
        WITH KEY so = ls_entity-so so_item = ls_entity-SOItem
                 so_lenh = ls_entity-SoLenhXuatHang so_lenh_item = ls_entity-SoLenhXuatHangItem.
      IF sy-subrc = 0.
        <lfs_cont_text>-ngay_dong_cont          = ls_existing-ngay_dong_cont.
        <lfs_cont_text>-dong_dau_thung          = ls_existing-dong_dau_thung.
        <lfs_cont_text>-cont                    = ls_existing-cont.
        <lfs_cont_text>-ke_hoach_dong_cont      = ls_existing-ke_hoach_dong_cont.
        <lfs_cont_text>-ghi_chu_khac            = ls_existing-ghi_chu_khac.
        <lfs_cont_text>-ghi_chu_giao_hang       = ls_existing-ghi_chu_giao_hang.
        <lfs_cont_text>-ngay_tau_chay           = ls_existing-ngay_tau_chay.
        <lfs_cont_text>-thoi_gian_cat_mang      = ls_existing-thoi_gian_cat_mang.
        <lfs_cont_text>-dia_diem_dong_hang_cont = ls_existing-dia_diem_dong_hang_cont.
      ENDIF.

      <lfs_cont_text>-sort_order = ls_entity-SortOrder.
      <lfs_cont_text>-changed_by = sy-uname.
      <lfs_cont_text>-changed_at = utclong_current( ).
    ENDLOOP.

    IF lt_cont_text IS NOT INITIAL.
      zcl_ce_cont_text_buffer=>set_data( it_data = lt_cont_text ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
  ENDMETHOD.



















  METHOD get_instance_authorizations.
  ENDMETHOD.

























  METHOD read.
    SELECT FROM ztb_cont_text
    FIELDS
        so,
        so_item,
        so_lenh,
        so_lenh_item,

        dong_dau_thung,
        cont,
        ke_hoach_dong_cont,
        ghi_chu_khac,
        ghi_chu_giao_hang,
        ngay_tau_chay,
        thoi_gian_cat_mang,
        dia_diem_dong_hang_cont,
        sort_order
    FOR ALL ENTRIES IN @keys
    WHERE
        so = @keys-so
        AND so_item = @keys-SOItem
        AND so_lenh = @keys-SoLenhXuatHang
        AND so_lenh_item = @keys-SoLenhXuatHangItem
    INTO TABLE @DATA(lt_read).

    LOOP AT lt_read INTO DATA(ls_read).
      APPEND INITIAL LINE TO result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-so                 = ls_read-so.
      <lfs_result>-SOItem             = ls_read-so_item.
      <lfs_result>-SoLenhXuatHang     = ls_read-so_lenh.
      <lfs_result>-SoLenhXuatHangItem = ls_read-so_lenh_item.

      <lfs_result>-DongDauThung      = ls_read-dong_dau_thung.
      <lfs_result>-Cont              = ls_read-cont.
      <lfs_result>-KeHoachDongCont   = ls_read-ke_hoach_dong_cont.
      <lfs_result>-GhiChuKhac        = ls_read-ghi_chu_khac.
      <lfs_result>-GhiChuGiaoHang    = ls_read-ghi_chu_giao_hang.
      <lfs_result>-NgayTauChay       = ls_read-ngay_tau_chay.
      <lfs_result>-ThoiGianCatMang   = ls_read-thoi_gian_cat_mang.
      <lfs_result>-DiaDiemDongHang   = ls_read-dia_diem_dong_hang_cont.
      <lfs_result>-SortOrder         = ls_read-sort_order.
    ENDLOOP.
  ENDMETHOD.

























  METHOD lock.
  ENDMETHOD.




















  METHOD updContText.
    DATA: lt_cont_text TYPE STANDARD TABLE OF ztb_cont_text.

    " Đọc dữ liệu hiện có để không bị mất field khác (kể cả SortOrder) khi save()
    " ghi đè cả dòng
    SELECT FROM ztb_cont_text
      FIELDS so, so_item, so_lenh, so_lenh_item, ngay_dong_cont,
             dong_dau_thung, cont, ke_hoach_dong_cont, ghi_chu_khac,
             ghi_chu_giao_hang, ngay_tau_chay, thoi_gian_cat_mang,
             dia_diem_dong_hang_cont, sort_order
      FOR ALL ENTRIES IN @keys
      WHERE so           = @keys-%key-so
        AND so_item      = @keys-%key-SOItem
        AND so_lenh      = @keys-%key-SoLenhXuatHang
        AND so_lenh_item = @keys-%key-SoLenhXuatHangItem
      INTO TABLE @DATA(lt_existing).

    LOOP AT keys INTO DATA(ls_key).
      APPEND INITIAL LINE TO lt_cont_text ASSIGNING FIELD-SYMBOL(<lfs_cont_text>).

      " Giữ nguyên dữ liệu hiện có (kể cả SortOrder) nếu dòng đã tồn tại
      READ TABLE lt_existing INTO DATA(ls_existing)
        WITH KEY so = ls_key-%key-so so_item = ls_key-%key-SOItem
                 so_lenh = ls_key-%key-SoLenhXuatHang so_lenh_item = ls_key-%key-SoLenhXuatHangItem.
      IF sy-subrc = 0.
        MOVE-CORRESPONDING ls_existing TO <lfs_cont_text>.
      ENDIF.

      <lfs_cont_text>-client       = sy-mandt.
      <lfs_cont_text>-so           = ls_key-%key-so.
      <lfs_cont_text>-so_item      = ls_key-%key-SOItem.
      <lfs_cont_text>-so_lenh      = ls_key-%key-SoLenhXuatHang.
      <lfs_cont_text>-so_lenh_item = ls_key-%key-SoLenhXuatHangItem.

      IF ls_key-%param-NgayDongCont IS NOT INITIAL.
        <lfs_cont_text>-ngay_dong_cont = ls_key-%param-NgayDongCont.
      ENDIF.
      IF ls_key-%param-DongDauThung IS NOT INITIAL.
        <lfs_cont_text>-dong_dau_thung = COND #( WHEN ls_key-%param-DongDauThung = 'D' THEN '' ELSE ls_key-%param-DongDauThung ).
      ENDIF.
      IF ls_key-%param-Cont IS NOT INITIAL.
        <lfs_cont_text>-cont = COND #( WHEN ls_key-%param-Cont = 'D' THEN '' ELSE ls_key-%param-Cont ).
      ENDIF.
      IF ls_key-%param-KeHoachDongCont IS NOT INITIAL.
        <lfs_cont_text>-ke_hoach_dong_cont = COND #( WHEN ls_key-%param-KeHoachDongCont = 'D' THEN '' ELSE ls_key-%param-KeHoachDongCont ).
      ENDIF.
      IF ls_key-%param-GhiChuKhac IS NOT INITIAL.
        <lfs_cont_text>-ghi_chu_khac = COND #( WHEN ls_key-%param-GhiChuKhac = 'D' THEN '' ELSE ls_key-%param-GhiChuKhac ).
      ENDIF.
      IF ls_key-%param-GhiChuGiaoHang IS NOT INITIAL.
        <lfs_cont_text>-ghi_chu_giao_hang = COND #( WHEN ls_key-%param-GhiChuGiaoHang = 'D' THEN '' ELSE ls_key-%param-GhiChuGiaoHang ).
      ENDIF.
      IF ls_key-%param-NgayTauChay IS NOT INITIAL.
        <lfs_cont_text>-ngay_tau_chay = COND #( WHEN ls_key-%param-NgayTauChay = 'D' THEN '' ELSE ls_key-%param-NgayTauChay ).
      ENDIF.
      IF ls_key-%param-ThoiGianCatMang IS NOT INITIAL.
        <lfs_cont_text>-thoi_gian_cat_mang = COND #( WHEN ls_key-%param-ThoiGianCatMang = 'D' THEN '' ELSE ls_key-%param-ThoiGianCatMang ).
      ENDIF.
      IF ls_key-%param-DiaDiemDongHangCont IS NOT INITIAL.
        <lfs_cont_text>-dia_diem_dong_hang_cont = COND #( WHEN ls_key-%param-DiaDiemDongHangCont = 'D' THEN '' ELSE ls_key-%param-DiaDiemDongHangCont ).
        SELECT SINGLE FROM I_Plant
        FIELDS PlantName
        WHERE Plant = @ls_key-%param-DiaDiemDongHangCont
        INTO @<lfs_cont_text>-dia_diem_dong_hang_cont_name.
      ENDIF.

      <lfs_cont_text>-changed_by = sy-uname.
      <lfs_cont_text>-changed_at = utclong_current( ).

      APPEND VALUE #(
        %tky = ls_key-%tky
        %msg = new_message( id       = 'ZCONT'
                            number   = '000'
                            severity = if_abap_behv_message=>severity-success
                            v1       = 'Cập nhật thông tin Cont thành công' )
      ) TO reported-cont.
    ENDLOOP.

    zcl_ce_cont_text_buffer=>set_data( it_data = lt_cont_text ).

    " (phần READ ENTITIES / MODIFY ENTITIES giữ nguyên như cũ, không đổi)

  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZCE_CONT DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZCE_CONT IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    zcl_ce_cont_text_buffer=>get_data(
      IMPORTING
        et_data = DATA(lt_cont_text)
    ).

    IF lt_cont_text IS NOT INITIAL.
      MODIFY ztb_cont_text FROM TABLE @lt_cont_text.
      IF sy-subrc <> 0.
        CHECK 1 = 1.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup.
    zcl_ce_cont_text_buffer=>clear_data( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
