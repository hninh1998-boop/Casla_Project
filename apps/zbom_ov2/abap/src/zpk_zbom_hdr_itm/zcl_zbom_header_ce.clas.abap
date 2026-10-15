CLASS zcl_zbom_header_ce DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-DATA: mv_quantity TYPE decfloat16 VALUE '1'.

    INTERFACES if_rap_query_provider .

    CLASS-METHODS class_constructor .

    METHODS select
      IMPORTING
        !io_request  TYPE REF TO if_rap_query_request
        !io_response TYPE REF TO if_rap_query_response .

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF lty_requested_elements,
        requested_element            TYPE string,
        requested_element_with_table TYPE string,
      END OF lty_requested_elements .
    TYPES:
      "! Range option with the semantics of selection table criteria (see ABAP Keyword Documentation on "<em>SELECT-OPTIONS</em>" for allowed values for each component)
      BEGIN OF ty_range_option,
        sign   TYPE c LENGTH 1,
        option TYPE c LENGTH 2,
        low    TYPE string,
        high   TYPE string,
      END OF ty_range_option .
    TYPES:
      "! Ranges-table-compatible format (see ABAP Keyword Documentation for "TYPES - RANGE OF")
      tt_range_option TYPE STANDARD TABLE OF ty_range_option WITH EMPTY KEY .
    TYPES:
      BEGIN OF ty_name_range_pairs,
        name  TYPE string,
        range TYPE tt_range_option,
      END OF ty_name_range_pairs .
    TYPES:
      "! List of range tables along with the element that they refer to
      tt_name_range_pairs TYPE STANDARD TABLE OF ty_name_range_pairs WITH EMPTY KEY .
    TYPES:
      ltt_requested_elements TYPE STANDARD TABLE OF lty_requested_elements WITH EMPTY KEY .
    TYPES:
      lt_requested_elements TYPE STANDARD TABLE OF string .
    TYPES:
      view_char TYPE c LENGTH 19 .

    CLASS-DATA:
      mt_materialbomlink_dd03nd TYPE cl_abap_structdescr=>component_table.
    CLASS-DATA:
      mt_salesorderbomlink_dd03nd TYPE cl_abap_structdescr=>component_table .
    CLASS-DATA:
      mt_proddesc_dd03nd TYPE cl_abap_structdescr=>component_table.
    CLASS-DATA:
      mt_plantdesc_dd03nd TYPE cl_abap_structdescr=>component_table.
    CLASS-DATA:
      mt_bomusage_dd03nd TYPE cl_abap_structdescr=>component_table.
    CLASS-DATA:
      mt_producttype_dd03nd TYPE cl_abap_structdescr=>component_table.
    CLASS-DATA:
      mt_SOSCHEDULELINE_dd03nd TYPE cl_abap_structdescr=>component_table.


    METHODS sorting
      IMPORTING
        !io_request          TYPE REF TO if_rap_query_request
        !req_elem_with_table TYPE ltt_requested_elements
        !req_elem_final      TYPE lt_requested_elements
      EXPORTING
        !sort_string         TYPE string .
    METHODS grouping
      IMPORTING
        !io_request          TYPE REF TO if_rap_query_request
        !req_elem_with_table TYPE ltt_requested_elements
      EXPORTING
        !grouping            TYPE string .
    METHODS requested_fields
      IMPORTING
        !io_request                TYPE REF TO if_rap_query_request
        !bomcategory               TYPE string
      EXPORTING
        !requested_elements_string TYPE string
        !req_elem_final            TYPE lt_requested_elements
      CHANGING
        !req_elem_with_table       TYPE ltt_requested_elements .
    METHODS where
      IMPORTING
        !filter_range TYPE tt_name_range_pairs
      EXPORTING
        !source_view  TYPE view_char
        !select_from  TYPE string
        !lv_lang      TYPE sy-langu
      CHANGING
        !bomcategory  TYPE string .
    METHODS filtering
      IMPORTING
        !io_request            TYPE REF TO if_rap_query_request
        !source_view           TYPE view_char
        !bomcategory           TYPE string
      EXPORTING
        !sql_filter_esc_quotes TYPE string .

    METHODS get_component_tab
      IMPORTING iv_tab        TYPE string
      RETURNING VALUE(rt_tab) TYPE cl_abap_structdescr=>component_table.
ENDCLASS.



CLASS ZCL_ZBOM_HEADER_CE IMPLEMENTATION.


  METHOD select.
    TYPES: BEGIN OF lty_requested_elements,
             requested_element            TYPE string,
             requested_element_with_table TYPE string,
           END OF lty_requested_elements,
           ltt_requested_elements TYPE STANDARD TABLE OF lty_requested_elements WITH EMPTY KEY.

    DATA lt_explosion                 TYPE STANDARD TABLE OF zce_zbom_header.
    DATA lt_bomexplosion_search       TYPE STANDARD TABLE OF zce_zbom_header.
    DATA lt_req_elem_with_table       TYPE ltt_requested_elements.


    TRY.
        DATA(lt_filter_range) = io_request->get_filter( )->get_as_ranges( abap_true ).
      CATCH cx_rap_query_filter_no_range.
        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( 0 ).
        ENDIF.
        IF io_request->is_data_requested( ).
          io_response->set_data( lt_explosion ).   " sửa ở đây: dùng lt_explosion (đang rỗng) thay vì VALUE #( )
        ENDIF.
        RETURN.
    ENDTRY.

*    "choose data source
    DATA: lv_bomcategory TYPE string.
    where(
      EXPORTING
        filter_range = lt_filter_range
      IMPORTING
        lv_lang      = DATA(lv_lang)
        source_view  = DATA(lv_source_view)
        select_from  = DATA(lv_select_from)
      CHANGING
        bomcategory  = lv_bomcategory
    ).
    IF lv_source_view IS INITIAL.
      IF io_request->is_total_numb_of_rec_requested( ).
        io_response->set_total_number_of_records( 0 ).
      ENDIF.
      IF io_request->is_data_requested( ).
        io_response->set_data( lt_explosion ).   " sửa ở đây tương tự
      ENDIF.
      RETURN.
    ENDIF.

    "handle paging
    DATA(offset_value)   = io_request->get_paging( )->get_offset( ).
    DATA(max_rows_value) = COND #( WHEN io_request->get_paging( )->get_page_size( ) = if_rap_query_paging=>page_size_unlimited THEN 1
                                ELSE io_request->get_paging( )->get_page_size( ) ).

    "requested fields

    requested_fields(
      EXPORTING
        io_request                = io_request
        bomcategory               = lv_bomcategory
      IMPORTING
        req_elem_final            = DATA(lt_req_elem_final)
        requested_elements_string = DATA(lv_requested_elements_string)
      CHANGING
        req_elem_with_table       = lt_req_elem_with_table
    ).
    "handle grouping

    grouping(
      EXPORTING
        io_request          = io_request
        req_elem_with_table = lt_req_elem_with_table
      IMPORTING
        grouping            = DATA(lv_grouping)
    ).
    "handle filter
*    Get all filters as string

    filtering(
      EXPORTING
        io_request            = io_request
        source_view           = lv_source_view
        bomcategory           = lv_bomcategory
      IMPORTING
        sql_filter_esc_quotes = DATA(lv_sql_filter_esc_quotes)
    ).
*    "handle search string
    DATA(lv_search_string) = cl_abap_dyn_prg=>escape_quotes_str( io_request->get_search_expression( )  ).

*    handle sort

    sorting(
      EXPORTING
        io_request          = io_request
        req_elem_final      = lt_req_elem_final
        req_elem_with_table = lt_req_elem_with_table
      IMPORTING
        sort_string         = DATA(lv_sort_string)
    ).


    IF lv_search_string IS INITIAL.
      IF io_request->is_total_numb_of_rec_requested( ).
        TRY.
            SELECT DISTINCT (lv_requested_elements_string)
            FROM (lv_select_from)
            WHERE (lv_sql_filter_esc_quotes)
            GROUP BY (lv_grouping)
*            ORDER BY (lv_sort_string)****Commented
            INTO CORRESPONDING FIELDS OF TABLE @lt_explosion.
            IF sy-subrc IS INITIAL.
**************Remove duplicates based on bom categ., mat., plant, sales order & sales order item***********************************
              SORT lt_explosion.
              DELETE ADJACENT DUPLICATES FROM lt_explosion COMPARING billofmaterialcategory material plant salesorder salesorderitem.
              REPLACE ALL OCCURRENCES OF PCRE  `\w+~ ` IN lv_sort_string WITH ''.
              SELECT *
              FROM @lt_explosion AS i_materialbomlink
              ORDER BY (lv_sort_string)
              INTO TABLE @DATA(lt_explosion_sorted).

              CLEAR lt_explosion[].
              lt_explosion[] = lt_explosion_sorted[].

**************Remove duplicates based on bom categ., mat., plant, sales order & sales order item***********************************

              DATA(lv_result_count) = CONV int8( lines( lt_explosion ) ).
            ENDIF.
            io_response->set_total_number_of_records( iv_total_number_of_records = lv_result_count  ).
          CATCH cx_sy_dynamic_osql_semantics INTO DATA(lx_dynamic_osql_semantic).
          CATCH cx_sy_dynamic_osql_syntax    INTO DATA(lx_dynamic_osql_syntax).
        ENDTRY.
      ENDIF.

      IF io_request->is_data_requested( ).
        TRY.

            "NinhNH added
            IF lv_sql_filter_esc_quotes CS |AND SALESORDER = ' ' AND SALESORDERITEM = '000000'|.
              REPLACE |AND SALESORDER = ' ' AND SALESORDERITEM = '000000'|
                     IN lv_sql_filter_esc_quotes
                     WITH ||.
              DATA(lv_flag_chk) = 'X'.
            ENDIF.
            "End of NinhNH added

            SELECT DISTINCT (lv_requested_elements_string)
            FROM (lv_select_from)
            WHERE (lv_sql_filter_esc_quotes)
            GROUP BY (lv_grouping)
*            ORDER BY (lv_sort_string)
            INTO CORRESPONDING FIELDS OF TABLE @lt_explosion
*            OFFSET @offset_value UP TO @max_rows_value ROWS
            .
            SORT lt_explosion.
            DELETE ADJACENT DUPLICATES FROM lt_explosion COMPARING billofmaterialcategory material plant salesorder salesorderitem.
            REPLACE ALL OCCURRENCES OF PCRE  `\w+~ ` IN lv_sort_string WITH ''.
            SELECT *
            FROM @lt_explosion AS i_materialbomlink
            ORDER BY (lv_sort_string)
            INTO TABLE @lt_explosion_sorted
            OFFSET @offset_value UP TO @max_rows_value ROWS.

            CLEAR lt_explosion[].
            lt_explosion[] = lt_explosion_sorted[].


            "NinhNH added
            IF lv_flag_chk = 'X'.
              io_response->set_total_number_of_records( iv_total_number_of_records = lines( lt_explosion )  ).
            ENDIF.
            "End of NinhNH added


          CATCH cx_sy_dynamic_osql_semantics INTO lx_dynamic_osql_semantic.
          CATCH cx_sy_dynamic_osql_syntax    INTO lx_dynamic_osql_syntax.
        ENDTRY.


        "NinhNH added - 18/03/2026
**        SELECT * FROM ztb_bom_chk8 INTO TABLE @DATA(lt_bom_chk8).
*
*        SELECT a~BillOfMaterial,
*               a~BillOfMaterialCategory,
*               a~material,
*               a~plant,
*               a~BillOfMaterialVariantUsage,
*               a~SalesOrder,
*               a~SalesOrderItem,
*               b~quantity
*          FROM @lt_explosion AS a
*          INNER JOIN ztb_zbom_explode AS b
*            ON  a~BillOfMaterial           = b~bill_of_material
*            AND a~BillOfMaterialCategory  = b~bill_of_material_category
*            AND a~material                   = b~material
*            AND a~plant                      = b~plant
*            AND a~BillOfMaterialVariantUsage = b~bill_of_material_variant_usage
*            AND a~SalesOrder                = b~sales_order
*            AND a~SalesOrderItem           = b~sales_order_item
*          WHERE b~uname = @sy-uname
*          INTO TABLE @DATA(lt_result_chk).
*        LOOP AT lt_explosion ASSIGNING FIELD-SYMBOL(<lfs_explosion>).
*          READ TABLE lt_result_chk INTO DATA(ls_result_chk)
*            WITH KEY billofmaterial = <lfs_explosion>-BillOfMaterial
*                     BillOfMaterialCategory = <lfs_explosion>-BillOfMaterialCategory
*                     material = <lfs_explosion>-material
*                     plant = <lfs_explosion>-plant
*                     BillOfMaterialVariantUsage = <lfs_explosion>-BillOfMaterialVariantUsage
*                     SalesOrder = <lfs_explosion>-SalesOrder
*                     SalesOrderItem = <lfs_explosion>-SalesOrderItem.
*          IF sy-subrc = 0.
*            <lfs_explosion>-RequiredQuantityHeader = ls_result_chk-quantity.
*          ENDIF.
*        ENDLOOP.
        LOOP AT lt_explosion ASSIGNING FIELD-SYMBOL(<lfs_explosion>).
          IF <lfs_explosion>-BillOfMaterialCategory = 'M'.
            <lfs_explosion>-RequiredQuantityHeader = '1000'.
          ELSEIF <lfs_explosion>-BillOfMaterialCategory = 'K'.
            DATA(lv_product) = <lfs_explosion>-Material.
            lv_product = |{ lv_product WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.

            SELECT SINGLE FROM I_SalesOrderItem
            FIELDS OrderQuantity
            WHERE SalesOrder = @<lfs_explosion>-SalesOrder AND
                  SalesOrderItem = @<lfs_explosion>-SalesOrderItem AND
                  Plant = @<lfs_explosion>-Plant AND
                  Product = @lv_product
            INTO @DATA(lv_quantity).
            IF sy-subrc <> 0.
              lv_quantity = 1000.
            ENDIF.
            <lfs_explosion>-RequiredQuantityHeader = lv_quantity.
          ENDIF.
        ENDLOOP.
        "End of NinhNH added - 18/03/2026

        io_response->set_data( lt_explosion ).
      ENDIF.
    ELSE.
      IF io_request->is_data_requested( ).
        TRY.
            SELECT DISTINCT (lv_requested_elements_string)
            FROM (lv_select_from)
            WHERE (lv_sql_filter_esc_quotes)
            GROUP BY (lv_grouping)
*            ORDER BY (lv_sort_string)
            INTO CORRESPONDING FIELDS OF TABLE @lt_explosion.

            SORT lt_explosion.
            DELETE ADJACENT DUPLICATES FROM lt_explosion COMPARING billofmaterialcategory material plant salesorder salesorderitem.
            REPLACE ALL OCCURRENCES OF PCRE  `\w+~ ` IN lv_sort_string WITH ''.
            SELECT *
            FROM @lt_explosion AS i_materialbomlink
            ORDER BY (lv_sort_string)
            INTO TABLE @lt_explosion_sorted.

            CLEAR lt_explosion[].
            lt_explosion[] = lt_explosion_sorted[].
          CATCH cx_sy_dynamic_osql_semantics INTO lx_dynamic_osql_semantic.
          CATCH cx_sy_dynamic_osql_syntax    INTO lx_dynamic_osql_syntax.
        ENDTRY.
        "if search string is not initial, then first find result based on given where condition
        "then find the search string from that list
        FIND ALL OCCURRENCES OF lv_search_string IN TABLE lt_explosion IGNORING CASE RESULTS DATA(lt_search_result).
        IF lt_search_result IS NOT INITIAL.
          LOOP AT lt_search_result ASSIGNING FIELD-SYMBOL(<ls_search_result>).
            APPEND lt_explosion[ <ls_search_result>-line ] TO lt_bomexplosion_search.
          ENDLOOP.
          DELETE ADJACENT DUPLICATES FROM lt_bomexplosion_search COMPARING ALL FIELDS.
          lt_explosion = lt_bomexplosion_search.
          IF io_request->is_total_numb_of_rec_requested( ).
            io_response->set_total_number_of_records( iv_total_number_of_records = lines( lt_explosion ) ).
          ENDIF.
          IF lines( lt_explosion ) > max_rows_value.
            IF offset_value >= 1.

              DELETE lt_explosion FROM 1 TO offset_value.
            ENDIF.
            IF max_rows_value >= 1.
              DELETE lt_explosion FROM ( max_rows_value + 1 ).
            ENDIF.
          ENDIF.

          "NinhNH added - 18/03/2026
*          SELECT a~BillOfMaterial,
*                 a~BillOfMaterialCategory,
*                 a~material,
*                 a~plant,
*                 a~BillOfMaterialVariantUsage,
*                 a~SalesOrder,
*                 a~SalesOrderItem,
*                 b~quantity
*            FROM @lt_explosion AS a
*            INNER JOIN ztb_zbom_explode AS b
*              ON  a~BillOfMaterial           = b~bill_of_material
*              AND a~BillOfMaterialCategory  = b~bill_of_material_category
*              AND a~material                   = b~material
*              AND a~plant                      = b~plant
*              AND a~BillOfMaterialVariantUsage = b~bill_of_material_variant_usage
*              AND a~SalesOrder                = b~sales_order
*              AND a~SalesOrderItem           = b~sales_order_item
*            WHERE b~uname = @sy-uname
*            INTO TABLE @DATA(lt_result_chk_2).
*
*          LOOP AT lt_explosion ASSIGNING <lfs_explosion>.
*            READ TABLE lt_result_chk_2 INTO DATA(ls_result_chk_2)
*              WITH KEY billofmaterial = <lfs_explosion>-BillOfMaterial
*                       BillOfMaterialCategory = <lfs_explosion>-BillOfMaterialCategory
*                       material = <lfs_explosion>-material
*                       plant = <lfs_explosion>-plant
*                       BillOfMaterialVariantUsage = <lfs_explosion>-BillOfMaterialVariantUsage
*                       SalesOrder = <lfs_explosion>-SalesOrder
*                       SalesOrderItem = <lfs_explosion>-SalesOrderItem.
*            IF sy-subrc = 0.
*              <lfs_explosion>-RequiredQuantityHeader = ls_result_chk_2-quantity.
*            ENDIF.
*          ENDLOOP.
          LOOP AT lt_explosion ASSIGNING <lfs_explosion>.
            IF <lfs_explosion>-BillOfMaterialCategory = 'M'.
              <lfs_explosion>-RequiredQuantityHeader = '1000'.
            ELSEIF <lfs_explosion>-BillOfMaterialCategory = 'K'.
              lv_product = <lfs_explosion>-Material.
              lv_product = |{ lv_product WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.

              SELECT SINGLE FROM I_SalesOrderItem
              FIELDS OrderQuantity
              WHERE SalesOrder = @<lfs_explosion>-SalesOrder AND
                    SalesOrderItem = @<lfs_explosion>-SalesOrderItem AND
                    Plant = @<lfs_explosion>-Plant AND
                    Product = @lv_product
              INTO @lv_quantity.
              IF sy-subrc <> 0.
                lv_quantity = 1000.
              ENDIF.
              <lfs_explosion>-RequiredQuantityHeader = lv_quantity.
            ENDIF.
          ENDLOOP.
          "End of NinhNH added - 18/03/2026

          io_response->set_data( lt_explosion ).
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD grouping.
*    Get all grouped data into table
    DATA(lt_grouped_element) = io_request->get_aggregation( )->get_grouped_elements( ).
    DATA lt_grouped_element_final LIKE lt_grouped_element.
    LOOP AT lt_grouped_element ASSIGNING FIELD-SYMBOL(<lv_grouped_element>).
      READ TABLE req_elem_with_table ASSIGNING FIELD-SYMBOL(<ls_req_elem_with_table>) WITH KEY requested_element = <lv_grouped_element>.
      IF sy-subrc IS INITIAL.
        APPEND <ls_req_elem_with_table>-requested_element_with_table TO lt_grouped_element_final .
      ENDIF.
    ENDLOOP.
    grouping = concat_lines_of(  table = lt_grouped_element sep = `, ` ).
  ENDMETHOD.


  METHOD class_constructor.
    mt_materialbomlink_dd03nd =  NEW zcl_zbom_header_ce( )->get_component_tab( iv_tab = 'I_MaterialBOMLink' ).
    mt_salesorderbomlink_dd03nd =  NEW zcl_zbom_header_ce( )->get_component_tab( iv_tab = 'I_SALESORDERBOMLINK' ).
    mt_proddesc_dd03nd =  NEW zcl_zbom_header_ce( )->get_component_tab( iv_tab = 'I_PRODUCTDESCRIPTION' ).
    mt_plantdesc_dd03nd =  NEW zcl_zbom_header_ce( )->get_component_tab( iv_tab = 'I_PLANTSTDVH' ).
    mt_producttype_dd03nd =  NEW zcl_zbom_header_ce( )->get_component_tab( iv_tab = 'I_PRODUCTTYPEVH' ).
    mt_SOSCHEDULELINE_dd03nd =  NEW zcl_zbom_header_ce( )->get_component_tab( iv_tab = 'I_SALESORDERSCHEDULELINE' ).
  ENDMETHOD.


  METHOD get_component_tab.
    DATA(lo_type) = cl_abap_typedescr=>describe_by_name( iv_tab ).
    DATA(lo_struct) = CAST cl_abap_structdescr( lo_type ).
    rt_tab = lo_struct->get_components( ).
  ENDMETHOD.


  METHOD requested_fields.
    DATA(lt_requested_elements) = io_request->get_requested_elements( ).
*    req_elem_final LIKE lt_requested_elements.
    LOOP AT lt_requested_elements INTO DATA(lv_requested_element).
      APPEND INITIAL LINE TO req_elem_with_table ASSIGNING FIELD-SYMBOL(<ls_req_elem_with_table>).
      IF bomcategory EQ 'K'.
        READ TABLE mt_salesorderbomlink_dd03nd INTO DATA(ls_salesorderbomlink_dd03nd) WITH KEY name = lv_requested_element.
        IF sy-subrc IS INITIAL.
          DATA(lv_req_elem_final) = |i_salesorderbomlink~{ lv_requested_element } |.
          APPEND lv_req_elem_final TO req_elem_final.
          <ls_req_elem_with_table> = VALUE #( requested_element = lv_requested_element requested_element_with_table = lv_req_elem_final ).
          CONTINUE.
        ENDIF.

        READ TABLE mt_soscheduleline_dd03nd INTO DATA(ls_soscheduleline_dd03nd) WITH KEY name = lv_requested_element.
        IF sy-subrc IS INITIAL.
          lv_req_elem_final = |I_SALESORDERSCHEDULELINE~{ lv_requested_element } |.
          APPEND lv_req_elem_final TO req_elem_final.
          <ls_req_elem_with_table> = VALUE #( requested_element = lv_requested_element requested_element_with_table = lv_req_elem_final ).
          CONTINUE.
        ENDIF.

      ELSEIF bomcategory EQ 'M'.
        READ TABLE mt_materialbomlink_dd03nd INTO DATA(ls_materialbomlink_dd03nd) WITH KEY name = lv_requested_element.
        IF sy-subrc IS INITIAL.
          lv_req_elem_final = |i_materialbomlink~{ lv_requested_element } |.
          APPEND lv_req_elem_final TO req_elem_final.
          <ls_req_elem_with_table> = VALUE #( requested_element = lv_requested_element requested_element_with_table = lv_req_elem_final ).
          CONTINUE.
        ENDIF.
      ENDIF.

*      READ TABLE mt_bomusage_dd03nd INTO DATA(ls_bomusage_dd03nd) WITH KEY fieldname = lv_requested_element.
*      IF sy-subrc IS INITIAL.
*        lv_req_elem_final = |{ ls_bomusage_dd03nd-strucobjn }~{ lv_requested_element } |.
*        APPEND lv_req_elem_final TO req_elem_final.
*        <ls_req_elem_with_table> = VALUE #( requested_element = lv_requested_element requested_element_with_table = lv_req_elem_final ).
*        CONTINUE.
*      ENDIF.

*I_PRODUCTTYPEVH
      READ TABLE mt_producttype_dd03nd INTO DATA(ls_producttype_dd03nd) WITH KEY name = lv_requested_element.
      IF sy-subrc IS INITIAL.
        lv_req_elem_final = |I_PRODUCT~{ lv_requested_element } |.
        APPEND lv_req_elem_final TO req_elem_final.
        <ls_req_elem_with_table> = VALUE #( requested_element = lv_requested_element requested_element_with_table = lv_req_elem_final ).
        CONTINUE.
      ENDIF.


*I_PLANTSTDVH
      READ TABLE mt_plantdesc_dd03nd INTO DATA(ls_plantdesc_dd03nd) WITH KEY name = lv_requested_element.
      IF sy-subrc IS INITIAL.
        lv_req_elem_final = |I_PLANTSTDVH~{ lv_requested_element } |.
        APPEND lv_req_elem_final TO req_elem_final.
        <ls_req_elem_with_table> = VALUE #( requested_element = lv_requested_element requested_element_with_table = lv_req_elem_final ).
        CONTINUE.
      ENDIF.

*I_PRODUCTDESCRIPTION
      READ TABLE mt_proddesc_dd03nd INTO DATA(ls_proddesc_dd03nd) WITH KEY name = lv_requested_element.
      IF sy-subrc IS INITIAL.
        lv_req_elem_final = |I_PRODUCTDESCRIPTION~{ lv_requested_element } |.
        APPEND lv_req_elem_final TO req_elem_final.
        <ls_req_elem_with_table> = VALUE #( requested_element = lv_requested_element requested_element_with_table = lv_req_elem_final ).
        CONTINUE.
      ENDIF.
    ENDLOOP.
    requested_elements_string  = concat_lines_of( table = req_elem_final sep = `, ` ).
  ENDMETHOD.


  METHOD sorting.
*    Get all sort data in a table
    DATA(lt_sort_table) = VALUE string_table(
     FOR sort_element IN io_request->get_sort_elements( )
       ( sort_element-element_name && COND #( WHEN sort_element-descending = abap_true THEN ` descending` ELSE ` ascending` )  )
     ).
    DATA sort_table_final LIKE lt_sort_table.
    LOOP AT lt_sort_table ASSIGNING FIELD-SYMBOL(<lv_sort_table>).
      DATA(lv_fieldname) = COND #( WHEN <lv_sort_table> CS 'descending' THEN substring_before( val = <lv_sort_table> sub = ' descending' )
                                                                        ELSE substring_before( val = <lv_sort_table> sub = ' ascending' ) ).
      READ TABLE req_elem_with_table ASSIGNING FIELD-SYMBOL(<ls_req_elem_with_table>) WITH KEY requested_element = lv_fieldname.
      IF sy-subrc IS INITIAL.
        DATA(lv_sort_order) = COND #( WHEN <lv_sort_table> CS 'descending' THEN 'descending' ELSE 'ascending' ).
*        DATA(lv_ele_name_with_order) = | { <ls_req_elem_with_table>-requested_element_with_table } { lv_sort_order } |.
        DATA(lv_ele_name_with_order) = | { <ls_req_elem_with_table>-requested_element } { lv_sort_order } |.
        APPEND lv_ele_name_with_order TO sort_table_final.
      ELSE.
        DELETE lt_sort_table INDEX sy-tabix + 1.
      ENDIF.
    ENDLOOP.
    sort_string  = COND #( WHEN lt_sort_table IS INITIAL THEN concat_lines_of( table = req_elem_final sep = `, ` )
                                                                     ELSE concat_lines_of( table = sort_table_final sep = `, ` )
                                                                  ) .
  ENDMETHOD.


  METHOD where.
    "choose data source
    lv_lang = sy-langu.
    TRY.
        bomcategory = filter_range[ name = 'BILLOFMATERIALCATEGORY' ]-range[ 1 ]-low.
      CATCH cx_sy_itab_line_not_found INTO DATA(lx_itab_line_not_found).

    ENDTRY.

    IF bomcategory EQ 'K'.
      source_view = 'I_SalesOrderBOMLink'."'C_OrderBOMExplosionList'."
    ELSEIF bomcategory EQ 'M'.
      source_view = 'I_MaterialBOMLink'."'C_BOMExplosionList'."
    ENDIF.
*    CONCATENATE ' LEFT OUTER JOIN I_BillOfMaterialUsage ON' source_view INTO DATA(lv_join_usage_desc) SEPARATED BY space.
*    lv_join_usage_desc = lv_join_usage_desc && '~billofmaterialvariantusage = I_BillOfMaterialUsage~billofmaterialvariantusage AND I_BillOfMaterialUsage~language = @lv_lang'.
    CONCATENATE  ' LEFT OUTER JOIN I_ProductDescription ON' source_view INTO DATA(lv_join_prod_desc) SEPARATED BY space.
    lv_join_prod_desc  = lv_join_prod_desc && '~material = I_ProductDescription~product AND I_ProductDescription~language = @lv_lang'.
    CONCATENATE  ' LEFT OUTER JOIN I_PlantStdVH ON ' source_view INTO DATA(lv_join_plant_desc) SEPARATED BY space.
    lv_join_plant_desc =  lv_join_plant_desc && '~plant = I_PlantStdVH~plant '.
    CONCATENATE  ' LEFT OUTER JOIN  I_Product ON' source_view INTO DATA(lv_join_prod) SEPARATED BY space.
    lv_join_prod       = lv_join_prod && '~material = I_Product~product '.
    select_from     = |{ source_view } { lv_join_plant_desc } { lv_join_prod_desc } { lv_join_prod } |.

    IF bomcategory EQ 'K'.
      DATA(lv_join_scheduleline) =
      |LEFT OUTER JOIN I_SalesOrderScheduleLine| &&
      | ON I_SalesOrderBOMLink~SalesOrder = I_SalesOrderScheduleLine~SalesOrder| &&
      | AND I_SalesOrderBOMLink~SalesOrderItem = I_SalesOrderScheduleLine~SalesOrderItem|.

      select_from = |{ select_from } { lv_join_scheduleline }|.
    ENDIF.
  ENDMETHOD.


  METHOD filtering.
*    Get all filters as string
    sql_filter_esc_quotes = cl_abap_dyn_prg=>escape_quotes_str( io_request->get_filter(  )->get_as_sql_string(  ) ).
*    REPLACE  ALL OCCURRENCES OF 'BILLOFMATERIALVARIANTUSAGE' IN sql_filter_esc_quotes WITH source_view && '~BILLOFMATERIALVARIANTUSAGE'.
    REPLACE  ALL OCCURRENCES OF 'PLANT ' IN sql_filter_esc_quotes WITH source_view && '~PLANT '.
    REPLACE  ALL OCCURRENCES OF source_view && '~PLANTNAME' IN sql_filter_esc_quotes WITH 'I_PlantStdVH' && '~PLANTNAME'.
*    REPLACE  ALL OCCURRENCES OF source_view && '~BILLOFMATERIALVARIANTUSAGEDESC' IN sql_filter_esc_quotes WITH 'I_BILLOFMATERIALUSAGE' && '~BILLOFMATERIALVARIANTUSAGEDESC'.
*  SalesOrder and SalesOrderItem empty in case of Material BOM
    IF bomcategory = 'M'.
      REPLACE ALL OCCURRENCES OF `SALESORDERITEM = '000000' AND SALESORDER = ' ' AND ` IN sql_filter_esc_quotes WITH ''.
    ELSEIF bomcategory = 'K'.
      IF sql_filter_esc_quotes CS 'SALESORDER'.
        REPLACE ALL OCCURRENCES OF 'SALESORDER' IN sql_filter_esc_quotes WITH 'I_SalesOrderBOMLink~SALESORDER'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD if_rap_query_provider~select.
    select( EXPORTING io_request = io_request io_response = io_response ).
  ENDMETHOD.
ENDCLASS.
