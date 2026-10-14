CLASS lhc_ThungMau DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES: tt_update TYPE TABLE FOR UPDATE zi_thung_mau,
           tr_so     TYPE RANGE OF ztb_custom_hu-so_khsx.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ThungMau RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ThungMau RESULT result.

    METHODS deleteThung FOR MODIFY
      IMPORTING keys FOR ACTION ThungMau~deleteThung RESULT result.

    METHODS doThung FOR MODIFY
      IMPORTING keys FOR ACTION ThungMau~doThung RESULT result.

    METHODS chuyenViTri FOR MODIFY
      IMPORTING keys FOR ACTION ThungMau~chuyenViTri RESULT result.

    METHODS daXuat FOR MODIFY
      IMPORTING keys FOR ACTION ThungMau~daXuat RESULT result.

    "! Số KHSX có dạng SO/SOITEM (vd 10001234/10) → trả về range lấy mọi item của cùng SO
    METHODS add_so_header
      IMPORTING iv_so_khsx TYPE ztb_custom_hu-so_khsx
      CHANGING  cr_so      TYPE tr_so.

    "! Chuyển vị trí / Dỡ thùng / Đã xuất chạy theo cấp header: lấy toàn bộ dòng
    "! Tồn kho, chưa đánh dấu xóa của các SO được chọn.
    METHODS get_lines_by_so
      IMPORTING ir_so            TYPE tr_so
      RETURNING VALUE(rt_update) TYPE tt_update.

ENDCLASS.

CLASS lhc_ThungMau IMPLEMENTATION.

  METHOD get_instance_features.
    " Chỉ cho thao tác khi trạng thái = Tồn kho và chưa đánh dấu xóa/dỡ thùng
    READ ENTITIES OF zi_thung_mau IN LOCAL MODE
      ENTITY ThungMau
        FIELDS ( TrangThai DelFlag )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_thung)
      FAILED failed.

    result = VALUE #( FOR ls_thung IN lt_thung
                      LET lv_fc = COND #( WHEN ls_thung-TrangThai  = zcl_thung_implement=>hu_status-in_stock
                                           AND ls_thung-DelFlag = zcl_thung_implement=>del_flag-none
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
                      IN ( %tky                = ls_thung-%tky
                           %action-deleteThung = lv_fc
                           %action-doThung     = lv_fc
                           %action-chuyenViTri = lv_fc
                           %action-daXuat      = lv_fc ) ).
  ENDMETHOD.


  METHOD get_global_authorizations.
  ENDMETHOD.


  METHOD add_so_header.
    DATA(lv_header) = COND string( WHEN iv_so_khsx CS '/'
                                   THEN substring_before( val = iv_so_khsx sub = '/' )
                                   ELSE iv_so_khsx ).

    " Dòng chỉ có SO (không có item) và mọi dòng SO/item
    APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_header ) TO cr_so.
    APPEND VALUE #( sign = 'I' option = 'CP' low = |{ lv_header }/*| ) TO cr_so.
  ENDMETHOD.


  METHOD get_lines_by_so.
    IF ir_so IS INITIAL.
      RETURN.
    ENDIF.

    " Dòng đã xuất hoặc có DELETE <> null thì không thay đổi
    SELECT FROM ztb_custom_hu
      FIELDS so_khsx,
             so_thung,
             material,
             batch
      WHERE so_khsx     IN @ir_so
        AND status      =  @zcl_thung_implement=>hu_status-in_stock
        AND del_flag    =  @zcl_thung_implement=>del_flag-none
      INTO TABLE @DATA(lt_line).

    rt_update = VALUE #( FOR ls_line IN lt_line ( SoKhsx   = ls_line-so_khsx
                                                  SoThung  = ls_line-so_thung
                                                  Material = ls_line-material
                                                  Batch    = ls_line-batch ) ).
  ENDMETHOD.


  METHOD deleteThung.
    " Delete chạy theo từng dòng được chọn
    DATA lt_update TYPE tt_update.

    READ ENTITIES OF zi_thung_mau IN LOCAL MODE
      ENTITY ThungMau
        FIELDS ( TrangThai DelFlag )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_thung).

    LOOP AT lt_thung INTO DATA(ls_thung).
      " Chỉ cho đánh dấu xóa khi trạng thái = Tồn kho
      IF ls_thung-TrangThai <> zcl_thung_implement=>hu_status-in_stock
      OR ls_thung-DelFlag <> zcl_thung_implement=>del_flag-none.
        APPEND VALUE #( %tky = ls_thung-%tky ) TO failed-thungmau.
        APPEND VALUE #( %tky = ls_thung-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Thùng { ls_thung-SoThung }: chỉ được xóa khi trạng thái = Tồn kho| )
                      ) TO reported-thungmau.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky    = ls_thung-%tky
                      DelFlag = zcl_thung_implement=>del_flag-deleted ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_thung_mau IN LOCAL MODE
        ENTITY ThungMau
          UPDATE FIELDS ( DelFlag )
          WITH lt_update
        FAILED   DATA(lt_failed)
        REPORTED DATA(lt_reported).
    ENDIF.

    READ ENTITIES OF zi_thung_mau IN LOCAL MODE
      ENTITY ThungMau
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result ( %tky   = ls_result-%tky
                                                   %param = ls_result ) ).
  ENDMETHOD.


  METHOD doThung.
    " Dỡ thùng: đánh dấu D cho toàn bộ dòng Tồn kho của số KHSX được chọn
    DATA lr_so TYPE tr_so.

    LOOP AT keys INTO DATA(ls_key).
      add_so_header( EXPORTING iv_so_khsx = ls_key-SoKhsx
                     CHANGING  cr_so      = lr_so ).
    ENDLOOP.

    DATA(lt_update) = get_lines_by_so( lr_so ).

    LOOP AT lt_update ASSIGNING FIELD-SYMBOL(<lfs_update>).
      <lfs_update>-DelFlag = zcl_thung_implement=>del_flag-unpacked.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_thung_mau IN LOCAL MODE
        ENTITY ThungMau
          UPDATE FIELDS ( DelFlag )
          WITH lt_update
        FAILED   DATA(lt_failed)
        REPORTED DATA(lt_reported).
    ENDIF.

    READ ENTITIES OF zi_thung_mau IN LOCAL MODE
      ENTITY ThungMau
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result ( %tky   = ls_result-%tky
                                                   %param = ls_result ) ).
  ENDMETHOD.


  METHOD chuyenViTri.
    " Chuyển vị trí: cập nhật Storage Location cho toàn bộ dòng Tồn kho của số KHSX được chọn
    READ TABLE keys INTO DATA(ls_first) INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lv_sloc)  = ls_first-%param-StorageLocation.
    DATA(lv_error) = VALUE string( ).

    IF lv_sloc IS INITIAL.
      lv_error = |Vui lòng nhập Storage Location|.
    ELSE.
      " Storage Location phải thuộc plant cố định của kho thùng mẫu
      SELECT SINGLE FROM I_StorageLocation
        FIELDS StorageLocation
        WHERE Plant           = @zcl_thung_implement=>plant
          AND StorageLocation = @lv_sloc
        INTO @DATA(lv_exist).
      IF sy-subrc <> 0.
        lv_error = |Storage Location { lv_sloc } không tồn tại ở plant { zcl_thung_implement=>plant }|.
      ENDIF.
    ENDIF.

    IF lv_error IS NOT INITIAL.
      LOOP AT keys INTO DATA(ls_key_err).
        APPEND VALUE #( %tky = ls_key_err-%tky ) TO failed-thungmau.
        APPEND VALUE #( %tky = ls_key_err-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lv_error )
                      ) TO reported-thungmau.
      ENDLOOP.
      RETURN.
    ENDIF.

    DATA lr_so TYPE tr_so.

    LOOP AT keys INTO DATA(ls_key).
      add_so_header( EXPORTING iv_so_khsx = ls_key-SoKhsx
                     CHANGING  cr_so      = lr_so ).
    ENDLOOP.

    DATA(lt_update) = get_lines_by_so( lr_so ).

    LOOP AT lt_update ASSIGNING FIELD-SYMBOL(<lfs_update>).
      <lfs_update>-StorageLocation = lv_sloc.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_thung_mau IN LOCAL MODE
        ENTITY ThungMau
          UPDATE FIELDS ( StorageLocation )
          WITH lt_update
        FAILED   DATA(lt_failed)
        REPORTED DATA(lt_reported).
    ENDIF.

    READ ENTITIES OF zi_thung_mau IN LOCAL MODE
      ENTITY ThungMau
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result ( %tky   = ls_result-%tky
                                                   %param = ls_result ) ).
  ENDMETHOD.


  METHOD daXuat.
    " Đã xuất: chuyển Tồn kho → Đã xuất cho toàn bộ dòng của số KHSX được chọn
    DATA lr_so TYPE tr_so.

    LOOP AT keys INTO DATA(ls_key).
      add_so_header( EXPORTING iv_so_khsx = ls_key-SoKhsx
                     CHANGING  cr_so      = lr_so ).
    ENDLOOP.

    DATA(lt_update) = get_lines_by_so( lr_so ).

    LOOP AT lt_update ASSIGNING FIELD-SYMBOL(<lfs_update>).
      <lfs_update>-TrangThai = zcl_thung_implement=>hu_status-issued.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_thung_mau IN LOCAL MODE
        ENTITY ThungMau
          UPDATE FIELDS ( TrangThai )
          WITH lt_update
        FAILED   DATA(lt_failed)
        REPORTED DATA(lt_reported).
    ENDIF.

    READ ENTITIES OF zi_thung_mau IN LOCAL MODE
      ENTITY ThungMau
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result ( %tky   = ls_result-%tky
                                                   %param = ls_result ) ).
  ENDMETHOD.

ENDCLASS.
