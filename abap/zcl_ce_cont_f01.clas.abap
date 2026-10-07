CLASS zcl_ce_cont_f01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS requested
      IMPORTING
        io_request TYPE REF TO if_rap_query_request
      EXPORTING
        et_filters TYPE if_rap_query_filter=>tt_name_range_pairs.

    CLASS-METHODS response
      IMPORTING
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response
      CHANGING
        ct_result   TYPE zcl_ce_cont_top=>tt_result.

    CLASS-METHODS main
      IMPORTING
        it_filters TYPE if_rap_query_filter=>tt_name_range_pairs
      EXPORTING
        et_result  TYPE zcl_ce_cont_top=>tt_result.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS build_param
      IMPORTING
        it_filters            TYPE if_rap_query_filter=>tt_name_range_pairs
      EXPORTING
        er_diadiemdonghang    TYPE zcl_ce_cont_top=>ry_string
        er_so                 TYPE zcl_ce_cont_top=>ry_string
        er_solenhxuathang     TYPE zcl_ce_cont_top=>ry_string
        er_ngaygiaohangdukien TYPE zcl_ce_cont_top=>ry_string
        er_soitem             TYPE zcl_ce_cont_top=>ry_string
        er_solenhxuathangitem TYPE zcl_ce_cont_top=>ry_string
        er_ngay               TYPE zcl_ce_cont_top=>ry_string
        er_plant              TYPE zcl_ce_cont_top=>ry_string
        er_sokh               TYPE zcl_ce_cont_top=>ry_string.

    CLASS-METHODS get_keys
      IMPORTING
        ir_diadiemdonghang    TYPE zcl_ce_cont_top=>ry_string
        ir_so                 TYPE zcl_ce_cont_top=>ry_string
        ir_solenhxuathang     TYPE zcl_ce_cont_top=>ry_string
        ir_ngaygiaohangdukien TYPE zcl_ce_cont_top=>ry_string
        ir_soitem             TYPE zcl_ce_cont_top=>ry_string
        ir_solenhxuathangitem TYPE zcl_ce_cont_top=>ry_string
        ir_ngay               TYPE zcl_ce_cont_top=>ry_string
        ir_plant              TYPE zcl_ce_cont_top=>ry_string
        ir_sokh               TYPE zcl_ce_cont_top=>ry_string
      EXPORTING
        et_keys               TYPE zcl_ce_cont_top=>tt_key.

    CLASS-METHODS get_longtext_result_data
      IMPORTING
        it_longtext    TYPE zcl_ce_cont_top=>tt_longtext
        iv_longtextid  TYPE string
        iv_od          TYPE I_OutboundDelivery-OutboundDelivery
      RETURNING
        VALUE(rv_data) TYPE string.

    CLASS-METHODS get_longtext_result
      IMPORTING
        it_longtext TYPE zcl_ce_cont_top=>tt_longtext
        it_bases    TYPE zcl_ce_cont_top=>tt_base
        is_key      TYPE zcl_ce_cont_top=>ty_key
        iv_od       TYPE I_OutboundDelivery-OutboundDelivery
      CHANGING
        cs_result   TYPE zce_cont.

    CLASS-METHODS get_longtext_cont
      IMPORTING
        it_keys     TYPE zcl_ce_cont_top=>tt_key
      EXPORTING
        et_longtext TYPE zcl_ce_cont_top=>tt_longtext.

    CLASS-METHODS build_result
      IMPORTING
        it_keys            TYPE zcl_ce_Cont_top=>tt_key
        it_longtext        TYPE zcl_ce_Cont_top=>tt_longtext
        it_bases           TYPE zcl_ce_Cont_top=>tt_base
        it_kichthuoctui    TYPE zcl_ce_Cont_top=>tt_kichthuoctui
        ir_ngay            TYPE zcl_ce_Cont_top=>ry_string
        ir_diadiemdonghang TYPE zcl_ce_Cont_top=>ry_string
        it_quantity        TYPE zcl_ce_Cont_top=>tt_quantity
      EXPORTING
        et_result          TYPE zcl_ce_Cont_top=>tt_result.

    CLASS-METHODS get_bases
      IMPORTING
        it_keys  TYPE zcl_ce_cont_top=>tt_key
      EXPORTING
        et_bases TYPE zcl_ce_cont_top=>tt_base.

    CLASS-METHODS get_result_key
      IMPORTING
        is_key    TYPE zcl_ce_cont_top=>ty_key
      CHANGING
        cs_result TYPE zce_cont.

    CLASS-METHODS get_kichthuoctui
      IMPORTING
        it_bases        TYPE zcl_ce_cont_top=>tt_base
      EXPORTING
        et_kichthuoctui TYPE zcl_ce_cont_top=>tt_kichthuoctui.

    CLASS-METHODS get_base_result
      IMPORTING
        it_bases        TYPE zcl_ce_cont_top=>tt_base
        is_key          TYPE zcl_ce_cont_top=>ty_key
        it_kichthuoctui TYPE zcl_ce_cont_top=>tt_kichthuoctui
      CHANGING
        cs_result       TYPE zce_cont.

    CLASS-METHODS build_main
      IMPORTING
        ir_diadiemdonghang    TYPE zcl_ce_cont_top=>ry_string
        ir_so                 TYPE zcl_ce_cont_top=>ry_string
        ir_solenhxuathang     TYPE zcl_ce_cont_top=>ry_string
        ir_ngaygiaohangdukien TYPE zcl_ce_cont_top=>ry_string
        ir_soitem             TYPE zcl_ce_cont_top=>ry_string
        ir_solenhxuathangitem TYPE zcl_ce_cont_top=>ry_string
        ir_ngay               TYPE zcl_ce_cont_top=>ry_string
        ir_plant              TYPE zcl_ce_cont_top=>ry_string
        ir_sokh               TYPE zcl_ce_cont_top=>ry_string
      EXPORTING
        et_keys               TYPE zcl_ce_cont_top=>tt_key
        et_bases              TYPE zcl_ce_cont_top=>tt_base
        et_longtext           TYPE zcl_ce_cont_top=>tt_longtext
        et_kichthuoctui       TYPE zcl_ce_cont_top=>tt_kichthuoctui
        et_quantity           TYPE zcl_ce_cont_top=>tt_quantity.

    CLASS-METHODS add_new_line_result
      IMPORTING
        it_bases    TYPE zcl_ce_cont_top=>tt_base
        it_quantity TYPE zcl_ce_cont_top=>tt_quantity
      CHANGING
        ct_results  TYPE zcl_ce_cont_top=>tt_result.

    CLASS-METHODS get_quantity
      IMPORTING
        it_keys     TYPE zcl_ce_cont_top=>tt_key
      EXPORTING
        et_quantity TYPE zcl_ce_cont_top=>tt_quantity.

    CLASS-METHODS get_quantity_result
      IMPORTING
        it_quantity TYPE zcl_ce_cont_top=>tt_quantity
        is_key      TYPE zcl_ce_cont_top=>ty_key
      CHANGING
        cs_result   TYPE zce_cont.
ENDCLASS.



CLASS ZCL_CE_CONT_F01 IMPLEMENTATION.


  METHOD main.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "1. Build Param
    build_param(
      EXPORTING
        it_filters            = it_filters
      IMPORTING
        er_diadiemdonghang    = DATA(lr_diadiemdonghang)
        er_so                 = DATA(lr_so)
        er_solenhxuathang     = DATA(lr_solenhxuathang)
        er_ngaygiaohangdukien = DATA(lr_ngaygiaohangdukien)
        er_soitem             = DATA(lr_soitem)
        er_solenhxuathangitem = DATA(lr_solenhxuathangitem)
        er_ngay               = DATA(lr_ngay)
        er_plant              = DATA(lr_plant)
        er_sokh               = DATA(lr_sokh)
    ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "2. Build Main Data
    build_main(
      EXPORTING
        ir_diadiemdonghang    = lr_diadiemdonghang
        ir_so                 = lr_so
        ir_solenhxuathang     = lr_solenhxuathang
        ir_ngaygiaohangdukien = lr_ngaygiaohangdukien
        ir_soitem             = lr_soitem
        ir_solenhxuathangitem = lr_solenhxuathangitem
        ir_ngay               = lr_ngay
        ir_plant              = lr_plant
        ir_sokh               = lr_sokh
      IMPORTING
        et_keys               = DATA(lt_keys)
        et_bases              = DATA(lt_bases)
        et_longtext           = DATA(lt_longtext)
        et_kichthuoctui       = DATA(lt_kichthuoctui)
        et_quantity           = DATA(lt_quantity)
    ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "3. Build Result Data
    build_result(
      EXPORTING
        it_keys            = lt_keys
        it_longtext        = lt_longtext
        it_bases           = lt_bases
        it_kichthuoctui    = lt_kichthuoctui
        ir_ngay            = lr_ngay
        ir_diadiemdonghang = lr_diadiemdonghang
        it_quantity        = lt_quantity
      IMPORTING
        et_result   = et_result
    ).
  ENDMETHOD.


  METHOD requested.
    TRY.
        et_filters = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        "handle exception
    ENDTRY.
  ENDMETHOD.


  METHOD response.
    " ── a. AGGREGATION ──
    TRY.
        DATA(lo_aggregation) = io_request->get_aggregation( ).
        DATA(lt_group_by)    = lo_aggregation->get_grouped_elements( ).    " table of string
        DATA(lt_agg_elems)   = lo_aggregation->get_aggregated_elements( ). " table of ty_aggregation_element
      CATCH cx_rap_query_provider.
    ENDTRY.

    " ── b. RESPONSE ────────────────────────────────
    DATA(lv_total) = lines( ct_result ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( CONV int8( lv_total ) ).
    ENDIF.
    " ── c. HANDLE SORT ─────────────────────────────────────
    DATA(lt_sort) = io_request->get_sort_elements( ).
    IF lt_sort IS NOT INITIAL.
      DATA lt_sort_order TYPE abap_sortorder_tab.
      LOOP AT lt_sort INTO DATA(ls_sort).
        APPEND VALUE #(
            name       = ls_sort-element_name
            descending = ls_sort-descending
        ) TO lt_sort_order.
      ENDLOOP.
      SORT ct_result BY (lt_sort_order).
    ELSE.
      " Default sort: ưu tiên thứ tự user tự sắp xếp (SortOrder); các dòng cùng
      " SortOrder (vd chưa từng kéo-thả, đều = 0) thì fallback theo thứ tự cũ
      SORT ct_result BY
                        SoCont DESCENDING
                        SoChi DESCENDING
                        SortOrder ASCENDING
                        Cont DESCENDING
                        SoLenhXuatHang DESCENDING
                        SoLenhXuatHangItem
                        so
                        soitem.
    ENDIF.


    " ── d. PAGING ──────────────────────────────────────────
    DATA(lv_skip) = io_request->get_paging( )->get_offset( ).
    DATA(lv_top)  = io_request->get_paging( )->get_page_size( ).

    IF lv_top = if_rap_query_paging=>page_size_unlimited.
      lv_top = lv_total.
    ENDIF.

    IF lv_skip > 0.
      DELETE ct_result TO lv_skip.
    ENDIF.

    IF lv_top < lines( ct_result ).
      DELETE ct_result FROM lv_top + 1.
    ENDIF.

    io_response->set_data( ct_result ).
  ENDMETHOD.


  METHOD build_param.
    LOOP AT it_filters INTO  DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'DIADIEMDONGHANG'.
          er_diadiemdonghang = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'SO'.
          er_so = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'SOLENHXUATHANG'.
          er_solenhxuathang = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'SOLENHXUATHANGITEM'.
          er_solenhxuathangitem = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'NGAYGIAOHANGDUKIEN'.
          er_ngaygiaohangdukien = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'SOITEM'.
          er_soitem = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'NGAY'.
          er_ngay = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'PLANT'.
          er_plant = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
        WHEN 'SOKH'.
          er_sokh = CORRESPONDING zcl_ce_cont_top=>ry_string( ls_filter-range ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_keys.
    "Modify DO và DOItem cho case có SO nhưng chưa tạo DO --> chạy vào trong detail sẽ lỗi nếu không handle
    DATA(lr_temp_solenhxuathang) = ir_solenhxuathang.
    DATA(lr_temp_solenhxuathangitem) = ir_solenhxuathangitem.

    IF lines( lr_temp_solenhxuathang ) = 1.
      READ TABLE lr_temp_solenhxuathang INTO DATA(ls_do) INDEX 1.
      IF sy-subrc = 0.
        IF ls_do-low IS INITIAL AND ls_do-high IS INITIAL.
          CLEAR: lr_temp_solenhxuathang.
        ENDIF.
      ENDIF.
    ENDIF.
    IF lines( lr_temp_solenhxuathangitem ) = 1.
      READ TABLE lr_temp_solenhxuathangitem INTO DATA(ls_doitem) INDEX 1.
      IF sy-subrc = 0.
        IF ( ls_doitem-low IS INITIAL OR ls_doitem-low = '000000' )
            AND ( ls_doitem-high IS INITIAL OR ls_doitem-high = '000000' ).
          CLEAR: lr_temp_solenhxuathangitem.
        ENDIF.
      ENDIF.
    ENDIF.

    "Select keys
    SELECT FROM I_SalesOrderitem AS a
    LEFT JOIN I_SalesOrderitem AS aMaterial
        ON aMaterial~SalesOrder              = a~SalesOrder
        AND aMaterial~SalesOrderItem         = a~SalesOrderItem
        AND aMaterial~SalesOrderItemCategory = 'TAN'
    LEFT JOIN I_SalesOrderPartner AS b
        ON b~SalesOrder = a~SalesOrder
    LEFT JOIN I_OutboundDeliveryItem AS c
        ON c~ReferenceSDDocument      = a~SalesOrder
        AND c~ReferenceSDDocumentItem = a~SalesOrderItem
        AND c~GoodsMovementType       = '601'
        AND c~product                 = amaterial~product
        AND c~ActualDeliveryQuantity > 0
        AND ( a~DeliveryStatus = 'B' OR a~DeliveryStatus = 'C' )
    LEFT JOIN I_OutboundDelivery AS d
        ON d~OutboundDelivery = c~OutboundDelivery
    LEFT JOIN I_DeliveryDocument AS e
        ON e~DeliveryDocument = d~OutboundDelivery
        AND e~DeliveryDocumentType = 'LF'
    LEFT JOIN I_SalesOrderScheduleLine AS f
        ON f~SalesOrder = a~SalesOrder
        AND f~SalesOrderItem = a~SalesOrderItem
    LEFT JOIN zi_cont_text AS g
        ON g~so      = a~SalesOrder
        AND g~SoItem = a~SalesOrderItem
    INNER JOIN zvh_sokh_cont AS k "Số KH = SO/SOItem
        ON k~SalesOrder      = a~SalesOrder
        AND k~SalesOrderItem = a~SalesOrderItem
    FIELDS
        a~SalesOrder           AS so,
        a~SalesOrderItem       AS SOItem,
        c~OutboundDelivery     AS SoLenhXuatHang,
        c~OutboundDeliveryItem AS SoLenhXuatHangItem
    WHERE
        a~SalesOrderType             = 'TA'
        AND b~Customer               NOT IN ('0000006710','0000006720')
        AND a~SalesOrderItemCategory IN ('TAN', 'CBXN')

        AND ( a~plant                 IN @ir_diadiemdonghang
            OR g~DiaDiemDongHangCont IN @ir_diadiemdonghang )
        AND a~SalesOrder            IN @ir_so
        AND c~OutboundDelivery      IN @lr_temp_solenhxuathang
        AND a~RequestedDeliveryDate IN @ir_ngaygiaohangdukien
        AND a~SalesOrderItem        IN @ir_soitem
        AND c~OutboundDeliveryItem  IN @lr_temp_solenhxuathangitem
        AND a~plant                 IN @ir_plant
        AND k~SoKH                  IN @ir_sokh
    GROUP BY
        a~SalesOrder,
        a~SalesOrderItem,
        c~OutboundDelivery,
        c~OutboundDeliveryItem
    ORDER BY
        a~SalesOrder,
        a~SalesOrderItem,
        c~OutboundDelivery DESCENDING,
        c~OutboundDeliveryItem DESCENDING
    INTO TABLE @et_keys.
  ENDMETHOD.


  METHOD get_longtext_result_data.
    READ TABLE it_longtext INTO DATA(ls_longtext) WITH KEY entity
      COMPONENTS %key-OutboundDelivery = iv_od
                 %key-LongTextID = iv_longtextid
                 %key-Language = sy-langu.
    IF sy-subrc = 0.
      rv_data = ls_longtext-LongText.
    ENDIF.
  ENDMETHOD.


  METHOD get_longtext_result.
    "Giờ gọi cont về nhà máy - Z007
    cs_result-GioGoiContVeNM = get_longtext_result_data( it_longtext   = it_longtext
                                                 iv_longtextid = 'Z007'
                                                 iv_od         = iv_od ).
    "Số Cont - Uu tien: Z006 --> Neu khong co Z006 --> Lay Z005 "Update 24.08.2026
    DATA(lv_so_container) = get_longtext_result_data( it_longtext   = it_longtext
                                                      iv_longtextid = 'Z006'
                                                      iv_od         = iv_od ).
    IF lv_so_container IS NOT INITIAL.
      cs_result-socont = lv_so_container.
    ELSE.
      DATA(lv_bien_so_xe) = get_longtext_result_data( it_longtext   = it_longtext
                                                      iv_longtextid = 'Z005'
                                                      iv_od         = iv_od ).
      cs_result-socont = lv_bien_so_xe.
    ENDIF.

    "Số chì - Z029
    cs_result-SoChi = get_longtext_result_data( it_longtext   = it_longtext
                                                 iv_longtextid = 'Z029'
                                                 iv_od         = iv_od ).
    "Dev/NinhNH/cont/udt logic  - v1.7
    "Ưu tiên lấy ở ztable --> sau mới đến longtext
    "Ghi chú giao hàng - Z009
    "Ngày tàu chạy - Z010
    "Thời gian cắt máng - Z008
    READ TABLE it_bases INTO DATA(ls_ztab) WITH KEY so                 = is_key-so
                                                     soitem             = is_key-soitem
                                                     solenhxuathang     = is_key-solenhxuathang
                                                     solenhxuathangitem = is_key-solenhxuathangitem.
    IF sy-subrc = 0.
      IF ls_ztab-ghichugiaohang IS NOT INITIAL.
        cs_result-GhiChuGiaoHang = ls_ztab-ghichugiaohang.
      ELSE.
        cs_result-GhiChuGiaoHang = get_longtext_result_data( it_longtext   = it_longtext
                                                             iv_longtextid = 'Z009'
                                                             iv_od         = iv_od ).
      ENDIF.
      IF ls_ztab-NgayTauChay IS NOT INITIAL.
        cs_result-NgayTauChay = ls_ztab-NgayTauChay.
      ELSE.
        cs_result-NgayTauChay = get_longtext_result_data( it_longtext   = it_longtext
                                                          iv_longtextid = 'Z010'
                                                          iv_od         = iv_od ).
      ENDIF.
      IF ls_ztab-ThoiGianCatMang IS NOT INITIAL.
        cs_result-ThoiGianCatMang = ls_ztab-ThoiGianCatMang.
      ELSE.
        cs_result-ThoiGianCatMang = get_longtext_result_data( it_longtext   = it_longtext
                                                              iv_longtextid = 'Z008'
                                                              iv_od         = iv_od ).
      ENDIF.
    ENDIF.

    "Tare Weight - Z045
    cs_result-TareWeight = get_longtext_result_data( it_longtext   = it_longtext
                                                     iv_longtextid = 'Z045'
                                                     iv_od         = iv_od ).

    "Cont - Z034
    cs_result-cont = get_longtext_result_data( it_longtext   = it_longtext
                                               iv_longtextid = 'Z034'
                                               iv_od         = iv_od ).

    "Booking - Z047 "Update 24.08.2026
    cs_result-Booking = get_longtext_result_data( it_longtext   = it_longtext
                                                  iv_longtextid = 'Z047'
                                                  iv_od         = iv_od ).
  ENDMETHOD.


  METHOD get_longtext_cont.
    READ ENTITIES OF I_OutboundDeliveryTP FORWARDING PRIVILEGED
    ENTITY OutboundDelivery
    BY \_Text
    ALL FIELDS WITH VALUE #( FOR key IN it_keys
        ( OutboundDelivery = key-solenhxuathang )
    )
    RESULT et_longtext
    FAILED DATA(ls_failed)
    REPORTED DATA(lt_reported).
  ENDMETHOD.


  METHOD build_result.
    "Get Material
    SELECT FROM I_SalesOrderItem AS a
    FIELDS
        a~SalesOrder,
        a~SalesOrderItem,

        a~Product
    FOR ALL ENTRIES IN @it_keys
    WHERE
        a~SalesOrder = @it_keys-so
        AND a~SalesOrderItem = @it_keys-soitem
        AND a~SalesOrderItemCategory IN ( 'TAN', 'CBXN' )
    INTO TABLE @DATA(lt_material).
    IF lt_material IS NOT INITIAL.
      DATA: lr_mara TYPE RANGE OF I_ClfnObjectCharcValue-CharcValue.

      LOOP AT lt_material INTO DATA(ls_material).
        APPEND INITIAL LINE TO lr_mara ASSIGNING FIELD-SYMBOL(<lfs_mara>).
        <lfs_mara>-sign   = 'I'.
        <lfs_mara>-option = 'EQ'.
        <lfs_mara>-low    = ls_material-Product.
      ENDLOOP.

      SELECT FROM I_ClfnObjectCharcValue AS a
      INNER JOIN I_ClfnCharacteristic AS b
          ON b~CharcInternalID     = a~CharcInternalID
          AND b~TimeIntervalNumber = a~TimeIntervalNumber
      FIELDS
          a~ClfnObjectID,
          b~Characteristic,

          a~CharcValue
      WHERE
          b~Characteristic      IN ( 'Z_LOAIMANG', 'Z_LOAIMANH' )
          AND a~ClassType       = '001'
          AND a~ClfnObjectID IN @lr_mara
          AND a~ClfnObjectTable = 'MARA'
      INTO TABLE @DATA(lt_mara).
    ENDIF.

    "Main Processing result data
    LOOP AT it_keys  INTO DATA(ls_key).
      DATA(lv_tabix) = sy-tabix.

      APPEND INITIAL LINE TO et_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      "Key fields
      get_result_key( EXPORTING is_key    = ls_key
                      CHANGING  cs_result = <lfs_result> ).

      "Long text fields
      get_longtext_result( EXPORTING it_longtext = it_longtext
                                     it_bases    = it_bases
                                     is_key      = ls_key
                                     iv_od       = ls_key-solenhxuathang
                           CHANGING  cs_result   = <lfs_result> ).

      "Base fields
      get_base_result( EXPORTING it_bases        = it_bases
                                 is_key          = ls_key
                                 it_kichthuoctui = it_kichthuoctui
                       CHANGING  cs_result       = <lfs_result> ).

      "Số lượng chưa lên lệnh sản xuất
      get_quantity_result( EXPORTING it_quantity = it_quantity
                                     is_key      = ls_key
                            CHANGING cs_result   = <lfs_result> ).

      "Loại màng + Loại manh
      READ TABLE lt_material INTO ls_material WITH KEY SalesOrder     = ls_key-so
                                                       SalesOrderItem = ls_key-soitem
                                                       Product        = <lfs_result>-MaHang.
      IF sy-subrc = 0.
        LOOP AT lt_mara INTO DATA(ls_mara) WHERE ClfnObjectID = ls_material-Product.
          IF ls_mara-Characteristic = 'Z_LOAIMANG'.
            <lfs_result>-LoaiMang = ls_mara-CharcValue.
          ELSEIF ls_mara-Characteristic = 'Z_LOAIMANH'.
            <lfs_result>-LoaiManh = ls_mara-CharcValue.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    "Add thêm line phụ thuộc logic của quantity
    add_new_line_result( EXPORTING it_bases    = it_bases
                                   it_quantity = it_quantity
                          CHANGING ct_results  = et_result ).

    IF ir_ngay IS NOT INITIAL.
      DELETE et_result WHERE Ngay NOT IN ir_ngay.
    ENDIF.

    DELETE et_result WHERE DiaDiemDongHang NOT IN ir_diadiemdonghang.
  ENDMETHOD.


  METHOD get_bases.
    SELECT FROM @it_keys AS a
    LEFT JOIN I_SalesOrderItem AS b
        ON b~SalesOrder = a~so
        AND b~SalesOrderItem = a~soitem
    LEFT JOIN I_CnsldtnPlantT AS c
        ON c~plant = b~plant
        AND c~Language = @sy-langu
    LEFT JOIN I_OutboundDeliveryItem AS d
        ON d~OutboundDelivery = a~solenhxuathang
        AND d~OutboundDeliveryItem = a~solenhxuathangitem
    LEFT JOIN zi_cont_text AS e
        ON e~So = a~so
        AND e~SoItem = a~soitem
        AND e~SoLenh = a~solenhxuathang
        AND e~SoLenhItem = a~solenhxuathangitem
    LEFT JOIN I_CompanyCode AS f
        ON f~CompanyCode = b~SalesOrganization
    LEFT JOIN I_DeliveryDocument AS g
        ON g~DeliveryDocument = a~solenhxuathang
        AND g~DeliveryDocumentType = 'LF'
    LEFT JOIN I_SalesOrderScheduleLine AS h
        ON h~SalesOrder = a~so
        AND h~SalesOrderItem = a~soitem
    LEFT JOIN I_OutboundDelivery AS i
        ON i~OutboundDelivery = a~solenhxuathang
        AND i~OverallGoodsMovementStatus IS NOT INITIAL
    LEFT JOIN I_SalesOrderPartner AS j
        ON j~SalesOrder = a~so
        AND j~PartnerFunction = 'ZE'
    FIELDS
        "Key
        a~so,
        a~soitem,
        a~solenhxuathang,
        a~solenhxuathangitem,

        "Base
        b~RequestedDeliveryDate AS NgayGiaoHangDuKien,
        b~Product AS MaHang,
        b~SalesOrderItemText AS TenHang,
        CASE WHEN e~DiaDiemDongHangCont IS NOT INITIAL
             THEN e~DiaDiemDongHangCont
             ELSE b~Plant END AS DiaDiemDongHangCont,
        CASE WHEN e~DiaDiemDongHangContName IS NOT INITIAL
             THEN e~DiaDiemDongHangContName
             ELSE c~PlantName END AS DiaDiemDongHangContName,
        d~ActualDeliveryQuantity AS SoLuongTrenLenhXuatHang,
        d~DeliveryQuantityUnit,

        "Z Table
        e~DongDauThung,
        j~FullName AS NguoiPhuTrach, "Update 24.08.2026
        e~Cont,
        e~KeHoachDongCont,
        e~GhiChuKhac,
        e~GhiChuGiaoHang,
        e~NgayTauChay,
        e~ThoiGianCatMang,
        e~SortOrder,

        "Excel
        f~CompanyCodeName,
        CASE WHEN g~OverallGoodsMovementStatus = 'C' THEN g~ActualGoodsMovementDate
             WHEN e~NgayDongCont IS NOT INITIAL      THEN e~NgayDongCont
             WHEN g~OverallGoodsMovementStatus = 'A' THEN g~PlannedGoodsIssueDate
        END AS Ngay,

        "Số lượng chưa lên lệnh xuất hàng
        CASE WHEN h~IsConfirmedDelivSchedLine = 'X' THEN h~OpenConfdDelivQtyInBaseUnit ELSE 0
        END AS SoLuongChuaLenLenhXuatHang,
        h~DeliveredQuantityInBaseUnit, "Check case sinh thêm line "Update 25.08.2026
        h~IsConfirmedDelivSchedLine, "Check case sinh thêm line "Update 27.08.2026

        "Trạng thái OD
        i~\_OverallGoodsMovementStatus\_Text[ Language = @sy-langu ]-OverallGoodsMovementStatusDesc AS TrangThaiOD,
        b~Plant,
        c~PlantName
    INTO TABLE @et_bases.
  ENDMETHOD.


  METHOD get_result_key.
    cs_result-so                 = is_key-so.
    cs_result-SOItem             = is_key-soitem.
    cs_result-SoLenhXuatHang     = is_key-solenhxuathang.
    cs_result-SoLenhXuatHangItem = is_key-solenhxuathangitem.

    "Số Kế hoạch
    DATA(lv_so) = |{ is_key-so ALPHA = OUT }|.
    DATA(lv_soitem) = |{ is_key-soitem ALPHA = OUT }|.

    cs_result-SoKH = |{ lv_so }/{ lv_soitem }|.
    CONDENSE: cs_result-SoKH NO-GAPS.
  ENDMETHOD.


  METHOD get_kichthuoctui.
    "Bước 1: Check CDS view I_CLFNCHARACTERISTIC,
    "   check CHARACTERISTIC = Z_KICHTHUOC,
    "   lấy CHARCINTERNALID và TIMEINTERVALNUMBER
    SELECT SINGLE FROM I_ClfnCharacteristic
    FIELDS
        CharcInternalID,
        TimeIntervalNumber
    WHERE
        Characteristic = 'Z_KICHTHUOC'
    INTO @DATA(ls_kichthuoc).

    CHECK sy-subrc = 0.
    "Bước 2: CDS view I_CLFNOBJECTCHARCVALUE:
    "   Classtype = 001,
    "   CLFNOBJECTID = mã thành phẩm,
    "   CLFNOBJECTTABLE = MARA,
    "   CHARCINTERNALID =  CHARCINTERNALID  lấy được ở bước 1,
    "   TIMEINTERVALNUMBER=TIMEINTERVALNUMBER lấy được ở bước 1,
    "   ==> lấy trường CHARCVALUE
    SELECT FROM @it_bases AS a
    LEFT JOIN I_ClfnObjectCharcValue AS b
      ON b~ClfnObjectID = a~mahang
    FIELDS
        "Key fields
        a~so,
        a~soitem,
        a~solenhxuathang,
        a~solenhxuathangitem,
        b~ClfnObjectID AS mahang,

        b~CharcValue AS KichThuocTui
    WHERE
        b~ClassType = '001'
        AND b~ClfnObjectTable = 'MARA'
        AND b~CharcInternalID = @ls_kichthuoc-CharcInternalID
        AND b~TimeIntervalNumber = @ls_kichthuoc-TimeIntervalNumber
    INTO TABLE @et_kichthuoctui.
  ENDMETHOD.


  METHOD get_base_result.
    READ TABLE it_bases INTO DATA(ls_base) WITH KEY so                 = is_key-so
                                                    soitem             = is_key-soitem
                                                    solenhxuathang     = is_key-solenhxuathang
                                                    solenhxuathangitem = is_key-solenhxuathangitem.
    IF sy-subrc = 0.
      cs_result-NgayGiaoHangDuKien      = ls_base-ngaygiaohangdukien.
      cs_result-MaHang                  = ls_base-mahang.
      cs_result-TenHang                 = ls_base-tenhang.
      cs_result-DiaDiemDongHang         = ls_base-diadiemdonghang.
      cs_result-DiaDiemDongHangContName = ls_base-DiaDiemDongHangContName.
      cs_result-SoLuongTrenLenhXuatHang = ls_base-soluongtrenlenhxuathang.
      cs_result-DeliveryQuantityUnit    = ls_base-deliveryquantityunit.

      "Z table
      cs_result-DongDauThung      = ls_base-dongdauthung.
      cs_result-NguoiPhuTrachCont = ls_base-nguoiphutrach.
      IF cs_result-Cont IS INITIAL.
        cs_result-Cont              = ls_base-cont.
      ENDIF.
      cs_result-KeHoachDongCont   = ls_base-kehoachdongcont.
      cs_result-GhiChuKhac        = ls_base-GhiChuKhac.
      cs_result-SortOrder        = ls_base-SortOrder.

      "Kích thước túi
      READ TABLE it_kichthuoctui INTO DATA(ls_kichthuoctui) WITH KEY so                 = ls_base-so
                                                                     soitem             = ls_base-soitem
                                                                     solenhxuathang     = ls_base-solenhxuathang
                                                                     solenhxuathangitem = ls_base-solenhxuathangitem
                                                                     mahang             = ls_base-mahang.
      IF sy-subrc = 0.
        cs_result-KichThhuocTui = ls_kichthuoctui-kichthuoctui.
      ENDIF.

      "Excel
      cs_result-CompanyCodeName            = ls_base-companycodename.
      cs_result-Ngay                       = ls_base-ngay.

      "Trạng thái OD
      cs_result-TrangThaiOD = ls_base-trangthaiod.

      "Plant + Plant Name
      cs_result-Plant     = ls_base-plant.
      cs_result-PlantName = ls_base-plantname.

    ENDIF.
  ENDMETHOD.


  METHOD build_main.
    "1. Get key
    get_keys(
      EXPORTING
        ir_diadiemdonghang    = ir_diadiemdonghang
        ir_so                 = ir_so
        ir_solenhxuathang     = ir_solenhxuathang
        ir_ngaygiaohangdukien = ir_ngaygiaohangdukien
        ir_soitem             = ir_soitem
        ir_solenhxuathangitem = ir_solenhxuathangitem
        ir_ngay               = ir_ngay
        ir_plant              = ir_plant
        ir_sokh               = ir_sokh
      IMPORTING
        et_keys               = et_keys
    ).
    "2. Get longtext
    get_longtext_cont(
      EXPORTING
        it_keys     = et_keys
      IMPORTING
        et_longtext = et_longtext
    ).
    "3. Get base
    get_bases(
      EXPORTING
        it_keys  = et_keys
      IMPORTING
        et_bases = et_bases
    ).
    "4. Get Kích thước túi
    get_kichthuoctui(
      EXPORTING
        it_bases        = et_bases
      IMPORTING
        et_kichthuoctui = et_kichthuoctui
    ).

    "5. Get quantity
    get_quantity(
      EXPORTING
        it_keys     = et_keys
      IMPORTING
        et_quantity = et_quantity
    ).
  ENDMETHOD.


  METHOD add_new_line_result.
    DATA lt_new_line TYPE zcl_ce_cont_top=>tt_result.

    LOOP AT ct_results ASSIGNING FIELD-SYMBOL(<lfs_result>)
         GROUP BY ( so     = <lfs_result>-so
                    soitem = <lfs_result>-soitem )
         ASCENDING
         ASSIGNING FIELD-SYMBOL(<lfs_group>).

      LOOP AT GROUP <lfs_group> ASSIGNING FIELD-SYMBOL(<lfs_first>).
        EXIT. "chỉ cần dòng đầu tiên của nhóm để lấy thông tin đại diện
      ENDLOOP.

      READ TABLE it_quantity INTO DATA(ls_quantity) WITH KEY so                 = <lfs_first>-so
                                                             soitem             = <lfs_first>-SOItem
                                                             solenhxuathang     = <lfs_first>-solenhxuathang
                                                             SoLenhXuatHangItem = <lfs_first>-SoLenhXuatHangItem.
      IF sy-subrc = 0.
        IF ls_quantity-soluongchualenlenhsanxuat <> 0.
          IF ls_quantity-deliveredquantityinbaseunit <> 0.
            APPEND INITIAL LINE TO lt_new_line ASSIGNING FIELD-SYMBOL(<lfs_new>).
            <lfs_new>-so                         = <lfs_first>-so.
            <lfs_new>-soitem                     = <lfs_first>-soitem.
            <lfs_new>-sokh                       = <lfs_first>-sokh.
            <lfs_new>-tenhang                    = <lfs_first>-tenhang.
            <lfs_new>-kichthhuoctui              = <lfs_first>-kichthhuoctui.
            <lfs_new>-nguoiphutrachcont          = <lfs_first>-nguoiphutrachcont.
            <lfs_new>-soluongchualenlenhxuathang = <lfs_first>-soluongchualenlenhxuathang.
            <lfs_new>-baseunit                   = <lfs_first>-baseunit.
            <lfs_new>-DiaDiemDongHang            = <lfs_first>-DiaDiemDongHang.
            <lfs_new>-DiaDiemDongHangContName    = <lfs_first>-DiaDiemDongHangContName.
          ENDIF.
        ENDIF.
      ENDIF.

      "Add thông tin của button cập nhật thông tin cont
      SELECT SINGLE FROM zi_cont_text WITH PRIVILEGED ACCESS
      FIELDS
        NgayDongCont,
        DongDauThung,
        Cont,
        KeHoachDongCont,
        GhiChuKhac,
        GhiChuGiaoHang,
        NgayTauChay,
        ThoiGianCatMang,
        SortOrder
      WHERE
        so = @<lfs_first>-so
        AND soitem =  @<lfs_first>-SOItem
        AND SoLenh IS INITIAL
        AND SoLenhItem IS INITIAL
      INTO @DATA(ls_cont_text).
      IF sy-subrc = 0 AND <lfs_new> IS ASSIGNED.
        <lfs_new>-Ngay = ls_cont_text-NgayDongCont.
        <lfs_new>-DongDauThung = ls_cont_text-DongDauThung.
        <lfs_new>-Cont = ls_cont_text-Cont.
        <lfs_new>-KeHoachDongCont = ls_cont_text-KeHoachDongCont.
        <lfs_new>-GhiChuKhac = ls_cont_text-GhiChuKhac.
        <lfs_new>-GhiChuGiaoHang = ls_cont_text-GhiChuGiaoHang.
        <lfs_new>-NgayTauChay = ls_cont_text-NgayTauChay.
        <lfs_new>-ThoiGianCatMang = ls_cont_text-ThoiGianCatMang.
        <lfs_new>-SortOrder = ls_cont_text-SortOrder.
      ENDIF.

      UNASSIGN: <lfs_new>.
    ENDLOOP.

    IF lt_new_line IS NOT INITIAL.
      APPEND LINES OF lt_new_line TO ct_results.
    ENDIF.
  ENDMETHOD.


  METHOD get_quantity.
    SELECT FROM @it_keys AS a
    LEFT JOIN I_SalesOrderScheduleLine AS b
        ON b~SalesOrder = a~so
        AND b~SalesOrderItem = a~soitem
    FIELDS
        "key fields
        a~so,
        a~soitem,
        a~solenhxuathang,
        a~solenhxuathangitem,

        SUM( CASE WHEN b~IsConfirmedDelivSchedLine = 'X'
                  THEN b~OpenConfdDelivQtyInBaseUnit
                  ELSE 0
        END ) AS soluongchualenlenhsanxuat,
        SUM( b~DeliveredQuantityInBaseUnit ) AS DeliveredQuantityInBaseUnit
    GROUP BY
        a~so,
        a~soitem,
        a~solenhxuathang,
        a~solenhxuathangitem
    INTO TABLE @et_quantity.
  ENDMETHOD.


  METHOD get_quantity_result.
    READ TABLE it_quantity INTO DATA(ls_quantity) WITH KEY so                 = is_key-so
                                                           soitem             = is_key-soitem
                                                           solenhxuathang     = is_key-solenhxuathang
                                                           solenhxuathangitem = is_key-solenhxuathangitem.
    IF sy-subrc = 0.
      cs_result-SoLuongChuaLenLenhXuatHang = ls_quantity-soluongchualenlenhsanxuat.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
