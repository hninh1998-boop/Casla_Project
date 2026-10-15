CLASS zcl_process_mbom_zbom_rp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_key_mbom_api,
             BillOfMaterial(8),
             BillOfMaterialCategory    TYPE stlty,
             BillOfMaterialVariant(2),
             BillOfMaterialVersion(4),
             Material                  TYPE matnr,
             Plant                     TYPE werks_d,
             EngineeringChangeDocument TYPE aennr,
           END OF ty_key_mbom_api.

    TYPES: BEGIN OF ty_body_mbom_api,
             BillOfMaterial(8),
             BillOfMaterialCategory      TYPE stlty,
             BillOfMaterialVariant(2),
             Material                    TYPE matnr,
             Plant                       TYPE werks_d,
             EngineeringChangeDocument   TYPE aennr,

             BillOfMaterialItemNumber(4),
             BillOfMaterialItemCategory  TYPE postp,
             BillOfMaterialComponent(40),
             BillOfMaterialItemQuantity  TYPE I_BillOfMaterialItemDEX_3-BillOfMaterialItemQuantity,
             BillOfMaterialItemUnit      TYPE I_BillOfMaterialItemDEX_3-BillOfMaterialItemUnit,
             IsNetScrap(5), "true or false value
             ComponentScrapInPercent     TYPE I_BillOfMaterialItemDEX_3-ComponentScrapInPercent,
             BOMItemIsCostingRelevant    TYPE I_BillOfMaterialItemDEX_3-BOMItemIsCostingRelevant,
             SpecialProcurementType      TYPE I_BillOfMaterialItemDEX_3-SpecialProcurementType,
             IsProductionRelevant(4), "Fix
             ProdOrderIssueLocation      TYPE I_BillOfMaterialItemDEX_3-ProdOrderIssueLocation,
           END OF ty_body_mbom_api.

    CLASS-METHODS: main
      CHANGING cs_data TYPE ztb_d_zbom_rp.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PROCESS_MBOM_ZBOM_RP IMPLEMENTATION.


  METHOD main.
    DATA: ls_key  TYPE ty_key_mbom_api,
          ls_body TYPE ty_body_mbom_api.

    "Get key API
    SELECT SINGLE FROM zi_zbom_rp
    FIELDS BillOfMaterial
    WHERE
      Material = @cs_data-Material AND
      Plant = @cs_data-Plant AND
      BillOfMaterialVariant = @cs_data-bill_of_material_variant AND
      BillOfMaterialVariantUsage = @cs_data-bill_of_material_variant_usage AND
      BillOfMaterialCategory = 'M'
    INTO @ls_key-billofmaterial.

    ls_key-billofmaterialcategory = 'M'.
    ls_key-billofmaterialvariant = cs_data-bill_of_material_variant.
    ls_key-billofmaterialversion = ''.
    ls_key-EngineeringChangeDocument = ''.
    ls_key-material = cs_data-material.
    ls_key-Plant = cs_data-Plant.

    "Get body data
    "Key field
    ls_body-billofmaterial = ls_key-billofmaterial.
    ls_body-BillOfMaterialCategory = ls_key-BillOfMaterialCategory.
    ls_body-BillOfMaterialVariant = cs_data-bill_of_material_variant.
    ls_body-Material = cs_data-Material.
    ls_body-Plant = cs_data-Plant.
    ls_body-EngineeringChangeDocument = ls_key-EngineeringChangeDocument.
    "Item field
    ls_body-BillOfMaterialItemNumber = cs_data-bill_of_material_item_number.
    ls_body-BillOfMaterialItemCategory = cs_data-bill_of_material_item_category.
    ls_body-BillOfMaterialComponent = cs_data-component.
    ls_body-BillOfMaterialItemQuantity = cs_data-component_quantity.
    ls_body-BillOfMaterialItemUnit = cs_data-component_unit.
    ls_body-IsNetScrap = COND #( WHEN cs_data-is_net_scrap IS INITIAL THEN 'false' ELSE 'true' ).
    ls_body-ComponentScrapInPercent = cs_data-component_scrap_in_percent.
    ls_body-BOMItemIsCostingRelevant = cs_data-bom_item_is_costing_relevant.
    ls_body-SpecialProcurementType = cs_data-special_procurement_type.
    ls_body-IsProductionRelevant = 'true'.
    ls_body-ProdOrderIssueLocation = cs_data-prod_order_issue_location.

    DATA: lv_endpoint TYPE string,
          lv_body     TYPE string.

    lv_endpoint =
        '/sap/opu/odata/sap/API_BILL_OF_MATERIAL_SRV;v=2'
        && |/MaterialBOM(BillOfMaterial='{ ls_key-BillOfMaterial }',|
        && |BillOfMaterialCategory='{ ls_key-BillOfMaterialCategory }',|
        && |BillOfMaterialVariant='{ ls_key-BillOfMaterialVariant }',|
        && |BillOfMaterialVersion='{ ls_key-BillOfMaterialVersion }',|
        && |EngineeringChangeDocument='{ ls_key-EngineeringChangeDocument }',|
        && |Material='{ ls_key-Material }',|
        && |Plant='{ ls_key-Plant }')|
        && '/to_BillOfMaterialItem'.
    lv_body =
        |\{|
        && |"BillOfMaterial": "{ ls_body-billofmaterial }",|
        && |"BillOfMaterialCategory": "{ ls_body-BillOfMaterialCategory }",|
        && |"BillOfMaterialVariant": "{ ls_body-BillOfMaterialVariant }",|
        && |"Material": "{ ls_body-Material }",|
        && |"Plant": "{ ls_body-Plant }",|
        && |"EngineeringChangeDocument": "{ ls_body-EngineeringChangeDocument }",|

        && |"BillOfMaterialItemNumber": "{ ls_body-BillOfMaterialItemNumber }",|
        && |"BillOfMaterialItemCategory": "{ ls_body-BillOfMaterialItemCategory }",|
        && |"BillOfMaterialComponent": "{ ls_body-BillOfMaterialComponent }",|
        && |"BillOfMaterialItemQuantity": "{ ls_body-BillOfMaterialItemQuantity }",|
        && |"BillOfMaterialItemUnit": "{ ls_body-BillOfMaterialItemUnit }",|
        && |"IsNetScrap": { ls_body-IsNetScrap },|
        && |"ComponentScrapInPercent": "{ ls_body-ComponentScrapInPercent }",|
        && |"BOMItemIsCostingRelevant": "{ ls_body-BOMItemIsCostingRelevant }",|
        && |"SpecialProcurementType": "{ ls_body-SpecialProcurementType }",|
        && |"IsProductionRelevant": { ls_body-IsProductionRelevant },|
        && |"ProdOrderIssueLocation": "{ ls_body-ProdOrderIssueLocation }"|
        && |\}|.
    DATA(lv_result) = zcl_call_api_zbom_rp=>call_api(
                        iv_body     = lv_body
                        iv_endpoint = lv_endpoint
                        iv_method   = 'POST'
                      ).
    IF zcl_call_api_zbom_rp=>code = 200
        OR zcl_call_api_zbom_rp=>code = 201
        OR zcl_call_api_zbom_rp=>code = 202
        OR zcl_call_api_zbom_rp=>code = 204.
      " ── Success ──────────────────────────────────────────────────
      cs_data-messagetype = 'S'.
      cs_data-message     = 'Success'.
    ELSE.
      " ── Error — parse message từ response JSON ───────────────────
      cs_data-messagetype = 'E'.

      " Thử parse error message từ response
      " Response format: {"error":{"message":{"value":"..."}}}
      DATA(lv_msg) = ||.
      FIND REGEX '"value"\s*:\s*"([^"]*)"' IN lv_result SUBMATCHES lv_msg.
      IF sy-subrc = 0 AND lv_msg IS NOT INITIAL.
        cs_data-message = lv_msg.
      ELSE.
        cs_data-message = |API Error HTTP { zcl_call_api_zbom_rp=>code }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
