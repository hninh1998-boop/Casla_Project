CLASS zcl_zbom_item_ce DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: tt_res TYPE STANDARD TABLE OF zce_zbom_item WITH DEFAULT KEY.

    METHODS get_fields_key
      IMPORTING
        io_request                    TYPE REF TO if_rap_query_request
      EXPORTING
        ev_itemindex                  TYPE string
        ev_itemindexstring            TYPE string
        ev_billofmaterial             TYPE string
        ev_billofmaterialcategory     TYPE string
        ev_billofmaterialvariantusage TYPE string
        ev_material                   TYPE string
        ev_plant                      TYPE string
        ev_salesorder                 TYPE string
        ev_salesorderitem             TYPE string
        ev_requiredquantity           TYPE string.

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

    METHODS call_api_line_mbom_kbom
      IMPORTING
        iv_quant_before           TYPE decfloat34
        iv_salesorder             TYPE string
        iv_salesorderitem         TYPE string
        iv_billofmaterial         TYPE string
        iv_billofmaterialcategory TYPE string
        iv_material               TYPE string
        iv_plant                  TYPE string
      CHANGING
        cs_result                 TYPE zce_zbom_item.

    METHODS call_api_head_kbom
      IMPORTING
                is_result       TYPE zce_zbom_item
      EXPORTING
                ev_error_flag   TYPE abap_boolean
      RETURNING VALUE(rv_quant) TYPE string.

    METHODS call_api_filter
      IMPORTING
                iv_endpoint             TYPE string
      EXPORTING ev_rc                   TYPE i
      RETURNING VALUE(rv_result_filter) TYPE string.

    METHODS call_api_item_kbom
      IMPORTING
                is_result       TYPE zce_zbom_item
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
ENDCLASS.



CLASS ZCL_ZBOM_ITEM_CE IMPLEMENTATION.


  METHOD get_tree_view.
    DATA: lv_tree    TYPE string,
          lt_counter TYPE TABLE OF i WITH DEFAULT KEY,
          lv_level   TYPE i,
          lv_idx     TYPE i.

    "Init counter table với 10 level
    DO 10 TIMES.
      APPEND 0 TO lt_counter.
    ENDDO.

    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      lv_level = <lfs_result>-BomExplosionLevel + 1.  "← +1 vì level 0 = cấp 1

      "Reset tất cả level con khi lên level cha
      lv_idx = lv_level + 1.
      WHILE lv_idx <= 10.
        lt_counter[ lv_idx ] = 0.
        ADD 1 TO lv_idx.
      ENDWHILE.

      "Tăng counter của level hiện tại
      lt_counter[ lv_level ] = lt_counter[ lv_level ] + 1.

      "Build tree string
      CLEAR lv_tree.
      DO lv_level TIMES.
        lv_idx = sy-index.
        IF lv_idx = 1.
*          lv_tree = |{ lt_counter[ lv_idx ] }|.
          lv_tree = iv_tabix.
          CONDENSE: lv_tree NO-GAPS.
        ELSE.
          lv_tree = |{ lv_tree }.{ lt_counter[ lv_idx ] }|.
        ENDIF.
      ENDDO.

      <lfs_result>-TreeView = lv_tree.
    ENDLOOP.
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


  METHOD call_api_head_kbom.
****************************************************************************************************************************************************************************************************************
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
      SELECT SINGLE FROM ztb_zbom_explode
      FIELDS quantity
      WHERE bill_of_material = @iv_billofmaterial AND
            bill_of_material_category = @iv_billofmaterialcategory AND
            material = @iv_material AND
            plant = @iv_plant AND
            sales_order = @iv_salesorder AND
            sales_order_item = @iv_salesorderitem AND
            uname = @sy-uname
      INTO @DATA(lv_quantity).
      IF sy-subrc = 0.
      ELSE.
        lv_quantity = 1.
      ENDIF.
      IF cs_result-BomExplosionLevel = '01'.
        cs_result-BomCompQuant = lv_quant_item * iv_quant_before * lv_quantity / lv_quant_head.
      ELSE.
        cs_result-BomCompQuant = lv_quant_item * iv_quant_before / lv_quant_head.
      ENDIF.
    ENDIF.
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


  METHOD get_fields_key.
    " Read filter conditions if provided
    DATA(lo_filter)               = io_request->get_filter( ).
    TRY.
        DATA(lt_filters) = lo_filter->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        "handle exception
    ENDTRY.
**********************************************************************
*Version 2
    CHECK lt_filters IS NOT INITIAL.

*    DATA(lr_material) = get_material_range( it_filters = lt_filters ).
*    DATA(lr_plant) = get_plant_range( it_filters = lt_filters ).
*    DATA(lr_salesorder) = get_so_range( it_filters = lt_filters ).
*    DATA(lr_salesorderitem) = get_soitem_range( it_filters = lt_filters ).
*    DATA(lr_bomvariantusage) = get_bomvariantusage_range( it_filters = lt_filters ).

    "Get BILLOFMATERIAL
    READ TABLE lt_filters INTO DATA(ls_bom) WITH KEY name = 'BILLOFMATERIAL'.
    CHECK sy-subrc = 0.
    SORT ls_bom-range BY low.

    "Get BILLOFMATERIALCATEGORY
    READ TABLE lt_filters INTO DATA(ls_bomcategory) WITH KEY name = 'BILLOFMATERIALCATEGORY'.
    IF sy-subrc = 0.
      DATA(lv_bom_cat) = ls_bomcategory-range[ 1 ]-low.
    ENDIF.

    "Get MATERIAL, PLANT, SALESORDER, SALESORDERITEM
    IF lv_bom_cat = 'M'.
      "Processing key fields MBOM
      SELECT DISTINCT a~BillOfMaterial,
                      a~material,
                      a~plant
      FROM I_MaterialBOMLink AS a
      WHERE a~BillOfMaterial IN @ls_bom-range
            AND a~BillOfMaterialVariant = '01' "NinhNH Updated
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
*      APPEND INITIAL LINE TO rt_key_field ASSIGNING FIELD-SYMBOL(<lfs_key_field>).
      ev_billofmaterial = ls_bom_range-low.
      ev_billofmaterialcategory = lv_bom_cat.
      ev_billofmaterialvariantusage = lv_bom_variant_usage.

      IF ev_billofmaterialcategory = 'M'.
        READ TABLE lt_bom_m INTO DATA(ls_bom_m) WITH KEY BillOfMaterial = ev_billofmaterial.
        IF sy-subrc = 0.
          ev_material = ls_bom_m-Material.
          ev_plant = ls_bom_m-Plant.
        ENDIF.
        ev_salesorder = ''.
        ev_salesorderitem = '000000'.
      ELSEIF ev_billofmaterialcategory = 'K'.
        READ TABLE lt_bom_k INTO DATA(ls_bom_k) WITH KEY BillOfMaterial = ev_billofmaterial.
        IF sy-subrc = 0.
          ev_material = ls_bom_k-Material.
          ev_plant = ls_bom_k-Plant.
          ev_salesorder = ls_bom_k-salesorder.
          ev_salesorderitem = ls_bom_k-SalesOrderItem.
        ENDIF.
      ENDIF.

      IF ev_billofmaterialcategory = 'M'.
        ev_requiredquantity = 1000.
      ELSEIF ev_billofmaterialcategory = 'K'.
        READ TABLE lt_quantity INTO DATA(ls_quantity) WITH KEY BillOfMaterial = ev_billofmaterial.
        IF sy-subrc = 0.
          ev_requiredquantity = ls_quantity-OrderQuantity.
        ENDIF.
        IF ev_requiredquantity = 0.
          ev_requiredquantity = 1000.
        ENDIF.
      ENDIF.
      CONDENSE: ev_requiredquantity NO-GAPS.

      ev_itemindexstring  =  |{ ev_billofmaterial }~#%| &&
                                          |{ ev_billofmaterialcategory }~#%| &&
                                          |{ ev_billofmaterialvariantusage }~#%| &&
                                          |{ ev_material }~#%| &&
                                          |{ ev_plant }~#%| &&
                                          |{ ev_salesorder }~#%| &&
                                          |{ ev_salesorderitem }| &&
                                          |{ ev_requiredquantity }|.
    ENDLOOP.

**********************************************************************
*Version 1
*    LOOP AT lt_filters INTO DATA(ls_filter).
*      CASE ls_filter-name.
*        WHEN 'ITEMINDEX'.
*          ev_itemindex = ls_filter-range[ 1 ]-low.
*        WHEN 'ITEMINDEXSTRING'.
*          ev_itemindexstring = ls_filter-range[ 1 ]-low.
*          SPLIT ev_itemindexstring AT '~#%' INTO
*            ev_billofmaterial
*            ev_billofmaterialcategory
*            ev_billofmaterialvariantusage
*            ev_material
*            ev_plant
*            ev_salesorder
*            ev_salesorderitem.
*
*          DATA(lv_flag_details) = 'X'.
*        WHEN 'BILLOFMATERIAL'.
*          ev_billofmaterial = ls_filter-range[ 1 ]-low.
*        WHEN 'BILLOFMATERIALCATEGORY'.
*          ev_billofmaterialcategory = ls_filter-range[ 1 ]-low.
*        WHEN 'BILLOFMATERIALVARIANTUSAGE'.
*          ev_billofmaterialvariantusage = ls_filter-range[ 1 ]-low.
*        WHEN 'MATERIAL'.
*          ev_material = ls_filter-range[ 1 ]-low.
*        WHEN 'PLANT'.
*          ev_plant = ls_filter-range[ 1 ]-low.
*        WHEN 'SALESORDER'.
*          ev_salesorder = ls_filter-range[ 1 ]-low.
*        WHEN 'SALESORDERITEM'.
*          ev_salesorderitem = ls_filter-range[ 1 ]-low.
*        WHEN OTHERS.
*      ENDCASE.
*    ENDLOOP.
*
*    IF lv_flag_details = 'X'.
*    ELSE.
*      ev_itemindexstring = |{ ev_billofmaterial }~#%| &&
*                           |{ ev_billofmaterialcategory }~#%| &&
*                           |{ ev_billofmaterialvariantusage }~#%| &&
*                           |{ ev_material }~#%| &&
*                           |{ ev_plant }~#%| &&
*                           |{ ev_salesorder }~#%| &&
*                           |{ ev_salesorderitem }|.
*    ENDIF.
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
*    DATA: lt_paged  LIKE it_result,
*          lv_total  TYPE int8.
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


  METHOD if_rap_query_provider~select.
    DATA: lv_billofmaterial             TYPE string,
          lv_billofmaterialcategory     TYPE string,
          lv_billofmaterialvariantusage TYPE string,
          lv_material                   TYPE string,
          lv_plant                      TYPE string,
          lv_salesorder                 TYPE string,
          lv_salesorderitem             TYPE string,
          lv_itemindex                  TYPE string,
          lv_itemindexstring            TYPE string,
          lv_requiredquantity           TYPE string,

          lt_result                     TYPE tt_res.

    "Step 1: Get keys field
    get_fields_key(
      EXPORTING
        io_request                    = io_request
      IMPORTING
        ev_itemindex                  = lv_itemindex
        ev_itemindexstring            = lv_itemindexstring
        ev_billofmaterial             = lv_billofmaterial
        ev_billofmaterialcategory     = lv_billofmaterialcategory
        ev_billofmaterialvariantusage = lv_billofmaterialvariantusage
        ev_material                   = lv_material
        ev_plant                      = lv_plant
        ev_salesorder                 = lv_salesorder
        ev_salesorderitem             = lv_salesorderitem
        ev_requiredquantity            = lv_requiredquantity
    ).

    "Step 2: Processing API to get result data into internal table
    DATA(lt_result_tmp) = processing_api(
                            iv_billofmaterial             = lv_billofmaterial
                            iv_billofmaterialcategory     = lv_billofmaterialcategory
                            iv_billofmaterialvariantusage = lv_billofmaterialvariantusage
                            iv_material                   = lv_material
                            iv_plant                      = lv_plant
                            iv_salesorder                 = lv_salesorder
                            iv_salesorderitem             = lv_salesorderitem
                            iv_itemindexstring            = lv_itemindexstring
                            iv_requiredquantity           = lv_requiredquantity
                          ).
    "Step 3: Append into lt_result and Modify result
    get_tree_view(
      EXPORTING
        iv_tabix = 1
      CHANGING
        ct_result = lt_result_tmp
  ).
    APPEND LINES OF lt_result_tmp TO lt_result.
    CLEAR: lt_result_tmp[].
    IF lv_itemindex IS NOT INITIAL.
      DELETE lt_result WHERE itemindex <> lv_itemindex.
    ENDIF.

    "Step 4: Apply paging
    get_result_paging(
      it_result   = lt_result
      io_request  = io_request
      io_response = io_response
    ).
  ENDMETHOD.


  METHOD processing_api.
****************************************************************************************************************************************************************************************************************
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
        iv_requiredquantity           = iv_requiredquantity
      ).
    ELSE.
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
      "Processing with KBom
      processing_kbom2(
          EXPORTING
            iv_billofmaterial             = iv_billofmaterial
            iv_billofmaterialcategory     = iv_billofmaterialcategory
            iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
            iv_material                   = iv_material
            iv_plant                      = iv_plant
            iv_salesorder                 = iv_salesorder
            iv_salesorderitem             = iv_salesorderitem
            iv_itemindexstring            = iv_itemindexstring
            iv_requiredquantity            = iv_requiredquantity
          CHANGING
            ct_result = rt_result
        ).
      """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
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
*          CHANGING
*            ct_result = rt_result
*        ).
    ENDIF.
  ENDMETHOD.


  METHOD processing_kbom.
    "1."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Get quantity
    SELECT SINGLE FROM ztb_zbom_explode
    FIELDS quantity
    WHERE bill_of_material = @iv_billofmaterial AND
          bill_of_material_category = @iv_billofmaterialcategory AND
          material = @iv_material AND
          plant = @iv_plant AND
          sales_order = @iv_salesorder AND
          sales_order_item = @iv_salesorderitem AND
          uname = @sy-uname
    INTO @DATA(lv_quantity).
    IF sy-subrc = 0.
    ELSE.
      lv_quantity = 1.
    ENDIF.

    "2."""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Select Recursive
    Recursive_data(
        EXPORTING
             iv_material               = CONV string( iv_material )
             iv_plant                  = CONV string( iv_plant )
             iv_salesorder             = CONV string( iv_salesorder )
             iv_salesorderitem         = CONV string( iv_salesorderitem )
             iv_itemindexstring        = CONV string( iv_itemindexstring )
             iv_quantity               = CONV i( lv_quantity )
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
        lv_quant_before = 1.
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
          LOOP AT lt_elements INTO DATA(lv_elements).
            DATA(lv_quant_udt) = get_tag_value(
                                   iv_xml = lv_elements
                                   iv_tag = 'd:BillOfMaterialItemQuantity'
                                 ).
            DATA(lv_quant_udt_num) = CONV decfloat34( lv_quant_udt ).
            IF <lfs_result_present>-BomExplosionLevel = '01'.
              lv_quant_udt_num = lv_quant_udt_num * lv_quant_before * lv_quantity.
            ELSE.
              lv_quant_udt_num = lv_quant_udt_num * lv_quant_before.
            ENDIF.
            <lfs_result_present>-BomCompQuant = lv_quant_udt_num.
          ENDLOOP.
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


  METHOD processing_kbom2.
    DATA: lv_product TYPE matnr VALUE '300004388',
          lv_plant   TYPE werks_d VALUE '6711',
          lv_bom_cat TYPE c VALUE 'K',
          lv_so      TYPE vbeln VALUE '0010000010',
          lv_so_item TYPE n LENGTH 6 VALUE '000010'.
    DATA: lv_quant_before TYPE p.

*    DATA: lv_bomlevel TYPE n LENGTH 2 VALUE '00'.

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

*        " 1. Check material có tồn tại ở plant không
*        SELECT SINGLE *
*          FROM i_product                    " hoặc i_productplant
*          inner join i_plant
*
*          WHERE Product = @lv_product
*            AND Plant = @lv_plant
*          INTO @DATA(ls_marc).
**        out->write( |MARC found: { sy-subrc }| ).

        " 2. Check BOM link có đúng SO không
        SELECT *
          FROM i_salesorderbomlink
          WHERE material               = @lv_product
            AND plant                  = @lv_plant
            AND billofmaterialcategory = 'K'
*            AND SalesOrder = @lv_so
*            AND SalesOrderItem = @lv_so_item
          INTO TABLE @DATA(lt_bom_links).
*        out->write( lt_bom_links ).
        CHECK sy-subrc = 0.
*        " 3. Check BOM header tồn tại không
        SELECT  *
          FROM i_salesorderbomheaderdex
          WHERE billofmaterial         = @ls_bom_key-billofmaterial
            AND billofmaterialcategory = 'K'
          INTO TABLE @DATA(ls_bom_hdr).
**        out->write( |BOM HDR: { sy-subrc }| ).
*        out->write( ls_bom_hdr ).

        READ ENTITIES OF I_SalesOrderBillOfMaterialTP_2
          ENTITY SalesBillOfMaterial            " ← đúng theo Content Assist
          EXECUTE ExplodeBOM
          FROM VALUE #( (
              %key-BillOfMaterial            = ls_bom_key-billofmaterial
              %key-BillOfMaterialCategory    = lv_bom_cat
              %key-BillOfMaterialVariant     = ls_bom_key-billofmaterialvariant
*        %key-BillOfMaterialVersion     = ''
              %key-EngineeringChangeDocument = ''
              %key-Material                  = lv_product
              %key-Plant                     = lv_plant

              " Ctrl+Space sau %param- để xem đúng fields
              %param-BOMExplosionDate           = cl_abap_context_info=>get_system_date( )
              %param-BOMExplosionIsMultilevel   = abap_true
              %param-RequiredQuantity           = lv_requiredquantity
              %param-BOMExplosionApplication    = 'PP01'
*          %param-EngineeringChangeDocument  = ''
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
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD processing_mbom.
************************************************************************************************
* Version 2
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
    DATA(lv_xml_mbom) = zcl_call_api=>call_api(
      iv_body        = ''
      iv_endpoint    = lv_endpoint_mbom
      iv_method      = 'GET'
      iv_contenttype = 'application/xml'
    ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Parse data into itab result
    IF zcl_call_api=>code = '200'.
      DATA(lt_elements) = extract_elements(
        iv_xml = lv_xml_mbom
        iv_tag = 'd:element'
      ).
      LOOP AT lt_elements INTO DATA(lv_elem_xml).
        APPEND INITIAL LINE TO rt_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
        <lfs_result>-billofmaterial = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:Bill_Of_Material_Root' ).
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
        <lfs_result>-billofmaterialvariant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant' ).
        <lfs_result>-billofmaterialversion = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_version' ).
        <lfs_result>-billofmaterialitemnodenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_node' ).
        <lfs_result>-headerchangedocument = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bom_change_number' ).
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

************************************************************************************************
* Version 1
*    DATA: lv_quantity TYPE string.
*
*    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    "Prepare Data
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
*
*    DATA(lv_date_time) = |{ cl_abap_context_info=>get_system_date( ) DATE = ISO }T00:00:00|.
*    " URL-encode the date: 2026-03-06T00:00:00 -> datetime%272026-03-06T00%3A00%3A00%27
*    DATA(lv_date_enc) = |datetime%27{ lv_date_time }%27|.
*    REPLACE ALL OCCURRENCES OF ':' IN lv_date_enc WITH '%3A'.
*
*
*    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    "Get endpoint
*    DATA(lv_endpoint_mbom) =
*      '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2/ExplodeBOM?' &&
*      |Material=%27{ iv_material }%27&|          && "1. Material - Mandatory
*      |Plant=%27{ iv_plant }%27&|                && "2. Plant - Optional
*      |BillOfMaterialVariant=%27%27&|            && "3. BillOfMaterialVariant - Optional
*      |BOMExplosionApplication=%27PP01%27&|      && "4. BOMExplosionApplication - Mandatory
*      |RequiredQuantity={ lv_quantity }m&|                     && "5. Required Quantity - Mandatory --> Không gán cứng - Check
*      |EngineeringChangeDocument=%27%27&|        && "6. EngineeringChangeDocument - Optional
*      |BOMExplosionIsLimited=false&|             && "7. BOMExplosionIsLimited - Mandatory
*      |BOMItmQtyIsScrapRelevant=%27%27&|         && "8. BOMItmQtyIsScrapRelevant - Optional
*      |BillOfMaterialItemCategory=%27%27&|       && "9. BillOfMaterialItemCategory - Optional
*      |BOMExplosionAssembly=%27%27&|             && "10. BOMExplosionAssembly - Optional
*      |BOMExplosionDate={ lv_date_enc }&|        && "11. BOMExplosionDate - Mandatory
*      |BOMExplosionLevel=0m&|                    && "12. BOMExplosionLevel - Mandatory
*      |BOMExplosionIsMultilevel=true&|           && "13. BOMExplosionIsMultilevel - Mandatory
*      |MaterialProvisionFltrType=%27%20%27&|     && "14. MaterialProvisionFltrType - Optional
*      |SparePartFltrType=%27%20%27&|              && "15. SparePartFltrType - Optional
*      |BillOfMaterial=%27{ iv_billofmaterial }%27&|         && "Key Header
*      |BillOfMaterialCategory=%27M%27&|          && "Key Header
*      |BillOfMaterialVersion=%27%27|.              "Key Header
*
*    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    " Call API - uses your existing zcl_call_api utility
*    DATA(lv_xml_mbom) = zcl_call_api=>call_api(
*      iv_body        = ''
*      iv_endpoint    = lv_endpoint_mbom
*      iv_method      = 'GET'
*      iv_contenttype = 'application/xml'
*    ).
*
*    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    "Parse data into itab result
*    IF zcl_call_api=>code = '200'.
*      DATA(lt_elements) = extract_elements(
*        iv_xml = lv_xml_mbom
*        iv_tag = 'd:element'
*      ).
*      LOOP AT lt_elements INTO DATA(lv_elem_xml).
*
*        APPEND INITIAL LINE TO rt_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
*        <lfs_result>-billofmaterial = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:Bill_Of_Material_Root' ).
*        <lfs_result>-billofmaterialcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_category' ).
*        <lfs_result>-material = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
*        <lfs_result>-billofmaterialvariantusage = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant_usage' ).
*        <lfs_result>-salesorder = ''.
*        <lfs_result>-salesorderitem = '000000'.
*
*        <lfs_result>-itemindex = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_index' ).
*        <lfs_result>-itemindexstring = iv_itemindexstring.
*
*        "Field 1 - Component
*        <lfs_result>-billofmaterialcomponent = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_component' ).
*        <lfs_result>-bomexplosionlevel = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_explosion_level' ).
*        <lfs_result>-bomhhdrmatlhiernode = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
*
*        "Field 2 - Component Description
*        <lfs_result>-componentdescription = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_component_description' ).
*
*        "Field 3 - Component Quantity (Component UoM)
*        <lfs_result>-bomcompquant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_comp_quant' ).
*
*        "Field 4 - Item Category
*        <lfs_result>-billofmaterialitemcategory = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_category' ).
*
*        "Field 5 - Item Number
*        <lfs_result>-billofmaterialitemnumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_item_number' ).
*
*        "Field 6 - Assembly Indicator
*        DATA(lv_assy) = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:assembly_indicator' ).
*        <lfs_result>-isassembly = COND #( WHEN lv_assy = 'true' THEN abap_true ELSE abap_false ).
*
*        "Field 7 - Material Type
*        <lfs_result>-materialtype = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:material_type' ).
*
*        "Field 8 - Plant - Header Key
*        <lfs_result>-plant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:plant' ).
*
*        "Field 9 - Base UoM
*        <lfs_result>-billofmaterialitemunit = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:base_uom' ).
*
*        "Field 10 - Maintenance Status
*        <lfs_result>-maintenancestatus = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:maintenance_status' ).
*
*        "Field 11 - Valid From
*        DATA: lv_start_date TYPE char10.
*        lv_start_date = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:validity_start_date' ).
*        REPLACE ALL OCCURRENCES OF '-' IN lv_start_date WITH ''.
*        <lfs_result>-validitystartdate = lv_start_date.
*
*        "Field 12 - Change Number
*        <lfs_result>-changenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:change_number' ).
*
*        "Field 13 - Created On
*        DATA: lv_created_on TYPE char10.
*        lv_created_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:record_creation_date' ).
*        REPLACE ALL OCCURRENCES OF '-' IN lv_created_on WITH ''.
*        <lfs_result>-createdon = lv_created_on.
*
*        "Field 14 - Created By
*        <lfs_result>-createdby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:created_by_user' ).
*
*        "Field 15 - Changed On
*        DATA: lv_changed_on TYPE char10.
*        lv_changed_on = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_change_date' ).
*        REPLACE ALL OCCURRENCES OF '-' IN lv_changed_on WITH ''.
*        <lfs_result>-changedon = lv_changed_on.
*
*        "Field 16 - Changed By
*        <lfs_result>-changedby = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:last_changed_by_user' ).
*
*        "Field 17 - Item Spare Part Indicator
*        <lfs_result>-isbomitemsparepart = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:is_b_o_m_item_spare_part' ).
*
*        <lfs_result>-billofmaterialvariant = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bill_of_material_variant' ).
*        <lfs_result>-billofmaterialversion = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:b_o_m_version' ).
*        <lfs_result>-billofmaterialitemnodenumber = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:item_node' ).
*        <lfs_result>-headerchangedocument = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bom_change_number' ).
*      ENDLOOP.
*
**      "Get result header - LV0 into index 1 of internal table
**      get_mbom_result_lv0(
**        EXPORTING
**          iv_material                   = iv_material
**          iv_billofmaterial             = iv_billofmaterial
**          iv_billofmaterialcategory     = iv_billofmaterialcategory
**          iv_plant                      = iv_plant
**          iv_billofmaterialvariantusage = iv_billofmaterialvariantusage
**          iv_itemindexstring            = iv_itemindexstring
**          iv_salesorder                 = iv_salesorder
**          iv_salesorderitem             = iv_salesorderitem
**          iv_xml                        = lv_xml_mbom
**          iv_quantity                   = lv_quantity
**        CHANGING
**          ct_result                     = rt_result
**      ).
*    ENDIF.
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
*Field 15 - Changed O
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
        <lfs_result>-headerchangedocument = get_tag_value( iv_xml = lv_elem_xml iv_tag = 'd:bom_change_number' ).
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

*        <lfs_item>-BillOfMaterialItemQuantity = <lfs_item>-BillOfMaterialItemQuantity / ls_hdr-BOMHeaderQuantityInBaseUnit.
        <lfs_result>-BomCompQuant = iv_quantity * <lfs_item>-BillOfMaterialItemQuantity.

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
ENDCLASS.
