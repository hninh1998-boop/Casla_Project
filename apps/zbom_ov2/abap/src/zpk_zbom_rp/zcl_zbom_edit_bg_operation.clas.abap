CLASS zcl_zbom_edit_bg_operation DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_bgmc_op_single_tx_uncontr.

    " Reuse type từ handler — define lại ở đây để độc lập
    TYPES: BEGIN OF ty_bg_item,
             material                     TYPE matnr,
             plant                        TYPE werks_d,
             billofmaterialvariantusage   TYPE c LENGTH 1,
             billofmaterialvariant        TYPE c LENGTH 2,
             salesorder                   TYPE vbeln,
             salesorderitem               TYPE posnr,
             billofmaterialitemnumber     TYPE c LENGTH 4,
             billofmaterialitemnodenumber TYPE stlkn,
             bomiteminternalchangecount   TYPE cim_count,
             billofmaterial               TYPE c LENGTH 8,
             billofmaterialcategory       TYPE stlty,
             component                    TYPE zabs_edit_massChange-Component,
             componentquantity            TYPE zabs_edit_massChange-ComponentQuantity,
             componentscrap               TYPE zabs_edit_massChange-ComponentScrap,
           END OF ty_bg_item.

    TYPES tt_bg_items TYPE TABLE OF ty_bg_item WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING it_items TYPE tt_bg_items.

  PRIVATE SECTION.
    DATA mt_items TYPE tt_bg_items.

ENDCLASS.



CLASS ZCL_ZBOM_EDIT_BG_OPERATION IMPLEMENTATION.


  METHOD constructor.
    mt_items = it_items.
  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.
    " Controlled variant: switch sang save phase trước khi làm việc
    " vì chúng ta chỉ gọi HTTP API (không phải EML) → dùng save phase
*    cl_abap_tx=>save( ).

    LOOP AT mt_items INTO DATA(ls_item).

      DATA lv_endpoint TYPE string.
      DATA lv_body     TYPE string.
      CLEAR: lv_endpoint, lv_body.

      " ── Build endpoint theo category ───────────────────────────────
      IF ls_item-billofmaterialcategory = 'K'.
        lv_endpoint =
          '/sap/opu/odata/sap/API_ORDER_BILL_OF_MATERIAL_SRV'
          && |/SalesOrderBOMItem(BillOfMaterial='{ ls_item-billofmaterial }',|
          && |BillOfMaterialCategory='{ ls_item-billofmaterialcategory }',|
          && |BillOfMaterialVariant='{ ls_item-billofmaterialvariant }',|
          && |BillOfMaterialItemNodeNumber='{ ls_item-billofmaterialitemnodenumber }',|
          && |HeaderChangeDocument='',|
          && |Material='{ ls_item-material }',|
          && |Plant='{ ls_item-plant }'|
          && ')'.

      ELSEIF ls_item-billofmaterialcategory = 'M'.
*        lv_endpoint =
*          '/sap/opu/odata/sap/API_BILL_OF_MATERIAL_SRV'
*          && |/MaterialBOMItem(BillOfMaterial='{ ls_item-billofmaterial }',|
*          && |BillOfMaterialCategory='{ ls_item-billofmaterialcategory }',|
*          && |BillOfMaterialVariant='{ ls_item-billofmaterialvariant }',|
*          && |BillOfMaterialItemNodeNumber='{ ls_item-billofmaterialitemnodenumber }',|
*          && |HeaderChangeDocument='',|
*          && |Material='{ ls_item-material }',|
*          && |Plant='{ ls_item-plant }'|
*          && ')'.
*
*      ELSE.
*        CONTINUE. " Category không hỗ trợ
      ENDIF.

      " ── Build body ──────────────────────────────────────────────────
      lv_body =
        |\{|
        && |"BillOfMaterialComponent": "{ ls_item-component }",|
        && |"BillOfMaterialItemQuantity": "{ ls_item-componentquantity }",|
        && |"ComponentScrapInPercent": "{ ls_item-componentscrap }"|
        && |\}|.

      " ── Gọi API ─────────────────────────────────────────────────────
      zcl_call_api_kbom_rp=>call_api(
        iv_body     = lv_body
        iv_endpoint = lv_endpoint
        iv_method   = 'PATCH'
      ).

    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
