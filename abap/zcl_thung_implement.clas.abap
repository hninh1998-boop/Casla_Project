CLASS zcl_thung_implement DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES tt_data    TYPE STANDARD TABLE OF ztb_d_thung WITH EMPTY KEY.
    TYPES tt_data_od TYPE STANDARD TABLE OF ztb_d_od WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF hu_status,
        in_stock TYPE c LENGTH 1 VALUE '1', "Tồn kho
        issued   TYPE c LENGTH 1 VALUE '2', "Đã xuất
      END OF hu_status,

      BEGIN OF del_flag,
        none     TYPE c LENGTH 1 VALUE '',  "Đang hiệu lực
        deleted  TYPE c LENGTH 1 VALUE 'X', "Đã xóa
        unpacked TYPE c LENGTH 1 VALUE 'D', "Dỡ thùng
      END OF del_flag,

      " Plant cố định của kho thùng mẫu
      plant TYPE werks_d VALUE '6731',

      BEGIN OF tem,
        yes TYPE c LENGTH 1 VALUE 'C', "Có tem
        no  TYPE c LENGTH 1 VALUE 'K', "Không tem
      END OF tem.

    "! Kiểm tra từng dòng upload và ghi vào ZTB_CUSTOM_HU (qua BO zi_thung_mau).
    "! Thùng nào có dòng lỗi thì không ghi dòng nào của thùng đó.
    "! iv_check_only = true: chỉ kiểm tra và trả message cho từng dòng (dùng ngay lúc upload file),
    "! không ghi dữ liệu. Lúc bấm Ghi dữ liệu thì kiểm tra lại toàn bộ rồi mới ghi.
    CLASS-METHODS post
      IMPORTING iv_check_only TYPE abap_boolean DEFAULT abap_false
      CHANGING  ct_data       TYPE tt_data.

    "! Cập nhật lệnh xuất hàng (OD) cho thùng/pallet: gán OD cho mọi dòng của thùng trong ZTB_CUSTOM_HU,
    "! thùng đã có OD thì ghi đè. iv_check_only = true: chỉ kiểm tra (lúc upload), không ghi.
    CLASS-METHODS post_od
      IMPORTING iv_check_only TYPE abap_boolean DEFAULT abap_false
      CHANGING  ct_data       TYPE tt_data_od.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS set_error
      IMPORTING iv_message TYPE string
      CHANGING  cs_data    TYPE ztb_d_thung.

    CLASS-METHODS set_error_od
      IMPORTING iv_message TYPE string
      CHANGING  cs_data    TYPE ztb_d_od.
ENDCLASS.



CLASS ZCL_THUNG_IMPLEMENT IMPLEMENTATION.


  METHOD post.
    " Key nghiệp vụ của thùng mẫu: Số thùng + Mã hàng + Batch (Số KHSX không phải key, sửa được bằng Type M)
    TYPES: BEGIN OF ty_key,
             so_thung TYPE ztb_d_thung-so_thung,
             material TYPE ztb_d_thung-material,
             batch    TYPE ztb_d_thung-batch,
             cnt      TYPE i,
           END OF ty_key,

           BEGIN OF ty_thung_kl,
             so_thung   TYPE ztb_d_thung-so_thung,
             khoi_luong   TYPE ztb_d_thung-khoi_luong,
             gross_weight TYPE ztb_d_thung-gross_weight,
           END OF ty_thung_kl,

           BEGIN OF ty_thung,
             so_thung   TYPE ztb_d_thung-so_thung,
             kl_count   TYPE i,            "Cặp Net / Gross weight khác nhau của thùng trong file
             exist      TYPE abap_boolean, "Số thùng đã có trong bảng (không xét đánh dấu xóa)
             active     TYPE abap_boolean, "Thùng còn dòng đang sử dụng (chưa xóa / dỡ thùng)
             issued     TYPE abap_boolean, "Thùng có dòng Đã xuất
             has_error  TYPE abap_boolean,
             has_modify TYPE abap_boolean,
           END OF ty_thung.

    DATA: lt_key      TYPE HASHED TABLE OF ty_key
                      WITH UNIQUE KEY so_thung material batch,
          lt_thung_kl TYPE SORTED TABLE OF ty_thung_kl
                      WITH UNIQUE KEY so_thung khoi_luong gross_weight,
          lt_thung    TYPE HASHED TABLE OF ty_thung WITH UNIQUE KEY so_thung.

    DATA: lt_create TYPE TABLE FOR CREATE zi_thung_mau,
          lt_update TYPE TABLE FOR UPDATE zi_thung_mau.

    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    " ── 1. Gom key / thùng trong file ─────────────────────────────
    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<lfs_data>).
      CLEAR: <lfs_data>-messagetype, <lfs_data>-message.

      READ TABLE lt_key ASSIGNING FIELD-SYMBOL(<lfs_key>)
        WITH TABLE KEY so_thung         = <lfs_data>-so_thung
                       material         = <lfs_data>-material
                       batch            = <lfs_data>-batch.
      IF sy-subrc = 0.
        <lfs_key>-cnt = <lfs_key>-cnt + 1.
      ELSE.
        INSERT VALUE #( so_thung         = <lfs_data>-so_thung
                        material         = <lfs_data>-material
                        batch            = <lfs_data>-batch
                        cnt              = 1 ) INTO TABLE lt_key.
      ENDIF.

      READ TABLE lt_thung ASSIGNING FIELD-SYMBOL(<lfs_thung>)
        WITH TABLE KEY so_thung = <lfs_data>-so_thung.
      IF sy-subrc <> 0.
        INSERT VALUE #( so_thung = <lfs_data>-so_thung ) INTO TABLE lt_thung ASSIGNING <lfs_thung>.
      ENDIF.

      " Net / Gross weight: so nguyên text đã bỏ khoảng trắng hai đầu; ô trống cũng tính là một giá trị
      INSERT VALUE #( so_thung     = <lfs_data>-so_thung
                      khoi_luong   = <lfs_data>-khoi_luong
                      gross_weight = <lfs_data>-gross_weight ) INTO TABLE lt_thung_kl.
      IF sy-subrc = 0.
        <lfs_thung>-kl_count = <lfs_thung>-kl_count + 1.
      ENDIF.

      IF <lfs_data>-type = 'M'.
        <lfs_thung>-has_modify = abap_true.
      ENDIF.
    ENDLOOP.

    " ── 2. Đọc dữ liệu hiện có ────────────────────────────────────
    SELECT FROM ztb_custom_hu
      FIELDS *
      FOR ALL ENTRIES IN @ct_data
      WHERE so_thung = @ct_data-so_thung
      INTO TABLE @DATA(lt_db).

    LOOP AT lt_db INTO DATA(ls_db).
      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = ls_db-so_thung.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      <lfs_thung>-exist = abap_true.

      IF ls_db-del_flag = del_flag-none.
        <lfs_thung>-active = abap_true.
      ENDIF.

      IF ls_db-status = hu_status-issued.
        <lfs_thung>-issued = abap_true.
      ENDIF.
    ENDLOOP.

    " WITH PRIVILEGED ACCESS: hàm này còn được gọi lúc upload (determination on save của ZI_M_THUNG),
    " ở giai đoạn đó RAP cấm kiểm tra quyền DCL ngầm của CDS view → dump BEHAVIOR_ILLEGAL_STATEMENT
    SELECT FROM I_Product WITH PRIVILEGED ACCESS
      FIELDS Product
      FOR ALL ENTRIES IN @ct_data
      WHERE Product = @ct_data-material
      INTO TABLE @DATA(lt_product).

    SELECT FROM I_StorageLocation WITH PRIVILEGED ACCESS
      FIELDS StorageLocation
      FOR ALL ENTRIES IN @ct_data
      WHERE Plant           = @plant
        AND StorageLocation = @ct_data-storage_location
      INTO TABLE @DATA(lt_sloc).

    " ── 3. Kiểm tra từng dòng ─────────────────────────────────────
    LOOP AT ct_data ASSIGNING <lfs_data>.
      " ALPHA = OUT trên field CHAR 40 trả về cả khoảng trắng đệm → condense trước khi ghép message
      DATA(lv_material) = condense( |{ <lfs_data>-material ALPHA = OUT }| ).
      DATA(lv_line)     = |thùng { <lfs_data>-so_thung }, KHSX { <lfs_data>-so_khsx }, mã hàng { lv_material }, batch { <lfs_data>-batch }|.

      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = <lfs_data>-so_thung.

      IF <lfs_data>-type <> 'I' AND <lfs_data>-type <> 'M'.
        set_error( EXPORTING iv_message = |Type phải là I (thêm mới) hoặc M (chỉnh sửa)|
                   CHANGING  cs_data    = <lfs_data> ).
      ENDIF.

      " Số KHSX không bắt buộc
      IF <lfs_data>-so_thung IS INITIAL OR <lfs_data>-material IS INITIAL.
        set_error( EXPORTING iv_message = |Bắt buộc nhập Số thùng và Mã hàng|
                   CHANGING  cs_data    = <lfs_data> ).
      ENDIF.

      " Trùng key trong file
      READ TABLE lt_key ASSIGNING <lfs_key>
        WITH TABLE KEY so_thung         = <lfs_data>-so_thung
                       material         = <lfs_data>-material
                       batch            = <lfs_data>-batch.
      IF sy-subrc = 0 AND <lfs_key>-cnt > 1.
        set_error( EXPORTING iv_message = |Trùng dòng trong file: { lv_line }|
                   CHANGING  cs_data    = <lfs_data> ).
      ENDIF.

      CASE <lfs_data>-type.
        WHEN 'I' OR 'M'.
          " Một số thùng chỉ có một Net weight và một Gross weight
          IF <lfs_thung>-kl_count > 1.
            set_error( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } có nhiều Net weight / Gross weight khác nhau trong file, 1 thùng chỉ được có 1 giá trị mỗi loại|
                       CHANGING  cs_data    = <lfs_data> ).
          ENDIF.

          IF NOT line_exists( lt_product[ Product = <lfs_data>-material ] ).
            set_error( EXPORTING iv_message = |Mã hàng { lv_material } không tồn tại|
                       CHANGING  cs_data    = <lfs_data> ).
          ENDIF.

          IF <lfs_data>-quantity <= 0.
            set_error( EXPORTING iv_message = |Số lượng trống hoặc không hợp lệ|
                       CHANGING  cs_data    = <lfs_data> ).
          ENDIF.

          IF <lfs_data>-ngay_nhap_kho IS INITIAL.
            set_error( EXPORTING iv_message = |Ngày nhập kho trống hoặc sai định dạng DD/MM/YYYY|
                       CHANGING  cs_data    = <lfs_data> ).
          ENDIF.

          IF <lfs_data>-tem <> tem-yes AND <lfs_data>-tem <> tem-no.
            set_error( EXPORTING iv_message = |Tem phải là CÓ TEM hoặc KHÔNG TEM|
                       CHANGING  cs_data    = <lfs_data> ).
          ENDIF.

          IF <lfs_data>-storage_location IS NOT INITIAL
          AND NOT line_exists( lt_sloc[ StorageLocation = <lfs_data>-storage_location ] ).
            set_error( EXPORTING iv_message = |Storage Location { <lfs_data>-storage_location } không tồn tại ở plant { plant }|
                       CHANGING  cs_data    = <lfs_data> ).
          ENDIF.

          " Thùng đã xuất → không cho cập nhật (cả I và M).
          " I: thùng còn ít nhất 1 dòng đang sử dụng → báo thùng đã tồn tại (không xét Mã hàng / Batch).
          "    Thùng chỉ còn dòng đã xóa / dỡ thùng → dòng trùng key được ghi đè, key mới thì thêm dòng.
          " M: dòng trùng key được ghi đè (reset về Tồn kho, bỏ đánh dấu xóa / dỡ thùng), key mới thì thêm dòng
          IF <lfs_thung>-issued = abap_true.
            set_error( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } đã xuất, không cho phép cập nhật ({ lv_line })|
                       CHANGING  cs_data    = <lfs_data> ).
          ELSEIF <lfs_data>-type = 'I' AND <lfs_thung>-active = abap_true.
            set_error( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } đã tồn tại trong hệ thống ({ lv_line })|
                       CHANGING  cs_data    = <lfs_data> ).
          ELSEIF <lfs_data>-type = 'M' AND <lfs_thung>-exist = abap_false.
            set_error( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } chưa tồn tại, không thể chỉnh sửa|
                       CHANGING  cs_data    = <lfs_data> ).
          ENDIF.

      ENDCASE.

      IF <lfs_data>-messagetype = 'E'.
        <lfs_thung>-has_error = abap_true.
      ENDIF.
    ENDLOOP.

    " Chỉ kiểm tra (lúc upload): dòng hợp lệ thuộc thùng có lỗi cũng báo lỗi, không ghi gì
    IF iv_check_only = abap_true.
      LOOP AT ct_data ASSIGNING <lfs_data> WHERE messagetype <> 'E'.
        READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = <lfs_data>-so_thung.
        IF sy-subrc = 0 AND <lfs_thung>-has_error = abap_true.
          set_error( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } có dòng lỗi nên sẽ không được cập nhật|
                     CHANGING  cs_data    = <lfs_data> ).
        ENDIF.
      ENDLOOP.
      RETURN.
    ENDIF.

    " ── 4. Build dữ liệu ghi - bỏ qua toàn bộ thùng có dòng lỗi ──
    LOOP AT ct_data ASSIGNING <lfs_data>.
      DATA(lv_tabix) = sy-tabix.

      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = <lfs_data>-so_thung.
      IF <lfs_thung>-has_error = abap_true.
        CONTINUE.
      ENDIF.

      READ TABLE lt_db INTO ls_db WITH KEY so_thung         = <lfs_data>-so_thung
                                           material         = <lfs_data>-material
                                           batch            = <lfs_data>-batch.
      DATA(lv_exist) = xsdbool( sy-subrc = 0 ).

      IF lv_exist = abap_true.
        " Key đã có: Type M, hoặc Type I của thùng chỉ còn dòng đã xóa / dỡ thùng
        " → ghi đè, reset về Tồn kho và bỏ đánh dấu xóa / dỡ thùng
        APPEND VALUE #( SoKhsx          = <lfs_data>-so_khsx
                        SoThung         = <lfs_data>-so_thung
                        Material        = <lfs_data>-material
                        Batch           = <lfs_data>-batch
                        Quantity        = <lfs_data>-quantity
                        StorageLocation = <lfs_data>-storage_location
                        Customer        = <lfs_data>-customer
                        NgayNhapKho     = <lfs_data>-ngay_nhap_kho
                        Tem             = <lfs_data>-tem
                        KhoiLuong       = <lfs_data>-khoi_luong
                        GrossWeight     = <lfs_data>-gross_weight
                        TrangThai          = hu_status-in_stock
                        DelFlag         = del_flag-none
                        Uuidfile        = <lfs_data>-uuidfile
                        %control        = VALUE #( SoKhsx          = if_abap_behv=>mk-on
                                                   Quantity        = if_abap_behv=>mk-on
                                                   StorageLocation = if_abap_behv=>mk-on
                                                   Customer        = if_abap_behv=>mk-on
                                                   NgayNhapKho     = if_abap_behv=>mk-on
                                                   Tem             = if_abap_behv=>mk-on
                                                   KhoiLuong       = if_abap_behv=>mk-on
                                                   GrossWeight     = if_abap_behv=>mk-on
                                                   TrangThai          = if_abap_behv=>mk-on
                                                   DelFlag         = if_abap_behv=>mk-on
                                                   Uuidfile        = if_abap_behv=>mk-on ) ) TO lt_update.

      ELSE.
        APPEND VALUE #( %cid            = |THUNG_{ lv_tabix }|
                        SoKhsx          = <lfs_data>-so_khsx
                        SoThung         = <lfs_data>-so_thung
                        Material        = <lfs_data>-material
                        Batch           = <lfs_data>-batch
                        Quantity        = <lfs_data>-quantity
                        StorageLocation = <lfs_data>-storage_location
                        Customer        = <lfs_data>-customer
                        NgayNhapKho     = <lfs_data>-ngay_nhap_kho
                        Tem             = <lfs_data>-tem
                        KhoiLuong       = <lfs_data>-khoi_luong
                        GrossWeight     = <lfs_data>-gross_weight
                        TrangThai          = hu_status-in_stock
                        DelFlag         = del_flag-none
                        Uuidfile        = <lfs_data>-uuidfile ) TO lt_create.
      ENDIF.
    ENDLOOP.

    " Type M: dòng đang hiệu lực của thùng mà không còn trong file → đánh dấu X
    LOOP AT lt_thung ASSIGNING <lfs_thung> WHERE has_modify = abap_true AND has_error = abap_false.
      LOOP AT lt_db INTO ls_db WHERE so_thung = <lfs_thung>-so_thung
                                 AND del_flag = del_flag-none.
        IF line_exists( lt_key[ so_thung         = ls_db-so_thung
                                material         = ls_db-material
                                batch            = ls_db-batch ] ).
          CONTINUE.
        ENDIF.

        APPEND VALUE #( SoThung          = ls_db-so_thung
                        Material         = ls_db-material
                        Batch            = ls_db-batch
                        DelFlag          = del_flag-deleted
                        %control-DelFlag = if_abap_behv=>mk-on ) TO lt_update.
      ENDLOOP.
    ENDLOOP.

    " ── 5. Ghi vào ZTB_CUSTOM_HU qua BO zi_thung_mau ──────────────
    IF lt_create IS NOT INITIAL OR lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_thung_mau
        ENTITY ThungMau
          CREATE FIELDS ( SoKhsx SoThung Material Batch
                          Quantity StorageLocation Customer
                          NgayNhapKho Tem KhoiLuong GrossWeight TrangThai DelFlag Uuidfile )
          WITH lt_create
          UPDATE FROM lt_update
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

      LOOP AT ls_failed-thungmau INTO DATA(ls_fail).
        DATA(lv_thung_fail) = ls_fail-SoThung.

        IF ls_fail-%cid IS NOT INITIAL.
          READ TABLE lt_create INTO DATA(ls_create) WITH KEY %cid = ls_fail-%cid.
          IF sy-subrc = 0.
            lv_thung_fail = ls_create-SoThung.
          ENDIF.
        ENDIF.

        READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = lv_thung_fail.
        IF sy-subrc = 0.
          <lfs_thung>-has_error = abap_true.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " ── 6. Trả message cho từng dòng ──────────────────────────────
    LOOP AT ct_data ASSIGNING <lfs_data>.
      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = <lfs_data>-so_thung.

      IF <lfs_thung>-has_error = abap_true.
        set_error( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } có dòng lỗi nên không được cập nhật|
                   CHANGING  cs_data    = <lfs_data> ).
      ELSE.
        <lfs_data>-messagetype = 'S'.
        <lfs_data>-message     = SWITCH #( <lfs_data>-type
                                           WHEN 'I' THEN 'Thêm mới thành công'
                                           ELSE 'Chỉnh sửa thành công' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD post_od.
    TYPES: BEGIN OF ty_thung_od,
             so_thung TYPE ztb_d_od-so_thung,
             delivery TYPE ztb_d_od-delivery,
           END OF ty_thung_od,

           BEGIN OF ty_thung,
             so_thung  TYPE ztb_d_od-so_thung,
             od_count  TYPE i,            "Số OD khác nhau của thùng trong file
             exist     TYPE abap_boolean, "Số thùng đã có trong bảng
             active    TYPE abap_boolean, "Thùng còn dòng đang sử dụng (chưa xóa / dỡ thùng)
             issued    TYPE abap_boolean, "Thùng có dòng Đã xuất
             has_error TYPE abap_boolean,
           END OF ty_thung.

    DATA: lt_thung_od TYPE SORTED TABLE OF ty_thung_od WITH UNIQUE KEY so_thung delivery,
          lt_thung    TYPE HASHED TABLE OF ty_thung WITH UNIQUE KEY so_thung,
          lt_update   TYPE TABLE FOR UPDATE zi_thung_mau.

    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    " ── 1. Gom OD theo thùng trong file ───────────────────────────
    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<lfs_data>).
      CLEAR: <lfs_data>-messagetype, <lfs_data>-message.

      READ TABLE lt_thung ASSIGNING FIELD-SYMBOL(<lfs_thung>)
        WITH TABLE KEY so_thung = <lfs_data>-so_thung.
      IF sy-subrc <> 0.
        INSERT VALUE #( so_thung = <lfs_data>-so_thung ) INTO TABLE lt_thung ASSIGNING <lfs_thung>.
      ENDIF.

      INSERT VALUE #( so_thung = <lfs_data>-so_thung
                      delivery = <lfs_data>-delivery ) INTO TABLE lt_thung_od.
      IF sy-subrc = 0.
        <lfs_thung>-od_count = <lfs_thung>-od_count + 1.
      ENDIF.
    ENDLOOP.

    " ── 2. Đọc dữ liệu hiện có ────────────────────────────────────
    SELECT FROM ztb_custom_hu
      FIELDS so_thung, material, batch, delivery, status, del_flag
      FOR ALL ENTRIES IN @ct_data
      WHERE so_thung = @ct_data-so_thung
      INTO TABLE @DATA(lt_db).

    " Cùng quy tắc với upload thùng mẫu: thùng đã xuất thì không cho cập nhật,
    " chỉ cập nhật các dòng đang sử dụng của thùng
    LOOP AT lt_db INTO DATA(ls_db_flag).
      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = ls_db_flag-so_thung.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      <lfs_thung>-exist = abap_true.

      IF ls_db_flag-del_flag = del_flag-none.
        <lfs_thung>-active = abap_true.
      ENDIF.

      IF ls_db_flag-status = hu_status-issued.
        <lfs_thung>-issued = abap_true.
      ENDIF.
    ENDLOOP.

    " WITH PRIVILEGED ACCESS: cũng được gọi lúc upload (determination on save), không được kiểm tra quyền DCL
    SELECT FROM I_OutboundDelivery WITH PRIVILEGED ACCESS
      FIELDS OutboundDelivery
      FOR ALL ENTRIES IN @ct_data
      WHERE OutboundDelivery = @ct_data-delivery
      INTO TABLE @DATA(lt_od).

    " ── 3. Kiểm tra từng dòng ─────────────────────────────────────
    LOOP AT ct_data ASSIGNING <lfs_data>.
      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = <lfs_data>-so_thung.
      DATA(lv_od) = |{ <lfs_data>-delivery ALPHA = OUT }|.

      IF <lfs_data>-so_thung IS INITIAL OR <lfs_data>-delivery IS INITIAL.
        set_error_od( EXPORTING iv_message = |Bắt buộc nhập Số thùng/Pallet và Lệnh xuất hàng|
                      CHANGING  cs_data    = <lfs_data> ).
      ENDIF.

      " 1 thùng chỉ có 1 lệnh xuất hàng
      IF <lfs_thung>-od_count > 1.
        set_error_od( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } có nhiều lệnh xuất hàng khác nhau trong file, 1 thùng chỉ được có 1 lệnh xuất hàng|
                      CHANGING  cs_data    = <lfs_data> ).
      ENDIF.

      IF <lfs_data>-so_thung IS NOT INITIAL.
        IF <lfs_thung>-exist = abap_false.
          set_error_od( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } chưa tồn tại trong hệ thống|
                        CHANGING  cs_data    = <lfs_data> ).
        ELSEIF <lfs_thung>-issued = abap_true.
          set_error_od( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } đã xuất, không cho phép cập nhật lệnh xuất hàng|
                        CHANGING  cs_data    = <lfs_data> ).
        ELSEIF <lfs_thung>-active = abap_false.
          set_error_od( EXPORTING iv_message = |Thùng { <lfs_data>-so_thung } đã xóa / dỡ thùng, không thể cập nhật lệnh xuất hàng|
                        CHANGING  cs_data    = <lfs_data> ).
        ENDIF.
      ENDIF.

      IF <lfs_data>-delivery IS NOT INITIAL
      AND NOT line_exists( lt_od[ OutboundDelivery = <lfs_data>-delivery ] ).
        set_error_od( EXPORTING iv_message = |Lệnh xuất hàng { lv_od } không tồn tại|
                      CHANGING  cs_data    = <lfs_data> ).
      ENDIF.

      IF <lfs_data>-messagetype = 'E'.
        <lfs_thung>-has_error = abap_true.
      ENDIF.
    ENDLOOP.

    IF iv_check_only = abap_true.
      RETURN.
    ENDIF.

    " ── 4. Gán OD cho các dòng đang sử dụng của thùng (có OD rồi thì ghi đè) ──
    LOOP AT lt_thung_od INTO DATA(ls_thung_od).
      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = ls_thung_od-so_thung.
      IF <lfs_thung>-has_error = abap_true.
        CONTINUE.
      ENDIF.

      LOOP AT lt_db INTO DATA(ls_db) WHERE so_thung = ls_thung_od-so_thung
                                       AND del_flag = del_flag-none.
        APPEND VALUE #( SoThung           = ls_db-so_thung
                        Material          = ls_db-material
                        Batch             = ls_db-batch
                        Delivery          = ls_thung_od-delivery
                        %control-Delivery = if_abap_behv=>mk-on ) TO lt_update.
      ENDLOOP.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zi_thung_mau
        ENTITY ThungMau
          UPDATE FROM lt_update
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

      LOOP AT ls_failed-thungmau INTO DATA(ls_fail).
        READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = ls_fail-SoThung.
        IF sy-subrc = 0.
          <lfs_thung>-has_error = abap_true.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " ── 5. Trả message cho từng dòng ──────────────────────────────
    LOOP AT ct_data ASSIGNING <lfs_data> WHERE messagetype <> 'E'.
      READ TABLE lt_thung ASSIGNING <lfs_thung> WITH TABLE KEY so_thung = <lfs_data>-so_thung.
      IF <lfs_thung>-has_error = abap_true.
        set_error_od( EXPORTING iv_message = |Không cập nhật được lệnh xuất hàng cho thùng { <lfs_data>-so_thung }|
                      CHANGING  cs_data    = <lfs_data> ).
        CONTINUE.
      ENDIF.

      " OD cũ của thùng (trước khi cập nhật) để báo thêm mới hay ghi đè
      READ TABLE lt_db INTO ls_db WITH KEY so_thung = <lfs_data>-so_thung
                                           del_flag = del_flag-none.
      <lfs_data>-messagetype = 'S'.
      <lfs_data>-message     = COND #( WHEN ls_db-delivery IS INITIAL
                                       THEN |Thêm lệnh xuất hàng thành công|
                                       WHEN ls_db-delivery = <lfs_data>-delivery
                                       THEN |Lệnh xuất hàng không thay đổi|
                                       ELSE |Cập nhật lệnh xuất hàng thành công (thay cho { ls_db-delivery ALPHA = OUT })| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD set_error_od.
    " Giữ lỗi đầu tiên của dòng
    IF cs_data-messagetype = 'E'.
      RETURN.
    ENDIF.

    cs_data-messagetype = 'E'.
    cs_data-message     = iv_message.
  ENDMETHOD.


  METHOD set_error.
    " Giữ lỗi đầu tiên của dòng
    IF cs_data-messagetype = 'E'.
      RETURN.
    ENDIF.

    cs_data-messagetype = 'E'.
    cs_data-message     = iv_message.
  ENDMETHOD.
ENDCLASS.
