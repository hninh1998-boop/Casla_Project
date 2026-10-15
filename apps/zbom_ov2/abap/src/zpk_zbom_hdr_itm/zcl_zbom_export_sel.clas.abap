CLASS zcl_zbom_export_sel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES tt_headers TYPE STANDARD TABLE OF zce_zbom_header WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_filter_range,
             field_name TYPE string,
             sign       TYPE c LENGTH 1,
             option     TYPE c LENGTH 2,
             low        TYPE string,
             high       TYPE string,
           END OF ty_filter_range,
           tt_filter_range TYPE STANDARD TABLE OF ty_filter_range WITH EMPTY KEY.

    "! Chọn header cho Explode Excel BOM theo bộ lọc UI gửi sang.
    "! Cố ý KHÔNG dùng lại zcl_zbom_header_ce: class đó phục vụ màn hình
    "! báo cáo và phải giữ nguyên. Hệ quả: logic lọc có 2 bản, sửa 1 bên
    "! thì phải sửa bên kia, nếu không file export lệch với báo cáo.
    METHODS select_headers
      IMPORTING it_ranges          TYPE tt_filter_range
                iv_bomcategory     TYPE string
                iv_search          TYPE string OPTIONAL
      EXPORTING et_unmapped_fields TYPE string_table
      RETURNING VALUE(rt_headers)  TYPE tt_headers.

  PRIVATE SECTION.
    METHODS build_select_from
      IMPORTING iv_bomcategory TYPE string
      RETURNING VALUE(rv_from) TYPE string.

    METHODS build_elements
      IMPORTING iv_bomcategory     TYPE string
      RETURNING VALUE(rv_elements) TYPE string.

    METHODS build_sql_filter
      IMPORTING it_ranges            TYPE tt_filter_range
                iv_bomcategory       TYPE string
      EXPORTING et_unmapped_fields   TYPE string_table
      RETURNING VALUE(rv_sql_filter) TYPE string.

    "! Dựng điều kiện SQL cho một range.
    "! Lưu ý về field đệm '0' (MATERIAL, BILLOFMATERIAL, SALESORDER,
    "! SALESORDERITEM): với CP dạng "*X" / "*X*" ta dịch thẳng sang '%',
    "! chỉ đúng khi X không bắt đầu bằng '0'. Nếu người dùng gõ chuỗi tìm
    "! bắt đầu bằng '0' thì có thể khớp nhầm vào phần đệm.
    METHODS cond_for_range
      IMPORTING iv_field       TYPE string
                iv_column      TYPE string
                is_range       TYPE ty_filter_range
      RETURNING VALUE(rv_cond) TYPE string.

    METHODS pad_left
      IMPORTING iv_value        TYPE string
                iv_width        TYPE i
      RETURNING VALUE(rv_value) TYPE string.

    METHODS fill_required_quantity
      CHANGING ct_headers TYPE tt_headers.

    METHODS components_of
      IMPORTING iv_entity     TYPE string
      RETURNING VALUE(rt_tab) TYPE cl_abap_structdescr=>component_table.
ENDCLASS.


CLASS zcl_zbom_export_sel IMPLEMENTATION.

  METHOD select_headers.
    DATA lt_search_hits TYPE tt_headers.

    " lv_lang trông như không dùng nhưng có: nó là host variable được
    " tham chiếu bằng '@lv_lang' trong chuỗi JOIN của build_select_from,
    " nên phải tồn tại đúng ở method chạy lệnh SELECT động.
    DATA lv_lang TYPE sy-langu ##NEEDED.
    lv_lang = sy-langu.

    CLEAR et_unmapped_fields.

    IF iv_bomcategory <> 'K' AND iv_bomcategory <> 'M'.
      RETURN.
    ENDIF.

    DATA(lv_filter) = build_sql_filter(
      EXPORTING it_ranges          = it_ranges
                iv_bomcategory     = iv_bomcategory
      IMPORTING et_unmapped_fields = et_unmapped_fields ).

    IF et_unmapped_fields IS NOT INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_from)     = build_select_from( iv_bomcategory ).
    DATA(lv_elements) = build_elements( iv_bomcategory ).

    TRY.
        SELECT DISTINCT (lv_elements)
          FROM (lv_from)
          WHERE (lv_filter)
          INTO CORRESPONDING FIELDS OF TABLE @rt_headers.
      CATCH cx_sy_dynamic_osql_semantics cx_sy_dynamic_osql_syntax.
        CLEAR rt_headers.
        RETURN.
    ENDTRY.

    SORT rt_headers.
    DELETE ADJACENT DUPLICATES FROM rt_headers
      COMPARING BillOfMaterialCategory Material Plant SalesOrder SalesOrderItem.

    " Search: tìm chuỗi trên kết quả đã select, giống cách màn hình làm.
    IF iv_search IS NOT INITIAL.
      FIND ALL OCCURRENCES OF iv_search IN TABLE rt_headers
        IGNORING CASE RESULTS DATA(lt_hits).
      LOOP AT lt_hits INTO DATA(ls_hit).
        APPEND rt_headers[ ls_hit-line ] TO lt_search_hits.
      ENDLOOP.
      DELETE ADJACENT DUPLICATES FROM lt_search_hits COMPARING ALL FIELDS.
      rt_headers = lt_search_hits.
    ENDIF.

    fill_required_quantity( CHANGING ct_headers = rt_headers ).
  ENDMETHOD.


  METHOD build_select_from.
    DATA(lv_source) = COND string( WHEN iv_bomcategory = 'K'
                                   THEN `I_SalesOrderBOMLink`
                                   ELSE `I_MaterialBOMLink` ).

    rv_from = lv_source &&
      | LEFT OUTER JOIN I_PlantStdVH| &&
      |   ON { lv_source }~Plant = I_PlantStdVH~Plant| &&
      | LEFT OUTER JOIN I_ProductDescription| &&
      |   ON { lv_source }~Material = I_ProductDescription~Product| &&
      |   AND I_ProductDescription~Language = @lv_lang| &&
      | LEFT OUTER JOIN I_Product| &&
      |   ON { lv_source }~Material = I_Product~Product|.

    IF iv_bomcategory = 'K'.
      rv_from = rv_from &&
        | LEFT OUTER JOIN I_SalesOrderScheduleLine| &&
        |   ON I_SalesOrderBOMLink~SalesOrder = I_SalesOrderScheduleLine~SalesOrder| &&
        |   AND I_SalesOrderBOMLink~SalesOrderItem = I_SalesOrderScheduleLine~SalesOrderItem|.
    ENDIF.
  ENDMETHOD.


  METHOD build_elements.
    DATA lt_final TYPE string_table.

    DATA(lv_source) = COND string( WHEN iv_bomcategory = 'K'
                                   THEN `I_SalesOrderBOMLink`
                                   ELSE `I_MaterialBOMLink` ).
    DATA(lt_comp) = components_of( lv_source ).

    " Field key: đọc component thật của view để tự bỏ field không tồn tại
    " (I_MaterialBOMLink không có SalesOrder/SalesOrderItem).
    DATA(lt_keys) = VALUE string_table(
      ( `BILLOFMATERIAL` ) ( `BILLOFMATERIALCATEGORY` ) ( `MATERIAL` ) ( `PLANT` )
      ( `BILLOFMATERIALVARIANTUSAGE` ) ( `SALESORDER` ) ( `SALESORDERITEM` ) ).

    LOOP AT lt_keys INTO DATA(lv_elem).
      READ TABLE lt_comp TRANSPORTING NO FIELDS WITH KEY name = lv_elem.
      IF sy-subrc = 0.
        APPEND |{ lv_source }~{ lv_elem }| TO lt_final.
      ENDIF.
    ENDLOOP.

    " Các field hiển thị cũng phải select, vì ô Search quét trên toàn bộ
    " nội dung dòng: không select PlantName thì tìm theo tên nhà máy sẽ
    " ra kết quả khác màn hình.
    APPEND `I_ProductDescription~ProductDescription` TO lt_final.
    APPEND `I_PlantStdVH~PlantName`                  TO lt_final.
    APPEND `I_Product~ProductType`                   TO lt_final.

    IF iv_bomcategory = 'K'.
      APPEND `I_SalesOrderScheduleLine~DeliveryDate` TO lt_final.
    ENDIF.

    rv_elements = concat_lines_of( table = lt_final sep = `, ` ).
  ENDMETHOD.


  METHOD build_sql_filter.
    TYPES: BEGIN OF ty_col_map,
             field  TYPE string,
             column TYPE string,
           END OF ty_col_map.

    DATA lt_map TYPE STANDARD TABLE OF ty_col_map WITH EMPTY KEY.
    DATA lt_and TYPE string_table.
    DATA lt_or  TYPE string_table.

    CLEAR et_unmapped_fields.

    DATA(lv_source) = COND string( WHEN iv_bomcategory = 'K'
                                   THEN `I_SalesOrderBOMLink`
                                   ELSE `I_MaterialBOMLink` ).

    " Tên cột CHỈ lấy từ bảng map này, giá trị thì escape ở cond_for_range,
    " nên input từ UI không mở đường SQL injection vào lệnh động.
    lt_map = VALUE #(
      ( field = `BILLOFMATERIAL`             column = |{ lv_source }~BillOfMaterial| )
      ( field = `BILLOFMATERIALCATEGORY`     column = |{ lv_source }~BillOfMaterialCategory| )
      ( field = `MATERIAL`                   column = |{ lv_source }~Material| )
      ( field = `PLANT`                      column = |{ lv_source }~Plant| )
      ( field = `BILLOFMATERIALVARIANTUSAGE` column = |{ lv_source }~BillOfMaterialVariantUsage| )
      ( field = `PRODUCTTYPE`                column = `I_Product~ProductType` ) ).

    IF iv_bomcategory = 'K'.
      APPEND VALUE #( field  = `SALESORDER`
                      column = `I_SalesOrderBOMLink~SalesOrder` ) TO lt_map.
      APPEND VALUE #( field  = `SALESORDERITEM`
                      column = `I_SalesOrderBOMLink~SalesOrderItem` ) TO lt_map.
      APPEND VALUE #( field  = `DELIVERYDATE`
                      column = `I_SalesOrderScheduleLine~DeliveryDate` ) TO lt_map.
    ENDIF.

    DATA(lt_ranges) = it_ranges.
    LOOP AT lt_ranges ASSIGNING FIELD-SYMBOL(<ls_norm>).
      <ls_norm>-field_name = to_upper( <ls_norm>-field_name ).
    ENDLOOP.
    SORT lt_ranges BY field_name.

    LOOP AT lt_ranges INTO DATA(ls_range)
         GROUP BY ( field = ls_range-field_name )
         INTO DATA(lg_group).

      READ TABLE lt_map INTO DATA(ls_map) WITH KEY field = lg_group-field.
      IF sy-subrc <> 0.
        " Trường không dịch được sang SQL. Nếu bỏ qua thì job ra NHIỀU dòng
        " hơn màn hình -> trả ra ngoài để caller dừng, không gửi file sai.
        APPEND lg_group-field TO et_unmapped_fields.
        CONTINUE.
      ENDIF.

      CLEAR lt_or.
      DATA(lv_excl) = ``.

      LOOP AT GROUP lg_group INTO DATA(ls_member).
        DATA(lv_cond) = cond_for_range( iv_field  = lg_group-field
                                        iv_column = ls_map-column
                                        is_range  = ls_member ).
        IF lv_cond IS INITIAL.
          APPEND lg_group-field TO et_unmapped_fields.
          CONTINUE.
        ENDIF.

        IF ls_member-sign = 'E'.
          lv_excl = COND #( WHEN lv_excl IS INITIAL THEN lv_cond
                            ELSE |{ lv_excl } OR { lv_cond }| ).
        ELSE.
          APPEND lv_cond TO lt_or.
        ENDIF.
      ENDLOOP.

      IF lt_or IS NOT INITIAL.
        APPEND |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )| TO lt_and.
      ENDIF.
      IF lv_excl IS NOT INITIAL.
        APPEND |NOT ( { lv_excl } )| TO lt_and.
      ENDIF.
    ENDLOOP.

    SORT et_unmapped_fields.
    DELETE ADJACENT DUPLICATES FROM et_unmapped_fields.

    rv_sql_filter = COND #( WHEN lt_and IS INITIAL THEN `1 = 1`
                            ELSE concat_lines_of( table = lt_and sep = ` AND ` ) ).
  ENDMETHOD.


  METHOD cond_for_range.
    DATA lt_or   TYPE string_table.
    DATA lv_zero TYPE string.

    DATA(lv_low)  = cl_abap_dyn_prg=>escape_quotes_str( CONV string( is_range-low ) ).
    DATA(lv_high) = cl_abap_dyn_prg=>escape_quotes_str( CONV string( is_range-high ) ).

    " Các field này lưu nội bộ căn phải, đệm '0' cho đủ độ dài field:
    " material hiển thị "300002727" nằm trong cột là "000000000300002727".
    DATA(lv_width) = SWITCH i( iv_field
                               WHEN 'MATERIAL'       THEN 18
                               WHEN 'BILLOFMATERIAL' THEN 8
                               WHEN 'SALESORDER'     THEN 10
                               WHEN 'SALESORDERITEM' THEN 6
                               ELSE 0 ).

    IF lv_width > 0 AND is_range-option = 'CP'.
      DATA(lv_pat) = lv_low.
      REPLACE ALL OCCURRENCES OF '+' IN lv_pat WITH '_'.

      IF strlen( lv_pat ) > 0 AND lv_pat(1) = '*'.
        " "*3000" / "*3000*": không neo vào đầu giá trị hiển thị nên đổi
        " thẳng '*' thành '%' là đúng - phần đệm chỉ toàn '0' nên chuỗi tìm
        " bắt đầu bằng chữ số khác 0 không thể khớp nhầm vào vùng đệm.
        REPLACE ALL OCCURRENCES OF '*' IN lv_pat WITH '%'.
        rv_cond = |{ iv_column } LIKE '{ lv_pat }'|.
      ELSE.
        " "3000*" = giá trị HIỂN THỊ bắt đầu bằng 3000, tức trong cột thật
        " là một dãy '0' rồi mới tới "3000". Số '0' phụ thuộc độ dài material
        " của từng dòng nên phải liệt kê hết các khả năng.
        " KHÔNG dùng '%3000%': nó khớp nhầm cả material như 200030001.
        DATA(lv_like) = lv_pat.
        REPLACE ALL OCCURRENCES OF '*' IN lv_like WITH '%'.

        DATA(lv_fix) = lv_pat.
        REPLACE ALL OCCURRENCES OF '*' IN lv_fix WITH ``.

        DATA(lv_max_zero) = lv_width - strlen( lv_fix ).
        IF lv_max_zero < 0.
          lv_max_zero = 0.
        ENDIF.

        CLEAR lv_zero.
        WHILE strlen( lv_zero ) <= lv_max_zero.
          APPEND |{ iv_column } LIKE '{ lv_zero }{ lv_like }'| TO lt_or.
          lv_zero = |{ lv_zero }0|.
        ENDWHILE.

        rv_cond = |( { concat_lines_of( table = lt_or sep = ` OR ` ) } )|.
      ENDIF.

      RETURN.
    ENDIF.

    IF lv_width > 0.
      lv_low = pad_left( iv_value = lv_low iv_width = lv_width ).
      IF lv_high IS NOT INITIAL.
        lv_high = pad_left( iv_value = lv_high iv_width = lv_width ).
      ENDIF.
    ENDIF.

    CASE is_range-option.
      WHEN 'EQ'. rv_cond = |{ iv_column } = '{ lv_low }'|.
      WHEN 'NE'. rv_cond = |{ iv_column } <> '{ lv_low }'|.
      WHEN 'GE'. rv_cond = |{ iv_column } >= '{ lv_low }'|.
      WHEN 'GT'. rv_cond = |{ iv_column } > '{ lv_low }'|.
      WHEN 'LE'. rv_cond = |{ iv_column } <= '{ lv_low }'|.
      WHEN 'LT'. rv_cond = |{ iv_column } < '{ lv_low }'|.
      WHEN 'BT'. rv_cond = |{ iv_column } BETWEEN '{ lv_low }' AND '{ lv_high }'|.
      WHEN 'CP'.
        REPLACE ALL OCCURRENCES OF '*' IN lv_low WITH '%'.
        REPLACE ALL OCCURRENCES OF '+' IN lv_low WITH '_'.
        rv_cond = |{ iv_column } LIKE '{ lv_low }'|.
      WHEN OTHERS.
        CLEAR rv_cond.
    ENDCASE.
  ENDMETHOD.


  METHOD pad_left.
    rv_value = iv_value.
    WHILE strlen( rv_value ) < iv_width.
      rv_value = |0{ rv_value }|.
    ENDWHILE.
  ENDMETHOD.


  METHOD fill_required_quantity.
    TYPES: BEGIN OF ty_key,
             salesorder     TYPE i_salesorderitem-salesorder,
             salesorderitem TYPE i_salesorderitem-salesorderitem,
             plant          TYPE i_salesorderitem-plant,
             product        TYPE i_salesorderitem-product,
           END OF ty_key,
           BEGIN OF ty_qty,
             salesorder     TYPE i_salesorderitem-salesorder,
             salesorderitem TYPE i_salesorderitem-salesorderitem,
             plant          TYPE i_salesorderitem-plant,
             product        TYPE i_salesorderitem-product,
             orderquantity  TYPE i_salesorderitem-orderquantity,
           END OF ty_qty.

    DATA lt_keys    TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.
    DATA lt_qty     TYPE SORTED TABLE OF ty_qty
                    WITH NON-UNIQUE KEY salesorder salesorderitem plant product.
    DATA lv_product TYPE i_salesorderitem-product.

    " Gom key của BOM loại K rồi đọc 1 lần, thay vì 1 SELECT SINGLE mỗi dòng.
    LOOP AT ct_headers ASSIGNING FIELD-SYMBOL(<ls_row>)
         WHERE BillOfMaterialCategory = 'K'.
      APPEND VALUE #(
        salesorder     = <ls_row>-SalesOrder
        salesorderitem = <ls_row>-SalesOrderItem
        plant          = <ls_row>-Plant
        product        = |{ <ls_row>-Material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
      ) TO lt_keys.
    ENDLOOP.

    IF lt_keys IS NOT INITIAL.
      SORT lt_keys BY salesorder salesorderitem plant product.
      DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING ALL FIELDS.

      SELECT SalesOrder, SalesOrderItem, Plant, Product, OrderQuantity
        FROM i_salesorderitem
        FOR ALL ENTRIES IN @lt_keys
        WHERE SalesOrder     = @lt_keys-salesorder
          AND SalesOrderItem = @lt_keys-salesorderitem
          AND Plant          = @lt_keys-plant
          AND Product        = @lt_keys-product
        INTO CORRESPONDING FIELDS OF TABLE @lt_qty.
    ENDIF.

    LOOP AT ct_headers ASSIGNING <ls_row>.
      IF <ls_row>-BillOfMaterialCategory = 'M'.
        <ls_row>-RequiredQuantityHeader = 1000.
        CONTINUE.
      ENDIF.
      IF <ls_row>-BillOfMaterialCategory <> 'K'.
        CONTINUE.
      ENDIF.

      lv_product = |{ <ls_row>-Material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
      READ TABLE lt_qty INTO DATA(ls_qty)
        WITH KEY salesorder     = <ls_row>-SalesOrder
                 salesorderitem = <ls_row>-SalesOrderItem
                 plant          = <ls_row>-Plant
                 product        = lv_product.
      <ls_row>-RequiredQuantityHeader = COND #( WHEN sy-subrc = 0
                                                THEN ls_qty-orderquantity
                                                ELSE 1000 ).
    ENDLOOP.
  ENDMETHOD.


  METHOD components_of.
    DATA(lo_type) = cl_abap_typedescr=>describe_by_name( iv_entity ).
    rt_tab = CAST cl_abap_structdescr( lo_type )->get_components( ).
  ENDMETHOD.

ENDCLASS.

