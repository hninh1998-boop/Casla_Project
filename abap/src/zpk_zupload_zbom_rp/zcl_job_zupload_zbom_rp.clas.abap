    CLASS zcl_job_zupload_zbom_rp DEFINITION
      PUBLIC
      FINAL
      CREATE PUBLIC .

      PUBLIC SECTION.
        INTERFACES if_oo_adt_classrun.
        INTERFACES if_apj_dt_exec_object .
        INTERFACES if_apj_rt_exec_object .

        CONSTANTS:
          BEGIN OF file_status,
            open      TYPE c LENGTH 1 VALUE 'M', "Not process
            accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
            rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
            completed TYPE c LENGTH 1 VALUE 'D', "Done
            inprocess TYPE c LENGTH 1 VALUE 'P', "In Process
            error     TYPE c LENGTH 1 VALUE 'E', "Error
            success   TYPE c LENGTH 1 VALUE 'S', "Success
          END OF file_status.
      PROTECTED SECTION.
      PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_JOB_ZUPLOAD_ZBOM_RP IMPLEMENTATION.


      METHOD if_apj_rt_exec_object~execute.
        LOOP AT it_parameters INTO DATA(ls_param).
          " ── 1. SELECT ────────────────────────────────────────────────
          SELECT * FROM ztb_d_zbom_rp
            WITH PRIVILEGED ACCESS
            WHERE uuidfile = @ls_param-low
              AND messagetype NE 'S'
            INTO TABLE @DATA(lt_data).

          IF lt_data IS INITIAL.
            RETURN.
          ENDIF.

          LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<lfs_data>).
            DATA(lv_tabix) = sy-tabix.
            " ── 2. Reset ─────────────────────────────────────────────────
            CLEAR: <lfs_data>-messagetype,
                   <lfs_data>-message.

            CONDENSE: <lfs_data>-Sales_Order NO-GAPS,
                      <lfs_data>-Sales_Order NO-GAPS,
                      <lfs_data>-Material NO-GAPS,
                      <lfs_data>-Plant NO-GAPS,
                      <lfs_data>-bill_of_material_variant NO-GAPS,
                      <lfs_data>-bill_of_material_variant_usage NO-GAPS,
                      <lfs_data>-bill_of_material_item_number NO-GAPS,
                      <lfs_data>-bill_of_material_item_category NO-GAPS,
                      <lfs_data>-Component NO-GAPS,
                      <lfs_data>-Component_Unit NO-GAPS,
                      <lfs_data>-is_net_scrap NO-GAPS,
                      <lfs_data>-bom_item_is_costing_relevant NO-GAPS,
                      <lfs_data>-special_procurement_type NO-GAPS,
                      <lfs_data>-prod_order_issue_location NO-GAPS.

            " ── 6. Chạy API ─────────────────────────
            IF <lfs_data>-sales_order IS INITIAL AND <lfs_data>-sales_order_item = '000000'.
              "Check trùng key
              SELECT SINGLE FROM zi_zbom_rp
              FIELDS
                  Material,
                  Plant,
                  BillOfMaterialVariantUsage,
                  BillOfMaterialVariant,
                  BillOfMaterialItemNumber,
                  BillOfMaterial,
                  BillOfMaterialCategory,
                  BillOfMaterialComponent,
                  BillOfMaterialItemCategory
              WHERE
                  BillOfMaterialCategory = 'M' AND
                  Material = @<lfs_data>-material AND
                  BillOfMaterialVariant = @<lfs_data>-bill_of_material_variant AND
                  BillOfMaterialVariantUsage = @<lfs_data>-bill_of_material_variant_usage AND
                  BillOfMaterialItemNumber = @<lfs_data>-bill_of_material_item_number AND
                  BillOfMaterialItemCategory = @<lfs_data>-bill_of_material_item_category AND
                  BillOfMaterialComponent = @<lfs_data>-component
             INTO @DATA(ls_duplicate_mbom).
              IF sy-subrc = 0.
                <lfs_data>-messagetype = 'E'.
                <lfs_data>-message = 'Đã tồn tại BOM Item'.
              ELSE.
                "Get key M Bom
                zcl_process_mbom_zbom_rp=>main(
                 CHANGING
                   cs_data = <lfs_data>
               ).
              ENDIF.
            ELSE.
              "Check trùng key
              SELECT SINGLE FROM zi_zbom_rp
              FIELDS
                  SalesOrder,
                  SalesOrderItem,
                  Material,
                  Plant,
                  BillOfMaterialVariantUsage,
                  BillOfMaterialVariant,
                  BillOfMaterialItemNumber,
                  BillOfMaterial,
                  BillOfMaterialCategory,
                  BillOfMaterialComponent,
                  BillOfMaterialItemCategory
              WHERE
                  SalesOrder = @<lfs_data>-sales_order AND
                  SalesOrderItem = @<lfs_data>-sales_order_item AND
                  BillOfMaterialCategory = 'K' AND
                  Material = @<lfs_data>-material AND
                  BillOfMaterialVariant = @<lfs_data>-bill_of_material_variant AND
                  BillOfMaterialVariantUsage = @<lfs_data>-bill_of_material_variant_usage AND
                  BillOfMaterialItemNumber = @<lfs_data>-bill_of_material_item_number AND
                  BillOfMaterialItemCategory = @<lfs_data>-bill_of_material_item_category AND
                  BillOfMaterialComponent = @<lfs_data>-component
              INTO @DATA(ls_duplicate_kbom).
              IF sy-subrc = 0.
                <lfs_data>-messagetype = 'E'.
                <lfs_data>-message = 'Đã tồn tại BOM Item'.
              ELSE.
                "Process K BOM
                zcl_process_kbom_zbom_rp=>main(
                  CHANGING
                    cs_data  = <lfs_data>
                ).
              ENDIF.
            ENDIF.

            MODIFY ENTITIES OF zi_m_zbom_rp
              ENTITY datafile
              UPDATE FIELDS ( messagetype message )
              WITH VALUE #( (
                %tky-uuid        = <lfs_data>-uuid
                %tky-uuidfile        = <lfs_data>-uuidfile
                messagetype = <lfs_data>-messagetype
                message     = <lfs_data>-message
              ) )
              FAILED   DATA(lt_failed)
              REPORTED DATA(lt_reported).

            COMMIT WORK AND WAIT.
          ENDLOOP.

          " ── Update parent status ─────────────────────────────────────
          " Lấy UUIDFILE từ record đầu tiên (tất cả cùng 1 parent)
          DATA(lv_all_success) = abap_true.

          LOOP AT lt_data INTO DATA(ls_child).
            IF ls_child-messagetype <> 'S'.
              lv_all_success = abap_false.
            ENDIF.
          ENDLOOP.

          DATA(lv_new_status) = COND #(
            WHEN lv_all_success = abap_true
            THEN file_status-completed    " D = Done
            ELSE file_status-inprocess    " P = In process
          ).

          MODIFY ENTITIES OF zi_m_zbom_rp
            ENTITY managefile
            UPDATE FIELDS ( status )
            WITH VALUE #( (
              %tky-uuid = lt_data[ 1 ]-uuidfile
              %is_draft = if_abap_behv=>mk-off
              status    = lv_new_status
            ) )
            FAILED   DATA(lt_hdr_failed)
            REPORTED DATA(lt_hdr_reported).

          COMMIT WORK AND WAIT.
        ENDLOOP.
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
        DATA: lv_low(255) VALUE 'FA163EF80C7E1FD192F2F2093EFE6B60'.
        TRY.
            NEW zcl_job_zupload_zbom_rp( )->if_apj_rt_exec_object~execute(
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
