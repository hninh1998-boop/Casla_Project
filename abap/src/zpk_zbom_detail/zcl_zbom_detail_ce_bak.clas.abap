CLASS zcl_zbom_detail_ce_bak DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .

    TYPES: tt_zce_zbom_detail TYPE STANDARD TABLE OF zce_zbom_detail WITH DEFAULT KEY.

    METHODS explode_header_for_export
      IMPORTING
                iv_billofmaterial             TYPE string
                iv_billofmaterialcategory     TYPE string
                iv_billofmaterialvariantusage TYPE string
                iv_material                   TYPE string
                iv_plant                      TYPE string
                iv_salesorder                 TYPE string
                iv_salesorderitem             TYPE string
                iv_requiredquantity           TYPE string
                iv_tabix                      TYPE sy-tabix DEFAULT 1
      RETURNING VALUE(rt_result)              TYPE tt_zce_zbom_detail.


  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_key_field,
             itemindex                  TYPE string,
             itemindexstring            TYPE string,
             billofmaterial             TYPE string,
             billofmaterialcategory     TYPE string,
             billofmaterialvariantusage TYPE string,
             material                   TYPE string,
             plant                      TYPE string,
             salesorder                 TYPE string,
             salesorderitem             TYPE string,
             requiredquantity           TYPE string,
           END OF ty_key_field,
           tt_key_field TYPE STANDARD TABLE OF ty_key_field WITH DEFAULT KEY.

    TYPES: tt_res               TYPE STANDARD TABLE OF zce_zbom_detail WITH DEFAULT KEY,
           ry_salesorder        TYPE RANGE OF vbeln,
           ry_material          TYPE RANGE OF matnr,
           ry_plant             TYPE RANGE OF werks_d,
           ty_numc6             TYPE n LENGTH 6,
           ry_salesorderitem    TYPE RANGE OF ty_numc6,
           ry_component         TYPE RANGE OF zce_zbom_detail-BillOfMaterialComponent,
           ry_BomExplosionLevel TYPE RANGE OF zce_zbom_detail-BomExplosionLevel,
           ry_BomVariantUsage   TYPE RANGE OF zce_zbom_detail-BillOfMaterialVariantUsage.

    METHODS get_itab_key_field
      IMPORTING
                io_request          TYPE REF TO if_rap_query_request
      RETURNING VALUE(rt_key_field) TYPE tt_key_field.

    METHODS get_BomExplosionLevel_range
      IMPORTING
                it_filters                  TYPE  if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_BomExplosionLevel) TYPE ry_BomExplosionLevel.

    METHODS get_component_range
      IMPORTING
                it_filters          TYPE  if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_component) TYPE ry_component.

    METHODS get_so_range
      IMPORTING
                it_filters           TYPE  if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_salesorder) TYPE ry_salesorder.

    METHODS get_material_range
      IMPORTING
                it_filters         TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_material) TYPE ry_material.

    METHODS get_plant_range
      IMPORTING
                it_filters      TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_plant) TYPE ry_plant.

    METHODS get_soitem_range
      IMPORTING
                it_filters               TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_salesorderitem) TYPE ry_salesorderitem.

    METHODS get_bomvariantusage_range
      IMPORTING
                it_filters                TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_BomVariantUsage) TYPE ry_BomVariantUsage.

    METHODS processing_api
      IMPORTING
                iv_billofmaterial             TYPE string
                iv_billofmaterialcategory     TYPE string
                iv_billofmaterialvariantusage TYPE string
                iv_material                   TYPE string
                iv_plant                      TYPE string
                iv_salesorder                 TYPE string
                iv_salesorderitem             TYPE string
                iv_itemindexstring            TYPE string
                iv_requiredquantity           TYPE string
      RETURNING VALUE(rt_result)              TYPE tt_res.

    METHODS processing_mbom
      IMPORTING
                iv_billofmaterial             TYPE string
                iv_billofmaterialcategory     TYPE string
                iv_billofmaterialvariantusage TYPE string
                iv_material                   TYPE string
                iv_plant                      TYPE string
                iv_salesorder                 TYPE string
                iv_salesorderitem             TYPE string
                iv_itemindexstring            TYPE string
                iv_requiredquantity           TYPE string
      RETURNING VALUE(rt_result)              TYPE tt_res.

    METHODS extract_elements
      IMPORTING
        iv_xml             TYPE string
        iv_tag             TYPE string
      RETURNING
        VALUE(rt_elements) TYPE string_table.

    METHODS get_tag_value
      IMPORTING
        iv_xml          TYPE string
        iv_tag          TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    METHODS processing_kbom
      IMPORTING
        iv_billofmaterial             TYPE string
        iv_billofmaterialcategory     TYPE string
        iv_billofmaterialvariantusage TYPE string
        iv_material                   TYPE string
        iv_plant                      TYPE string
        iv_salesorder                 TYPE string
        iv_salesorderitem             TYPE string
        iv_itemindexstring            TYPE string
        iv_requiredquantity           TYPE string
      CHANGING
        ct_result                     TYPE tt_res.

    METHODS processing_kbom2
      IMPORTING
        iv_billofmaterial             TYPE string
        iv_billofmaterialcategory     TYPE string
        iv_billofmaterialvariantusage TYPE string
        iv_material                   TYPE string
        iv_plant                      TYPE string
        iv_salesorder                 TYPE string
        iv_salesorderitem             TYPE string
        iv_itemindexstring            TYPE string
        iv_requiredquantity           TYPE string
      CHANGING
        ct_result                     TYPE tt_res.

    METHODS processing_kbom3
      IMPORTING
        iv_billofmaterial             TYPE string
        iv_billofmaterialcategory     TYPE string
        iv_billofmaterialvariantusage TYPE string
        iv_material                   TYPE string
        iv_plant                      TYPE string
        iv_salesorder                 TYPE string
        iv_salesorderitem             TYPE string
        iv_itemindexstring            TYPE string
        iv_requiredquantity           TYPE string
      CHANGING
        ct_result                     TYPE tt_res.

    METHODS processing_kbom4
      IMPORTING
        iv_billofmaterial             TYPE string
        iv_billofmaterialcategory     TYPE string
        iv_billofmaterialvariantusage TYPE string
        iv_material                   TYPE string
        iv_plant                      TYPE string
        iv_salesorder                 TYPE string
        iv_salesorderitem             TYPE string
        iv_itemindexstring            TYPE string
        iv_requiredquantity           TYPE string
      CHANGING
        ct_result                     TYPE tt_res.

    METHODS Recursive_data
      IMPORTING
        iv_material               TYPE string
        iv_plant                  TYPE string
        iv_salesorder             TYPE string
        iv_salesorderitem         TYPE string
        iv_BillOfMaterialCategory TYPE string
        iv_itemindexstring        TYPE string
        iv_quantity               TYPE i
        iv_bomlevel               TYPE numc2
      CHANGING
        ct_result                 TYPE tt_res .

    METHODS call_api_filter
      IMPORTING
                iv_endpoint             TYPE string
      EXPORTING ev_rc                   TYPE i
      RETURNING VALUE(rv_result_filter) TYPE string.

    METHODS call_api_line_mbom_kbom
      IMPORTING
        iv_quant_before           TYPE decfloat34
        iv_salesorder             TYPE string
        iv_salesorderitem         TYPE string
        iv_billofmaterial         TYPE string
        iv_billofmaterialcategory TYPE string
        iv_material               TYPE string
        iv_plant                  TYPE string
        iv_requiredquantity       TYPE string
      CHANGING
        cs_result                 TYPE zce_zbom_detail.

    METHODS call_api_head_kbom
      IMPORTING
                is_result       TYPE zce_zbom_detail
      EXPORTING
                ev_error_flag   TYPE abap_boolean
      RETURNING VALUE(rv_quant) TYPE string.

    METHODS call_api_item_kbom
      IMPORTING
                is_result       TYPE zce_zbom_detail
      EXPORTING
                ev_error_flag   TYPE abap_boolean
      RETURNING VALUE(rv_quant) TYPE string.

    METHODS get_tree_view
      IMPORTING
        iv_tabix  TYPE sy-tabix
      CHANGING
        ct_result TYPE tt_res.

    METHODS get_result_paging
      IMPORTING
        it_result   TYPE tt_res
        io_request  TYPE REF TO if_rap_query_request
        io_response TYPE REF TO if_rap_query_response.

    METHODS recursive2
      IMPORTING
        iv_bom           TYPE string
        iv_product       TYPE string
        iv_plant         TYPE string
        iv_so            TYPE string
        iv_so_item       TYPE string
        iv_bom_cat       TYPE c
        iv_quantity_head TYPE p
        iv_quant_before  TYPE p
        iv_level         TYPE n
      CHANGING
        ct_result        TYPE tt_res.

    METHODS run_mbom2
      IMPORTING
        iv_material_mbom TYPE string
        iv_plant         TYPE string
        iv_level         TYPE numc2
        iv_quant         TYPE p
      CHANGING
        ct_result        TYPE tt_res.
ENDCLASS.



CLASS zcl_zbom_detail_ce_bak IMPLEMENTATION.


  METHOD explode_header_for_export.
    DATA(lt_result_tmp) = processing_api(
                            iv_billofmaterial             = iv_billofmaterial
                            iv_billofmaterialcategory     = iv_billofmaterialcategory
                            iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
                            iv_material                   = iv_material
                            iv_plant                      = iv_plant
                            iv_salesorder                 = iv_salesorder
                            iv_salesorderitem             = iv_salesorderitem
                            iv_itemindexstring            = ''
                            iv_requiredquantity           = iv_requiredquantity
                          ).

    get_tree_view(
      EXPORTING
        iv_tabix  = iv_tabix
      CHANGING
        ct_result = lt_result_tmp
    ).

    SELECT SINGLE BaseUnit FROM i_product
      WHERE Product = @iv_material
      INTO @DATA(lv_unitheader).

    LOOP AT lt_result_tmp ASSIGNING FIELD-SYMBOL(<lfs_result_tmp>).
      <lfs_result_tmp>-BillOfMaterialCategory = iv_billofmaterialcategory.
      <lfs_result_tmp>-MaterialHeader         = iv_material.
      <lfs_result_tmp>-SalesOrder             = iv_salesorder.
      <lfs_result_tmp>-SalesOrderItem         = iv_salesorderitem.
      <lfs_result_tmp>-RequiredQuantityHeader = iv_requiredquantity.
      <lfs_result_tmp>-UomHeader              = lv_unitheader.
    ENDLOOP.

    rt_result = lt_result_tmp.
  ENDMETHOD.


  METHOD if_rap_query_provider~select.
    DATA: lt_result TYPE tt_res.

    "Step 1: Get itab key fields
    DATA(lt_key_field) = get_itab_key_field( io_request = io_request ).

    "Step 2: Processing API to get result data into internal table
    DATA: lr_material TYPE RANGE OF matnr.
    lr_material = VALUE #( FOR lwa IN lt_key_field (
        sign = 'I'
        option = 'EQ'
        low = CONV matnr( lwa-material )
    ) ).

    SELECT a~Product,
           a~BaseUnit
    FROM i_product AS a
    WHERE Product IN @lr_material
    INTO TABLE @DATA(lt_unitheader).

    DATA lv_unitheader TYPE msehi.

    LOOP AT lt_key_field INTO DATA(ls_key_field).
      CLEAR: lv_unitheader.

      DATA(lv_tabix) = sy-tabix.
      DATA(lt_result_tmp) = processing_api(
                              iv_billofmaterial             = ls_key_field-billofmaterial
                              iv_billofmaterialcategory     = ls_key_field-billofmaterialcategory
                              iv_billofmaterialvariantusage = ls_key_field-billofmaterialvariantusage
                              iv_material                   = ls_key_field-material
                              iv_plant                      = ls_key_field-plant
                              iv_salesorder                 = ls_key_field-salesorder
                              iv_salesorderitem             = ls_key_field-salesorderitem
                              iv_itemindexstring            = ls_key_field-itemindexstring
                              iv_requiredquantity            = ls_key_field-requiredquantity
                            ).
      "Step 3: Append into lt_result and Modify result
      get_tree_view(
        EXPORTING
           iv_tabix = lv_tabix
        CHANGING
          ct_result = lt_result_tmp
      ).

      READ TABLE lt_unitheader INTO DATA(ls_unitheader) WITH KEY Product = ls_key_field-material.
      IF sy-subrc = 0 .
        lv_unitheader = ls_unitheader-BaseUnit.
      ENDIF.

      LOOP AT lt_result_tmp ASSIGNING FIELD-SYMBOL(<lfs_result_tmp>).
        <lfs_result_tmp>-BillOfMaterialCategory = ls_key_field-billofmaterialcategory.
        <lfs_result_tmp>-MaterialHeader = ls_key_field-material.
        <lfs_result_tmp>-SalesOrder = ls_key_field-salesorder.
        <lfs_result_tmp>-SalesOrderItem = ls_key_field-salesorderitem.
        <lfs_result_tmp>-RequiredQuantityHeader = ls_key_field-requiredquantity.
        <lfs_result_tmp>-UomHeader = lv_unitheader.
      ENDLOOP.
      APPEND LINES OF lt_result_tmp TO lt_result.
      CLEAR: lt_result_tmp[].
      IF ls_key_field-itemindex IS NOT INITIAL.
        DELETE lt_result WHERE itemindex <> ls_key_field-itemindex.
      ENDIF.
    ENDLOOP.

    "ninhnh3 updated
    "Step 3.2: Apply additional filters từ user trên filter bar
    DATA(lo_filter) = io_request->get_filter( ).
    TRY.
        DATA(lt_filters) = lo_filter->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    "Filter theo Component
    DATA(lr_component) = get_component_range( it_filters = lt_filters ).
    IF lr_component IS NOT INITIAL.
      DELETE lt_result WHERE BillOfMaterialComponent NOT IN lr_component.
    ENDIF.

    "Filter theo Bom Explosion Level
    DATA(lr_bomexplostion) = get_bomexplosionlevel_range( it_filters = lt_filters ).
    IF lr_bomexplostion IS NOT INITIAL.
      DELETE lt_result WHERE BomExplosionLevel NOT IN lr_bomexplostion.
    ENDIF.

*    "Filter theo SalesOrder
*    DATA(lr_salesorder) = get_so_range( it_filters = lt_filters ).
*    IF lr_salesorder IS NOT INITIAL.
*      DELETE lt_result WHERE SalesOrder NOT IN lr_salesorder.
*    ENDIF.
*
*    "Filter theo material
*    DATA(lr_material) = get_material_range( it_filters = lt_filters ).
*    IF lr_material IS NOT INITIAL.
*      DELETE lt_result WHERE Material NOT IN lr_material.
*    ENDIF.
*
*    "Get table range plant
*    DATA(lr_plant) = get_plant_range( it_filters = lt_filters ).
*    IF lr_plant IS NOT INITIAL.
*      DELETE lt_result WHERE Plant NOT IN lr_plant.
*    ENDIF.
*
*    "Get table range salesorderitem
*    DATA(lr_salesorderitem) = get_soitem_range( it_filters = lt_filters ).
*    IF lr_salesorderitem IS NOT INITIAL.
*      DELETE lt_result WHERE SalesOrderItem NOT IN lr_salesorderitem.
*    ENDIF.
    "end of ninhnh3 updated

    "Step 4: Apply paging
    get_result_paging(
      it_result   = lt_result
      io_request  = io_request
      io_response = io_response
    ).
  ENDMETHOD.


  METHOD get_result_paging.
****************************************************************************************************
* Version 2
    DATA: lt_paged  LIKE it_result,
          lt_sorted LIKE it_result,
          lv_total  TYPE int8.

    DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
    DATA(lv_rows)   = io_request->get_paging( )->get_page_size( ).

    " Handle sorting
    DATA(lt_sort) = io_request->get_sort_elements( ).
    lt_sorted = it_result.

    IF lt_sort IS NOT INITIAL.
      DATA: lt_sort_key TYPE abap_sortorder_tab.
      LOOP AT lt_sort INTO DATA(ls_sort).
        APPEND VALUE #(
          name       = ls_sort-element_name
          descending = COND #( WHEN ls_sort-descending = abap_true THEN abap_true ELSE abap_false )
        ) TO lt_sort_key.
      ENDLOOP.
      SORT lt_sorted BY (lt_sort_key).
    ENDIF.

    lv_total = lines( lt_sorted ).

    IF lv_rows = if_rap_query_paging=>page_size_unlimited.
      io_response->set_data( lt_sorted ).
    ELSE.
      LOOP AT lt_sorted INTO DATA(ls_row) FROM lv_offset + 1 TO lv_offset + lv_rows.
        APPEND ls_row TO lt_paged.
      ENDLOOP.
      io_response->set_data( lt_paged ).
    ENDIF.

    io_response->set_total_number_of_records( lv_total ).

****************************************************************************************************
* Version 1
*    DATA: lt_paged LIKE it_result,
*          lv_total TYPE int8.
*
*    DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
*    DATA(lv_rows)   = io_request->get_paging( )->get_page_size( ).
*
*    lv_total = lines( it_result ).
*
*    IF lv_rows = if_rap_query_paging=>page_size_unlimited.
*      io_response->set_data( it_result ).
*    ELSE.
*      LOOP AT it_result INTO DATA(ls_row) FROM lv_offset + 1 TO lv_offset + lv_rows.
*        APPEND ls_row TO lt_paged.
*      ENDLOOP.
*      io_response->set_data( lt_paged ).
*    ENDIF.
*
*    io_response->set_total_number_of_records( lv_total ).
  ENDMETHOD.


  METHOD get_tree_view.
    TYPES: BEGIN OF ty_node,
             tabix    TYPE i,
             parent   TYPE i,
             treeview TYPE string,
           END OF ty_node.

    DATA: lt_nodes     TYPE TABLE OF ty_node WITH DEFAULT KEY,
          lv_tree      TYPE string,
          lv_tabix     TYPE i,
          ls_node      TYPE ty_node,
          lv_min_level TYPE i VALUE 99,
          lv_cur_level TYPE i,
          lv_search    TYPE i,
          lv_mat_norm  TYPE matnr,   " node cha (BomHhdrMatlHierNode) của row hiện tại - normalized
          lv_comp_norm TYPE matnr.   " component của row đang scan - normalized

    " Tìm min level
    LOOP AT ct_result INTO DATA(ls_tmp).
      lv_cur_level = CONV i( ls_tmp-BomExplosionLevel ).
      IF lv_cur_level < lv_min_level.
        lv_min_level = lv_cur_level.
      ENDIF.
    ENDLOOP.

    " -------------------------------------------------------
    " FIX: đưa (các) dòng level = min level (root thật sự, vd
    " component duy nhất ở BomExplosionLevel = 01) lên ĐẦU bảng.
    " Các method fill ct_result (recursive2/run_mbom2/processing_kbomX)
    " thường APPEND dòng root này SAU CÙNG (sau khi đệ quy hết children),
    " nên nếu không reorder, PASS 2 bên dưới sẽ đếm nó như 1 sibling
    " bình thường theo vị trí tabix -> root bị đẩy xuống cuối
    " (vd "1.22" thay vì "1.1").
    " -------------------------------------------------------
    DATA lt_root     LIKE ct_result.
    DATA lt_children LIKE ct_result.

    LOOP AT ct_result INTO DATA(ls_reorder).
      IF CONV i( ls_reorder-BomExplosionLevel ) = lv_min_level.
        APPEND ls_reorder TO lt_root.
      ELSE.
        APPEND ls_reorder TO lt_children.
      ENDIF.
    ENDLOOP.

    CLEAR ct_result.
    APPEND LINES OF lt_root     TO ct_result.
    APPEND LINES OF lt_children TO ct_result.

    " -------------------------------------------------------
    " PASS 1: Xác định parent
    " Cha = row gần nhất phía trên có BillOfMaterialComponent =
    " BomHhdrMatlHierNode (node cha trực tiếp) của row hiện tại
    " (sau khi normalize ALPHA).
    " FIX: trước đây so khớp với field Material - field này không
    " đảm bảo phản ánh đúng "cha trực tiếp" ở mọi nhánh xử lý
    " (processing_kbom4...), trong khi BomHhdrMatlHierNode được set
    " nhất quán = material cha ở recursive2/run_mbom2 và đã verify
    " đúng bằng debug thực tế (vd row BomHhdrMatlHierNode=200009365
    " khớp đúng với row có BillOfMaterialComponent=200009365).
    " -------------------------------------------------------
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<lfs>).
      lv_tabix         = sy-tabix.
      lv_cur_level     = CONV i( <lfs>-BomExplosionLevel ).
      ls_node-tabix    = lv_tabix.
      ls_node-treeview = ''.
      ls_node-parent   = -1.

      " Normalize node cha (BomHhdrMatlHierNode) của row hiện tại
      lv_mat_norm = |{ <lfs>-BomHhdrMatlHierNode ALPHA = IN }|.

      IF lv_cur_level > lv_min_level.
        lv_search = lv_tabix - 1.
        WHILE lv_search >= 1.
          READ TABLE ct_result INDEX lv_search INTO DATA(ls_par).

          " Normalize component của row đang scan
          lv_comp_norm = |{ ls_par-BillOfMaterialComponent ALPHA = IN }|.

          IF lv_comp_norm = lv_mat_norm.
            ls_node-parent = lv_search.
            EXIT.
          ENDIF.

          lv_search -= 1.
        ENDWHILE.
      ENDIF.

      APPEND ls_node TO lt_nodes.
    ENDLOOP.

    " -------------------------------------------------------
    " PASS 2: Build treeview
    " -------------------------------------------------------
    TYPES: BEGIN OF ty_cnt,
             parent TYPE i,
             cnt    TYPE i,
           END OF ty_cnt.
    DATA lt_cnt   TYPE HASHED TABLE OF ty_cnt WITH UNIQUE KEY parent.
    DATA ls_cnt   TYPE ty_cnt.
    DATA ls_pnode TYPE ty_node.

    LOOP AT lt_nodes ASSIGNING FIELD-SYMBOL(<lfs_node>).
      READ TABLE lt_cnt
        WITH TABLE KEY parent = <lfs_node>-parent
        INTO ls_cnt.
      IF sy-subrc = 0.
        ls_cnt-cnt += 1.
        MODIFY TABLE lt_cnt FROM ls_cnt.
      ELSE.
        ls_cnt = VALUE #( parent = <lfs_node>-parent cnt = 1 ).
        INSERT ls_cnt INTO TABLE lt_cnt.
      ENDIF.

      IF <lfs_node>-parent = -1.
        lv_tree = |{ iv_tabix }.{ ls_cnt-cnt }|.
      ELSE.
        READ TABLE lt_nodes
          WITH KEY tabix = <lfs_node>-parent
          INTO ls_pnode.
        lv_tree = |{ ls_pnode-treeview }.{ ls_cnt-cnt }|.
      ENDIF.

      <lfs_node>-treeview = lv_tree.

      READ TABLE ct_result INDEX <lfs_node>-tabix
        ASSIGNING FIELD-SYMBOL(<lfs_res>).
      IF sy-subrc = 0.
        <lfs_res>-TreeView = lv_tree.
      ENDIF.
    ENDLOOP.

    " -------------------------------------------------------
    " SORT TreeView theo đúng thứ tự số (không sort string)
    " -------------------------------------------------------
    TYPES: BEGIN OF ty_sort,
             tabix TYPE i,
             seg1  TYPE i,
             seg2  TYPE i,
             seg3  TYPE i,
             seg4  TYPE i,
             seg5  TYPE i,
             seg6  TYPE i,
             seg7  TYPE i,
             seg8  TYPE i,
             seg9  TYPE i,
             seg10 TYPE i,
           END OF ty_sort.
    DATA lt_sort TYPE TABLE OF ty_sort WITH DEFAULT KEY.
    DATA ls_sort TYPE ty_sort.

    DATA lt_segs TYPE TABLE OF string.

    " Build sort key từ TreeView
    LOOP AT ct_result INTO DATA(ls_res_sort).
      CLEAR ls_sort.
      ls_sort-tabix = sy-tabix.

      " Split "1.8.1.2" → [ "1","8","1","2" ]
      SPLIT ls_res_sort-TreeView AT '.' INTO TABLE lt_segs.

      DATA(lv_seg_idx) = 0.
      LOOP AT lt_segs INTO DATA(lv_seg).
        lv_seg_idx += 1.
        CASE lv_seg_idx.
          WHEN 1. ls_sort-seg1  = CONV i( lv_seg ).
          WHEN 2. ls_sort-seg2  = CONV i( lv_seg ).
          WHEN 3. ls_sort-seg3  = CONV i( lv_seg ).
          WHEN 4. ls_sort-seg4  = CONV i( lv_seg ).
          WHEN 5. ls_sort-seg5  = CONV i( lv_seg ).
          WHEN 6. ls_sort-seg6  = CONV i( lv_seg ).
          WHEN 7. ls_sort-seg7  = CONV i( lv_seg ).
          WHEN 8. ls_sort-seg8  = CONV i( lv_seg ).
          WHEN 9. ls_sort-seg9  = CONV i( lv_seg ).
          WHEN 10. ls_sort-seg10 = CONV i( lv_seg ).
        ENDCASE.
      ENDLOOP.

      APPEND ls_sort TO lt_sort.
    ENDLOOP.

    " Sort theo segment số
    SORT lt_sort BY seg1 seg2 seg3 seg4 seg5 seg6 seg7 seg8 seg9 seg10.

    " Reorder ct_result theo thứ tự đã sort
    DATA lt_result_sorted LIKE ct_result.
    LOOP AT lt_sort INTO ls_sort.
      READ TABLE ct_result INDEX ls_sort-tabix INTO DATA(ls_res_tmp).
      IF sy-subrc = 0.
        APPEND ls_res_tmp TO lt_result_sorted.
      ENDIF.
    ENDLOOP.

    ct_result = lt_result_sorted.
  ENDMETHOD.


  METHOD processing_api.
    IF iv_salesorder IS INITIAL AND iv_salesorderitem = '000000'.
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      "Processing with MBom
      rt_result = processing_mbom(
        iv_billofmaterial             = iv_billofmaterial
        iv_billofmaterialcategory     = iv_billofmaterialcategory
        iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
        iv_material                   = iv_material
        iv_plant                      = iv_plant
        iv_salesorder                 = iv_salesorder
        iv_salesorderitem             = iv_salesorderitem
        iv_itemindexstring            = iv_itemindexstring
        iv_requiredquantity            = iv_requiredquantity
      ).
    ELSE.
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      "Version 4
      processing_kbom4(
          EXPORTING
            iv_billofmaterial             = iv_billofmaterial
            iv_billofmaterialcategory     = iv_billofmaterialcategory
            iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
            iv_material                   = iv_material
            iv_plant                      = iv_plant
            iv_salesorder                 = iv_salesorder
            iv_salesorderitem             = iv_salesorderitem
            iv_itemindexstring            = iv_itemindexstring
            iv_requiredquantity           = iv_requiredquantity
          CHANGING
            ct_result = rt_result
        ).
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*      "Version 3
*      processing_kbom3(
*          EXPORTING
*            iv_billofmaterial             = iv_billofmaterial
*            iv_billofmaterialcategory     = iv_billofmaterialcategory
*            iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
*            iv_material                   = iv_material
*            iv_plant                      = iv_plant
*            iv_salesorder                 = iv_salesorder
*            iv_salesorderitem             = iv_salesorderitem
*            iv_itemindexstring            = iv_itemindexstring
*            iv_requiredquantity           = iv_requiredquantity
*          CHANGING
*            ct_result = rt_result
*        ).

      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*      "Version 2
*      processing_kbom2(
*          EXPORTING
*            iv_billofmaterial             = iv_billofmaterial
*            iv_billofmaterialcategory     = iv_billofmaterialcategory
*            iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
*            iv_material                   = iv_material
*            iv_plant                      = iv_plant
*            iv_salesorder                 = iv_salesorder
*            iv_salesorderitem             = iv_salesorderitem
*            iv_itemindexstring            = iv_itemindexstring
*            iv_requiredquantity           = iv_requiredquantity
*          CHANGING
*            ct_result = rt_result
*        ).
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      "Version 1
*      "Processing with KBom
*      processing_kbom(
*          EXPORTING
*            iv_billofmaterial             = iv_billofmaterial
*            iv_billofmaterialcategory     = iv_billofmaterialcategory
*            iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
*            iv_material                   = iv_material
*            iv_plant                      = iv_plant
*            iv_salesorder                 = iv_salesorder
*            iv_salesorderitem             = iv_salesorderitem
*            iv_itemindexstring            = iv_itemindexstring
*            iv_requiredquantity           = iv_requiredquantity
*          CHANGING
*            ct_result = rt_result
*        ).

    ENDIF.
  ENDMETHOD.


  METHOD processing_kbom2.
    DATA: lv_product TYPE matnr VALUE '300004390',
          lv_plant   TYPE werks_d VALUE '6711',
          lv_bom_cat TYPE c VALUE 'K',
          lv_so      TYPE vbeln VALUE '0010000012',
          lv_so_item TYPE n LENGTH 6 VALUE '000010'.

    DATA: lv_quant_before TYPE p.

    DATA: lv_bomlevel TYPE n LENGTH 2 VALUE '00'.

    lv_product  = iv_material.
    lv_product = |{ lv_product WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.

    lv_plant = iv_plant.

    lv_bom_cat = iv_billofmaterialcategory.

    lv_so = iv_salesorder.

    lv_so_item = iv_salesorderitem.

    lv_quant_before = iv_requiredquantity.

    SELECT DISTINCT a~salesorder,
                    a~SalesOrderItem,
                    a~material,
                    a~BillOfMaterial,
                    b~BOMHeaderQuantityInBaseUnit
   FROM I_SalesOrderBOMLink AS a
   INNER JOIN I_SalesOrderBOMHeaderDEX AS b
     ON a~BillOfMaterial = b~BillOfMaterial
        AND a~BillOfMaterialCategory = b~BillOfMaterialCategory
        AND a~BillOfMaterialVariant = b~BillOfMaterialVariant
   WHERE a~BillOfMaterialCategory = @lv_bom_cat AND
         a~Material = @lv_product AND
         a~plant = @lv_plant AND
         a~salesorder = @lv_so AND
         a~SalesOrderItem = @lv_so_item
   INTO TABLE @DATA(lt_hdr).

    READ TABLE lt_hdr INTO DATA(ls_hdr) INDEX 1.
    IF sy-subrc = 0.
      recursive2(
          EXPORTING
            iv_bom      = CONV string( ls_hdr-BillOfMaterial )
            iv_product = CONV string( lv_product )
            iv_plant = CONV string( lv_plant )
            iv_so = CONV string( lv_so )
            iv_so_item = CONV string( lv_so_item )
            iv_bom_cat  = lv_bom_cat
            iv_quantity_head = ls_hdr-BOMHeaderQuantityInBaseUnit
            iv_quant_before = lv_quant_before
            iv_level    = lv_bomlevel
      CHANGING
        ct_result   = ct_result
    ).
    ENDIF.

    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-ItemIndex = sy-tabix.
      <lfs_result>-ItemIndexString = iv_itemindexstring.
      <lfs_result>-BillOfMaterialCategory = iv_billofmaterialcategory.
      <lfs_result>-Materialheader = iv_material.
      <lfs_result>-SalesOrder = iv_salesorder.
      <lfs_result>-SalesOrderitem = iv_salesorderitem.
      <lfs_result>-RequiredQuantityHeader = iv_requiredquantity.
      <lfs_result>-BillOfMaterialComponent = |{ <lfs_result>-BillOfMaterialComponent ALPHA = OUT }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD recursive2.
    " Guard: tránh infinite loop
    IF iv_level > 10.
      RETURN.
    ENDIF.

    " Lấy BOM Items của BOM hiện tại
    SELECT FROM I_SalesOrderBOMItemDEX AS itm
    FIELDS *
    WHERE itm~BillOfMaterial = @iv_bom
          AND itm~BillOfMaterialCategory = @iv_bom_cat
    INTO TABLE @DATA(lt_itm).

    LOOP AT lt_itm INTO DATA(ls_itm).
      DATA(lv_tabix) = sy-tabix.
      APPEND INITIAL LINE TO ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-ItemIndex = lv_tabix.
*      <lfs_result>-ItemIndexString = iv_itemindexstring.
      <lfs_result>-BillOfMaterial = ls_itm-BillOfMaterial.
      <lfs_result>-BillOfMaterialCategory = ls_itm-BillOfMaterialCategory.
      <lfs_result>-Material = iv_product.
      <lfs_result>-Plant = iv_plant.
      <lfs_result>-BillOfMaterialVariantUsage = 1.
      <lfs_result>-SalesOrder = iv_so.
      <lfs_result>-SalesOrderItem = iv_so_item.

      SELECT SINGLE FROM i_product
      FIELDS ProductType
      WHERE product = @ls_itm-BillOfMaterialComponent
      INTO @<lfs_result>-MaterialType.

      <lfs_result>-BillOfMaterialComponent = ls_itm-BillOfMaterialComponent.
      <lfs_result>-BomExplosionLevel = iv_level + 1.
      <lfs_result>-BomhHdrMatlHierNode = iv_product.

      SELECT SINGLE FROM I_ProductText
      FIELDS ProductName
      WHERE Language = 'E'
            AND Product = @ls_itm-BillOfMaterialComponent
      INTO @<lfs_result>-ComponentDescription.

      <lfs_result>-BomCompQuant      = iv_quant_before * ls_itm-BillOfMaterialItemQuantity / iv_quantity_head.

*      <lfs_item>-BillOfMaterialItemQuantity = ls_itm-BillOfMaterialItemQuantity / ls_hdr-BOMHeaderQuantityInBaseUnit.
*        <lfs_result>-BomCompQuant = iv_quantity / ls_hdr-BOMHeaderQuantityInBaseUnit.

      <lfs_result>-BillOfMaterialItemCategory = ls_itm-BillOfMaterialItemCategory.
      <lfs_result>-BillOfMaterialItemNumber = ls_itm-BillOfMaterialItemNumber.
      <lfs_result>-BillOfMaterialItemUnit = ls_itm-BillOfMaterialItemUnit.
      <lfs_result>-ValidityStartDate = ls_itm-ValidityStartDate.

*      APPEND INITIAL LINE TO ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-BillOfMaterial    = ls_itm-BillOfMaterial.
      <lfs_result>-BillOfMaterialComponent    = ls_itm-BillOfMaterialComponent.
      <lfs_result>-BomCompQuant      = iv_quant_before * ls_itm-BillOfMaterialItemQuantity / iv_quantity_head.
      <lfs_result>-BomExplosionLevel = iv_level + 1.

      " Tìm BOM con của component này
      SELECT DISTINCT a~salesorder,
                      a~SalesOrderItem,
                      a~material,
                      a~BillOfMaterial,
                      b~BOMHeaderQuantityInBaseUnit
     FROM I_SalesOrderBOMLink AS a
     INNER JOIN I_SalesOrderBOMHeaderDEX AS b
       ON a~BillOfMaterial = b~BillOfMaterial
          AND a~BillOfMaterialCategory = b~BillOfMaterialCategory
          AND a~BillOfMaterialVariant = b~BillOfMaterialVariant
     WHERE a~BillOfMaterialCategory = @iv_bom_cat AND
           a~Material = @<lfs_result>-BillOfMaterialComponent AND
           a~plant = @iv_plant AND
           a~salesorder = @iv_so AND
           a~SalesOrderItem = @iv_so_item
     INTO TABLE @DATA(lt_hdr).

      IF sy-subrc = 0.
        me->recursive2(
          EXPORTING
            iv_bom      = CONV string( lt_hdr[ 1 ]-BillOfMaterial )
            iv_product  = CONV string( lt_hdr[ 1 ]-Material )
            iv_plant    = CONV string( iv_plant )
            iv_so       = CONV string( iv_so )
            iv_so_item  = CONV string( iv_so_item )
            iv_bom_cat  = iv_bom_cat
            iv_quantity_head = lt_hdr[ 1 ]-BOMHeaderQuantityInBaseUnit
            iv_quant_before = <lfs_result>-BomCompQuant
            iv_level    = <lfs_result>-BomExplosionLevel
          CHANGING
            ct_result   = ct_result
        ).
      ELSE.
        DATA: lt_result_tmp LIKE ct_result.
        run_mbom2(
          EXPORTING
            iv_material_mbom = CONV string( <lfs_result>-BillOfMaterialComponent )
            iv_plant          = CONV string( iv_plant )
            iv_level = CONV numc2( <lfs_result>-BomExplosionLevel )
            iv_quant = <lfs_result>-BomCompQuant
          CHANGING
            ct_result        = lt_result_tmp
        ).
        APPEND LINES OF lt_result_tmp TO ct_result.
        CLEAR: lt_result_tmp.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD run_mbom2.
    SELECT DISTINCT
        a~billofmaterial ,
        a~material ,
        a~plant ,
        b~plantname ,
        i_productdescription~productdescription
    FROM I_MaterialBOMLink AS a
    LEFT OUTER JOIN I_PlantStdVH AS b
        ON a~plant = b~plant
    LEFT OUTER JOIN I_ProductDescription
        ON a~material = I_ProductDescription~product
        AND I_ProductDescription~language = 'E'
    LEFT OUTER JOIN  I_Product
      ON a~material = I_Product~product
    WHERE a~billofmaterialcategory = 'M' AND
          a~material = @iv_material_mbom AND
          b~plant = @iv_plant
    INTO TABLE @DATA(lt_mbom_head).

    CHECK sy-subrc = 0.

    DATA(lv_date_time) = |{ cl_abap_context_info=>get_system_date( ) DATE = ISO }T00:00:00|.
    " URL-encode the date: 2026-03-06T00:00:00 -> datetime%272026-03-06T00%3A00%3A00%27
    DATA(lv_date_enc) = |datetime%27{ lv_date_time }%27|.
    REPLACE ALL OCCURRENCES OF ':' IN lv_date_enc WITH '%3A'.

    DATA(lv_endpoint) =
*          |https://my426501-api.s4hana.cloud.sap/sap/opu/odata/SAP/| &&
*          |API_BILL_OF_MATERIAL_SRV;v=2/ExplodeBOM?| &&
           '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2/ExplodeBOM?' &&
           |Material=%27{ lt_mbom_head[ 1 ]-material }%27&|          && "1. Material - Mandatory
           |Plant=%27{ lt_mbom_head[ 1 ]-plant }%27&|                && "2. Plant - Optional
           |BillOfMaterialVariant=%27%27&|            && "3. BillOfMaterialVariant - Optional
           |BOMExplosionApplication=%27PP01%27&|      && "4. BOMExplosionApplication - Mandatory
           |RequiredQuantity={ iv_quant }m&|                     && "5. Required Quantity - Mandatory --> Không gán cứng - Check
           |EngineeringChangeDocument=%27%27&|        && "6. EngineeringChangeDocument - Optional
           |BOMExplosionIsLimited=false&|             && "7. BOMExplosionIsLimited - Mandatory
           |BOMItmQtyIsScrapRelevant=%27%27&|         && "8. BOMItmQtyIsScrapRelevant - Optional
           |BillOfMaterialItemCategory=%27%27&|       && "9. BillOfMaterialItemCategory - Optional
           |BOMExplosionAssembly=%27%27&|             && "10. BOMExplosionAssembly - Optional
           |BOMExplosionDate={ lv_date_enc }&|        && "11. BOMExplosionDate - Mandatory
           |BOMExplosionLevel=0m&|                    && "12. BOMExplosionLevel - Mandatory
           |BOMExplosionIsMultilevel=true&|           && "13. BOMExplosionIsMultilevel - Mandatory
           |MaterialProvisionFltrType=%27%20%27&|     && "14. MaterialProvisionFltrType - Optional
           |SparePartFltrType=%27%20%27&|              && "15. SparePartFltrType - Optional
           |BillOfMaterial=%27{ lt_mbom_head[ 1 ]-BillOfMaterial }%27&|         && "Key Header
           |BillOfMaterialCategory=%27M%27&|          && "Key Header
           |BillOfMaterialVersion=%27%27|.              "Key Header

    DATA(lv_xml_mbom) = zcl_call_api=>call_api(
          iv_body        = ''
          iv_endpoint    = lv_endpoint
          iv_method      = 'GET'
          iv_contenttype = 'application/xml'
        ).

    DATA(lt_elements) = extract_elements(
       iv_xml = lv_xml_mbom
       iv_tag = 'd:element'
    ).
    LOOP AT lt_elements INTO DATA(lv_elem_xml).
      APPEND INITIAL LINE TO ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-billofmaterial = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:Bill_Of_Material_Root' ).
      <lfs_result>-billofmaterialcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_category' ).
      <lfs_result>-material = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
      <lfs_result>-billofmaterialvariantusage = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant_usage' ).
      <lfs_result>-salesorder = ''.
      <lfs_result>-salesorderitem = '000000'.
      <lfs_result>-itemindex = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_index' ).
*      <lfs_result>-itemindexstring = iv_itemindexstring.
      "Field 1 - Component
      <lfs_result>-billofmaterialcomponent = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_component' ).

      DATA(lv_level) = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_explosion_level' ).
      <lfs_result>-BomExplosionLevel = iv_level + lv_level.

      <lfs_result>-bomhhdrmatlhiernode = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
      "Field 2 - Component Description
      <lfs_result>-componentdescription = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_component_description' ).
      "Field 3 - Component Quantity (Component UoM)
      <lfs_result>-bomcompquant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_comp_quant' ).
      "Field 4 - Item Category
      <lfs_result>-billofmaterialitemcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_category' ).
      "Field 5 - Item Number
      <lfs_result>-billofmaterialitemnumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_number' ).
      "Field 6 - Assembly Indicator
      DATA(lv_assy) = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:assembly_indicator' ).
      <lfs_result>-isassembly = COND #( WHEN lv_assy = 'true' THEN abap_true ELSE abap_false ).
      "Field 7 - Material Type
      <lfs_result>-materialtype = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:material_type' ).
      "Field 8 - Plant - Header Key
      <lfs_result>-plant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:plant' ).
      "Field 9 - Base UoM
      <lfs_result>-billofmaterialitemunit = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:base_uom' ).
      "Field 10 - Maintenance Status
      <lfs_result>-maintenancestatus = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:maintenance_status' ).
      "Field 11 - Valid From
      DATA: lv_start_date TYPE char10.
      lv_start_date = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:validity_start_date' ).
      REPLACE ALL OCCURRENCES OF '-' IN lv_start_date WITH ''.
      <lfs_result>-validitystartdate = lv_start_date.
      "Field 12 - Change Number
      <lfs_result>-changenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:change_number' ).
      "Field 13 - Created On
      DATA: lv_created_on TYPE char10.
      lv_created_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:record_creation_date' ).
      REPLACE ALL OCCURRENCES OF '-' IN lv_created_on WITH ''.
      <lfs_result>-createdon = lv_created_on.
      "Field 14 - Created By
      <lfs_result>-createdby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:created_by_user' ).
      "Field 15 - Changed On
      DATA: lv_changed_on TYPE char10.
      lv_changed_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_change_date' ).
      REPLACE ALL OCCURRENCES OF '-' IN lv_changed_on WITH ''.
      <lfs_result>-changedon = lv_changed_on.
      "Field 16 - Changed By
      <lfs_result>-changedby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_changed_by_user' ).
      "Field 17 - Item Spare Part Indicator
      <lfs_result>-isbomitemsparepart = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:is_b_o_m_item_spare_part' ).
      <lfs_result>-billofmaterialvariant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant' ).
      <lfs_result>-billofmaterialversion = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_version' ).
      <lfs_result>-billofmaterialitemnodenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_node' ).
      <lfs_result>-headerchangedocument = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bom_change_number' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD processing_kbom.
    "1."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Get quantity
*    SELECT SINGLE FROM ztb_zbom_explode
*    FIELDS quantity
*    WHERE bill_of_material = @iv_billofmaterial AND
*          bill_of_material_category = @iv_billofmaterialcategory AND
*          material = @iv_material AND
*          plant = @iv_plant AND
*          sales_order = @iv_salesorder AND
*          sales_order_item = @iv_salesorderitem AND
*          uname = @sy-uname
*    INTO @DATA(lv_quantity).
*    IF sy-subrc = 0.
*    ELSE.
*      lv_quantity = 1.
*    ENDIF.

    "2."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Select Recursive
    Recursive_data(
        EXPORTING
             iv_material               = CONV string( iv_material )
             iv_plant                  = CONV string( iv_plant )
             iv_salesorder             = CONV string( iv_salesorder )
             iv_salesorderitem         = CONV string( iv_salesorderitem )
             iv_itemindexstring        = CONV string( iv_itemindexstring )
             iv_quantity               = CONV i( iv_requiredquantity )
             iv_billofmaterialcategory = 'K'
             iv_bomlevel = '00'
        CHANGING
            ct_result = ct_result
       ).

    "3."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Modify result
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-ItemIndex = sy-tabix.
      <lfs_result>-Material = |{ <lfs_result>-Material ALPHA = OUT }|.
      <lfs_result>-BillOfMaterialComponent = |{ <lfs_result>-BillOfMaterialComponent ALPHA = OUT }|.
      <lfs_result>-MaterialHeader = |{ iv_material ALPHA = OUT }|.
      <lfs_result>-RequiredQuantityHeader = iv_requiredquantity.
    ENDLOOP.

    "4."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Update Quantity with K BOM
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<lfs_result_present>).
      "4.1."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      "Get Quantity before
      DATA(lv_tabix) = sy-tabix.

      DATA: ls_result_before LIKE LINE OF ct_result,
            lv_quant_before  TYPE decfloat34,
            lv_flag.

      IF lv_tabix = 1.
*        IF <lfs_result_present>-RequiredQuantityHeader IS INITIAL.
        lv_quant_before = 1.
*        ELSE.
*          lv_quant_before = <lfs_result_present>-RequiredQuantityHeader.
*        ENDIF.
      ELSE.
        CLEAR: ls_result_before,
               lv_flag.
        LOOP AT ct_result INTO ls_result_before
          WHERE BomExplosionLevel = <lfs_result_present>-BomExplosionLevel - 1
                AND BillOfMaterialComponent = <lfs_result_present>-Material
                AND ItemIndex < <lfs_result_present>-ItemIndex.
          lv_flag = 'X'.
        ENDLOOP.
        lv_quant_before = COND #( WHEN lv_flag = 'X' THEN ls_result_before-BomCompQuant ELSE 1 ).
      ENDIF.

      "4.2."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      "Get line KBOM by using API
      DATA: lv_rc TYPE i.
      DATA(lv_filter) = |BillOfMaterialCategory eq 'K'| &&
                  | and EngineeringChangeDocument eq ''| &&
                  | and Material eq '{ <lfs_result_present>-Material }'| &&
                  | and Plant eq '{ <lfs_result_present>-Plant }'| &&
                  | and SalesOrder eq '{ iv_salesorder }'| &&
                  | and SalesOrderItem eq '{ iv_salesorderitem }'| &&
                  | and BillOfMaterialComponent eq '{ <lfs_result_present>-BillOfMaterialComponent }' |.
      DATA(lv_endpoint) =
          |https://my426501-api.s4hana.cloud.sap/sap/opu/odata/SAP| &&
          |/API_ORDER_BILL_OF_MATERIAL_SRV/SalesOrderBOMItem?| &&
          |$filter=| &&
          |{ cl_web_http_utility=>escape_url( lv_filter ) }|.

      DATA(lv_xml_quant) = call_api_filter(
                            EXPORTING
                              iv_endpoint = lv_endpoint
                            IMPORTING
                              ev_rc       = lv_rc
                          ).
      IF lv_rc = '200'.
        DATA(lt_elements) = extract_elements(
           iv_xml = lv_xml_quant
           iv_tag = 'entry'
         ).
        IF lt_elements IS NOT INITIAL.
*          LOOP AT lt_elements INTO DATA(lv_elements).
*            DATA(lv_quant_udt) = get_tag_value(
*                                   iv_xml = lv_elements
*                                   iv_tag = 'd:BillOfMaterialItemQuantity'
*                                 ).
*            DATA(lv_quant_udt_num) = CONV decfloat34( lv_quant_udt ).
*            IF <lfs_result_present>-BomExplosionLevel = '01'.
*              lv_quant_udt_num = lv_quant_udt_num * lv_quant_before * lv_quantity.
*            ELSE.
*              lv_quant_udt_num = lv_quant_udt_num * lv_quant_before.
*            ENDIF.
*            <lfs_result_present>-BomCompQuant = lv_quant_udt_num.
*          ENDLOOP.
*          IF <lfs_result_present>-BomExplosionLevel = '01'.
*            IF iv_requiredquantity IS INITIAL.
*              <lfs_result_present>-BomCompQuant *= lv_quant_before.
*            ELSE.
*              <lfs_result_present>-BomCompQuant *= lv_quant_before * iv_requiredquantity.
*            ENDIF.
*          ELSE.
          <lfs_result_present>-BomCompQuant *= lv_quant_before.
*          ENDIF.
        ELSE.
          DATA(lv_mbom_flag) = 'X'.
        ENDIF.
      ENDIF.

      "4.3."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      IF lv_mbom_flag = 'X'.
        CLEAR: lv_mbom_flag.
        "Select M BOM --> chay 2 API
        call_api_line_mbom_kbom(
          EXPORTING
                iv_quant_before = lv_quant_before
                iv_salesorder = iv_salesorder
                iv_salesorderitem   = iv_salesorderitem
                iv_billofmaterial = iv_billofmaterial
                iv_billofmaterialcategory = iv_billofmaterialcategory
                iv_material = iv_material
                iv_plant = iv_plant
                iv_requiredquantity = iv_requiredquantity
          CHANGING
            cs_result       = <lfs_result_present>
        ).
      ENDIF.
    ENDLOOP.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    "Get KBOM lv0
*    get_kbom_lv0(
*      EXPORTING
*        iv_material               = iv_material
*        iv_plant                  = iv_plant
*        iv_salesorder             = iv_salesorder
*        iv_salesorderitem         = iv_salesorderitem
*        iv_billofmaterial         = iv_billofmaterial
*        iv_itemindexstring        = iv_itemindexstring
*        iv_billofmaterialcategory = iv_billofmaterialcategory
*      CHANGING
*        ct_result                 = ct_result
*    ).
  ENDMETHOD.


  METHOD call_api_line_mbom_kbom.
    DATA: lv_err_head_flag,
          lv_err_item_flag.
    "API 1: M BOM Header --> get base quantity
    DATA(lv_quant_head) = call_api_head_kbom(
                            EXPORTING
                              is_result     = cs_result
                            IMPORTING
                              ev_error_flag = lv_err_head_flag
                          ).
    "API 2: M BOM Item --> get Item Quantity
    DATA(lv_quant_item) = call_api_item_kbom(
                            EXPORTING
                              is_result     = cs_result
                            IMPORTING
                              ev_error_flag = lv_err_item_flag
                          ).
    "Cong thuc: item quantity * lv_quant_before / header quantity
    IF lv_err_head_flag IS INITIAL AND lv_err_item_flag IS INITIAL.
*      SELECT SINGLE FROM ztb_zbom_explode
*      FIELDS quantity
*      WHERE bill_of_material = @iv_billofmaterial AND
*            bill_of_material_category = @iv_billofmaterialcategory AND
*            material = @iv_material AND
*            plant = @iv_plant AND
*            sales_order = @iv_salesorder AND
*            sales_order_item = @iv_salesorderitem AND
*            uname = @sy-uname
*      INTO @DATA(lv_quantity).
*      IF sy-subrc = 0.
*      ELSE.
*        lv_quantity = 1.
*      ENDIF.
      IF iv_requiredquantity IS INITIAL.
        DATA(lv_quantity) = 1.
      ELSE.
        lv_quantity = iv_requiredquantity.
      ENDIF.
      IF cs_result-BomExplosionLevel = '01'.
        cs_result-BomCompQuant = lv_quant_item * iv_quant_before * lv_quantity / lv_quant_head.
      ELSE.
        cs_result-BomCompQuant = lv_quant_item * iv_quant_before / lv_quant_head.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD call_api_item_kbom.
    DATA: lv_rc TYPE i.

    CLEAR: ev_error_flag.
    DATA(lv_filter_item) =
        |Material eq '{ is_result-Material }'| &&
        |and Plant eq '{ is_result-Plant }'| &&
        |and BillOfMaterialCategory eq 'M'| &&
        |and BillOfMaterialComponent eq '{ is_result-BillOfMaterialComponent }'|.
    DATA(lv_endpoint_item) =
        |https://my426501-api.s4hana.cloud.sap/sap/opu/odata/SAP| &&
        |/API_BILL_OF_MATERIAL_SRV;v=2/MaterialBOMItem?| &&
        |$filter=| &&
        |{ cl_web_http_utility=>escape_url( lv_filter_item ) }|.
    DATA(lv_xml_item) = call_api_filter(
                          EXPORTING
                            iv_endpoint = lv_endpoint_item
                          IMPORTING
                            ev_rc       = lv_rc
                        ).
    IF lv_rc = '200'.
      DATA(lt_elements_item) = extract_elements(
        iv_xml = lv_xml_item
        iv_tag = 'entry'
      ).
      IF lt_elements_item IS NOT INITIAL.
        LOOP AT lt_elements_item INTO DATA(lv_elements_item).
          rv_quant = get_tag_value(
                         iv_xml = lv_elements_item
                         iv_tag = 'd:BillOfMaterialItemQuantity'
                       ).
        ENDLOOP.
      ELSE.
        ev_error_flag = 'X'.
      ENDIF.
    ELSE.
      ev_error_flag = 'X'.
    ENDIF.
  ENDMETHOD.


  METHOD call_api_head_kbom.
    DATA: lv_rc TYPE i.

    CLEAR: ev_error_flag.

*    DATA(lv_endpoint_head) = get_endpoint_head_kbom( is_result = is_result ).
    DATA(lv_filter_head) =
        |Material eq '{ is_result-Material }'| &&
        |and Plant eq '{ is_result-Plant }'|.
    DATA(lv_endpoint_head) =
        |https://my426501-api.s4hana.cloud.sap/sap/opu/odata/SAP| &&
        |/API_BILL_OF_MATERIAL_SRV;v=2/MaterialBOM?| &&
        |$filter=| &&
        |{ cl_web_http_utility=>escape_url( lv_filter_head ) }|.


    DATA(lv_xml_head) = call_api_filter(
                          EXPORTING
                            iv_endpoint = lv_endpoint_head
                          IMPORTING
                            ev_rc       = lv_rc
                        ).
    IF lv_rc = '200'.
      DATA(lt_elements_head) = extract_elements(
        iv_xml = lv_xml_head
        iv_tag = 'entry'
      ).
      IF lt_elements_head IS NOT INITIAL.
        LOOP AT lt_elements_head INTO DATA(lv_elements_head).
          rv_quant = get_tag_value(
                       iv_xml = lv_elements_head
                       iv_tag = 'd:BOMHeaderQuantityInBaseUnit'
                     ).
        ENDLOOP.
      ELSE.
        ev_error_flag = 'X'.
      ENDIF.
    ELSE.
      ev_error_flag = 'X'.
    ENDIF.
  ENDMETHOD.


  METHOD call_api_filter.
    " Build URL
    DATA(lv_url) =
        |{ iv_endpoint }|.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_url( i_url = lv_url ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( i_destination = lo_destination ).

        DATA: lv_username TYPE string,
              lv_password TYPE string.

*        lv_username = `PB9_LO`.
*        lv_password = `Qwertyuiop@1234567890`.

        SELECT SINGLE * FROM ztb_api_auth INTO @DATA(ls_api_auth).
        IF sy-subrc EQ 0.
          lv_username = ls_api_auth-api_user.
          lv_password = ls_api_auth-api_password.
        ENDIF.

*-- Passing the Accept value in header which is a mandatory field
        lo_client->get_http_request( )->set_header_field( i_name = |username| i_value = lv_username ).
        lo_client->get_http_request( )->set_header_field( i_name = |password| i_value = lv_password ).
*-- Authorization
        lo_client->get_http_request( )->set_authorization_basic( i_username = lv_username i_password = lv_password ).
        lo_client->get_http_request( )->set_content_type( |application/json| ).

        lo_client->get_http_request( )->set_version( version = if_web_http_request=>co_protocol_version_1_1 ).

        " Set headers
        lo_client->get_http_request( )->set_header_fields( VALUE #(
            ( name = 'Accept'             value = 'application/xml' )
            ( name = 'DataServiceVersion' value = '2.0' )
        ) ).

        " GET request
        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).

        DATA(lv_code)   = lo_response->get_status( )-code.
        DATA(lv_reason) = lo_response->get_status( )-reason.
        DATA(lv_body)   = lo_response->get_text( ).

        rv_result_filter = lv_body.
        ev_rc = lv_code.
      CATCH cx_root INTO DATA(lx_ex).
        DATA(lv_msg) = lx_ex->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD processing_mbom.
*    DATA: lv_quantity TYPE string.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Prepare Data
*    SELECT SINGLE FROM ztb_zbom_explode
*    FIELDS quantity
*    WHERE bill_of_material = @iv_billofmaterial AND
*          bill_of_material_category = @iv_billofmaterialcategory AND
*          material = @iv_material AND
*          plant = @iv_plant AND
*          sales_order = @iv_salesorder AND
*          sales_order_item = @iv_salesorderitem AND
*          uname = @sy-uname
*    INTO @lv_quantity.
*    IF sy-subrc = 0.
*    ELSE.
*      lv_quantity = 1.
*    ENDIF.
*    CONDENSE: lv_quantity.

    DATA(lv_date_time) = |{ cl_abap_context_info=>get_system_date( ) DATE = ISO }T00:00:00|.
    " URL-encode the date: 2026-03-06T00:00:00 -> datetime%272026-03-06T00%3A00%3A00%27
    DATA(lv_date_enc) = |datetime%27{ lv_date_time }%27|.
    REPLACE ALL OCCURRENCES OF ':' IN lv_date_enc WITH '%3A'.


    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Get endpoint
    DATA(lv_endpoint_mbom) =
      '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2/ExplodeBOM?' &&
      |Material=%27{ iv_material }%27&|          && "1. Material - Mandatory
      |Plant=%27{ iv_plant }%27&|                && "2. Plant - Optional
      |BillOfMaterialVariant=%27%27&|            && "3. BillOfMaterialVariant - Optional
      |BOMExplosionApplication=%27PP01%27&|      && "4. BOMExplosionApplication - Mandatory
      |RequiredQuantity={ iv_requiredquantity }m&|                     && "5. Required Quantity - Mandatory --> Không gán cứng - Check
      |EngineeringChangeDocument=%27%27&|        && "6. EngineeringChangeDocument - Optional
      |BOMExplosionIsLimited=false&|             && "7. BOMExplosionIsLimited - Mandatory
      |BOMItmQtyIsScrapRelevant=%27%27&|         && "8. BOMItmQtyIsScrapRelevant - Optional
      |BillOfMaterialItemCategory=%27%27&|       && "9. BillOfMaterialItemCategory - Optional
      |BOMExplosionAssembly=%27%27&|             && "10. BOMExplosionAssembly - Optional
      |BOMExplosionDate={ lv_date_enc }&|        && "11. BOMExplosionDate - Mandatory
      |BOMExplosionLevel=0m&|                    && "12. BOMExplosionLevel - Mandatory
      |BOMExplosionIsMultilevel=true&|           && "13. BOMExplosionIsMultilevel - Mandatory
      |MaterialProvisionFltrType=%27%20%27&|     && "14. MaterialProvisionFltrType - Optional
      |SparePartFltrType=%27%20%27&|              && "15. SparePartFltrType - Optional
      |BillOfMaterial=%27{ iv_billofmaterial }%27&|         && "Key Header
      |BillOfMaterialCategory=%27M%27&|          && "Key Header
      |BillOfMaterialVersion=%27%27|.              "Key Header

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " Call API - uses your existing zcl_call_api utility
    DATA(lv_xml_mbom) = zcl_call_api_mbom=>call_api(
      iv_body        = ''
      iv_endpoint    = lv_endpoint_mbom
      iv_method      = 'GET'
      iv_contenttype = 'application/xml'
    ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Parse data into itab result
    IF zcl_call_api_mbom=>code = '200'.
      DATA(lt_elements) = extract_elements(
        iv_xml = lv_xml_mbom
        iv_tag = 'd:element'
      ).
      LOOP AT lt_elements INTO DATA(lv_elem_xml).
        APPEND INITIAL LINE TO rt_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
        <lfs_result>-billofmaterial = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material' ).
        <lfs_result>-billofmaterialcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_category' ).
        <lfs_result>-material = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
        <lfs_result>-billofmaterialvariantusage = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant_usage' ).
        <lfs_result>-salesorder = ''.
        <lfs_result>-salesorderitem = '000000'.
        <lfs_result>-itemindex = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_index' ).
        <lfs_result>-itemindexstring = iv_itemindexstring.
        "Field 1 - Component
        <lfs_result>-billofmaterialcomponent = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_component' ).
        <lfs_result>-bomexplosionlevel = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_explosion_level' ).
        <lfs_result>-bomhhdrmatlhiernode = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
        "Field 2 - Component Description
        <lfs_result>-componentdescription = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_component_description' ).
        "Field 3 - Component Quantity (Component UoM)
        <lfs_result>-bomcompquant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_comp_quant' ).
        "Field 4 - Item Category
        <lfs_result>-billofmaterialitemcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_category' ).
        "Field 5 - Item Number
        <lfs_result>-billofmaterialitemnumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_number' ).
        "Field 6 - Assembly Indicator
        DATA(lv_assy) = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:assembly_indicator' ).
        <lfs_result>-isassembly = COND #( WHEN lv_assy = 'true' THEN abap_true ELSE abap_false ).
        "Field 7 - Material Type
        <lfs_result>-materialtype = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:material_type' ).
        "Field 8 - Plant - Header Key
        <lfs_result>-plant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:plant' ).
        "Field 9 - Base UoM
        <lfs_result>-billofmaterialitemunit = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:base_uom' ).
        "Field 10 - Maintenance Status
        <lfs_result>-maintenancestatus = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:maintenance_status' ).
        "Field 11 - Valid From
        DATA: lv_start_date TYPE char10.
        lv_start_date = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:validity_start_date' ).
        REPLACE ALL OCCURRENCES OF '-' IN lv_start_date WITH ''.
        <lfs_result>-validitystartdate = lv_start_date.
        "Field 12 - Change Number
        <lfs_result>-changenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:change_number' ).
        "Field 13 - Created On
        DATA: lv_created_on TYPE char10.
        lv_created_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:record_creation_date' ).
        REPLACE ALL OCCURRENCES OF '-' IN lv_created_on WITH ''.
        <lfs_result>-createdon = lv_created_on.
        "Field 14 - Created By
        <lfs_result>-createdby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:created_by_user' ).
        "Field 15 - Changed On
        DATA: lv_changed_on TYPE char10.
        lv_changed_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_change_date' ).
        REPLACE ALL OCCURRENCES OF '-' IN lv_changed_on WITH ''.
        <lfs_result>-changedon = lv_changed_on.
        "Field 16 - Changed By
        <lfs_result>-changedby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_changed_by_user' ).
        "Field 17 - Item Spare Part Indicator
        <lfs_result>-isbomitemsparepart = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:is_b_o_m_item_spare_part' ).
        "Field 18 - Component Scrap In Percent
        <lfs_result>-ComponentScrapInPercent = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:comp_scrap_itm' ).

        <lfs_result>-billofmaterialvariant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant' ).
        <lfs_result>-billofmaterialversion = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_version' ).
        <lfs_result>-billofmaterialitemnodenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_node' ).
        <lfs_result>-headerchangedocument = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bom_change_number' ).
      ENDLOOP.

      DATA(lt_result_tmp) = rt_result.
      LOOP AT lt_result_tmp ASSIGNING FIELD-SYMBOL(<lfs_result_tmp>).
        DATA(lv_tabix) = sy-tabix.

        <lfs_result_tmp>-BillOfMaterial = get_tag_value( iv_xml = lt_elements[ lv_tabix ] iv_tag = 'd:bill_of_material' ).
        <lfs_result_tmp>-BillOfMaterialVariant = |{ <lfs_result_tmp>-BillOfMaterialVariant ALPHA = IN }|.
        <lfs_result_tmp>-material = |{ <lfs_result_tmp>-material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
      ENDLOOP.

      SELECT FROM I_BillOfMaterialItemTP_2
      FIELDS
        BillOfMaterial,
        BillOfMaterialCategory,
        BillOfMaterialVariant,
        BillOfMaterialVersion,
        BillOfMaterialItemNodeNumber,
        HeaderChangeDocument,
        Material,
        Plant,

        IsAssembly
      FOR ALL ENTRIES IN @lt_result_tmp
      WHERE
        BillOfMaterial = @lt_result_tmp-BillOfMaterial
        AND BillOfMaterialCategory = @lt_result_tmp-BillOfMaterialCategory
        AND BillOfMaterialVariant = @lt_result_tmp-BillOfMaterialVariant
        AND BillOfMaterialVersion = @lt_result_tmp-BillOfMaterialVersion
        AND BillOfMaterialItemNodeNumber = @lt_result_tmp-BillOfMaterialItemNodeNumber
        AND HeaderChangeDocument = @lt_result_tmp-HeaderChangeDocument
        AND Material = @lt_result_tmp-Material
        AND Plant = @lt_result_tmp-Plant
      INTO TABLE @DATA(lt_bom_items_m).

      LOOP AT rt_result ASSIGNING FIELD-SYMBOL(<lfs_result_udt>).
        READ TABLE lt_bom_items_m INTO DATA(ls_bom_items_m) WITH KEY
                BillOfMaterial = <lfs_result_udt>-BillOfMaterial
                BillOfMaterialCategory       = <lfs_result_udt>-BillOfMaterialCategory
                BillOfMaterialVariant        = |{ <lfs_result_udt>-BillOfMaterialVariant ALPHA = IN }|
                BillOfMaterialVersion        = <lfs_result_udt>-BillOfMaterialVersion
                BillOfMaterialItemNodeNumber = <lfs_result_udt>-BillOfMaterialItemNodeNumber
                HeaderChangeDocument         = <lfs_result_udt>-HeaderChangeDocument
                Material                     = |{ <lfs_result_udt>-material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
                Plant                        = <lfs_result_udt>-Plant.
        IF sy-subrc = 0.
          <lfs_result_udt>-IsAssembly = ls_bom_items_m-IsAssembly.
        ENDIF.
      ENDLOOP.

*      "Get result header - LV0 into index 1 of internal table
*      get_mbom_result_lv0(
*        EXPORTING
*          iv_material                   = iv_material
*          iv_billofmaterial             = iv_billofmaterial
*          iv_billofmaterialcategory     = iv_billofmaterialcategory
*          iv_plant                      = iv_plant
*          iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
*          iv_itemindexstring            = iv_itemindexstring
*          iv_salesorder                 = iv_salesorder
*          iv_salesorderitem             = iv_salesorderitem
*          iv_xml                        = lv_xml_mbom
*          iv_quantity                   = lv_quantity
*        CHANGING
*          ct_result                     = rt_result
*      ).


    ENDIF.
  ENDMETHOD.


  METHOD Recursive_data.
    DATA(lv_salesorder) = iv_salesorder.
    DATA(lv_salesorderitem) = iv_salesorderitem.

    SELECT DISTINCT a~salesorder,
                    a~SalesOrderItem,
                    a~material,
                    a~BillOfMaterial,
                    b~BOMHeaderQuantityInBaseUnit
   FROM I_SalesOrderBOMLink AS a
   INNER JOIN I_SalesOrderBOMHeaderDEX AS b
     ON a~BillOfMaterial = b~BillOfMaterial
        AND a~BillOfMaterialCategory = b~BillOfMaterialCategory
        AND a~BillOfMaterialVariant = b~BillOfMaterialVariant
   WHERE a~BillOfMaterialCategory = 'K' AND
         a~Material = @iv_material AND
         a~plant = @iv_plant AND
         a~salesorder = @lv_salesorder AND
         a~SalesOrderItem = @lv_salesorderitem
   INTO TABLE @DATA(lt_hdr).
    IF sy-subrc <> 0.
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      "Call API M BOM
      "...
      SELECT DISTINCT
          a~billofmaterial ,
          a~material ,
          a~plant ,
          b~plantname ,
          i_productdescription~productdescription
      FROM I_MaterialBOMLink AS a
      LEFT OUTER JOIN I_PlantStdVH AS b
          ON a~plant = b~plant
      LEFT OUTER JOIN I_ProductDescription
          ON a~material = I_ProductDescription~product
          AND I_ProductDescription~language = 'E'
      LEFT OUTER JOIN  I_Product
        ON a~material = I_Product~product
      WHERE a~billofmaterialcategory = 'M' AND
            a~material = @iv_material AND
            b~plant = @iv_plant
      INTO TABLE @DATA(lt_mbom_head).

      CHECK sy-subrc = 0.
      READ TABLE lt_mbom_head INTO DATA(ls_mbom_head) INDEX 1.
      CHECK sy-subrc = 0.

      DATA(lv_date_time) = |{ cl_abap_context_info=>get_system_date( ) DATE = ISO }T00:00:00|.
      " URL-encode the date: 2026-03-06T00:00:00 -> datetime%272026-03-06T00%3A00%3A00%27
      DATA(lv_date_enc) = |datetime%27{ lv_date_time }%27|.
      REPLACE ALL OCCURRENCES OF ':' IN lv_date_enc WITH '%3A'.

      DATA(lv_material) = |{ iv_material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.

      DATA(lv_so_mbom) = ''.
      DATA(lv_so_item_mbom) = '000000'.

      DATA(lv_endpoint) =
*          |https://my426501-api.s4hana.cloud.sap/sap/opu/odata/SAP/| &&
*          |API_BILL_OF_MATERIAL_SRV;v=2/ExplodeBOM?| &&
            '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2/ExplodeBOM?' &&
            |Material=%27{ ls_mbom_head-material }%27&|          && "1. Material - Mandatory
            |Plant=%27{ ls_mbom_head-plant }%27&|                && "2. Plant - Optional
            |BillOfMaterialVariant=%27%27&|            && "3. BillOfMaterialVariant - Optional
            |BOMExplosionApplication=%27PP01%27&|      && "4. BOMExplosionApplication - Mandatory
            |RequiredQuantity={ iv_quantity }m&|                     && "5. Required Quantity - Mandatory --> Không gán cứng - Check
            |EngineeringChangeDocument=%27%27&|        && "6. EngineeringChangeDocument - Optional
            |BOMExplosionIsLimited=false&|             && "7. BOMExplosionIsLimited - Mandatory
            |BOMItmQtyIsScrapRelevant=%27%27&|         && "8. BOMItmQtyIsScrapRelevant - Optional
            |BillOfMaterialItemCategory=%27%27&|       && "9. BillOfMaterialItemCategory - Optional
            |BOMExplosionAssembly=%27%27&|             && "10. BOMExplosionAssembly - Optional
            |BOMExplosionDate={ lv_date_enc }&|        && "11. BOMExplosionDate - Mandatory
            |BOMExplosionLevel=0m&|                    && "12. BOMExplosionLevel - Mandatory
            |BOMExplosionIsMultilevel=true&|           && "13. BOMExplosionIsMultilevel - Mandatory
            |MaterialProvisionFltrType=%27%20%27&|     && "14. MaterialProvisionFltrType - Optional
            |SparePartFltrType=%27%20%27&|              && "15. SparePartFltrType - Optional
            |BillOfMaterial=%27{ ls_mbom_head-BillOfMaterial }%27&|         && "Key Header
            |BillOfMaterial=%27%27&|         && "Key Header
            |BillOfMaterialCategory=%27M%27&|          && "Key Header
            |BillOfMaterialVersion=%27%27|.              "Key Header

      DATA(lv_xml_mbom) = zcl_call_api=>call_api(
        iv_body        = ''
        iv_endpoint    = lv_endpoint
        iv_method      = 'GET'
        iv_contenttype = 'application/xml'
      ).
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      DATA: lt_result_tmp LIKE ct_result.

      DATA(lt_elements) = extract_elements(
        iv_xml = lv_xml_mbom
        iv_tag = 'd:element'
      ).

      LOOP AT lt_elements INTO DATA(lv_elem_xml).
        APPEND INITIAL LINE TO lt_result_tmp ASSIGNING FIELD-SYMBOL(<lfs_result>).
        <lfs_result>-billofmaterial = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:Bill_Of_Material_Root' ).
        <lfs_result>-billofmaterialcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_category' ).
        <lfs_result>-material = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
        <lfs_result>-billofmaterialvariantusage = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant_usage' ).
        <lfs_result>-salesorder = ''.
        <lfs_result>-salesorderitem = '000000'.

        <lfs_result>-itemindex = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_index' ).
        <lfs_result>-itemindexstring = iv_itemindexstring.

*Field 1 - Component
        <lfs_result>-billofmaterialcomponent = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_component' ).

        DATA(lv_level) = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_explosion_level' ).
        <lfs_result>-bomexplosionlevel = lv_level + iv_bomlevel.

        <lfs_result>-bomhhdrmatlhiernode = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
*Field 2 - Component Description
        <lfs_result>-componentdescription = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_component_description' ).
*Field 3 - Component Quantity (Component UoM)
        <lfs_result>-bomcompquant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_comp_quant' ).
*Field 4 - Item Category
        <lfs_result>-billofmaterialitemcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_category' ).
*Field 5 - Item Number
        <lfs_result>-billofmaterialitemnumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_number' ).
*Field 6 - Assembly Indicator
        DATA(lv_assy) = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:assembly_indicator' ).
        <lfs_result>-isassembly = COND #( WHEN lv_assy = 'true' THEN abap_true ELSE abap_false ).
*Field 7 - Material Type
        <lfs_result>-materialtype = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:material_type' ).
*Field 8 - Plant - Header Key
        <lfs_result>-plant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:plant' ).
*Field 9 - Base UoM
        <lfs_result>-billofmaterialitemunit = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:base_uom' ).
*Field 10 - Maintenance Status
        <lfs_result>-maintenancestatus = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:maintenance_status' ).
*Field 11 - Valid From
        DATA: lv_start_date TYPE char10.
        lv_start_date = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:validity_start_date' ).
        REPLACE ALL OCCURRENCES OF '-' IN lv_start_date WITH ''.
        <lfs_result>-validitystartdate = lv_start_date.
*Field 12 - Change Number
        <lfs_result>-changenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:change_number' ).
*Field 13 - Created On
        DATA: lv_created_on TYPE char10.
        lv_created_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:record_creation_date' ).
        REPLACE ALL OCCURRENCES OF '-' IN lv_created_on WITH ''.
        <lfs_result>-createdon = lv_created_on.
*Field 14 - Created By
        <lfs_result>-createdby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:created_by_user' ).
*Field 15 - Changed On
        DATA: lv_changed_on TYPE char10.
        lv_changed_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_change_date' ).
        REPLACE ALL OCCURRENCES OF '-' IN lv_changed_on WITH ''.
        <lfs_result>-changedon = lv_changed_on.
*Field 16 - Changed By
        <lfs_result>-changedby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_changed_by_user' ).
*Field 17 - Item Spare Part Indicator
        <lfs_result>-isbomitemsparepart = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:is_b_o_m_item_spare_part' ).

        <lfs_result>-billofmaterialvariant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant' ).
        <lfs_result>-billofmaterialversion = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_version' ).
        <lfs_result>-billofmaterialitemnodenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_node' ).
        <lfs_result>-headerchangedocument = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:comp_scrap_itm' ).
      ENDLOOP.
      SORT lt_result_tmp BY itemindex.
      APPEND LINES OF lt_result_tmp TO ct_result.
*      "Update Quantity with K BOM
*      update_quant_kbom(
*        EXPORTING
*          iv_salesorder             = iv_salesorder
*          iv_salesorderitem         = iv_salesorderitem
*          iv_billofmaterial         = iv_billofmaterial
*          iv_billofmaterialcategory = iv_billofmaterialcategory
*          iv_material               = iv_material
*          iv_plant                  = iv_plant
*        CHANGING
*          ct_result                 = ct_result
*      ).
    ENDIF.

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    CHECK sy-subrc = 0.

    LOOP AT lt_hdr INTO DATA(ls_hdr).
      SELECT *
      FROM I_SalesOrderBOMItemDEX AS itm
      WHERE itm~BillOfMaterial        = @ls_hdr-BillOfMaterial
        AND itm~BillOfMaterialCategory = 'K'
      INTO TABLE @DATA(lt_items).
      CHECK sy-subrc = 0.
      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>).
        DATA(lv_tabix) = sy-tabix.
        APPEND INITIAL LINE TO ct_result ASSIGNING <lfs_result>.
        <lfs_result>-ItemIndex = lv_tabix.
        <lfs_result>-ItemIndexString = iv_itemindexstring.
        <lfs_result>-BillOfMaterial = <lfs_item>-BillOfMaterial.
        <lfs_result>-BillOfMaterialCategory = <lfs_item>-BillOfMaterialCategory.
        <lfs_result>-Material = iv_material.
        <lfs_result>-Plant = iv_plant.
        <lfs_result>-BillOfMaterialVariantUsage = 1.
        <lfs_result>-SalesOrder = iv_salesorder.
        <lfs_result>-SalesOrderItem = iv_salesorderitem.

        SELECT SINGLE FROM i_product
        FIELDS ProductType
        WHERE product = @<lfs_item>-BillOfMaterialComponent
        INTO @<lfs_result>-MaterialType.

        <lfs_result>-BillOfMaterialComponent = <lfs_item>-BillOfMaterialComponent.
        <lfs_result>-BomExplosionLevel = iv_bomlevel + 1.
        <lfs_result>-BomhHdrMatlHierNode = ls_hdr-Material.

        SELECT SINGLE FROM I_ProductText
        FIELDS ProductName
        WHERE Language = 'E'
              AND Product = @<lfs_item>-BillOfMaterialComponent
        INTO @<lfs_result>-ComponentDescription.

        <lfs_item>-BillOfMaterialItemQuantity = <lfs_item>-BillOfMaterialItemQuantity / ls_hdr-BOMHeaderQuantityInBaseUnit.
*        <lfs_result>-BomCompQuant = iv_quantity / ls_hdr-BOMHeaderQuantityInBaseUnit.

        <lfs_result>-BillOfMaterialItemCategory = <lfs_item>-BillOfMaterialItemCategory.
        <lfs_result>-BillOfMaterialItemNumber = <lfs_item>-BillOfMaterialItemNumber.
        <lfs_result>-BillOfMaterialItemUnit = <lfs_item>-BillOfMaterialItemUnit.
        <lfs_result>-ValidityStartDate = <lfs_item>-ValidityStartDate.

        "Step 3: Select để check xem còn data cho item không
        Recursive_data(
                        EXPORTING
                             iv_material               = CONV string( <lfs_result>-BillOfMaterialComponent )
                             iv_plant                  = CONV string( <lfs_result>-Plant )
                             iv_salesorder             = CONV string( iv_salesorder )
                             iv_salesorderitem         = CONV string( iv_salesorderitem )
                             iv_billofmaterialcategory = 'K'
                             iv_itemindexstring        = CONV string( iv_itemindexstring )
                             iv_quantity               = CONV i( iv_quantity )
                             iv_bomlevel               = CONV numc2( <lfs_result>-BomExplosionLevel )
                        CHANGING
                            ct_result = ct_result
                       ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_itab_key_field.
    " Read filter conditions if provided
    DATA(lo_filter)               = io_request->get_filter( ).
    TRY.
        DATA(lt_filters) = lo_filter->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        "handle exception
    ENDTRY.
    CHECK lt_filters IS NOT INITIAL.

    DATA(lr_material) = get_material_range( it_filters = lt_filters ).
    DATA(lr_plant) = get_plant_range( it_filters = lt_filters ).
    DATA(lr_salesorder) = get_so_range( it_filters = lt_filters ).
    DATA(lr_salesorderitem) = get_soitem_range( it_filters = lt_filters ).
    DATA(lr_bomvariantusage) = get_bomvariantusage_range( it_filters = lt_filters ).

    "Get BILLOFMATERIAL
    READ TABLE lt_filters INTO DATA(ls_bom) WITH KEY name = 'BILLOFMATERIAL'.
    CHECK sy-subrc = 0.
    SORT ls_bom-range BY low.

    "Get BILLOFMATERIALCATEGORY
    READ TABLE lt_filters INTO DATA(ls_bomcategory) WITH KEY name = 'BILLOFMATERIALCATEGORY'.
    IF sy-subrc = 0.
      DATA(lv_bom_cat) = ls_bomcategory-range[ 1 ]-low.
    ENDIF.

    "NinhNH Updated - Determine allowed BillOfMaterialVariant(s):
    "plants in the 673* series (e.g. 6731, 673K) also use alternative BOM variants A*/B*/X*/G*/M*
    DATA(lv_is_673_plant) = abap_false.
    LOOP AT lr_plant INTO DATA(ls_plant_chk).
      IF ls_plant_chk-low(3) = '673' OR ( ls_plant_chk-high IS NOT INITIAL AND ls_plant_chk-high(3) = '673' ).
        lv_is_673_plant = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    DATA lr_bom_variant TYPE RANGE OF i_materialbomlink-billofmaterialvariant.
    lr_bom_variant = VALUE #( ( sign = 'I' option = 'EQ' low = '01' ) ).
    IF lv_is_673_plant = abap_true.
      lr_bom_variant = VALUE #( BASE lr_bom_variant
        ( sign = 'I' option = 'CP' low = 'A*' )
        ( sign = 'I' option = 'CP' low = 'B*' )
        ( sign = 'I' option = 'CP' low = 'X*' )
        ( sign = 'I' option = 'CP' low = 'G*' )
        ( sign = 'I' option = 'CP' low = 'M*' ) ).
    ENDIF.

    "Get MATERIAL, PLANT, SALESORDER, SALESORDERITEM
    IF lv_bom_cat = 'M'.
      "Processing key fields MBOM
      SELECT DISTINCT a~BillOfMaterial,
                      a~material,
                      a~plant
      FROM I_MaterialBOMLink AS a
      WHERE a~BillOfMaterial IN @ls_bom-range
            AND a~BillOfMaterialVariant IN @lr_bom_variant "NinhNH Updated
            AND a~BillOfMaterialCategory = 'M'
      INTO TABLE @DATA(lt_bom_m).
    ELSEIF lv_bom_cat = 'K'.
      "Processing key fields KBOM
      SELECT DISTINCT a~BillOfMaterial,
                      a~material,
                      a~plant,
                      a~salesorder,
                      a~salesorderitem
      FROM i_salesorderbomlink AS a
      WHERE a~BillOfMaterial IN @ls_bom-range
            AND a~BillOfMaterialCategory = 'K'
      INTO TABLE @DATA(lt_bom_k).
    ENDIF.

    "Get Required Quantity
    IF lv_bom_cat = 'M'.
*      DATA(lv_quantity) = 1000.
    ELSEIF lv_bom_cat = 'K'.
      SELECT FROM I_SalesOrderItem AS a
      INNER JOIN @lt_bom_k AS b ON b~SalesOrder = a~SalesOrder AND
                                   b~SalesOrderItem = a~SalesOrderItem AND
                                   b~Plant = a~Plant AND
                                   b~Material = a~Product
      FIELDS b~BillOfMaterial,
             a~OrderQuantity
      INTO TABLE @DATA(lt_quantity).
    ENDIF.

    "Get BILLOFMATERIALVARIANTUSAGE
    READ TABLE lt_filters INTO DATA(ls_bomvariantusage) WITH KEY name = 'BILLOFMATERIALVARIANTUSAGE'.
    IF sy-subrc = 0.
      DATA(lv_bom_variant_usage) = ls_bomvariantusage-range[ 1 ]-low.
    ENDIF.

    "Append data
    LOOP AT ls_bom-range INTO DATA(ls_bom_range).
      APPEND INITIAL LINE TO rt_key_field ASSIGNING FIELD-SYMBOL(<lfs_key_field>).
      <lfs_key_field>-billofmaterial = ls_bom_range-low.
      <lfs_key_field>-billofmaterialcategory = lv_bom_cat.
      <lfs_key_field>-billofmaterialvariantusage = lv_bom_variant_usage.

      IF <lfs_key_field>-billofmaterialcategory = 'M'.
        READ TABLE lt_bom_m INTO DATA(ls_bom_m) WITH KEY BillOfMaterial = <lfs_key_field>-billofmaterial.
        IF sy-subrc = 0.
          <lfs_key_field>-material = ls_bom_m-Material.
          <lfs_key_field>-plant = ls_bom_m-Plant.
        ENDIF.
        <lfs_key_field>-salesorder = ''.
        <lfs_key_field>-salesorderitem = '000000'.
      ELSEIF <lfs_key_field>-billofmaterialcategory = 'K'.
        READ TABLE lt_bom_k INTO DATA(ls_bom_k) WITH KEY BillOfMaterial = <lfs_key_field>-billofmaterial.
        IF sy-subrc = 0.
          <lfs_key_field>-material = ls_bom_k-Material.
          <lfs_key_field>-plant = ls_bom_k-Plant.
          <lfs_key_field>-salesorder = ls_bom_k-salesorder.
          <lfs_key_field>-salesorderitem = ls_bom_k-SalesOrderItem.
        ENDIF.
      ENDIF.

      IF <lfs_key_field>-billofmaterialcategory = 'M'.
        <lfs_key_field>-requiredquantity = 1000.
      ELSEIF <lfs_key_field>-billofmaterialcategory = 'K'.
        READ TABLE lt_quantity INTO DATA(ls_quantity) WITH KEY BillOfMaterial = <lfs_key_field>-billofmaterial.
        IF sy-subrc = 0.
          <lfs_key_field>-requiredquantity = ls_quantity-OrderQuantity.
        ENDIF.
        IF <lfs_key_field>-requiredquantity = 0.
          <lfs_key_field>-requiredquantity = 1000.
        ENDIF.
      ENDIF.
      CONDENSE: <lfs_key_field>-requiredquantity NO-GAPS.

      <lfs_key_field>-itemindexstring  =  |{ <lfs_key_field>-billofmaterial }~#%| &&
                                          |{ <lfs_key_field>-billofmaterialcategory }~#%| &&
                                          |{ <lfs_key_field>-billofmaterialvariantusage }~#%| &&
                                          |{ <lfs_key_field>-material }~#%| &&
                                          |{ <lfs_key_field>-plant }~#%| &&
                                          |{ <lfs_key_field>-salesorder }~#%| &&
                                          |{ <lfs_key_field>-salesorderitem }| &&
                                          |{ <lfs_key_field>-requiredquantity }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_soitem_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'SALESORDERITEM'.
    IF sy-subrc = 0.
      LOOP AT ls_filters-range INTO DATA(ls_salesorderitem).
        APPEND INITIAL LINE TO rr_salesorderitem ASSIGNING FIELD-SYMBOL(<lfs_salesorderitem>).
        <lfs_salesorderitem>-sign =  'I'.
        <lfs_salesorderitem>-option =  'EQ'.
        <lfs_salesorderitem>-low =  ls_salesorderitem-low.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_plant_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'PLANT'.
    IF sy-subrc = 0.
      LOOP AT ls_filters-range INTO DATA(ls_plant).
        APPEND INITIAL LINE TO rr_plant ASSIGNING FIELD-SYMBOL(<lfs_plant>).
        <lfs_plant>-sign =  'I'.
        <lfs_plant>-option =  'EQ'.
        <lfs_plant>-low =  ls_plant-low.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_material_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'MATERIAL'.
    IF sy-subrc = 0.
      LOOP AT ls_filters-range INTO DATA(ls_material).
        APPEND INITIAL LINE TO rr_material ASSIGNING FIELD-SYMBOL(<lfs_material>).
        <lfs_material>-sign =  'I'.
        <lfs_material>-option = 'EQ'.
        <lfs_material>-low = ls_material-low.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_so_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'SALESORDER'.
    IF sy-subrc = 0.
      LOOP AT ls_filters-range INTO DATA(ls_salesorder).
        APPEND INITIAL LINE TO rr_salesorder ASSIGNING FIELD-SYMBOL(<lfs_salesorder>).
        <lfs_salesorder>-sign =  'I'.
        <lfs_salesorder>-option =  'EQ'.
        <lfs_salesorder>-low =  ls_salesorder-low.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_tag_value.
    " Extract text content between <iv_tag> and </iv_tag>
    " Returns empty string for missing or self-closing (m:null) tags

    DATA(lv_open)  = |<{ iv_tag }>|.
    DATA(lv_close) = |</{ iv_tag }>|.

    DATA(lv_start) = find( val = iv_xml sub = lv_open ).
    IF lv_start < 0.
      rv_value = ''.
      RETURN.
    ENDIF.

    DATA(lv_content_start) = lv_start + strlen( lv_open ).
    DATA(lv_end) = find( val = iv_xml sub = lv_close off = lv_content_start ).
    IF lv_end < 0.
      rv_value = ''.
      RETURN.
    ENDIF.

    rv_value = substring( val = iv_xml off = lv_content_start len = lv_end - lv_content_start ).
    CONDENSE rv_value.
  ENDMETHOD.


  METHOD extract_elements.
    " Split iv_xml into blocks delimited by <iv_tag>...</iv_tag>
    " Returns the inner content of each block as a string table entry

    DATA(lv_open)      = |<{ iv_tag }|.
    DATA(lv_close)     = |</{ iv_tag }>|.
    DATA(lv_open_len)  = strlen( lv_open ).
    DATA(lv_close_len) = strlen( lv_close ).
    DATA(lv_xml)       = iv_xml.

    DO.
      DATA(lv_start) = find( val = lv_xml sub = lv_open ).
      IF lv_start < 0. EXIT. ENDIF.

      DATA(lv_inner_start) = lv_start + lv_open_len.
      DATA(lv_end)         = find( val = lv_xml sub = lv_close off = lv_inner_start ).
      IF lv_end < 0. EXIT. ENDIF.

      APPEND substring( val = lv_xml off = lv_inner_start len = lv_end - lv_inner_start )
        TO rt_elements.

      " Advance past this element for next iteration
      lv_xml = substring( val = lv_xml off = lv_end + lv_close_len ).
    ENDDO.
  ENDMETHOD.


  METHOD get_component_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'BILLOFMATERIALCOMPONENT'.
    IF sy-subrc = 0.
      LOOP AT ls_filters-range INTO DATA(ls_bomcomponent).
        APPEND INITIAL LINE TO rr_component ASSIGNING FIELD-SYMBOL(<lfs_component>).
        <lfs_component>-sign =  'I'.
        <lfs_component>-option =  'EQ'.
        <lfs_component>-low =  ls_bomcomponent-low.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_bomexplosionlevel_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'BOMEXPLOSIONLEVEL'.
    IF sy-subrc = 0.
      LOOP AT ls_filters-range INTO DATA(ls_bomlevel).
        APPEND INITIAL LINE TO rr_bomexplosionlevel ASSIGNING FIELD-SYMBOL(<lfs_bomexplosionlevel>).
        <lfs_bomexplosionlevel>-sign =  'I'.
        <lfs_bomexplosionlevel>-option =  'EQ'.
        <lfs_bomexplosionlevel>-low =  ls_bomlevel-low.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD get_bomvariantusage_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'BILLOFMATERIALVARIANTUSAGE'.
    IF sy-subrc = 0.
      LOOP AT ls_filters-range INTO DATA(ls_range).
        APPEND INITIAL LINE TO rr_bomvariantusage ASSIGNING FIELD-SYMBOL(<lfs_bomvariantusage>).
        <lfs_bomvariantusage>-sign =  'I'.
        <lfs_bomvariantusage>-option =  'EQ'.
        <lfs_bomvariantusage>-low =  ls_range-low.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD processing_kbom3.
    DATA: lv_product TYPE matnr VALUE '300004388',
          lv_plant   TYPE werks_d VALUE '6711',
          lv_bom_cat TYPE c VALUE 'K',
          lv_so      TYPE vbeln VALUE '0010000010',
          lv_so_item TYPE n LENGTH 6 VALUE '000010'.

*    DATA: lt_result   TYPE tt_res.

    lv_product = |{ lv_product WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.

    DATA: lv_quant_before TYPE p.

*    DATA: lv_bomlevel TYPE n LENGTH 2 VALUE '00'.

    lv_product  = iv_material.
    lv_product = |{ lv_product WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.

    lv_plant = iv_plant.

    lv_bom_cat = iv_billofmaterialcategory.

    lv_so = iv_salesorder.

    lv_so_item = iv_salesorderitem.

    lv_quant_before = iv_requiredquantity.

    "======================================================
    " STEP 1: Load toàn bộ BOM Links của SO này 1 lần
    " → biết được material nào có KBOM con
    "======================================================

    SELECT DISTINCT a~salesorder,
                    a~SalesOrderItem,
                    a~material,
                    a~BillOfMaterial,
                    b~BOMHeaderQuantityInBaseUnit
   FROM I_SalesOrderBOMLink AS a
   INNER JOIN I_SalesOrderBOMHeaderDEX AS b
     ON a~BillOfMaterial = b~BillOfMaterial
        AND a~BillOfMaterialCategory = b~BillOfMaterialCategory
        AND a~BillOfMaterialVariant = b~BillOfMaterialVariant
   WHERE a~BillOfMaterialCategory = @lv_bom_cat AND
*         a~Material = @lv_product AND
         a~plant = @lv_plant AND
         a~salesorder = @lv_so AND
         a~SalesOrderItem = @lv_so_item
   INTO TABLE @DATA(lt_all_bom_links).
    CHECK lt_all_bom_links IS NOT INITIAL.

    "======================================================
    " STEP 2: Load toàn bộ BOM Items 1 lần
    "======================================================
    DATA lr_bom_range TYPE RANGE OF string.
    lr_bom_range = VALUE #( FOR ls IN lt_all_bom_links
                            ( sign = 'I' option = 'EQ'
                              low  = ls-billofmaterial ) ).

    SELECT *
    FROM i_salesorderbomitemdex
    WHERE billofmaterial IN @lr_bom_range
      AND billofmaterialcategory = @lv_bom_cat
    INTO TABLE @DATA(lt_all_items).
    CHECK lt_all_items IS NOT INITIAL.

    "======================================================
    " STEP 3: Load Product Type + Text 1 lần
    "======================================================
    " Gom toàn bộ component từ lt_all_items vào 1 range
    DATA lr_comp_range TYPE RANGE OF matnr.
    lr_comp_range = VALUE #(
      FOR ls_i IN lt_all_items
      ( sign   = 'I'
        option = 'EQ'
        low    = CONV matnr( ls_i-BillOfMaterialComponent ) )
    ).
    " Thêm cả root product phòng trường hợp cần tra cứu
    APPEND VALUE #(
      sign   = 'I'
      option = 'EQ'
      low    = CONV matnr( lv_product )
    ) TO lr_comp_range.

    " --- Product Type ---
    SELECT product,
           producttype
      FROM i_product
      WHERE product IN @lr_comp_range
      INTO TABLE @DATA(lt_product_types).

    " --- Product Description (ngôn ngữ EN) ---
    SELECT product,
           ProductDescription
      FROM i_productdescription
      WHERE product   IN @lr_comp_range
        AND language   = 'E'
      INTO TABLE @DATA(lt_product_texts).

    " Sort để BINARY SEARCH ở STEP 5
    SORT lt_product_types BY product.
    SORT lt_product_texts BY product.

    " Sort để BINARY SEARCH
    SORT lt_all_bom_links BY material.
    SORT lt_all_items     BY billofmaterial billofmaterialcomponent.

    "======================================================
    " STEP 4: Build tree bằng Stack (không dùng recursion)
    "======================================================
    TYPES: BEGIN OF ty_stack,
             bom          TYPE string,
             product      TYPE string,
             level        TYPE numc2,
             quant_before TYPE p LENGTH 10 DECIMALS 6,
             quant_head   TYPE p LENGTH 10 DECIMALS 6,
           END OF ty_stack.
    DATA lt_stack TYPE TABLE OF ty_stack.

    " Tìm root BOM
    READ TABLE lt_all_bom_links INTO DATA(ls_root)
      WITH KEY material = CONV matnr( lv_product )
      BINARY SEARCH.
    CHECK sy-subrc = 0.

    APPEND VALUE #(
      bom          = ls_root-billofmaterial
      product      = lv_product
      level        = '00'
      quant_before = 1000
      quant_head   = ls_root-bomheaderquantityinbaseunit
    ) TO lt_stack.

    "======================================================
    " STEP 5: Process stack → không cần DB call nữa
    "======================================================
    WHILE lt_stack IS NOT INITIAL.
      DATA(lv_last_idx) = lines( lt_stack ).
      READ TABLE lt_stack INTO DATA(ls_cur) INDEX lv_last_idx.
      DELETE lt_stack INDEX lv_last_idx.

      " Lấy items từ memory
      LOOP AT lt_all_items INTO DATA(ls_item)
        WHERE billofmaterial = ls_cur-bom.

        APPEND INITIAL LINE TO ct_result ASSIGNING FIELD-SYMBOL(<lfs>).

        <lfs>-BillOfMaterial             = ls_item-BillOfMaterial.
        <lfs>-BillOfMaterialCategory     = lv_bom_cat.
        <lfs>-Material                   = ls_cur-product.
        <lfs>-Plant                      = lv_plant.
        <lfs>-BillOfMaterialVariantUsage = 1.
        <lfs>-SalesOrder                 = lv_so.
        <lfs>-SalesOrderItem             = lv_so_item.
        <lfs>-BillOfMaterialComponent    = ls_item-BillOfMaterialComponent.
        <lfs>-BomExplosionLevel          = ls_cur-level + 1.
        <lfs>-BomhHdrMatlHierNode        = ls_cur-product.
        <lfs>-BomCompQuant               = ls_cur-quant_before
                                           * ls_item-BillOfMaterialItemQuantity
                                           / ls_cur-quant_head.
        <lfs>-BillOfMaterialItemCategory = ls_item-BillOfMaterialItemCategory.
        <lfs>-BillOfMaterialItemNumber   = ls_item-BillOfMaterialItemNumber.
        <lfs>-BillOfMaterialItemUnit     = ls_item-BillOfMaterialItemUnit.
        <lfs>-ValidityStartDate          = ls_item-ValidityStartDate.

        " Lookup từ memory — không cần SELECT
        READ TABLE lt_product_types INTO DATA(ls_ptype)
          WITH KEY product = CONV matnr( ls_item-BillOfMaterialComponent )
          BINARY SEARCH.
        IF sy-subrc = 0.
          <lfs>-MaterialType = ls_ptype-producttype.
        ENDIF.

        READ TABLE lt_product_texts INTO DATA(ls_ptext)
          WITH KEY product = CONV matnr( ls_item-BillOfMaterialComponent )
          BINARY SEARCH.
        IF sy-subrc = 0.
          <lfs>-ComponentDescription = ls_ptext-ProductDescription.
        ENDIF.

        " Check BOM con từ memory
        READ TABLE lt_all_bom_links INTO DATA(ls_child)
          WITH KEY material = CONV matnr( ls_item-BillOfMaterialComponent )
          BINARY SEARCH.

        IF sy-subrc = 0 AND ls_cur-level < 10.
          " Có KBOM con → push vào stack
          APPEND VALUE #(
            bom          = ls_child-billofmaterial
            product      = ls_item-BillOfMaterialComponent
            level        = ls_cur-level + 1
            quant_before = <lfs>-BomCompQuant
            quant_head   = ls_child-bomheaderquantityinbaseunit
          ) TO lt_stack.
        ELSE.
          " Leaf node → thử MBOM (API call)
          DATA lt_mbom_tmp LIKE ct_result.
          run_mbom2(
            EXPORTING
              iv_material_mbom = CONV string( ls_item-BillOfMaterialComponent )
              iv_plant         = CONV string( lv_plant )
              iv_level         = CONV numc2( <lfs>-BomExplosionLevel )
              iv_quant         = <lfs>-BomCompQuant
            CHANGING
              ct_result        = lt_mbom_tmp
          ).
          APPEND LINES OF lt_mbom_tmp TO ct_result.
          CLEAR lt_mbom_tmp.
        ENDIF.
      ENDLOOP.
    ENDWHILE.

    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-ItemIndex = sy-tabix.
      <lfs_result>-ItemIndexString = iv_itemindexstring.
      <lfs_result>-BillOfMaterialCategory = iv_billofmaterialcategory.
      <lfs_result>-Materialheader = iv_material.
      <lfs_result>-SalesOrder = iv_salesorder.
      <lfs_result>-SalesOrderitem = iv_salesorderitem.
      <lfs_result>-RequiredQuantityHeader = iv_requiredquantity.
      <lfs_result>-BillOfMaterialComponent = |{ <lfs_result>-BillOfMaterialComponent ALPHA = OUT }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD processing_kbom4.
    DATA: lv_product TYPE matnr VALUE '300004388',
          lv_plant   TYPE werks_d VALUE '6711',
          lv_bom_cat TYPE c VALUE 'K',
          lv_so      TYPE vbeln VALUE '0010000010',
          lv_so_item TYPE n LENGTH 6 VALUE '000010'.
    DATA: lv_quant_before TYPE p.

    lv_product  = iv_material.
    lv_product = |{ lv_product WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.

    lv_plant = iv_plant.
    lv_bom_cat = iv_billofmaterialcategory.
    lv_so = iv_salesorder.
    lv_so_item = iv_salesorderitem.
    lv_quant_before = iv_requiredquantity.

    DATA: lv_requiredquantity TYPE i.

    lv_requiredquantity = iv_requiredquantity.
    TRY.
        SELECT SINGLE billofmaterial,
                     billofmaterialvariant,
                     salesorder,
                     salesorderitem
         FROM i_salesorderbomlink
         WHERE material               = @lv_product
           AND plant                  = @lv_plant
           AND billofmaterialcategory = @lv_bom_cat
           AND salesorder             = @lv_so
           AND salesorderitem         = @lv_so_item
         INTO @DATA(ls_bom_key).

        " 2. Check BOM link có đúng SO không
        SELECT *
          FROM i_salesorderbomlink
          WHERE material               = @lv_product
            AND plant                  = @lv_plant
            AND billofmaterialcategory = 'K'
          INTO TABLE @DATA(lt_bom_links).
        CHECK sy-subrc = 0.

        SELECT  *
          FROM i_salesorderbomheaderdex
          WHERE billofmaterial         = @ls_bom_key-billofmaterial
            AND billofmaterialcategory = 'K'
          INTO TABLE @DATA(ls_bom_hdr).

        READ ENTITIES OF I_SalesOrderBillOfMaterialTP_2
          ENTITY SalesBillOfMaterial
          EXECUTE ExplodeBOM
          FROM VALUE #( (
              %key-BillOfMaterial            = ls_bom_key-billofmaterial
              %key-BillOfMaterialCategory    = lv_bom_cat
              %key-BillOfMaterialVariant     = ls_bom_key-billofmaterialvariant
              %key-EngineeringChangeDocument = ''
              %key-Material                  = lv_product
              %key-Plant                     = lv_plant

              %param-BOMExplosionDate           = cl_abap_context_info=>get_system_date( )
              %param-BOMExplosionIsMultilevel   = abap_true
              %param-RequiredQuantity           = lv_requiredquantity
              %param-BOMExplosionApplication    = 'PP01'
              %param-BillOfMaterialItemCategory = ''
              %param-SalesOrder                 = ls_bom_key-salesorder
              %param-SalesOrderItem             = ls_bom_key-salesorderitem
          ) )
          RESULT DATA(lt_result)
          FAILED DATA(lt_failed)
          REPORTED DATA(lt_reported).
      CATCH cx_root.
        CHECK 1 = 1.
    ENDTRY.

    IF lt_result IS NOT INITIAL.
      " ComponentScrapInPercent là field master của BOM item, action
      " ExplodeBOM không trả về, nên phải lấy kèm ở đây cùng IsAssembly.
      SELECT FROM I_SlsOrdBillOfMaterialItemTP_2
        FIELDS BillOfMaterial,
               BillOfMaterialCategory,
               BillOfMaterialVariant,
               BillOfMaterialItemNodeNumber,
               HeaderChangeDocument,
               Material,
               Plant,
               IsAssembly,
               ComponentScrapInPercent
        FOR ALL ENTRIES IN @lt_result
        WHERE BillOfMaterial            = @lt_result-%param-BillOfMaterial
          AND BillOfMaterialCategory    = @lt_result-%param-BillOfMaterialCategory
          AND BillOfMaterialVariant     = @lt_result-%param-BillOfMaterialVariant
          AND BillOfMaterialItemNodeNumber = @lt_result-%param-BillOfMaterialItemNodeNumber
          AND HeaderChangeDocument                  = @lt_result-%param-BOMHdrEngChgDoc
          AND Material                  = @lt_result-%param-BOMHdrMatlHierNode
          AND Plant                     = @lt_result-%param-Plant
        INTO TABLE @DATA(lt_bom_items).

      READ ENTITIES OF I_BillOfMaterialTP_2
        ENTITY BillOfMaterialItem
        FIELDS ( IsAssembly ComponentScrapInPercent )
        WITH VALUE
          #( FOR ls_res IN lt_result
          ( %key-BillOfMaterial            = ls_res-%param-BillOfMaterial
            %key-BillOfMaterialCategory       = ls_res-%param-BillOfMaterialCategory
            %key-BillOfMaterialVariant        = ls_res-%param-BillOfMaterialVariant
            %key-BillOfMaterialVersion        = ls_res-%param-BillOfMaterialVersion
            %key-BillOfMaterialItemNodeNumber = ls_res-%param-BillOfMaterialItemNodeNumber
            %key-HeaderChangeDocument         = ls_res-%param-BOMHdrEngChgDoc
            %key-Material                     = ls_res-%param-BOMHdrMatlHierNode
            %key-Plant                        = ls_res-%param-Plant
          ) )
        RESULT DATA(lt_bom_items_m)
        FAILED DATA(lt_failed_items_m)
        REPORTED DATA(lt_reported_items_m).

      LOOP AT lt_result INTO DATA(ls_result_tmp).
        DATA(lv_tabix) = sy-tabix.
        APPEND INITIAL LINE TO ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
        <lfs_result> = CORRESPONDING #( ls_result_tmp ).
        <lfs_result> = CORRESPONDING #( ls_result_tmp-%param ).
        <lfs_result>-ItemIndex = lv_tabix.
        <lfs_result>-ItemIndexString = iv_itemindexstring.

        <lfs_result>-material = ls_result_tmp-%param-BOMHdrMatlHierNode.
        <lfs_result>-materialheader = ls_result_tmp-%param-BOMHdrRootMatlHierNode.
        <lfs_result>-UomHeader = ls_result_tmp-%param-BOMHeaderBaseUnit.
        <lfs_result>-RequiredQuantityHeader = iv_requiredquantity.
        <lfs_result>-BomExplosionLevel = ls_result_tmp-%param-ExplodeBOMLevelValue.
        <lfs_result>-BomhHdrMatlHierNode = ls_result_tmp-%param-BOMHdrMatlHierNode.
        <lfs_result>-BomCompQuant = ls_result_tmp-%param-ComponentQuantityInCompUoM.

        READ TABLE lt_bom_items INTO DATA(ls_bom_items) WITH KEY
            BillOfMaterial = ls_result_tmp-%param-BillOfMaterial
            BillOfMaterialCategory = ls_result_tmp-%param-BillOfMaterialCategory
            BillOfMaterialVariant = ls_result_tmp-%param-BillOfMaterialVariant
            BillOfMaterialItemNodeNumber = ls_result_tmp-%param-BillOfMaterialItemNodeNumber
            HeaderChangeDocument = ls_result_tmp-%param-BOMHdrEngChgDoc
            Material = ls_result_tmp-%param-BOMHdrMatlHierNode
            Plant = ls_result_tmp-%param-Plant.
        IF sy-subrc = 0.
          <lfs_result>-IsAssembly = ls_bom_items-IsAssembly.
          <lfs_result>-ComponentScrapInPercent = ls_bom_items-ComponentScrapInPercent.
        ELSE.
          READ TABLE lt_bom_items_m INTO DATA(ls_bom_items_m) WITH KEY
                %key-BillOfMaterial = ls_result_tmp-%param-BillOfMaterial
                %key-BillOfMaterialCategory       = ls_result_tmp-%param-BillOfMaterialCategory
                %key-BillOfMaterialVariant        = ls_result_tmp-%param-BillOfMaterialVariant
                %key-BillOfMaterialVersion        = ls_result_tmp-%param-BillOfMaterialVersion
                %key-BillOfMaterialItemNodeNumber = ls_result_tmp-%param-BillOfMaterialItemNodeNumber
                %key-HeaderChangeDocument         = ls_result_tmp-%param-BOMHdrEngChgDoc
                %key-Material                     = ls_result_tmp-%param-BOMHdrMatlHierNode
                %key-Plant                        = ls_result_tmp-%param-Plant
              .
          IF sy-subrc = 0.
            <lfs_result>-IsAssembly = ls_bom_items_m-IsAssembly.
            <lfs_result>-ComponentScrapInPercent = ls_bom_items_m-ComponentScrapInPercent.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
