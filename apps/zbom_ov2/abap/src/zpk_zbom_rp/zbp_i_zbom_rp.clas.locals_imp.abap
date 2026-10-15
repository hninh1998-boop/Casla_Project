CLASS lhc_ZbomMassChange DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR ZbomMassChange RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ZbomMassChange RESULT result.

    METHODS create FOR MODIFY
      IMPORTING entities FOR CREATE ZbomMassChange.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE ZbomMassChange.

    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE ZbomMassChange.

    METHODS read FOR READ
      IMPORTING keys FOR READ ZbomMassChange RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK ZbomMassChange.

    METHODS AddMassChange FOR MODIFY
      IMPORTING keys FOR ACTION ZbomMassChange~AddMassChange.

    METHODS DeleteMassChange FOR MODIFY
      IMPORTING keys FOR ACTION ZbomMassChange~DeleteMassChange.

    METHODS EditMassChange FOR MODIFY
      IMPORTING keys FOR ACTION ZbomMassChange~EditMassChange.

    METHODS MassChange FOR MODIFY
      IMPORTING keys FOR ACTION ZbomMassChange~MassChange.

    TYPES: BEGIN OF ty_data_edit,
             BillOfMaterialComponent    TYPE zi_zbom_rp-BillOfMaterialComponent,
             BillOfMaterialItemQuantity TYPE zi_zbom_rp-BillOfMaterialItemQuantity,
             ComponentUOM               TYPE zi_zbom_rp-BillOfMaterialItemUnit,
             ComponentScrapInPercent    TYPE zi_zbom_rp-ComponentScrapInPercent,
             SpecialProcurementType     TYPE zi_zbom_rp-SpecialProcurementType,
             BOMItemIsCostingRelevant   TYPE zi_zbom_rp-BOMItemIsCostingRelevant,
             ProdOrderIssueLocation     TYPE zi_zbom_rp-ProdOrderIssueLocation,
           END OF ty_data_edit.

    TYPES: tt_keys_edit TYPE TABLE FOR ACTION IMPORT zi_zbom_rp\\zbommasschange~editmasschange,
           tt_keys_del  TYPE TABLE FOR ACTION IMPORT zi_zbom_rp\\zbommasschange~deletemasschange,
           ty_key_edit  TYPE STRUCTURE FOR ACTION IMPORT zi_zbom_rp\\zbommasschange~editmasschange,
           tt_reported  TYPE RESPONSE FOR REPORTED EARLY zi_zbom_rp,
           tt_failed    TYPE RESPONSE FOR FAILED EARLY zi_zbom_rp.

    METHODS edit_mass_foreground
      IMPORTING
        keys     TYPE tt_keys_edit
      CHANGING
        reported TYPE tt_reported
        failed   TYPE tt_failed.

    METHODS edit_mass_background
      IMPORTING
        keys     TYPE tt_keys_edit
      CHANGING
        reported TYPE tt_reported
        failed   TYPE tt_failed.

    METHODS del_mass_foreground
      IMPORTING
        keys     TYPE tt_keys_del
      CHANGING
        reported TYPE tt_reported
        failed   TYPE tt_failed.

    METHODS del_mass_background
      IMPORTING
        keys     TYPE tt_keys_del
      CHANGING
        reported TYPE tt_reported
        failed   TYPE tt_failed.

    METHODS get_data_edit
      IMPORTING
        key      TYPE ty_key_edit
      EXPORTING
        es_data  TYPE ty_data_edit
        ev_subrc TYPE i.

    METHODS get_param_edit_foreground
      IMPORTING
        key                       TYPE ty_key_edit
        is_data                   TYPE ty_data_edit
      EXPORTING
        ev_quantity               TYPE zi_zbom_rp-billofmaterialitemquantity
        ev_ComponentUOM           TYPE msehiunit
        ev_component              TYPE string
        ev_ProdOrderIssueLocation TYPE zi_zbom_rp-ProdOrderIssueLocation
        ev_error                  TYPE abap_boolean
      CHANGING
        reported                  TYPE tt_reported
        failed                    TYPE tt_failed.

    METHODS call_api_edit_foreground_k
      IMPORTING
        key                       TYPE ty_key_edit
        iv_quantity               TYPE zi_zbom_rp-billofmaterialitemquantity
        iv_componentuom           TYPE msehiunit
        iv_component              TYPE string
        iv_ProdOrderIssueLocation TYPE zi_zbom_rp-ProdOrderIssueLocation
      EXPORTING
        ev_error                  TYPE abap_boolean
      CHANGING
        reported                  TYPE tt_reported
        failed                    TYPE tt_failed.

    METHODS call_api_edit_foreground_m
      IMPORTING
        key                       TYPE ty_key_edit
        iv_quantity               TYPE zi_zbom_rp-billofmaterialitemquantity
        iv_componentuom           TYPE msehiunit
        iv_component              TYPE string
        iv_ProdOrderIssueLocation TYPE zi_zbom_rp-ProdOrderIssueLocation
      EXPORTING
        ev_error                  TYPE abap_boolean
      CHANGING
        reported                  TYPE tt_reported
        failed                    TYPE tt_failed.

    METHODS call_api_edit_foreground
      IMPORTING
        key                       TYPE ty_key_edit
        iv_quantity               TYPE zi_zbom_rp-billofmaterialitemquantity
        iv_componentuom           TYPE msehiunit
        iv_component              TYPE string
        iv_ProdOrderIssueLocation TYPE zi_zbom_rp-ProdOrderIssueLocation
      EXPORTING
        ev_error                  TYPE abap_boolean
      CHANGING
        reported                  TYPE tt_reported
        failed                    TYPE tt_failed.

    METHODS get_param_edit_background
      IMPORTING
        key                         TYPE ty_key_edit
        is_data                     TYPE ty_data_edit
      EXPORTING
        ev_quantity                 TYPE zi_zbom_rp-billofmaterialitemquantity
        ev_SpecialProcurementType   TYPE zabs_edit_massChange-SpecialProcurementType
        ev_BOMItemIsCostingRelevant TYPE zabs_edit_massChange-BOMItemIsCostingRelevant
        ev_ComponentUOM             TYPE msehiunit
        ev_component                TYPE string
        ev_ProdOrderIssueLocation   TYPE zi_zbom_rp-ProdOrderIssueLocation
        ev_error                    TYPE abap_boolean
      CHANGING
        reported                    TYPE tt_reported
        failed                      TYPE tt_failed.

    METHODS append_buffer_edit_background
      IMPORTING
        key                         TYPE ty_key_edit
        iv_hdrid                    TYPE sysuuid_x16
        iv_quantity                 TYPE zi_zbom_rp-billofmaterialitemquantity
        iv_SpecialProcurementType   TYPE zabs_edit_massChange-SpecialProcurementType
        iv_BOMItemIsCostingRelevant TYPE zabs_edit_massChange-BOMItemIsCostingRelevant
        iv_ComponentUOM             TYPE msehiunit
        iv_component                TYPE string
        iv_prodorderissuelocation   TYPE zi_zbom_rp-prodorderissuelocation
      CHANGING
        ct_bg_jobs                  TYPE zcl_zbom_bg_buffer=>tt_bg_items.

ENDCLASS.

CLASS lhc_ZbomMassChange IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
    SELECT SINGLE uname
      FROM ztb_zbom_auth
      WHERE uname = @sy-uname
      INTO @DATA(ls_auth).
    result = VALUE #(
      %action-EditMassChange   = COND #( WHEN sy-subrc = 0
                                          THEN if_abap_behv=>auth-allowed
                                          ELSE if_abap_behv=>auth-unauthorized )
      %action-DeleteMassChange = COND #( WHEN sy-subrc = 0
                                          THEN if_abap_behv=>auth-allowed
                                          ELSE if_abap_behv=>auth-unauthorized )
                                          ).
  ENDMETHOD.

  METHOD create.
  ENDMETHOD.

  METHOD update.
  ENDMETHOD.

  METHOD delete.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD AddMassChange.
  ENDMETHOD.

  METHOD DeleteMassChange.
    "Delete - Chạy Fore Ground - API
    IF keys[ 1 ]-%param-RunNow IS NOT INITIAL.
      del_mass_foreground( EXPORTING keys     = keys
                            CHANGING reported = reported
                                     failed   = failed ).
    ENDIF.

    "Delete - Chạy Back Ground
    IF keys[ 1 ]-%param-RunInBackground IS NOT INITIAL.
      del_mass_background( EXPORTING keys     = keys
                            CHANGING reported = reported
                                     failed   = failed ).
    ENDIF.
  ENDMETHOD.















  METHOD EditMassChange.
    "Chạy Fore Ground
    IF keys[ 1 ]-%param-RunNow IS NOT INITIAL.
      edit_mass_foreground( EXPORTING keys     = keys
                             CHANGING reported = reported
                                      failed   = failed ).
    ENDIF.

    "Chạy Back Ground
    IF keys[ 1 ]-%param-RunInBackground IS NOT INITIAL.
      edit_mass_background( EXPORTING keys     = keys
                             CHANGING reported = reported
                                      failed   = failed ).
    ENDIF.
  ENDMETHOD.
















  METHOD MassChange.
  ENDMETHOD.













  METHOD edit_mass_foreground.
    LOOP AT keys INTO DATA(key).
      get_data_edit( EXPORTING key      = key
                                IMPORTING es_data  = DATA(ls_data)
                                          ev_subrc = DATA(lv_subrc) ).
      IF lv_subrc = 0.
        get_param_edit_foreground( EXPORTING key                       = key
                                             is_data                   = ls_data
                                   IMPORTING ev_quantity               = DATA(lv_quantity)
                                             ev_componentuom           = DATA(lv_componentuom)
                                             ev_component              = DATA(lv_component)
                                             ev_ProdOrderIssueLocation = DATA(lv_ProdOrderIssueLocation)
                                             ev_error                  = DATA(lv_error)
                                    CHANGING reported                  = reported
                                             failed                    = failed ).
        IF lv_error IS NOT INITIAL.
          CLEAR: lv_error.
          CONTINUE.
        ENDIF.
      ENDIF.

      "Chạy API
      call_api_edit_foreground( EXPORTING key                          = key
                                          iv_quantity                  = lv_quantity
                                          iv_componentuom              = lv_componentuom
                                          iv_component                 = lv_component
                                          iv_ProdOrderIssueLocation    = lv_ProdOrderIssueLocation
                                IMPORTING ev_error                     = lv_error
                                 CHANGING reported                     = reported
                                          failed                       = failed ).

      IF lv_error IS NOT INITIAL.
        CLEAR: lv_error.
        CONTINUE.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

















  METHOD edit_mass_background.
    TRY.
        DATA(lv_hdrid) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        "handle exception
    ENDTRY.

    LOOP AT keys INTO DATA(key).
      get_data_edit( EXPORTING key      = key
                     IMPORTING es_data  = DATA(ls_data)
                               ev_subrc = DATA(lv_subrc) ).
      IF lv_subrc <> 0.
        CLEAR: lv_subrc.
        CONTINUE.
      ENDIF.

      get_param_edit_background( EXPORTING key                         = key
                                           is_data                     = ls_data
                                 IMPORTING ev_quantity                 = DATA(lv_quantity)
                                           ev_specialprocurementtype   = DATA(lv_specialprocurementtype)
                                           ev_bomitemiscostingrelevant = DATA(lv_bomitemiscostingrelevant)
                                           ev_componentuom             = DATA(lv_componentuom)
                                           ev_component                = DATA(lv_component)
                                           ev_prodorderissuelocation   = DATA(lv_prodorderissuelocation)
                                           ev_error                    = DATA(lv_error)
                                  CHANGING reported                    = reported
                                           failed                      = failed ).
      IF lv_error IS NOT INITIAL.
        CLEAR: lv_error.
        CONTINUE.
      ENDIF.

      append_buffer_edit_background( EXPORTING key                         = key
                                               iv_hdrid                    = lv_hdrid
                                               iv_quantity                 = lv_quantity
                                               iv_specialprocurementtype   = lv_specialprocurementtype
                                               iv_bomitemiscostingrelevant = lv_bomitemiscostingrelevant
                                               iv_componentuom             = lv_componentuom
                                               iv_component                = lv_component
                                               iv_prodorderissuelocation   = lv_prodorderissuelocation
                                      CHANGING ct_bg_jobs                  = zcl_zbom_bg_buffer=>gt_bg_jobs ).
    ENDLOOP.
  ENDMETHOD.




















  METHOD del_mass_foreground.
    LOOP AT keys INTO DATA(key).
      DATA(lv_tabix) = sy-tabix.

      IF key-%key-BillOfMaterialCategory = 'K'.
        DATA: lv_endpoint_kbom TYPE string.

        lv_endpoint_kbom =
          '/sap/opu/odata/sap/API_ORDER_BILL_OF_MATERIAL_SRV'
          && |/SalesOrderBOMItem(BillOfMaterial='{ key-%key-BillOfMaterial }',|
          && |BillOfMaterialCategory='{ key-%key-BillOfMaterialCategory }',|
          && |BillOfMaterialVariant='{ key-%key-BillOfMaterialVariant }',|
          && |BillOfMaterialItemNodeNumber='{ key-%key-BillOfMaterialItemNodeNumber }',|
          && |HeaderChangeDocument='',|
          && |Material='{ key-%key-Material }',|
          && |Plant='{ key-%key-Plant }'|
          && ')'.

        DATA(lv_result_kbom) = zcl_call_api_kbom_rp=>call_api(
                                 iv_endpoint = lv_endpoint_kbom
                                 iv_method   = 'DELETE'
                               ).
        IF zcl_call_api_kbom_rp=>code = 200
            OR zcl_call_api_kbom_rp=>code = 201
            OR zcl_call_api_kbom_rp=>code = 202
            OR zcl_call_api_kbom_rp=>code = 204.
        ELSE.
          DATA(lv_error_msg) = |Line { lv_tabix }: HTTP { zcl_call_api_kbom_rp=>code }|.
          DATA(lv_search) = `"value":"`.
          DATA(lv_pos) = find( val = lv_result_kbom sub = lv_search ).
          IF lv_pos >= 0.
            DATA(lv_start) = lv_pos + strlen( lv_search ).
            DATA(lv_end) = find( val = lv_result_kbom off = lv_start sub = `"` ).
            IF lv_end > lv_start.
              lv_error_msg = |Line { lv_tabix }: { substring( val = lv_result_kbom off = lv_start len = lv_end - lv_start ) }|.
            ENDIF.
          ENDIF.

          APPEND VALUE #(
            %key = key-%key
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = lv_error_msg )
          ) TO reported-zbommasschange.
          APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
          CONTINUE.
        ENDIF.
      ELSEIF key-%key-BillOfMaterialCategory = 'M'.
        DATA: lv_endpoint_mbom TYPE string.

        lv_endpoint_mbom =
            '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2'
            && |/MaterialBOMItem(BillOfMaterial='{ key-%key-BillOfMaterial }',|
            && |BillOfMaterialCategory='{ key-%key-BillOfMaterialCategory }',|
            && |BillOfMaterialVariant='{ key-%key-BillOfMaterialVariant }',|
            && |BillOfMaterialVersion='',|
            && |BillOfMaterialItemNodeNumber='{ key-%key-BillOfMaterialItemNodeNumber }',|
            && |HeaderChangeDocument='',|
            && |Material='{ key-%key-Material }',|
            && |Plant='{ key-%key-Plant }'|
            && ')'.

        DATA(lv_result_mbom) = zcl_call_api_kbom_rp=>call_api(
                                 iv_endpoint = lv_endpoint_mbom
                                 iv_method   = 'DELETE'
                               ).
        IF zcl_call_api_kbom_rp=>code = 200
            OR zcl_call_api_kbom_rp=>code = 201
            OR zcl_call_api_kbom_rp=>code = 202
            OR zcl_call_api_kbom_rp=>code = 204.
        ELSE.
          lv_error_msg = |Line { lv_tabix }: HTTP { zcl_call_api_kbom_rp=>code }|.
          lv_search = `"value":"`.
          lv_pos = find( val = lv_result_mbom sub = lv_search ).
          IF lv_pos >= 0.
            lv_start = lv_pos + strlen( lv_search ).
            lv_end = find( val = lv_result_mbom off = lv_start sub = `"` ).
            IF lv_end > lv_start.
              lv_error_msg = |Line { lv_tabix }: { substring( val = lv_result_mbom off = lv_start len = lv_end - lv_start ) }|.
            ENDIF.
          ENDIF.

          APPEND VALUE #(
            %key = key-%key
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = lv_error_msg )
          ) TO reported-zbommasschange.
          APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
          CONTINUE.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.














  METHOD del_mass_background.
    TRY.
        DATA(lv_hdrid) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        "handle exception
    ENDTRY.

    LOOP AT keys INTO DATA(key_bg).
      " ── Append vào buffer ────────────────────────────────────────
      TRY.
          APPEND VALUE #(
            hdrid                        = lv_hdrid
            itmid                        = cl_system_uuid=>create_uuid_x16_static( )
            material                     = key_bg-%key-material
            plant                        = key_bg-%key-plant
            billofmaterialvariantusage   = key_bg-%key-billofmaterialvariantusage
            billofmaterialvariant        = key_bg-%key-billofmaterialvariant
            salesorder                   = key_bg-%key-salesorder
            salesorderitem               = key_bg-%key-salesorderitem
            billofmaterialitemnumber     = key_bg-%key-billofmaterialitemnumber
            billofmaterialitemnodenumber = key_bg-%key-billofmaterialitemnodenumber
            bomiteminternalchangecount   = key_bg-%key-bomiteminternalchangecount
            billofmaterial               = key_bg-%key-billofmaterial
            billofmaterialcategory       = key_bg-%key-billofmaterialcategory
            jobtext                      = key_bg-%param-jobtext
          ) TO zcl_zbom_bg_buffer=>gt_bg_jobs.
        CATCH cx_uuid_error.
          "handle exception
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.



















  METHOD get_data_edit.
    SELECT SINGLE FROM zi_zbom_rp
    FIELDS
        BillOfMaterialComponent,
        BillOfMaterialItemQuantity,
        BillOfMaterialItemUnit AS ComponentUOM,
        ComponentScrapInPercent,
        SpecialProcurementType,
        BOMItemIsCostingRelevant,
        ProdOrderIssueLocation
    WHERE
          material                     = @key-%key-material AND
          plant                        = @key-%key-plant AND
          billofmaterialvariantusage   = @key-%key-billofmaterialvariantusage AND
          billofmaterialvariant        = @key-%key-billofmaterialvariant AND
          salesorder                   = @key-%key-salesorder AND
          salesorderitem               = @key-%key-salesorderitem AND
          billofmaterialitemnumber     = @key-%key-billofmaterialitemnumber AND
          billofmaterialitemnodenumber = @key-%key-billofmaterialitemnodenumber AND
          bomiteminternalchangecount   = @key-%key-bomiteminternalchangecount AND
          billofmaterial               = @key-%key-billofmaterial AND
          billofmaterialcategory       = @key-%key-billofmaterialcategory
    INTO @es_data.

    ev_subrc = sy-subrc.
  ENDMETHOD.










  METHOD get_param_edit_foreground.
    "Validate param
    ev_quantity = COND #( WHEN key-%param-ComponentQuantity IS INITIAL
                          THEN is_data-BillOfMaterialItemQuantity
                          ELSE key-%param-ComponentQuantity ).

    IF key-%param-EditComponentUOM IS NOT INITIAL.
      ev_ComponentUOM = COND msehiunit( WHEN key-%param-ComponentUOM IS NOT INITIAL
                                              THEN key-%param-ComponentUOM
                                              ELSE is_data-ComponentUOM ).

      SELECT SINGLE FROM I_UnitOfMeasure
      FIELDS UnitOfMeasure
      WHERE UnitOfMeasure = @ev_ComponentUOM
      INTO @DATA(lv_ComponentUOM_valid).
      IF sy-subrc <> 0.
        APPEND VALUE #(
          %key = key-%key
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Component UOM { key-%param-ComponentUOM } không tồn tại| )
        ) TO reported-zbommasschange.
        APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
        ev_error = 'X'.
        RETURN.
      ENDIF.
    ELSE.
      ev_ComponentUOM = is_data-ComponentUOM.
    ENDIF.

    "Validate component
    IF key-%param-Component IS INITIAL.
      ev_component = |{ is_data-BillOfMaterialComponent WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
    ELSE.
      ev_component = |{ key-%param-Component WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
      SELECT SINGLE FROM i_product
      FIELDS Product
      WHERE Product = @ev_component
      INTO @DATA(lv_component_valid).
      IF sy-subrc <> 0.
        APPEND VALUE #(
          %key = key-%key
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Component { key-%param-component } không tồn tại| )
        ) TO reported-zbommasschange.
        APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
        ev_error = 'X'.
        RETURN.
      ENDIF.
    ENDIF.

    "Issue Location
    IF key-%param-ProdOrderIssueLocation IS INITIAL.
      ev_ProdOrderIssueLocation = |{ is_data-ProdOrderIssueLocation ALPHA = IN }|.
    ELSE.
      ev_ProdOrderIssueLocation = |{ key-%param-ProdOrderIssueLocation ALPHA = IN }|.
*      SELECT SINGLE FROM I_StorageLocation
*      FIELDS
*        plant,
*        StorageLocation
*      WHERE
*        Plant = @key-%key-Plant
*        AND StorageLocation = @ev_prodorderissuelocation
*      INTO @DATA(lv_sloc_valid).
*      IF sy-subrc <> 0.
*        APPEND VALUE #(
*          %key = key-%key
*          %msg = new_message_with_text(
*                   severity = if_abap_behv_message=>severity-error
*                   text     = |SLOC { key-%param-ProdOrderIssueLocation } không tồn tại| )
*        ) TO reported-zbommasschange.
*        APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
*        ev_error = 'X'.
*        RETURN.
*      ENDIF.
    ENDIF.
  ENDMETHOD.













  METHOD call_api_edit_foreground_k.
    DATA: lv_endpoint_kbom TYPE string,
          lv_body_kbom     TYPE string.

    lv_endpoint_kbom =
      '/sap/opu/odata/sap/API_ORDER_BILL_OF_MATERIAL_SRV'
      && |/SalesOrderBOMItem(BillOfMaterial='{ key-%key-BillOfMaterial }',|
      && |BillOfMaterialCategory='{ key-%key-BillOfMaterialCategory }',|
      && |BillOfMaterialVariant='{ key-%key-BillOfMaterialVariant }',|
      && |BillOfMaterialItemNodeNumber='{ key-%key-BillOfMaterialItemNodeNumber }',|
      && |HeaderChangeDocument='',|
      && |Material='{ key-%key-Material }',|
      && |Plant='{ key-%key-Plant }'|
      && ')'.

    " Chỉ đưa field vào body nếu flag = true
    lv_body_kbom = |\{|.
    IF key-%param-EditComponent = abap_true.
      lv_body_kbom = lv_body_kbom && |"BillOfMaterialComponent": "{ iv_component }",|.
    ENDIF.
    IF key-%param-EditComponentQuantity = abap_true.
      lv_body_kbom = lv_body_kbom && |"BillOfMaterialItemQuantity": "{ iv_quantity }",|.
    ENDIF.
    IF key-%param-EditComponentScrap = abap_true.
      lv_body_kbom = lv_body_kbom && |"ComponentScrapInPercent": "{ key-%param-ComponentScrap }",|.
    ENDIF.
    IF key-%param-EditSpecialProcurementType = abap_true.
      lv_body_kbom = lv_body_kbom && |"SpecialProcurementType": "{ key-%param-SpecialProcurementType }",|.
    ENDIF.
    IF key-%param-EditBOMItemIsCostingRelevant = abap_true.
      lv_body_kbom = lv_body_kbom && |"BOMItemIsCostingRelevant": "{ key-%param-BOMItemIsCostingRelevant }",|.
    ENDIF.
    IF key-%param-EditComponentUOM = abap_true.
      lv_body_kbom = lv_body_kbom && |"BillOfMaterialItemUnit": "{ iv_ComponentUOM }",|.
    ENDIF.
    IF key-%param-EditProdOrderIssueLocation = abap_true.
      lv_body_kbom = lv_body_kbom && |"ProdOrderIssueLocation": "{ iv_prodorderissuelocation }",|.
    ENDIF.
    " Bỏ dấu phẩy cuối nếu có
    IF lv_body_kbom CS ','.
      lv_body_kbom = substring( val = lv_body_kbom len = strlen( lv_body_kbom ) - 1 ).
    ENDIF.
    lv_body_kbom = lv_body_kbom && |\}|.

    DATA(lv_result_kbom) = zcl_call_api_kbom_rp=>call_api(
                             iv_body     = lv_body_kbom
                             iv_endpoint = lv_endpoint_kbom
                             iv_method   = 'PATCH'
                           ).
    IF zcl_call_api_kbom_rp=>code = 200
        OR zcl_call_api_kbom_rp=>code = 201
        OR zcl_call_api_kbom_rp=>code = 202
        OR zcl_call_api_kbom_rp=>code = 204.
    ELSE.
      DATA(lv_error_msg) = |Line { key-%param-lineitem }: HTTP { zcl_call_api_kbom_rp=>code }|.
      DATA(lv_search) = `"value":"`.
      DATA(lv_pos) = find( val = lv_result_kbom sub = lv_search ).
      IF lv_pos >= 0.
        DATA(lv_start) = lv_pos + strlen( lv_search ).
        DATA(lv_end) = find( val = lv_result_kbom off = lv_start sub = `"` ).
        IF lv_end > lv_start.
          lv_error_msg = |Line { key-%param-lineitem }: { substring( val = lv_result_kbom off = lv_start len = lv_end - lv_start ) }|.
        ENDIF.
      ENDIF.

      APPEND VALUE #(
        %key = key-%key
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = lv_error_msg )
      ) TO reported-zbommasschange.
      APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
      ev_error = 'X'.
      RETURN.
    ENDIF.
  ENDMETHOD.












  METHOD call_api_edit_foreground_m.
    DATA: lv_endpoint_mbom TYPE string,
          lv_body_mbom     TYPE string.

    lv_endpoint_mbom =
        '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2'
        && |/MaterialBOMItem(BillOfMaterial='{ key-%key-BillOfMaterial }',|
        && |BillOfMaterialCategory='{ key-%key-BillOfMaterialCategory }',|
        && |BillOfMaterialVariant='{ key-%key-BillOfMaterialVariant }',|
        && |BillOfMaterialVersion='',|
        && |BillOfMaterialItemNodeNumber='{ key-%key-BillOfMaterialItemNodeNumber }',|
        && |HeaderChangeDocument='',|
        && |Material='{ key-%key-Material }',|
        && |Plant='{ key-%key-Plant }'|
        && ')'.

    " Chỉ đưa field vào body nếu flag = true
    lv_body_mbom = |\{|.
    IF key-%param-EditComponent = abap_true.
      lv_body_mbom = lv_body_mbom && |"BillOfMaterialComponent": "{ iv_component }",|.
    ENDIF.
    IF key-%param-EditComponentQuantity = abap_true.
      lv_body_mbom = lv_body_mbom && |"BillOfMaterialItemQuantity": "{ iv_quantity }",|.
    ENDIF.
    IF key-%param-EditComponentScrap = abap_true.
      lv_body_mbom = lv_body_mbom && |"ComponentScrapInPercent": "{ key-%param-ComponentScrap }",|.
    ENDIF.
    IF key-%param-EditSpecialProcurementType = abap_true.
      lv_body_mbom = lv_body_mbom && |"SpecialProcurementType": "{ key-%param-SpecialProcurementType }",|.
    ENDIF.
    IF key-%param-EditBOMItemIsCostingRelevant = abap_true.
      lv_body_mbom = lv_body_mbom && |"BOMItemIsCostingRelevant": "{ key-%param-BOMItemIsCostingRelevant }",|.
    ENDIF.
    IF key-%param-EditComponentUOM = abap_true.
      lv_body_mbom = lv_body_mbom && |"BillOfMaterialItemUnit": "{ iv_ComponentUOM }",|.
    ENDIF.
    IF key-%param-EditProdOrderIssueLocation = abap_true.
      lv_body_mbom = lv_body_mbom && |"ProdOrderIssueLocation": "{ iv_ProdOrderIssueLocation }",|.
    ENDIF.
    " Bỏ dấu phẩy cuối nếu có
    IF lv_body_mbom CS ','.
      lv_body_mbom = substring( val = lv_body_mbom len = strlen( lv_body_mbom ) - 1 ).
    ENDIF.
    lv_body_mbom = lv_body_mbom && |\}|.

    DATA(lv_result_mbom) = zcl_call_api_kbom_rp=>call_api(
                             iv_body     = lv_body_mbom
                             iv_endpoint = lv_endpoint_mbom
                             iv_method   = 'PATCH'
                           ).
    IF zcl_call_api_kbom_rp=>code = 200
        OR zcl_call_api_kbom_rp=>code = 201
        OR zcl_call_api_kbom_rp=>code = 202
        OR zcl_call_api_kbom_rp=>code = 204.
    ELSE.
      DATA(lv_error_msg) = |Line { key-%param-lineitem }: HTTP { zcl_call_api_kbom_rp=>code }|.
      DATA(lv_search) = `"value":"`.
      DATA(lv_pos) = find( val = lv_result_mbom sub = lv_search ).
      IF lv_pos >= 0.
        DATA(lv_start) = lv_pos + strlen( lv_search ).
        DATA(lv_end) = find( val = lv_result_mbom off = lv_start sub = `"` ).
        IF lv_end > lv_start.
          lv_error_msg = |Line { key-%param-lineitem }: { substring( val = lv_result_mbom off = lv_start len = lv_end - lv_start ) }|.
        ENDIF.
      ENDIF.

      APPEND VALUE #(
        %key = key-%key
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = lv_error_msg )
      ) TO reported-zbommasschange.
      APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
      ev_error = 'X'.
      RETURN.
    ENDIF.
  ENDMETHOD.











  METHOD call_api_edit_foreground.
    IF key-%key-BillOfMaterialCategory = 'K'.
      call_api_edit_foreground_k( EXPORTING key                       = key
                                            iv_quantity               = iv_quantity
                                            iv_componentuom           = iv_componentuom
                                            iv_component              = iv_component
                                            iv_ProdOrderIssueLocation = iv_ProdOrderIssueLocation
                                  IMPORTING ev_error                  = ev_error
                                  CHANGING reported                   = reported
                                            failed                    = failed ).
      IF ev_error IS NOT INITIAL.
        RETURN.
      ENDIF.

    ELSEIF key-%key-BillOfMaterialCategory = 'M'.
      call_api_edit_foreground_m( EXPORTING key                       = key
                                            iv_quantity               = iv_quantity
                                            iv_componentuom           = iv_componentuom
                                            iv_component              = iv_component
                                            iv_ProdOrderIssueLocation = iv_ProdOrderIssueLocation
                                  IMPORTING ev_error                  = ev_error
                                  CHANGING reported                   = reported
                                            failed                    = failed ).
      IF ev_error IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.
  ENDMETHOD.












  METHOD get_param_edit_background.
    "Validate param
    ev_quantity = COND #( WHEN key-%param-ComponentQuantity IS INITIAL
                          THEN is_data-BillOfMaterialItemQuantity
                          ELSE key-%param-ComponentQuantity ).
    IF key-%param-EditSpecialProcurementType IS NOT INITIAL.
      ev_SpecialProcurementType = key-%param-SpecialProcurementType.
    ENDIF.
    IF key-%param-EditBOMItemIsCostingRelevant IS NOT INITIAL.
      ev_BOMItemIsCostingRelevant = key-%param-BOMItemIsCostingRelevant.
    ENDIF.

    IF key-%param-EditComponentUOM IS NOT INITIAL.
      ev_ComponentUOM = COND #( WHEN key-%param-ComponentUOM IS NOT INITIAL
                                THEN key-%param-ComponentUOM
                                ELSE is_data-ComponentUOM ).

      SELECT SINGLE FROM I_UnitOfMeasure
      FIELDS UnitOfMeasure
      WHERE UnitOfMeasure = @ev_ComponentUOM
      INTO @DATA(lv_ComponentUOM_valid).
      IF sy-subrc <> 0.
        APPEND VALUE #(
          %key = key-%key
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Component UOM { key-%param-ComponentUOM } không tồn tại| )
        ) TO reported-zbommasschange.
        APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
        ev_error = 'X'.
        RETURN.
      ENDIF.
    ELSE.
      ev_ComponentUOM = is_data-ComponentUOM.
    ENDIF.


    "Validate component
    IF key-%param-Component IS INITIAL.
      ev_component = |{ is_data-BillOfMaterialComponent WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
    ELSE.
      ev_component = |{ key-%param-Component WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
      SELECT SINGLE FROM i_product
      FIELDS Product
      WHERE Product = @ev_component
      INTO @DATA(lv_component_valid).
      IF sy-subrc <> 0.
        APPEND VALUE #(
          %key = key-%key
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |Component { key-%param-component } không tồn tại| )
        ) TO reported-zbommasschange.
        APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
        ev_error = 'X'.
        RETURN.
      ENDIF.
    ENDIF.

    "Issue Location
    IF key-%param-ProdOrderIssueLocation IS INITIAL.
      ev_ProdOrderIssueLocation = |{ is_data-ProdOrderIssueLocation ALPHA = IN }|.
    ELSE.
      ev_ProdOrderIssueLocation = |{ key-%param-ProdOrderIssueLocation ALPHA = IN }|.
*      SELECT SINGLE FROM I_StorageLocation
*      FIELDS
*        plant,
*        StorageLocation
*      WHERE
*        Plant = @key-%key-Plant
*        AND StorageLocation = @ev_prodorderissuelocation
*      INTO @DATA(lv_sloc_valid).
*      IF sy-subrc <> 0.
*        APPEND VALUE #(
*          %key = key-%key
*          %msg = new_message_with_text(
*                   severity = if_abap_behv_message=>severity-error
*                   text     = |SLOC { key-%param-ProdOrderIssueLocation } không tồn tại| )
*        ) TO reported-zbommasschange.
*        APPEND VALUE #( %key = key-%key ) TO failed-zbommasschange.
*        ev_error = 'X'.
*        RETURN.
*      ENDIF.
    ENDIF.
  ENDMETHOD.













  METHOD append_buffer_edit_background.
    TRY.
        APPEND VALUE #(
          hdrid                        = iv_hdrid
          itmid                        = cl_system_uuid=>create_uuid_x16_static( )
          material                     = key-%key-material
          plant                        = key-%key-plant
          billofmaterialvariantusage   = key-%key-billofmaterialvariantusage
          billofmaterialvariant        = key-%key-billofmaterialvariant
          salesorder                   = key-%key-salesorder
          salesorderitem               = key-%key-salesorderitem
          billofmaterialitemnumber     = key-%key-billofmaterialitemnumber
          billofmaterialitemnodenumber = key-%key-billofmaterialitemnodenumber
          bomiteminternalchangecount   = key-%key-bomiteminternalchangecount
          billofmaterial               = key-%key-billofmaterial
          billofmaterialcategory       = key-%key-billofmaterialcategory
          lineitem                     = key-%param-LineItem

          component                    = iv_component
          componentquantity            = iv_quantity
          specialprocurementtype       = iv_SpecialProcurementType
          bomitemiscostingrelevant     = iv_BOMItemIsCostingRelevant
          componentscrap               = key-%param-componentscrap
          componentuom                 = iv_ComponentUOM
          ProdOrderIssueLocation       = iv_prodorderissuelocation

          jobtext                      = key-%param-jobtext
          editcomponent                = key-%param-editcomponent
          editcomponentquantity        = key-%param-editcomponentquantity
          editcomponentscrap           = key-%param-editcomponentscrap
          editspecialprocurementtype   = key-%param-editspecialprocurementtype
          editbomitemiscostingrelevant = key-%param-editbomitemiscostingrelevant
          editcomponentuom             = key-%param-editcomponentuom
          editProdOrderIssueLocation   = key-%param-editProdOrderIssueLocation
        ) TO ct_bg_jobs.
      CATCH cx_uuid_error.
        "handle exception
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZI_ZBOM_RP DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_ZBOM_RP IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    DATA: ls_start_info          TYPE cl_apj_rt_api=>ty_start_info,
          ls_scheduling_info     TYPE cl_apj_rt_api=>ty_scheduling_info,
          ls_end_info            TYPE cl_apj_rt_api=>ty_end_info,
          lt_job_parameter_value TYPE cl_apj_rt_api=>tt_job_parameter_value,
          lv_jobname             TYPE cl_apj_rt_api=>ty_jobname,
          lv_jobcount            TYPE cl_apj_rt_api=>ty_jobcount,
          lv_job_status          TYPE cl_apj_rt_api=>ty_job_status,
          lv_job_status_text     TYPE cl_apj_rt_api=>ty_job_status_text,
          lv_job_text            TYPE cl_apj_rt_api=>ty_job_text.

    DATA: lt_db TYPE STANDARD TABLE OF ztb_zbom_bg.

    " Chỉ chạy nếu có items trong buffer
    CHECK zcl_zbom_bg_buffer=>gt_bg_jobs IS NOT INITIAL.

    lt_db = CORRESPONDING #( zcl_zbom_bg_buffer=>gt_bg_jobs ).

    " ── 1. Persist buffer vào DB ──
    INSERT ztb_zbom_bg FROM TABLE @lt_db.

    " ── 2. Lấy hdrid (tất cả lines cùng 1 hdrid) ──
    DATA(lv_hdrid) = zcl_zbom_bg_buffer=>gt_bg_jobs[ 1 ]-hdrid.

    "Get data for APJ
    GET TIME STAMP FIELD DATA(ls_ts).
    ls_start_info-timestamp  = cl_abap_tstmp=>add(
                                 tstmp = ls_ts
                                 secs  = 1
    ).
    ls_scheduling_info = VALUE #(
      periodic_granularity = ''
      periodic_value = 1
      test_mode = abap_false
      timezone = 'CET'
    ).
    ls_end_info = VALUE #(
      type = 'NUM'
      max_iterations = 3
    ).
    APPEND INITIAL LINE TO lt_job_parameter_value ASSIGNING FIELD-SYMBOL(<lfs_job_param>).
    <lfs_job_param>-name = 'HDR_ID'.
    APPEND INITIAL LINE TO <lfs_job_param>-t_value ASSIGNING FIELD-SYMBOL(<lfs_job_value>).
    <lfs_job_value>-sign = 'I'.
    <lfs_job_value>-option = 'EQ'.
    <lfs_job_value>-low = lv_hdrid.

    lv_job_text = zcl_zbom_bg_buffer=>gt_bg_jobs[ 1 ]-jobtext.

*    IF zcl_zbom_bg_buffer=>gt_bg_jobs[ 1 ]-editcomponent IS NOT INITIAL OR
*       zcl_zbom_bg_buffer=>gt_bg_jobs[ 1 ]-editcomponentquantity IS NOT INITIAL OR
*       zcl_zbom_bg_buffer=>gt_bg_jobs[ 1 ]-editcomponentscrap IS NOT INITIAL.
*      lv_job_text = |ZBOM Edit Mass { ls_ts }|.
*    ELSE.
*      lv_job_text = |ZBOM Delete Mass { ls_ts }|.
*    ENDIF.


    "Run APJ
    TRY.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name          = 'ZJT_ZBOM_RP'
            iv_job_text                   = lv_job_text
            is_start_info                 = ls_start_info
            is_end_info                   = ls_end_info
            is_scheduling_info            = ls_scheduling_info
            it_job_parameter_value        = lt_job_parameter_value
          IMPORTING
            ev_jobname                    = lv_jobname
            ev_jobcount                   = lv_jobcount
          ).
      CATCH cx_apj_rt INTO DATA(lx_apj).
        DATA(lv_error_text) = lx_apj->get_text( ).
        DATA(lv_error_long) = lx_apj->get_longtext( ).
    ENDTRY.

    "Get Job Status
    TRY.
        cl_apj_rt_api=>get_job_status(
          EXPORTING
            iv_jobname         = lv_jobname
            iv_jobcount        = lv_jobcount
          IMPORTING
            ev_job_status      = lv_job_status
            ev_job_status_text = lv_job_status_text
        ).
      CATCH cx_apj_rt INTO DATA(lx_apj_status).
        DATA(lv_error_status_text) = lx_apj_status->get_text( ).
        DATA(lv_error_status_long) = lx_apj_status->get_longtext( ).
    ENDTRY.

*    TRY.
*        " ── Tạo operation với data từ buffer ─────────────────────────
*        DATA(lo_operation) = NEW zcl_zbom_edit_bg_operation(
*                                 zcl_zbom_bg_buffer=>gt_bg_jobs ).
*
*        " ── Tạo BGPF process ──────────────────────────────────────────
*        DATA(lo_process) = cl_bgmc_process_factory=>get_default( )->create( ).
*
**        lo_process->set_name( 'BOM Edit Mass Change' )->set_operation( lo_operation ).
*        lo_process->set_name( 'BOM Edit Mass Change' )->set_operation_tx_uncontrolled( lo_operation ).
*
*        " ── Save for execution → bắt buộc COMMIT WORK ngay sau ────────
*        lo_process->save_for_execution( ).
**        COMMIT WORK.
*
*        " ── Clear buffer ───────────────────────────────────────────────
*        CLEAR zcl_zbom_bg_buffer=>gt_bg_jobs.
*
*      CATCH cx_bgmc INTO DATA(lx_bgmc).
**        ROLLBACK WORK.
*        " Có thể log lx_bgmc->get_text( ) vào Z table nếu cần
*    ENDTRY.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
