CLASS zcl_job_zbom_rp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun.
    INTERFACES if_apj_dt_exec_object .
    INTERFACES if_apj_rt_exec_object .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_JOB_ZBOM_RP IMPLEMENTATION.


  METHOD if_apj_rt_exec_object~execute.
    DATA: l_log        TYPE REF TO if_bali_log,
          lv_has_error TYPE abap_bool.

    " ── Tạo log 1 lần ──
    TRY.
        l_log = cl_bali_log=>create_with_header(
            cl_bali_header_setter=>create(
                object    = 'ZJL_ZBOM_RP'
                subobject = 'ZJL_SUB_ZBOM_RP' ) ).
      CATCH cx_bali_runtime.
    ENDTRY.

    LOOP AT it_parameters INTO DATA(ls_param).

      SELECT FROM ztb_zbom_bg
      FIELDS *
      WHERE hdrid = @ls_param-low
      INTO TABLE @DATA(lt_db).
      IF sy-subrc = 0.
        LOOP AT lt_db INTO DATA(ls_db).
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
                material                     = @ls_db-material AND
                plant                        = @ls_db-plant AND
                billofmaterialvariantusage   = @ls_db-billofmaterialvariantusage AND
                billofmaterialvariant        = @ls_db-billofmaterialvariant AND
                salesorder                   = @ls_db-salesorder AND
                salesorderitem               = @ls_db-salesorderitem AND
                billofmaterialitemnumber     = @ls_db-billofmaterialitemnumber AND
                billofmaterialitemnodenumber = @ls_db-billofmaterialitemnodenumber AND
                bomiteminternalchangecount   = @ls_db-bomiteminternalchangecount AND
                billofmaterial               = @ls_db-billofmaterial AND
                billofmaterialcategory       = @ls_db-billofmaterialcategory
          INTO @DATA(ls_data).

          IF sy-subrc = 0.
            "Validate param
            DATA(lv_quantity) = COND #( WHEN ls_db-ComponentQuantity IS INITIAL
                                        THEN ls_data-BillOfMaterialItemQuantity
                                        ELSE ls_db-ComponentQuantity ).

            "Validate component
            IF ls_db-Component IS INITIAL.
              DATA(lv_component) = |{ ls_data-BillOfMaterialComponent WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
            ELSE.
              lv_component = |{ ls_db-Component WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
              SELECT SINGLE FROM i_product
              FIELDS Product
              WHERE Product = @lv_component
              INTO @DATA(lv_component_valid).
              IF sy-subrc <> 0.
                CONTINUE.
              ENDIF.
            ENDIF.
          ENDIF.

          "Chạy API
          IF ls_db-BillOfMaterialCategory = 'K'.
            DATA: lv_endpoint_kbom TYPE string,
                  lv_body_kbom     TYPE string.

            lv_endpoint_kbom =
              '/sap/opu/odata/sap/API_ORDER_BILL_OF_MATERIAL_SRV'
              && |/SalesOrderBOMItem(BillOfMaterial='{ ls_db-BillOfMaterial }',|
              && |BillOfMaterialCategory='{ ls_db-BillOfMaterialCategory }',|
              && |BillOfMaterialVariant='{ ls_db-BillOfMaterialVariant }',|
              && |BillOfMaterialItemNodeNumber='{ ls_db-BillOfMaterialItemNodeNumber }',|
              && |HeaderChangeDocument='',|
              && |Material='{ ls_db-Material }',|
              && |Plant='{ ls_db-Plant }'|
              && ')'.

            " Chỉ đưa field vào body nếu flag = true
            lv_body_kbom = |\{|.
            IF ls_db-EditComponent = abap_true.
              lv_body_kbom = lv_body_kbom && |"BillOfMaterialComponent": "{ lv_component }",|.
            ENDIF.
            IF ls_db-EditComponentQuantity = abap_true.
              lv_body_kbom = lv_body_kbom && |"BillOfMaterialItemQuantity": "{ lv_quantity }",|.
            ENDIF.
            IF ls_db-EditComponentScrap = abap_true.
              lv_body_kbom = lv_body_kbom && |"ComponentScrapInPercent": "{ ls_db-ComponentScrap }",|.
            ENDIF.
            IF ls_db-EditSpecialProcurementType = abap_true.
              lv_body_kbom = lv_body_kbom && |"SpecialProcurementType": "{ ls_db-SpecialProcurementType }",|.
            ENDIF.
            IF ls_db-EditBOMItemIsCostingRelevant = abap_true.
              lv_body_kbom = lv_body_kbom && |"BOMItemIsCostingRelevant": "{ ls_db-BOMItemIsCostingRelevant }",|.
            ENDIF.
            IF ls_db-EditBOMItemIsCostingRelevant = abap_true.
              lv_body_kbom = lv_body_kbom && |"BOMItemIsCostingRelevant": "{ ls_db-BOMItemIsCostingRelevant }",|.
            ENDIF.
            IF ls_db-editcomponentuom = abap_true.
              lv_body_kbom = lv_body_kbom && |"BillOfMaterialItemUnit": "{ ls_db-componentuom }",|.
            ENDIF.
            IF ls_db-editprodorderissuelocation = abap_true.
              lv_body_kbom = lv_body_kbom && |"ProdOrderIssueLocation": "{ ls_db-prodorderissuelocation }",|.
            ENDIF.
            " Bỏ dấu phẩy cuối nếu có
            IF lv_body_kbom CS ','.
              lv_body_kbom = substring( val = lv_body_kbom len = strlen( lv_body_kbom ) - 1 ).
            ENDIF.
            lv_body_kbom = lv_body_kbom && |\}|.

            IF ls_db-EditComponent = abap_false AND
               ls_db-editcomponentquantity = abap_false AND
               ls_db-editcomponentscrap = abap_false AND
               ls_db-EditSpecialProcurementType   = abap_false AND
               ls_db-EditBOMItemIsCostingRelevant = abap_false AND
               ls_db-editcomponentuom = abap_false AND
               ls_db-editprodorderissuelocation = abap_false.
              CLEAR: lv_body_kbom.
            ENDIF.

            IF lv_body_kbom IS NOT INITIAL.
              DATA(lv_result_kbom) = zcl_call_api_kbom_rp=>call_api(
                                       iv_body     = lv_body_kbom
                                       iv_endpoint = lv_endpoint_kbom
                                       iv_method   = 'PATCH'
                                     ).
            ELSE.
              lv_result_kbom = zcl_call_api_kbom_rp=>call_api(
                                       iv_endpoint = lv_endpoint_kbom
                                       iv_method   = 'DELETE'
                                     ).
            ENDIF.

            GET TIME STAMP FIELD DATA(lv_ts_k).

            IF zcl_call_api_kbom_rp=>code = 200
                OR zcl_call_api_kbom_rp=>code = 201
                OR zcl_call_api_kbom_rp=>code = 202
                OR zcl_call_api_kbom_rp=>code = 204.
              " ── Success → update status ──
              UPDATE ztb_zbom_bg SET
                status        = 'S',
                error_message = '',
                processed_at  = @lv_ts_k
              WHERE hdrid = @ls_db-hdrid.
              COMMIT WORK.

              TRY.
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_information
                      text     = CONV #( |line { ls_db-lineitem }: Success| )
                  ) ).
                CATCH cx_bali_runtime.
                  "handle exception
              ENDTRY.
            ELSE.
              " ── Error → parse message và ghi log ──
              DATA(lv_error_msg_line) = |HTTP { zcl_call_api_kbom_rp=>code }|.
              DATA(lv_search) = `"value":"`.
              DATA(lv_pos) = find( val = lv_result_kbom sub = lv_search ).
              IF lv_pos >= 0.
                DATA(lv_start) = lv_pos + strlen( lv_search ).
                DATA(lv_end) = find( val = lv_result_kbom off = lv_start sub = `"` ).
                IF lv_end > lv_start.
                  lv_error_msg_line = substring( val = lv_result_kbom off = lv_start len = lv_end - lv_start ).
                  DATA(lv_error_msg) =
                    |line { ls_db-lineitem }: { lv_error_msg_line }| &&
                    cl_abap_char_utilities=>newline &&
                    |hdrid: { ls_db-hdrid }| &&
                    cl_abap_char_utilities=>newline &&
                    |itmid: { ls_db-itmid }|.
                ENDIF.
              ENDIF.

              UPDATE ztb_zbom_bg SET
                status        = 'E',
                error_message = @lv_error_msg,
                processed_at  = @lv_ts_k
              WHERE hdrid = @ls_db-hdrid.
              COMMIT WORK.

*              "Ghi Job Log
*              TRY.
*                  l_log = cl_bali_log=>create_with_header(
*                      cl_bali_header_setter=>create(
*                          object = 'ZJL_ZBOM_RP'
*                          subobject = 'ZJL_SUB_ZBOM_RP' ) ).
*                CATCH cx_bali_runtime.
*                  "handle exception
*              ENDTRY.

              "Add a message as item to the log
*              DATA(l_message) = cl_bali_free_text_setter=>create(
*                                  severity = if_bali_constants=>c_severity_error
*                                  text     = CONV cl_bali_free_text_setter=>ty_text( lv_error_msg )
*                                ).

              TRY.
*                  l_log->add_item( item = l_message ).
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_error
                      text     = CONV #( |line { ls_db-lineitem }: { lv_error_msg_line }| )
                  ) ).
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_information
                      text     = CONV #( |hdrid: { ls_db-hdrid }| )
                  ) ).
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_information
                      text     = CONV #( |itmid: { ls_db-itmid }| )
                  ) ).
                CATCH cx_bali_runtime.
                  "handle exception
              ENDTRY.

*              "Save the log into the database
*              TRY.
*                  cl_bali_log_db=>get_instance( )->save_log(
*                      log = l_log
*                      assign_to_current_appl_job = abap_true ).
*                CATCH cx_bali_runtime.
*                  "handle exception
*              ENDTRY.

              COMMIT WORK.

              CONTINUE.
            ENDIF.
          ELSEIF ls_db-BillOfMaterialCategory = 'M'.
            DATA: lv_endpoint_mbom TYPE string,
                  lv_body_mbom     TYPE string.

            lv_endpoint_mbom =
                '/sap/opu/odata/SAP/API_BILL_OF_MATERIAL_SRV;v=2'
                && |/MaterialBOMItem(BillOfMaterial='{ ls_db-BillOfMaterial }',|
                && |BillOfMaterialCategory='{ ls_db-BillOfMaterialCategory }',|
                && |BillOfMaterialVariant='{ ls_db-BillOfMaterialVariant }',|
                && |BillOfMaterialVersion='',|
                && |BillOfMaterialItemNodeNumber='{ ls_db-BillOfMaterialItemNodeNumber }',|
                && |HeaderChangeDocument='',|
                && |Material='{ ls_db-Material }',|
                && |Plant='{ ls_db-Plant }'|
                && ')'.

            " Chỉ đưa field vào body nếu flag = true
            lv_body_mbom = |\{|.
            IF ls_db-EditComponent = abap_true.
              lv_body_mbom = lv_body_mbom && |"BillOfMaterialComponent": "{ lv_component }",|.
            ENDIF.
            IF ls_db-EditComponentQuantity = abap_true.
              lv_body_mbom = lv_body_mbom && |"BillOfMaterialItemQuantity": "{ lv_quantity }",|.
            ENDIF.
            IF ls_db-EditComponentScrap = abap_true.
              lv_body_mbom = lv_body_mbom && |"ComponentScrapInPercent": "{ ls_db-ComponentScrap }",|.
            ENDIF.
            IF ls_db-EditSpecialProcurementType = abap_true.
              lv_body_mbom = lv_body_mbom && |"SpecialProcurementType": "{ ls_db-SpecialProcurementType }",|.
            ENDIF.
            IF ls_db-EditBOMItemIsCostingRelevant = abap_true.
              lv_body_mbom = lv_body_mbom && |"BOMItemIsCostingRelevant": "{ ls_db-BOMItemIsCostingRelevant }",|.
            ENDIF.
            IF ls_db-editcomponentuom = abap_true.
              lv_body_mbom = lv_body_mbom && |"BillOfMaterialItemUnit": "{ ls_db-componentuom }",|.
            ENDIF.
            IF ls_db-editprodorderissuelocation = abap_true.
              lv_body_mbom = lv_body_mbom && |"ProdOrderIssueLocation": "{ ls_db-prodorderissuelocation }",|.
            ENDIF.
            " Bỏ dấu phẩy cuối nếu có
            IF lv_body_mbom CS ','.
              lv_body_mbom = substring( val = lv_body_mbom len = strlen( lv_body_mbom ) - 1 ).
            ENDIF.
            lv_body_mbom = lv_body_mbom && |\}|.

            IF ls_db-EditComponent = abap_false AND
               ls_db-editcomponentquantity = abap_false AND
               ls_db-editcomponentscrap = abap_false AND
               ls_db-EditSpecialProcurementType = abap_false AND
               ls_db-EditBOMItemIsCostingRelevant = abap_false AND
               ls_db-editcomponentuom = abap_false AND
               ls_db-editprodorderissuelocation = abap_false.
              CLEAR: lv_body_mbom.
            ENDIF.

            IF lv_body_mbom IS NOT INITIAL.
              DATA(lv_result_mbom) = zcl_call_api_kbom_rp=>call_api(
                                       iv_body     = lv_body_mbom
                                       iv_endpoint = lv_endpoint_mbom
                                       iv_method   = 'PATCH'
                                     ).
            ELSE.
              lv_result_mbom = zcl_call_api_kbom_rp=>call_api(
                                       iv_endpoint = lv_endpoint_mbom
                                       iv_method   = 'DELETE'
                                     ).
            ENDIF.

            GET TIME STAMP FIELD DATA(lv_ts_m).

            IF zcl_call_api_kbom_rp=>code = 200
                OR zcl_call_api_kbom_rp=>code = 201
                OR zcl_call_api_kbom_rp=>code = 202
                OR zcl_call_api_kbom_rp=>code = 204.
              " ── Success → update status ──
              UPDATE ztb_zbom_bg SET
                status        = 'S',
                error_message = '',
                processed_at  = @lv_ts_m
              WHERE hdrid = @ls_db-hdrid.
              COMMIT WORK.

              TRY.
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_information
                      text     = CONV #( |line { ls_db-lineitem }: Success| )
                  ) ).
                CATCH cx_bali_runtime.
              ENDTRY.
            ELSE.
              " ── Error → parse message và ghi log ──
              lv_error_msg_line = |HTTP { zcl_call_api_kbom_rp=>code }|.
              lv_search = `"value":"`.
              lv_pos = find( val = lv_result_mbom sub = lv_search ).
              IF lv_pos >= 0.
                lv_start = lv_pos + strlen( lv_search ).
                lv_end = find( val = lv_result_mbom off = lv_start sub = `"` ).
                IF lv_end > lv_start.
                  lv_error_msg_line = substring( val = lv_result_mbom off = lv_start len = lv_end - lv_start ).
                  lv_error_msg =
                    |line { ls_db-lineitem }: { lv_error_msg_line }| &&
                    cl_abap_char_utilities=>newline &&
                    |hdrid: { ls_db-hdrid }| &&
                    cl_abap_char_utilities=>newline &&
                    |itmid: { ls_db-itmid }|.
                ENDIF.
              ENDIF.

              UPDATE ztb_zbom_bg SET
                status        = 'E',
                error_message = @lv_error_msg,
                processed_at  = @lv_ts_m
              WHERE hdrid = @ls_db-hdrid.
              COMMIT WORK.

*              "Ghi Job Log
*              TRY.
*                  l_log = cl_bali_log=>create_with_header(
*                      cl_bali_header_setter=>create(
*                          object = 'ZJL_ZBOM_RP'
*                          subobject = 'ZJL_SUB_ZBOM_RP' ) ).
*                CATCH cx_bali_runtime.
*                  "handle exception
*              ENDTRY.

*              "Add a message as item to the log
*              l_message = cl_bali_free_text_setter=>create(
*                                  severity = if_bali_constants=>c_severity_error
*                                  text     = CONV cl_bali_free_text_setter=>ty_text( lv_error_msg )
*                                ).

              TRY.
*                  l_log->add_item( item = l_message ).
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_error
                      text     = CONV #( |line { ls_db-lineitem }: { lv_error_msg_line }| )
                  ) ).
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_information
                      text     = CONV #( |hdrid: { ls_db-hdrid }| )
                  ) ).
                  l_log->add_item( item = cl_bali_free_text_setter=>create(
                      severity = if_bali_constants=>c_severity_information
                      text     = CONV #( |itmid: { ls_db-itmid }| )
                  ) ).
                CATCH cx_bali_runtime.
                  "handle exception
              ENDTRY.

*              "Save the log into the database
*              TRY.
*                  cl_bali_log_db=>get_instance( )->save_log(
*                      log = l_log
*                      assign_to_current_appl_job = abap_true ).
*                CATCH cx_bali_runtime.
*                  "handle exception
*              ENDTRY.

              COMMIT WORK.

              CONTINUE.
            ENDIF.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    " ── Save log 1 lần sau khi xong tất cả ──
    TRY.
        cl_bali_log_db=>get_instance( )->save_log(
            log = l_log
            assign_to_current_appl_job = abap_true ).
      CATCH cx_bali_runtime.
    ENDTRY.
    COMMIT WORK.

  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = 'HDR_ID'
        kind = if_apj_dt_exec_object=>select_option
        datatype = 'C'
        length = 50
        param_text = 'HDR ID'
        changeable_ind = abap_true )
    ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    "Test
    DATA: lv_low TYPE char255 VALUE 'FA163EF80C7E1FD192CF68087D918B5C'.
    TRY.
        NEW zcl_job_zbom_rp( )->if_apj_rt_exec_object~execute(
            it_parameters = VALUE #(
                ( selname = 'HDR_ID'
                  kind = if_apj_dt_exec_object=>select_option
                  sign = 'I'
                  option = 'EQ'
                  low = lv_low )
            )
        ).
      CATCH cx_apj_rt_content.
        "handle exception
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
