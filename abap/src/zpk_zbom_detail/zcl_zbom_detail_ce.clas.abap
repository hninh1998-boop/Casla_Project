CLASS zcl_zbom_detail_ce DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES tt_zce_zbom_detail TYPE STANDARD TABLE OF zce_zbom_detail WITH DEFAULT KEY.

    METHODS explode_header_for_export
      IMPORTING iv_billofmaterial             TYPE string
                iv_billofmaterialcategory     TYPE string
                iv_billofmaterialvariantusage TYPE string
                iv_material                   TYPE string
                iv_plant                      TYPE string
                iv_salesorder                 TYPE string
                iv_salesorderitem             TYPE string
                iv_requiredquantity           TYPE string
                iv_tabix                      TYPE sy-tabix DEFAULT 1
      RETURNING VALUE(rt_result)              TYPE tt_zce_zbom_detail.

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
           ry_plant             TYPE RANGE OF werks_d,
           ry_component         TYPE RANGE OF zce_zbom_detail-BillOfMaterialComponent,
           ry_bomexplosionlevel TYPE RANGE OF zce_zbom_detail-BomExplosionLevel.

    TYPES: BEGIN OF ty_sp_cfg,
             plant               TYPE werks_d,
             sp_type             TYPE c LENGTH 2,
             procurement_type    TYPE c LENGTH 1,
             special_procurement TYPE c LENGTH 1,
             issuing_plant       TYPE werks_d,
           END OF ty_sp_cfg,
           tt_sp_cfg TYPE HASHED TABLE OF ty_sp_cfg WITH UNIQUE KEY plant sp_type.

    DATA mt_sp_cfg        TYPE tt_sp_cfg.
    DATA mv_sp_cfg_loaded TYPE abap_bool.

    METHODS get_itab_key_field
      IMPORTING io_request          TYPE REF TO if_rap_query_request
      RETURNING VALUE(rt_key_field) TYPE tt_key_field.

    METHODS get_plant_range
      IMPORTING it_filters      TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_plant) TYPE ry_plant.

    METHODS get_component_range
      IMPORTING it_filters          TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_component) TYPE ry_component.

    METHODS get_bomexplosionlevel_range
      IMPORTING it_filters                  TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING VALUE(rr_bomexplosionlevel) TYPE ry_bomexplosionlevel.

    METHODS processing_api
      IMPORTING iv_billofmaterial         TYPE string
                iv_billofmaterialcategory TYPE string
                iv_material               TYPE string
                iv_plant                  TYPE string
                iv_salesorder             TYPE string
                iv_salesorderitem         TYPE string
                iv_itemindexstring        TYPE string
                iv_requiredquantity       TYPE string
      RETURNING VALUE(rt_result)          TYPE tt_res.

    METHODS processing_mbom
      IMPORTING iv_billofmaterial        TYPE string
                iv_billofmaterialvariant TYPE string OPTIONAL
                iv_material              TYPE string
                iv_plant                 TYPE string
                iv_itemindexstring       TYPE string
                iv_requiredquantity      TYPE string
                iv_depth                 TYPE i DEFAULT 0
                it_path                  TYPE string_table OPTIONAL
      RETURNING VALUE(rt_result)         TYPE tt_res.

    METHODS get_active_bom
      IMPORTING iv_material       TYPE clike
                iv_plant          TYPE clike
                iv_billofmaterial TYPE clike OPTIONAL
      EXPORTING ev_billofmaterial TYPE string
                ev_variant        TYPE string.

    METHODS processing_kbom
      IMPORTING iv_billofmaterialcategory TYPE string
                iv_material               TYPE string
                iv_plant                  TYPE string
                iv_salesorder             TYPE string
                iv_salesorderitem         TYPE string
                iv_itemindexstring        TYPE string
                iv_requiredquantity       TYPE string
      RETURNING VALUE(rt_result)          TYPE tt_res.

    METHODS get_issuing_plant
      IMPORTING iv_plant        TYPE werks_d
                iv_sp_type      TYPE clike
      RETURNING VALUE(rv_plant) TYPE werks_d.

    METHODS explode_in_supplying_plant
      IMPORTING iv_component       TYPE clike
                iv_plant           TYPE werks_d
                iv_quantity        TYPE zce_zbom_detail-bomcompquant
                iv_level           TYPE zce_zbom_detail-bomexplosionlevel
                iv_itemindexstring TYPE string
                iv_depth           TYPE i
                it_path            TYPE string_table
      RETURNING VALUE(rt_result)   TYPE tt_res.

    METHODS get_tree_view
      IMPORTING iv_tabix  TYPE sy-tabix
      CHANGING  ct_result TYPE tt_res.

    METHODS get_result_paging
      IMPORTING it_result   TYPE tt_res
                io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response.

    METHODS extract_elements
      IMPORTING iv_xml             TYPE string
                iv_tag             TYPE string
      RETURNING VALUE(rt_elements) TYPE string_table.

    METHODS get_tag_value
      IMPORTING iv_xml          TYPE string
                iv_tag          TYPE string
      RETURNING VALUE(rv_value) TYPE string.
ENDCLASS.



CLASS zcl_zbom_detail_ce IMPLEMENTATION.

  METHOD explode_header_for_export.
    DATA(lt_result_tmp) = processing_api(
      iv_billofmaterial         = iv_billofmaterial
      iv_billofmaterialcategory = iv_billofmaterialcategory
      iv_material               = iv_material
      iv_plant                  = iv_plant
      iv_salesorder             = iv_salesorder
      iv_salesorderitem         = iv_salesorderitem
      iv_itemindexstring        = ''
      iv_requiredquantity       = iv_requiredquantity ).

    get_tree_view( EXPORTING iv_tabix  = iv_tabix
                   CHANGING  ct_result = lt_result_tmp ).

    SELECT SINGLE BaseUnit FROM i_product
      WHERE Product = @iv_material
      INTO @DATA(lv_unitheader).

    SELECT SINGLE ProductDescription FROM I_ProductDescription
      WHERE Product  = @iv_material
        AND Language = @sy-langu
      INTO @DATA(lv_matdesc).

    LOOP AT lt_result_tmp ASSIGNING FIELD-SYMBOL(<lfs_result_tmp>).
      <lfs_result_tmp>-MaterialDescription    = lv_matdesc.
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
    DATA lv_matdesc TYPE maktx.
    DATA lt_result     TYPE tt_res.
    DATA lv_unitheader TYPE msehi.
    DATA lr_material   TYPE RANGE OF matnr.

    DATA(lt_key_field) = get_itab_key_field( io_request ).

    lr_material = VALUE #( FOR lwa IN lt_key_field
                           ( sign = 'I' option = 'EQ' low = CONV matnr( lwa-material ) ) ).

    " Range rỗng với IN sẽ đọc TOÀN BỘ i_product, nên phải chặn.
    IF lr_material IS NOT INITIAL.
      SELECT Product, BaseUnit
        FROM i_product
        WHERE Product IN @lr_material
        INTO TABLE @DATA(lt_unitheader).

      SELECT Product, ProductDescription
        FROM I_ProductDescription
        WHERE Product  IN @lr_material
          AND Language = @sy-langu
        INTO TABLE @DATA(lt_matdesc).
    ENDIF.

    LOOP AT lt_key_field INTO DATA(ls_key_field).
      DATA(lv_tabix) = sy-tabix.
      CLEAR: lv_unitheader, lv_matdesc.

      DATA(lt_result_tmp) = processing_api(
        iv_billofmaterial         = ls_key_field-billofmaterial
        iv_billofmaterialcategory = ls_key_field-billofmaterialcategory
        iv_material               = ls_key_field-material
        iv_plant                  = ls_key_field-plant
        iv_salesorder             = ls_key_field-salesorder
        iv_salesorderitem         = ls_key_field-salesorderitem
        iv_itemindexstring        = ls_key_field-itemindexstring
        iv_requiredquantity       = ls_key_field-requiredquantity ).

      get_tree_view( EXPORTING iv_tabix  = lv_tabix
                     CHANGING  ct_result = lt_result_tmp ).

      READ TABLE lt_unitheader INTO DATA(ls_unitheader)
        WITH KEY Product = ls_key_field-material.
      IF sy-subrc = 0.
        lv_unitheader = ls_unitheader-BaseUnit.
      ENDIF.

      READ TABLE lt_matdesc INTO DATA(ls_matdesc)
        WITH KEY Product = ls_key_field-material.
      IF sy-subrc = 0.
        lv_matdesc = ls_matdesc-ProductDescription.
      ENDIF.

      LOOP AT lt_result_tmp ASSIGNING FIELD-SYMBOL(<lfs_result_tmp>).
        <lfs_result_tmp>-MaterialDescription    = lv_matdesc.
        <lfs_result_tmp>-BillOfMaterialCategory = ls_key_field-billofmaterialcategory.
        <lfs_result_tmp>-MaterialHeader         = ls_key_field-material.
        <lfs_result_tmp>-SalesOrder             = ls_key_field-salesorder.
        <lfs_result_tmp>-SalesOrderItem         = ls_key_field-salesorderitem.
        <lfs_result_tmp>-RequiredQuantityHeader = ls_key_field-requiredquantity.
        <lfs_result_tmp>-UomHeader              = lv_unitheader.
      ENDLOOP.

      APPEND LINES OF lt_result_tmp TO lt_result.

      IF ls_key_field-itemindex IS NOT INITIAL.
        DELETE lt_result WHERE itemindex <> ls_key_field-itemindex.
      ENDIF.
    ENDLOOP.

    " Bộ lọc bổ sung trên filter bar của màn hình Detail
    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.

    DATA(lr_component) = get_component_range( lt_filters ).
    IF lr_component IS NOT INITIAL.
      DELETE lt_result WHERE BillOfMaterialComponent NOT IN lr_component.
    ENDIF.

    DATA(lr_bomexplosionlevel) = get_bomexplosionlevel_range( lt_filters ).
    IF lr_bomexplosionlevel IS NOT INITIAL.
      DELETE lt_result WHERE BomExplosionLevel NOT IN lr_bomexplosionlevel.
    ENDIF.

    get_result_paging( it_result   = lt_result
                       io_request  = io_request
                       io_response = io_response ).
  ENDMETHOD.


  METHOD get_itab_key_field.
    DATA lr_bom_variant       TYPE RANGE OF i_materialbomlink-billofmaterialvariant.
    DATA lv_bom_cat           TYPE string.
    DATA lv_bom_variant_usage TYPE string.

    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
    ENDTRY.
    CHECK lt_filters IS NOT INITIAL.

    READ TABLE lt_filters INTO DATA(ls_bom) WITH KEY name = 'BILLOFMATERIAL'.
    CHECK sy-subrc = 0.
    SORT ls_bom-range BY low.

    READ TABLE lt_filters INTO DATA(ls_bomcategory) WITH KEY name = 'BILLOFMATERIALCATEGORY'.
    IF sy-subrc = 0.
      lv_bom_cat = ls_bomcategory-range[ 1 ]-low.
    ENDIF.

    READ TABLE lt_filters INTO DATA(ls_bomvariantusage) WITH KEY name = 'BILLOFMATERIALVARIANTUSAGE'.
    IF sy-subrc = 0.
      lv_bom_variant_usage = ls_bomvariantusage-range[ 1 ]-low.
    ENDIF.

    " Plant dòng 673* (vd 6731, 673K) dùng thêm BOM variant A*/B*/X*/G*/M*.
    DATA(lr_plant) = get_plant_range( lt_filters ).
    DATA(lv_is_673_plant) = abap_false.
    LOOP AT lr_plant INTO DATA(ls_plant_chk).
      IF ls_plant_chk-low(3) = '673'
         OR ( ls_plant_chk-high IS NOT INITIAL AND ls_plant_chk-high(3) = '673' ).
        lv_is_673_plant = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    lr_bom_variant = VALUE #( ( sign = 'I' option = 'EQ' low = '01' ) ).
    IF lv_is_673_plant = abap_true.
      lr_bom_variant = VALUE #( BASE lr_bom_variant
        ( sign = 'I' option = 'CP' low = 'A*' )
        ( sign = 'I' option = 'CP' low = 'B*' )
        ( sign = 'I' option = 'CP' low = 'X*' )
        ( sign = 'I' option = 'CP' low = 'G*' )
        ( sign = 'I' option = 'CP' low = 'M*' ) ).
    ENDIF.

    IF lv_bom_cat = 'M'.
      SELECT DISTINCT a~BillOfMaterial, a~material, a~plant
        FROM I_MaterialBOMLink AS a
        WHERE a~BillOfMaterial         IN @ls_bom-range
          AND a~BillOfMaterialVariant  IN @lr_bom_variant
          AND a~BillOfMaterialCategory = 'M'
        INTO TABLE @DATA(lt_bom_m).
    ELSEIF lv_bom_cat = 'K'.
      SELECT DISTINCT a~BillOfMaterial, a~material, a~plant, a~salesorder, a~salesorderitem
        FROM i_salesorderbomlink AS a
        WHERE a~BillOfMaterial         IN @ls_bom-range
          AND a~BillOfMaterialCategory = 'K'
        INTO TABLE @DATA(lt_bom_k).

      SELECT FROM I_SalesOrderItem AS a
        INNER JOIN @lt_bom_k AS b ON b~SalesOrder     = a~SalesOrder
                                 AND b~SalesOrderItem = a~SalesOrderItem
                                 AND b~Plant          = a~Plant
                                 AND b~Material       = a~Product
        FIELDS b~BillOfMaterial, a~OrderQuantity
        INTO TABLE @DATA(lt_quantity).
    ENDIF.

    LOOP AT ls_bom-range INTO DATA(ls_bom_range).
      APPEND INITIAL LINE TO rt_key_field ASSIGNING FIELD-SYMBOL(<lfs_key_field>).
      <lfs_key_field>-billofmaterial             = ls_bom_range-low.
      <lfs_key_field>-billofmaterialcategory     = lv_bom_cat.
      <lfs_key_field>-billofmaterialvariantusage = lv_bom_variant_usage.

      IF lv_bom_cat = 'M'.
        READ TABLE lt_bom_m INTO DATA(ls_bom_m) WITH KEY BillOfMaterial = <lfs_key_field>-billofmaterial.
        IF sy-subrc = 0.
          <lfs_key_field>-material = ls_bom_m-Material.
          <lfs_key_field>-plant    = ls_bom_m-Plant.
        ENDIF.
        <lfs_key_field>-salesorder       = ''.
        <lfs_key_field>-salesorderitem   = '000000'.
        <lfs_key_field>-requiredquantity = 1000.

      ELSEIF lv_bom_cat = 'K'.
        READ TABLE lt_bom_k INTO DATA(ls_bom_k) WITH KEY BillOfMaterial = <lfs_key_field>-billofmaterial.
        IF sy-subrc = 0.
          <lfs_key_field>-material       = ls_bom_k-Material.
          <lfs_key_field>-plant          = ls_bom_k-Plant.
          <lfs_key_field>-salesorder     = ls_bom_k-salesorder.
          <lfs_key_field>-salesorderitem = ls_bom_k-SalesOrderItem.
        ENDIF.

        READ TABLE lt_quantity INTO DATA(ls_quantity) WITH KEY BillOfMaterial = <lfs_key_field>-billofmaterial.
        IF sy-subrc = 0.
          <lfs_key_field>-requiredquantity = ls_quantity-OrderQuantity.
        ENDIF.
        IF <lfs_key_field>-requiredquantity = 0.
          <lfs_key_field>-requiredquantity = 1000.
        ENDIF.
      ENDIF.
      CONDENSE <lfs_key_field>-requiredquantity NO-GAPS.

      <lfs_key_field>-itemindexstring = |{ <lfs_key_field>-billofmaterial }~#%| &&
                                        |{ <lfs_key_field>-billofmaterialcategory }~#%| &&
                                        |{ <lfs_key_field>-billofmaterialvariantusage }~#%| &&
                                        |{ <lfs_key_field>-material }~#%| &&
                                        |{ <lfs_key_field>-plant }~#%| &&
                                        |{ <lfs_key_field>-salesorder }~#%| &&
                                        |{ <lfs_key_field>-salesorderitem }| &&
                                        |{ <lfs_key_field>-requiredquantity }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_plant_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'PLANT'.
    IF sy-subrc = 0.
      rr_plant = VALUE #( FOR ls IN ls_filters-range ( sign = 'I' option = 'EQ' low = ls-low ) ).
    ENDIF.
  ENDMETHOD.


  METHOD get_component_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'BILLOFMATERIALCOMPONENT'.
    IF sy-subrc = 0.
      rr_component = VALUE #( FOR ls IN ls_filters-range ( sign = 'I' option = 'EQ' low = ls-low ) ).
    ENDIF.
  ENDMETHOD.


  METHOD get_bomexplosionlevel_range.
    READ TABLE it_filters INTO DATA(ls_filters) WITH KEY name = 'BOMEXPLOSIONLEVEL'.
    IF sy-subrc = 0.
      rr_bomexplosionlevel = VALUE #( FOR ls IN ls_filters-range ( sign = 'I' option = 'EQ' low = ls-low ) ).
    ENDIF.
  ENDMETHOD.


  METHOD processing_api.
    " Không có sales order -> Material BOM (M), ngược lại là Order BOM (K).
    IF iv_salesorder IS INITIAL AND iv_salesorderitem = '000000'.
      " API tự chọn alternative khi để trống, và báo lỗi nếu alternative đó
      " không hiệu lực -> chỉ định alternative active.
      get_active_bom( EXPORTING iv_material       = |{ iv_material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
                                iv_plant          = iv_plant
                                iv_billofmaterial = iv_billofmaterial
                      IMPORTING ev_variant        = DATA(lv_variant) ).

      rt_result = processing_mbom(
        iv_billofmaterial        = iv_billofmaterial
        iv_billofmaterialvariant = lv_variant
        iv_material              = iv_material
        iv_plant                 = iv_plant
        iv_itemindexstring       = iv_itemindexstring
        iv_requiredquantity      = iv_requiredquantity ).
    ELSE.
      rt_result = processing_kbom(
        iv_billofmaterialcategory = iv_billofmaterialcategory
        iv_material               = iv_material
        iv_plant                  = iv_plant
        iv_salesorder             = iv_salesorder
        iv_salesorderitem         = iv_salesorderitem
        iv_itemindexstring        = iv_itemindexstring
        iv_requiredquantity       = iv_requiredquantity ).
    ENDIF.
  ENDMETHOD.



  METHOD processing_mbom.
    TYPES: BEGIN OF ty_pp,
             product TYPE matnr,
             plant   TYPE werks_d,
           END OF ty_pp.

    DATA lv_date TYPE char10.
    DATA lt_pp   TYPE STANDARD TABLE OF ty_pp WITH DEFAULT KEY.

    DATA(lv_date_enc) = |datetime%27{ cl_abap_context_info=>get_system_date( ) DATE = ISO }T00%3A00%3A00%27|.

    DATA(lv_endpoint) =
      '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2/ExplodeBOM?' &&
      |Material=%27{ iv_material }%27| &&
      |&Plant=%27{ iv_plant }%27| &&
      |&BillOfMaterialVariant=%27{ iv_billofmaterialvariant }%27| &&
      |&BOMExplosionApplication=%27PP01%27| &&
      |&RequiredQuantity={ iv_requiredquantity }m| &&
      |&EngineeringChangeDocument=%27%27| &&
      |&BOMExplosionIsLimited=false| &&
      |&BOMItmQtyIsScrapRelevant=%27X%27| &&   " cộng component scrap vào quantity, như checkbox Scrap của app Explode BOM
      |&BillOfMaterialItemCategory=%27%27| &&
      |&BOMExplosionAssembly=%27%27| &&
      |&BOMExplosionDate={ lv_date_enc }| &&
      |&BOMExplosionLevel=0m| &&
      |&BOMExplosionIsMultilevel=true| &&
      |&MaterialProvisionFltrType=%27%20%27| &&
      |&SparePartFltrType=%27%20%27| &&
      |&BillOfMaterial=%27{ iv_billofmaterial }%27| &&
      |&BillOfMaterialCategory=%27M%27| &&
      |&BillOfMaterialVersion=%27%27|.

    DATA(lv_xml) = zcl_call_api_mbom=>call_api(
      iv_body        = ''
      iv_endpoint    = lv_endpoint
      iv_method      = 'GET'
      iv_contenttype = 'application/xml' ).

    IF zcl_call_api_mbom=>code <> '200'.
      RETURN.
    ENDIF.

    DATA(lt_elements) = extract_elements( iv_xml = lv_xml iv_tag = 'd:element' ).

    LOOP AT lt_elements INTO DATA(lv_elem).
      APPEND INITIAL LINE TO rt_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result>-billofmaterial               = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bill_of_material' ).
      <lfs_result>-billofmaterialcategory       = get_tag_value( iv_xml = lv_elem iv_tag = 'd:b_o_m_category' ).
      <lfs_result>-material                     = get_tag_value( iv_xml = lv_elem iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
      <lfs_result>-billofmaterialvariantusage   = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bill_of_material_variant_usage' ).
      <lfs_result>-salesorder                   = ''.
      <lfs_result>-salesorderitem               = '000000'.
      <lfs_result>-itemindex                    = get_tag_value( iv_xml = lv_elem iv_tag = 'd:item_index' ).
      <lfs_result>-itemindexstring              = iv_itemindexstring.
      <lfs_result>-billofmaterialcomponent      = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bill_of_material_component' ).
      <lfs_result>-bomexplosionlevel            = get_tag_value( iv_xml = lv_elem iv_tag = 'd:b_o_m_explosion_level' ).
      <lfs_result>-bomhhdrmatlhiernode          = get_tag_value( iv_xml = lv_elem iv_tag = 'd:b_o_m_hdr_matl_hier_node' ).
      <lfs_result>-componentdescription         = get_tag_value( iv_xml = lv_elem iv_tag = 'd:b_o_m_component_description' ).
      <lfs_result>-bomcompquant                 = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bill_of_material_comp_quant' ).
      <lfs_result>-billofmaterialitemcategory   = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bill_of_material_item_category' ).
      <lfs_result>-billofmaterialitemnumber     = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bill_of_material_item_number' ).
      <lfs_result>-isassembly                   = xsdbool( get_tag_value( iv_xml = lv_elem iv_tag = 'd:assembly_indicator' ) = 'true' ).
      <lfs_result>-materialtype                 = get_tag_value( iv_xml = lv_elem iv_tag = 'd:material_type' ).
      <lfs_result>-plant                        = get_tag_value( iv_xml = lv_elem iv_tag = 'd:plant' ).
      <lfs_result>-billofmaterialitemunit       = get_tag_value( iv_xml = lv_elem iv_tag = 'd:base_uom' ).
      <lfs_result>-maintenancestatus            = get_tag_value( iv_xml = lv_elem iv_tag = 'd:maintenance_status' ).
      <lfs_result>-changenumber                 = get_tag_value( iv_xml = lv_elem iv_tag = 'd:change_number' ).
      <lfs_result>-createdby                    = get_tag_value( iv_xml = lv_elem iv_tag = 'd:created_by_user' ).
      <lfs_result>-changedby                    = get_tag_value( iv_xml = lv_elem iv_tag = 'd:last_changed_by_user' ).
      <lfs_result>-isbomitemsparepart           = get_tag_value( iv_xml = lv_elem iv_tag = 'd:is_b_o_m_item_spare_part' ).
      <lfs_result>-componentscrapinpercent      = get_tag_value( iv_xml = lv_elem iv_tag = 'd:comp_scrap_itm' ).
      <lfs_result>-billofmaterialvariant        = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bill_of_material_variant' ).
      <lfs_result>-billofmaterialversion        = get_tag_value( iv_xml = lv_elem iv_tag = 'd:b_o_m_version' ).
      <lfs_result>-billofmaterialitemnodenumber = get_tag_value( iv_xml = lv_elem iv_tag = 'd:item_node' ).
      <lfs_result>-headerchangedocument         = get_tag_value( iv_xml = lv_elem iv_tag = 'd:bom_change_number' ).

      " Ngày trả về dạng yyyy-mm-dd..., chỉ lấy 10 ký tự đầu rồi bỏ dấu '-'.
      lv_date = get_tag_value( iv_xml = lv_elem iv_tag = 'd:validity_start_date' ).
      REPLACE ALL OCCURRENCES OF '-' IN lv_date WITH ''.
      <lfs_result>-validitystartdate = lv_date.

      lv_date = get_tag_value( iv_xml = lv_elem iv_tag = 'd:record_creation_date' ).
      REPLACE ALL OCCURRENCES OF '-' IN lv_date WITH ''.
      <lfs_result>-createdon = lv_date.

      lv_date = get_tag_value( iv_xml = lv_elem iv_tag = 'd:last_change_date' ).
      REPLACE ALL OCCURRENCES OF '-' IN lv_date WITH ''.
      <lfs_result>-changedon = lv_date.
    ENDLOOP.

    " IsAssembly lấy từ BOM item. Key trong view là dạng nội bộ: variant
    " ALPHA IN, material đệm '0' đủ 18 ký tự.
    DATA(lt_key) = rt_result.
    LOOP AT lt_key ASSIGNING FIELD-SYMBOL(<ls_key>).
      <ls_key>-BillOfMaterialVariant = |{ <ls_key>-BillOfMaterialVariant ALPHA = IN }|.
      <ls_key>-Material              = |{ <ls_key>-Material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
    ENDLOOP.

    " FOR ALL ENTRIES với bảng rỗng sẽ đọc TOÀN BỘ view, nên phải chặn.
    IF lt_key IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM I_BillOfMaterialItemTP_2
      FIELDS BillOfMaterial, BillOfMaterialCategory, BillOfMaterialVariant,
             BillOfMaterialVersion, BillOfMaterialItemNodeNumber,
             HeaderChangeDocument, Material, Plant, IsAssembly
      FOR ALL ENTRIES IN @lt_key
      WHERE BillOfMaterial               = @lt_key-BillOfMaterial
        AND BillOfMaterialCategory       = @lt_key-BillOfMaterialCategory
        AND BillOfMaterialVariant        = @lt_key-BillOfMaterialVariant
        AND BillOfMaterialVersion        = @lt_key-BillOfMaterialVersion
        AND BillOfMaterialItemNodeNumber = @lt_key-BillOfMaterialItemNodeNumber
        AND HeaderChangeDocument         = @lt_key-HeaderChangeDocument
        AND Material                     = @lt_key-Material
        AND Plant                        = @lt_key-Plant
      INTO TABLE @DATA(lt_bom_items).

    LOOP AT rt_result ASSIGNING <lfs_result>.
      READ TABLE lt_bom_items INTO DATA(ls_bom_item) WITH KEY
        BillOfMaterial               = <lfs_result>-BillOfMaterial
        BillOfMaterialCategory       = <lfs_result>-BillOfMaterialCategory
        BillOfMaterialVariant        = |{ <lfs_result>-BillOfMaterialVariant ALPHA = IN }|
        BillOfMaterialVersion        = <lfs_result>-BillOfMaterialVersion
        BillOfMaterialItemNodeNumber = <lfs_result>-BillOfMaterialItemNodeNumber
        HeaderChangeDocument         = <lfs_result>-HeaderChangeDocument
        Material                     = |{ <lfs_result>-Material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
        Plant                        = <lfs_result>-Plant.
      IF sy-subrc = 0.
        <lfs_result>-IsAssembly = ls_bom_item-IsAssembly.
      ENDIF.
    ENDLOOP.

    " Mã mua đặc biệt (MRP 2) của component tại plant của dòng.
    lt_pp = VALUE #( FOR ls_r IN rt_result
      ( product = |{ ls_r-BillOfMaterialComponent WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
        plant   = ls_r-Plant ) ).
    SORT lt_pp BY product plant.
    DELETE ADJACENT DUPLICATES FROM lt_pp COMPARING ALL FIELDS.

    SELECT Product, Plant, ProcurementSubType
      FROM I_ProductSupplyPlanning
      FOR ALL ENTRIES IN @lt_pp
      WHERE Product = @lt_pp-product
        AND Plant   = @lt_pp-plant
      INTO TABLE @DATA(lt_sp).

    " Component lấy từ plant khác: đổi plant theo config; chưa có BOM thì
    " xổ tiếp ở plant đó, chèn ngay dưới dòng cha và đánh dấu Assembly.
    DATA(lt_flat) = rt_result.
    CLEAR rt_result.
    LOOP AT lt_flat INTO DATA(ls_flat).
      APPEND ls_flat TO rt_result.

      DATA(lv_comp) = CONV matnr( |{ ls_flat-BillOfMaterialComponent WIDTH = 18 ALIGN = RIGHT PAD = '0' }| ).
      READ TABLE lt_sp INTO DATA(ls_sp) WITH KEY Product = lv_comp Plant = ls_flat-Plant.
      IF sy-subrc <> 0 OR ls_sp-ProcurementSubType IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_issuing) = get_issuing_plant( iv_plant   = CONV #( ls_flat-Plant )
                                            iv_sp_type = ls_sp-ProcurementSubType ).
      IF lv_issuing IS INITIAL.
        CONTINUE.
      ENDIF.

      rt_result[ lines( rt_result ) ]-Plant = lv_issuing.

      " API đã xổ component này nếu nó là header của dòng con ở level kế tiếp.
      " Dòng con mang plant hiện tại, hoặc plant cung ứng khi API tự xổ theo mã
      " mua đặc biệt (vd 6712 -> 6711); chỉ xét plant hiện tại thì component bị
      " xổ thêm lần nữa ở plant cung ứng, ra 2 bộ con trùng nhau.
      DATA(lv_child_level) = CONV zce_zbom_detail-bomexplosionlevel( ls_flat-BomExplosionLevel + 1 ).
      IF line_exists( lt_flat[ BomHhdrMatlHierNode = ls_flat-BillOfMaterialComponent
                               BomExplosionLevel   = lv_child_level
                               Plant               = ls_flat-Plant ] )
         OR line_exists( lt_flat[ BomHhdrMatlHierNode = ls_flat-BillOfMaterialComponent
                                  BomExplosionLevel   = lv_child_level
                                  Plant               = lv_issuing ] ).
        CONTINUE.
      ENDIF.


      DATA(lt_sub) = explode_in_supplying_plant(
        iv_component       = lv_comp
        iv_plant           = lv_issuing
        iv_quantity        = ls_flat-BomCompQuant
        iv_level           = ls_flat-BomExplosionLevel
        iv_itemindexstring = iv_itemindexstring
        iv_depth           = iv_depth
        it_path            = it_path ).
      IF lt_sub IS NOT INITIAL.
        rt_result[ lines( rt_result ) ]-IsAssembly = abap_true.
        APPEND LINES OF lt_sub TO rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.



  METHOD processing_kbom.
    DATA lv_product          TYPE matnr.
    DATA lv_plant            TYPE werks_d.
    DATA lv_bom_cat          TYPE c LENGTH 1.
    DATA lv_so               TYPE vbeln.
    DATA lv_so_item          TYPE n LENGTH 6.
    DATA lv_requiredquantity TYPE i.

    lv_product          = |{ iv_material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
    lv_plant            = iv_plant.
    lv_bom_cat          = iv_billofmaterialcategory.
    lv_so               = iv_salesorder.
    lv_so_item          = iv_salesorderitem.
    lv_requiredquantity = iv_requiredquantity.

    SELECT SINGLE billofmaterial, billofmaterialvariant, salesorder, salesorderitem
      FROM i_salesorderbomlink
      WHERE material               = @lv_product
        AND plant                  = @lv_plant
        AND billofmaterialcategory = @lv_bom_cat
        AND salesorder             = @lv_so
        AND salesorderitem         = @lv_so_item
      INTO @DATA(ls_bom_key).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    TRY.
        READ ENTITIES OF I_SalesOrderBillOfMaterialTP_2
          ENTITY SalesBillOfMaterial
          EXECUTE ExplodeBOM
          FROM VALUE #( (
              %key-BillOfMaterial               = ls_bom_key-billofmaterial
              %key-BillOfMaterialCategory       = lv_bom_cat
              %key-BillOfMaterialVariant        = ls_bom_key-billofmaterialvariant
              %key-EngineeringChangeDocument    = ''
              %key-Material                     = lv_product
              %key-Plant                        = lv_plant
              %param-BOMExplosionDate           = cl_abap_context_info=>get_system_date( )
              %param-BOMExplosionIsMultilevel   = abap_true
              %param-RequiredQuantity           = lv_requiredquantity
              %param-BOMExplosionApplication    = 'PP01'
              %param-BillOfMaterialItemCategory = ''
              %param-BOMItmQtyIsScrapRelevant   = abap_true   " cộng component scrap vào quantity, như checkbox Scrap của app Explode BOM
              %param-SalesOrder                 = ls_bom_key-salesorder
              %param-SalesOrderItem             = ls_bom_key-salesorderitem ) )
          RESULT DATA(lt_result)
          FAILED DATA(lt_failed)
          REPORTED DATA(lt_reported).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    IF lt_result IS INITIAL.
      RETURN.
    ENDIF.

    " IsAssembly và % scrap là dữ liệu master của BOM item, action ExplodeBOM
    " không trả về. Item của K BOM đọc từ I_SlsOrdBillOfMaterialItemTP_2; item
    " của M BOM nằm trong cây K thì đọc tiếp bằng EML trên I_BillOfMaterialTP_2.
    SELECT FROM I_SlsOrdBillOfMaterialItemTP_2
      FIELDS BillOfMaterial, BillOfMaterialCategory, BillOfMaterialVariant,
             BillOfMaterialItemNodeNumber, HeaderChangeDocument, Material, Plant,
             IsAssembly, ComponentScrapInPercent
      FOR ALL ENTRIES IN @lt_result
      WHERE BillOfMaterial               = @lt_result-%param-BillOfMaterial
        AND BillOfMaterialCategory       = @lt_result-%param-BillOfMaterialCategory
        AND BillOfMaterialVariant        = @lt_result-%param-BillOfMaterialVariant
        AND BillOfMaterialItemNodeNumber = @lt_result-%param-BillOfMaterialItemNodeNumber
        AND HeaderChangeDocument         = @lt_result-%param-BOMHdrEngChgDoc
        AND Material                     = @lt_result-%param-BOMHdrMatlHierNode
        AND Plant                        = @lt_result-%param-Plant
      INTO TABLE @DATA(lt_bom_items).

    READ ENTITIES OF I_BillOfMaterialTP_2
      ENTITY BillOfMaterialItem
      FIELDS ( IsAssembly ComponentScrapInPercent )
      WITH VALUE #( FOR ls_res IN lt_result
        ( %key-BillOfMaterial               = ls_res-%param-BillOfMaterial
          %key-BillOfMaterialCategory       = ls_res-%param-BillOfMaterialCategory
          %key-BillOfMaterialVariant        = ls_res-%param-BillOfMaterialVariant
          %key-BillOfMaterialVersion        = ls_res-%param-BillOfMaterialVersion
          %key-BillOfMaterialItemNodeNumber = ls_res-%param-BillOfMaterialItemNodeNumber
          %key-HeaderChangeDocument         = ls_res-%param-BOMHdrEngChgDoc
          %key-Material                     = ls_res-%param-BOMHdrMatlHierNode
          %key-Plant                        = ls_res-%param-Plant ) )
      RESULT DATA(lt_bom_items_m)
      FAILED DATA(lt_failed_m)
      REPORTED DATA(lt_reported_m).

    LOOP AT lt_result INTO DATA(ls_result).
      DATA(lv_tabix) = sy-tabix.
      APPEND INITIAL LINE TO rt_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
      <lfs_result> = CORRESPONDING #( ls_result-%param ).
      <lfs_result>-BillOfMaterialComponent = |{ ls_result-%param-BillOfMaterialComponent ALPHA = OUT }|.
      <lfs_result>-ItemIndex              = lv_tabix.
      <lfs_result>-ItemIndexString        = iv_itemindexstring.
      <lfs_result>-Material               = ls_result-%param-BOMHdrMatlHierNode.
      <lfs_result>-MaterialHeader         = ls_result-%param-BOMHdrRootMatlHierNode.
      <lfs_result>-UomHeader              = ls_result-%param-BOMHeaderBaseUnit.
      <lfs_result>-RequiredQuantityHeader = iv_requiredquantity.
      <lfs_result>-BomExplosionLevel      = ls_result-%param-ExplodeBOMLevelValue.
      <lfs_result>-BomhHdrMatlHierNode    = ls_result-%param-BOMHdrMatlHierNode.
      <lfs_result>-BomCompQuant           = ls_result-%param-ComponentQuantityInCompUoM.

      READ TABLE lt_bom_items INTO DATA(ls_bom_item) WITH KEY
        BillOfMaterial               = ls_result-%param-BillOfMaterial
        BillOfMaterialCategory       = ls_result-%param-BillOfMaterialCategory
        BillOfMaterialVariant        = ls_result-%param-BillOfMaterialVariant
        BillOfMaterialItemNodeNumber = ls_result-%param-BillOfMaterialItemNodeNumber
        HeaderChangeDocument         = ls_result-%param-BOMHdrEngChgDoc
        Material                     = ls_result-%param-BOMHdrMatlHierNode
        Plant                        = ls_result-%param-Plant.
      IF sy-subrc = 0.
        <lfs_result>-IsAssembly              = ls_bom_item-IsAssembly.
        <lfs_result>-ComponentScrapInPercent = ls_bom_item-ComponentScrapInPercent.
      ELSE.
        READ TABLE lt_bom_items_m INTO DATA(ls_bom_item_m) WITH KEY
          %key-BillOfMaterial               = ls_result-%param-BillOfMaterial
          %key-BillOfMaterialCategory       = ls_result-%param-BillOfMaterialCategory
          %key-BillOfMaterialVariant        = ls_result-%param-BillOfMaterialVariant
          %key-BillOfMaterialVersion        = ls_result-%param-BillOfMaterialVersion
          %key-BillOfMaterialItemNodeNumber = ls_result-%param-BillOfMaterialItemNodeNumber
          %key-HeaderChangeDocument         = ls_result-%param-BOMHdrEngChgDoc
          %key-Material                     = ls_result-%param-BOMHdrMatlHierNode
          %key-Plant                        = ls_result-%param-Plant.
        IF sy-subrc = 0.
          <lfs_result>-IsAssembly              = ls_bom_item_m-IsAssembly.
          <lfs_result>-ComponentScrapInPercent = ls_bom_item_m-ComponentScrapInPercent.
        ENDIF.
      ENDIF.

      " Component lấy từ plant khác (mã mua đặc biệt MRP 2): đổi plant theo
      " config; chưa có BOM thì xổ tiếp ở plant đó và đánh dấu Assembly.
      IF ls_result-%param-SpecialProcurementType IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_issuing) = get_issuing_plant( iv_plant   = ls_result-%param-Plant
                                            iv_sp_type = ls_result-%param-SpecialProcurementType ).
      IF lv_issuing IS INITIAL.
        CONTINUE.
      ENDIF.

      <lfs_result>-Plant = lv_issuing.

      " Cờ IsAssembly của BOM item có thể bật dù plant hiện tại không có BOM,
      " nên xem API đã xổ chưa qua NextLevelBillOfMaterial.
      IF ls_result-%param-NextLevelBillOfMaterial IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lt_sub) = explode_in_supplying_plant(
        iv_component       = ls_result-%param-BillOfMaterialComponent
        iv_plant           = lv_issuing
        iv_quantity        = CONV #( ls_result-%param-ComponentQuantityInCompUoM )
        iv_level           = CONV #( ls_result-%param-ExplodeBOMLevelValue )
        iv_itemindexstring = iv_itemindexstring
        iv_depth           = 0
        it_path            = VALUE #( ( |{ lv_product }@{ lv_plant }| ) ) ).
      IF lt_sub IS NOT INITIAL.
        <lfs_result>-IsAssembly = abap_true.
        APPEND LINES OF lt_sub TO rt_result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_issuing_plant.
    " Bảng config nhỏ, đọc 1 lần cho mỗi instance.
    IF mv_sp_cfg_loaded = abap_false.
      SELECT plant, sp_type, procurement_type, special_procurement, issuing_plant
        FROM ztb_zbom_spplant
        INTO CORRESPONDING FIELDS OF TABLE @mt_sp_cfg.
      mv_sp_cfg_loaded = abap_true.
    ENDIF.

    READ TABLE mt_sp_cfg INTO DATA(ls_cfg)
      WITH TABLE KEY plant = iv_plant sp_type = iv_sp_type.
    IF sy-subrc = 0 AND ls_cfg-issuing_plant <> iv_plant.
      rv_plant = ls_cfg-issuing_plant.
    ENDIF.
  ENDMETHOD.


  METHOD explode_in_supplying_plant.
    " Chống lặp: cấu hình cho phép 6711 -> 6713 -> 6711..., nên dừng khi
    " vật tư đã được xổ ở plant này trên cùng nhánh, hoặc quá sâu.
    DATA(lv_node) = |{ iv_component }@{ iv_plant }|.
    IF iv_depth >= 10 OR line_exists( it_path[ table_line = lv_node ] ).
      RETURN.
    ENDIF.

    get_active_bom( EXPORTING iv_material       = iv_component
                              iv_plant          = iv_plant
                    IMPORTING ev_billofmaterial = DATA(lv_bom)
                              ev_variant        = DATA(lv_variant) ).
    IF lv_bom IS INITIAL.
      RETURN.   " không có BOM active ở plant cung ứng -> chỉ đổi plant ở dòng cha
    ENDIF.

    rt_result = processing_mbom(
      iv_billofmaterial        = lv_bom
      iv_billofmaterialvariant = lv_variant
      iv_material              = CONV #( iv_component )
      iv_plant                 = CONV #( iv_plant )
      iv_itemindexstring       = iv_itemindexstring
      iv_requiredquantity      = |{ iv_quantity }|
      iv_depth                 = iv_depth + 1
      it_path                  = VALUE #( BASE it_path ( lv_node ) ) ).

    LOOP AT rt_result ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-BomExplosionLevel = <ls_row>-BomExplosionLevel + iv_level.
    ENDLOOP.
  ENDMETHOD.




  METHOD get_tree_view.
    TYPES: BEGIN OF ty_node,
             tabix    TYPE i,
             parent   TYPE i,
             treeview TYPE string,
           END OF ty_node,
           BEGIN OF ty_cnt,
             parent TYPE i,
             cnt    TYPE i,
           END OF ty_cnt,
           BEGIN OF ty_sort,
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

    DATA lt_nodes         TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY.
    DATA ls_node          TYPE ty_node.
    DATA ls_pnode         TYPE ty_node.
    DATA lt_cnt           TYPE HASHED TABLE OF ty_cnt WITH UNIQUE KEY parent.
    DATA ls_cnt           TYPE ty_cnt.
    DATA lt_sort          TYPE STANDARD TABLE OF ty_sort WITH DEFAULT KEY.
    DATA ls_sort          TYPE ty_sort.
    DATA lt_segs          TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA lt_root          LIKE ct_result.
    DATA lt_children      LIKE ct_result.
    DATA lt_result_sorted LIKE ct_result.
    DATA lv_tree          TYPE string.
    DATA lv_min_level     TYPE i VALUE 99.
    DATA lv_cur_level     TYPE i.
    DATA lv_search        TYPE i.
    DATA lv_parent_norm   TYPE matnr.
    DATA lv_comp_norm     TYPE matnr.

    LOOP AT ct_result INTO DATA(ls_tmp).
      lv_cur_level = CONV i( ls_tmp-BomExplosionLevel ).
      IF lv_cur_level < lv_min_level.
        lv_min_level = lv_cur_level.
      ENDIF.
    ENDLOOP.

    " Dòng gốc (level nhỏ nhất) thường nằm CUỐI bảng do cách API trả về.
    " Phải đưa lên đầu, nếu không nó bị đánh số như anh em bình thường
    " (vd "1.22" thay vì "1.1").
    LOOP AT ct_result INTO DATA(ls_reorder).
      IF CONV i( ls_reorder-BomExplosionLevel ) = lv_min_level.
        APPEND ls_reorder TO lt_root.
      ELSE.
        APPEND ls_reorder TO lt_children.
      ENDIF.
    ENDLOOP.
    ct_result = VALUE #( ( LINES OF lt_root ) ( LINES OF lt_children ) ).

    " Cha của một dòng = dòng gần nhất phía trên có BillOfMaterialComponent
    " bằng BomHhdrMatlHierNode của dòng đó (so ở dạng ALPHA nội bộ).
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<lfs>).
      ls_node = VALUE #( tabix = sy-tabix parent = -1 ).
      lv_cur_level   = CONV i( <lfs>-BomExplosionLevel ).
      lv_parent_norm = |{ <lfs>-BomHhdrMatlHierNode ALPHA = IN }|.

      IF lv_cur_level > lv_min_level.
        lv_search = ls_node-tabix - 1.
        WHILE lv_search >= 1.
          READ TABLE ct_result INDEX lv_search INTO DATA(ls_par).
          lv_comp_norm = |{ ls_par-BillOfMaterialComponent ALPHA = IN }|.
          IF lv_comp_norm = lv_parent_norm.
            ls_node-parent = lv_search.
            EXIT.
          ENDIF.
          lv_search -= 1.
        ENDWHILE.
      ENDIF.

      APPEND ls_node TO lt_nodes.
    ENDLOOP.

    " Dòng có cấp con hiển thị bên dưới là assembly, kể cả khi cờ Assembly của
    " BOM item không bật (vd cấp con do SAP xổ theo mã mua đặc biệt).
    LOOP AT lt_nodes INTO ls_node WHERE parent > 0.
      ct_result[ ls_node-parent ]-IsAssembly = abap_true.
    ENDLOOP.

    " Đánh số TreeView: cấp đầu là "<iv_tabix>.<n>", cấp con là "<cha>.<n>".
    LOOP AT lt_nodes ASSIGNING FIELD-SYMBOL(<lfs_node>).
      READ TABLE lt_cnt WITH TABLE KEY parent = <lfs_node>-parent INTO ls_cnt.
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
        READ TABLE lt_nodes WITH KEY tabix = <lfs_node>-parent INTO ls_pnode.
        lv_tree = |{ ls_pnode-treeview }.{ ls_cnt-cnt }|.
      ENDIF.

      <lfs_node>-treeview = lv_tree.

      READ TABLE ct_result INDEX <lfs_node>-tabix ASSIGNING FIELD-SYMBOL(<lfs_res>).
      IF sy-subrc = 0.
        <lfs_res>-TreeView = lv_tree.
      ENDIF.
    ENDLOOP.

    " Sắp theo từng đoạn số của TreeView (sắp chuỗi sẽ ra 1.10 trước 1.2).
    LOOP AT ct_result INTO DATA(ls_res_sort).
      CLEAR ls_sort.
      ls_sort-tabix = sy-tabix.
      SPLIT ls_res_sort-TreeView AT '.' INTO TABLE lt_segs.

      LOOP AT lt_segs INTO DATA(lv_seg).
        CASE sy-tabix.
          WHEN 1.  ls_sort-seg1  = CONV i( lv_seg ).
          WHEN 2.  ls_sort-seg2  = CONV i( lv_seg ).
          WHEN 3.  ls_sort-seg3  = CONV i( lv_seg ).
          WHEN 4.  ls_sort-seg4  = CONV i( lv_seg ).
          WHEN 5.  ls_sort-seg5  = CONV i( lv_seg ).
          WHEN 6.  ls_sort-seg6  = CONV i( lv_seg ).
          WHEN 7.  ls_sort-seg7  = CONV i( lv_seg ).
          WHEN 8.  ls_sort-seg8  = CONV i( lv_seg ).
          WHEN 9.  ls_sort-seg9  = CONV i( lv_seg ).
          WHEN 10. ls_sort-seg10 = CONV i( lv_seg ).
        ENDCASE.
      ENDLOOP.

      APPEND ls_sort TO lt_sort.
    ENDLOOP.

    SORT lt_sort BY seg1 seg2 seg3 seg4 seg5 seg6 seg7 seg8 seg9 seg10.

    LOOP AT lt_sort INTO ls_sort.
      READ TABLE ct_result INDEX ls_sort-tabix INTO DATA(ls_res_tmp).
      IF sy-subrc = 0.
        APPEND ls_res_tmp TO lt_result_sorted.
      ENDIF.
    ENDLOOP.

    ct_result = lt_result_sorted.

    " ItemIndex là key của entity. Dòng khai triển thêm ở plant cấp hàng lấy
    " ItemIndex từ API nên trùng nhau giữa các lần xuất hiện của cùng một
    " component cha -> UI gộp các dòng trùng key và hiện nhầm TreeView.
    " Đánh lại số tuần tự theo thứ tự cây để mỗi dòng có key riêng.
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<ls_idx>).
      <ls_idx>-ItemIndex = sy-tabix.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_result_paging.
    DATA lt_paged    LIKE it_result.
    DATA lt_sort_key TYPE abap_sortorder_tab.

    DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
    DATA(lv_rows)   = io_request->get_paging( )->get_page_size( ).
    DATA(lt_sorted) = it_result.

    LOOP AT io_request->get_sort_elements( ) INTO DATA(ls_sort).
      APPEND VALUE #( name       = ls_sort-element_name
                      descending = ls_sort-descending ) TO lt_sort_key.
    ENDLOOP.
    IF lt_sort_key IS NOT INITIAL.
      SORT lt_sorted BY (lt_sort_key).
    ENDIF.

    IF lv_rows = if_rap_query_paging=>page_size_unlimited.
      io_response->set_data( lt_sorted ).
    ELSE.
      LOOP AT lt_sorted INTO DATA(ls_row) FROM lv_offset + 1 TO lv_offset + lv_rows.
        APPEND ls_row TO lt_paged.
      ENDLOOP.
      io_response->set_data( lt_paged ).
    ENDIF.

    io_response->set_total_number_of_records( CONV int8( lines( lt_sorted ) ) ).
  ENDMETHOD.


  METHOD extract_elements.
    " Tách iv_xml thành các khối <iv_tag ...>...</iv_tag>, trả về phần bên trong.
    DATA(lv_open)      = |<{ iv_tag }|.
    DATA(lv_close)     = |</{ iv_tag }>|.
    DATA(lv_open_len)  = strlen( lv_open ).
    DATA(lv_close_len) = strlen( lv_close ).
    DATA(lv_xml)       = iv_xml.

    DO.
      DATA(lv_start) = find( val = lv_xml sub = lv_open ).
      IF lv_start < 0.
        EXIT.
      ENDIF.

      DATA(lv_inner_start) = lv_start + lv_open_len.
      DATA(lv_end)         = find( val = lv_xml sub = lv_close off = lv_inner_start ).
      IF lv_end < 0.
        EXIT.
      ENDIF.

      APPEND substring( val = lv_xml off = lv_inner_start len = lv_end - lv_inner_start ) TO rt_elements.
      lv_xml = substring( val = lv_xml off = lv_end + lv_close_len ).
    ENDDO.
  ENDMETHOD.


  METHOD get_tag_value.
    " Nội dung giữa <iv_tag> và </iv_tag>; tag thiếu hoặc tự đóng (m:null) trả về rỗng.
    DATA(lv_open)  = |<{ iv_tag }>|.
    DATA(lv_close) = |</{ iv_tag }>|.

    DATA(lv_start) = find( val = iv_xml sub = lv_open ).
    IF lv_start < 0.
      RETURN.
    ENDIF.

    DATA(lv_content_start) = lv_start + strlen( lv_open ).
    DATA(lv_end) = find( val = iv_xml sub = lv_close off = lv_content_start ).
    IF lv_end < 0.
      RETURN.
    ENDIF.

    rv_value = substring( val = iv_xml off = lv_content_start len = lv_end - lv_content_start ).
    CONDENSE rv_value.
  ENDMETHOD.



  METHOD get_active_bom.
    " BOM M hiệu lực hôm nay, trạng thái 01. Lấy alternative nhỏ nhất thỏa
    " mãn (alternative 1 inactive thì lấy 2, ...), không cố định usage.
    " iv_billofmaterial: giữ đúng BOM đã chọn trên màn hình header.
    DATA lr_bom TYPE RANGE OF i_materialbomlink-billofmaterial.

    IF iv_billofmaterial IS NOT INITIAL.
      lr_bom = VALUE #( ( sign = 'I' option = 'EQ' low = iv_billofmaterial ) ).
    ENDIF.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    SELECT a~BillOfMaterial, a~BillOfMaterialVariant
      FROM I_MaterialBOMLink AS a
      INNER JOIN I_BillOfMaterialWithKeyDate( P_KeyDate = @lv_today ) AS b
        ON  b~BillOfMaterialCategory     = a~BillOfMaterialCategory
        AND b~BillOfMaterial             = a~BillOfMaterial
        AND b~BillOfMaterialVariant      = a~BillOfMaterialVariant
        AND b~BillOfMaterialVariantUsage = a~BillOfMaterialVariantUsage
      WHERE a~Material               = @iv_material
        AND a~Plant                  = @iv_plant
        AND a~BillOfMaterialCategory = 'M'
        AND a~BillOfMaterial         IN @lr_bom
        AND b~BillOfMaterialStatus   = '01'
      ORDER BY a~BillOfMaterialVariant, a~BillOfMaterialVariantUsage
      INTO TABLE @DATA(lt_bom)
      UP TO 1 ROWS.

    IF lt_bom IS NOT INITIAL.
      ev_billofmaterial = lt_bom[ 1 ]-BillOfMaterial.
      ev_variant        = lt_bom[ 1 ]-BillOfMaterialVariant.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

