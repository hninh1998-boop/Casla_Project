CLASS lsc_zi_m_zbom_rp DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zi_m_zbom_rp IMPLEMENTATION.

  METHOD save_modified.
    " Kiểm tra có DataFile nào được update messagetype = 'J' không
    IF update-datafile IS NOT INITIAL.

      " Tìm records có messagetype = 'J'
      LOOP AT update-datafile ASSIGNING FIELD-SYMBOL(<upd>)
        WHERE messagetype = 'J'.

        DATA(lv_found) = abap_true.
        DATA(lv_uuidfile) = <upd>-uuidfile.
        EXIT.
      ENDLOOP.

      IF lv_found = abap_true.
        " ── Schedule Job ở đây — ngoài RAP LUW ──
        DATA(lv_job_text) = CONV cl_apj_rt_api=>ty_job_text( update-datafile[ 1 ]-Message ).
        GET TIME STAMP FIELD DATA(ls_ts).

        TRY.
            cl_apj_rt_api=>schedule_job(
              EXPORTING
                iv_job_template_name   = 'ZJT_ZUPLOAD_ZBOM_RP'
                iv_job_text            = lv_job_text
                is_start_info          = VALUE #(
                    timestamp = cl_abap_tstmp=>add( tstmp = ls_ts secs = 1 )
                )
                is_end_info            = VALUE #( type = 'NUM' max_iterations = 3 )
                is_scheduling_info     = VALUE #(
                  periodic_value = 1
                  test_mode      = abap_false
                  timezone       = 'CET'
                )
                it_job_parameter_value = VALUE #( (
                  name    = 'HDR_ID'
                  t_value = VALUE #( (
                    sign = 'I'  option = 'EQ'  low = lv_uuidfile
                  ) )
                ) )
              IMPORTING
                ev_jobname = DATA(lv_jobname)
            ).

          CATCH cx_apj_rt INTO DATA(lx_apj).
            APPEND VALUE #(
              uuid = <upd>-uuid
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = lx_apj->get_longtext( )
                     )
            ) TO reported-datafile.

*            DATA(lv_error_msg) = lx_apj->get_longtext( ).
*            UPDATE ztb_d_zbom_rp
*              SET messagetype = 'E',
*                  message     = @lv_error_msg
*              WHERE uuid     = @<upd>-uuid
*                AND uuidfile = @<upd>-uuidfile.
        ENDTRY.
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_ManageFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In process
        error     TYPE c LENGTH 1 VALUE 'E', "Error
        success   TYPE c LENGTH 1 VALUE 'S', "Success
      END OF file_status.

    TYPES: BEGIN OF ty_file_upload,
             SalesOrder                 TYPE string,
             SalesOrderItem             TYPE string,
             Material                   TYPE string,
             Plant                      TYPE string,
             BillOfMaterialVariant      TYPE string,
             BillOfMaterialVariantUsage TYPE string,
             BillOfMaterialItemNumber   TYPE string,
             BillOfMaterialItemCategory TYPE string,
             Component                  TYPE string,
             ComponentQuantity          TYPE string,
             ComponentUnit              TYPE string,
             IsNetScrap                 TYPE string,
             ComponentScrapInPercent    TYPE string,
             BomItemIsCostingRelevant   TYPE string,
             SpecialProcurementType     TYPE string,
             ProdOrderIssueLocation     TYPE string,
           END OF ty_file_upload.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ManageFile RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ManageFile.

    METHODS downloadFile FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~downloadFile RESULT result.

    METHODS downloadTemplate FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~downloadTemplate.

    METHODS uploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~uploadExcel.

    METHODS setStatusToOpen FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ManageFile~setStatusToOpen.

    METHODS getExcelData FOR DETERMINE ON SAVE
      IMPORTING keys FOR ManageFile~getExcelData.

ENDCLASS.

CLASS lhc_ManageFile IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    LOOP AT entities
                 ASSIGNING FIELD-SYMBOL(<f_entities>)
                 WHERE uuid IS NOT INITIAL.

      APPEND CORRESPONDING #( <f_entities> ) TO mapped-managefile.

    ENDLOOP.

    DATA(lt_file) = entities.

    DELETE lt_file WHERE uuid IS NOT INITIAL.

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.


    LOOP AT lt_file ASSIGNING <f_entities>.

      TRY.
          <f_entities>-uuid = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
        CATCH cx_uuid_error.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft
          )
                 TO reported-managefile.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft )
                 TO failed-managefile.

          EXIT.
      ENDTRY.

      APPEND VALUE #( %cid      = <f_entities>-%cid
                      %key      = <f_entities>-%key
                      %is_draft = <f_entities>-%is_draft )
       TO mapped-managefile.
    ENDLOOP.
  ENDMETHOD.

  METHOD downloadFile.
  ENDMETHOD.

  METHOD downloadTemplate.
  ENDMETHOD.

  METHOD uploadExcel.
    DATA lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_mn_file TYPE TABLE FOR CREATE zi_m_zbom_rp,
          ls_mn_file LIKE LINE OF lt_mn_file,

          lt_file_c  TYPE TABLE FOR CREATE zi_m_zbom_rp\_datafile,
          ls_file_c  LIKE LINE OF lt_file_c.

    DATA: lt_keys TYPE TABLE FOR READ IMPORT zi_m_zbom_rp.

    READ TABLE keys ASSIGNING FIELD-SYMBOL(<k>) INDEX 1.

    CHECK sy-subrc = 0.

    IF <k>-%param-filecontent IS INITIAL.
      RETURN.
    ENDIF.

    ls_mn_file-attachment = <k>-%param-filecontent.
    ls_mn_file-filename   = <k>-%param-filename.
    ls_mn_file-mimetype   = <k>-%param-mimetype.

    FINAL(lv_filecontent) = <k>-%param-filecontent.
    "XCOライブラリを使用したExcelファイルの読み取り
    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = lv_filecontent )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_file ) ).

    lo_execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
               )->if_xco_xlsx_ra_operation~execute( ).

    IF lt_file IS NOT INITIAL.
      DO 1 TIMES.
        DELETE lt_file INDEX 1.
      ENDDO.
    ENDIF.

    DATA: lv_error TYPE abap_boolean VALUE IS INITIAL.

    "Validate...
    IF NOT lv_error = abap_true.
      ls_mn_file-Countline = lines( lt_file ).
      APPEND ls_mn_file TO lt_mn_file.
    ENDIF.

    IF lt_mn_file IS NOT INITIAL.
      MODIFY ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
        ENTITY managefile
        CREATE AUTO FILL CID FIELDS (
                          status
                          attachment
                          mimetype
                          filename
                          countline
                          createdbyuser
                          createddate
                          changedbyuser
                          changeddate
                        ) WITH lt_mn_file
        MAPPED DATA(lt_mapped_create)
        REPORTED DATA(lt_reported_create)
        FAILED DATA(lt_failed_create).
    ENDIF.
  ENDMETHOD.

  METHOD setStatusToOpen.
    READ ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
     ENTITY managefile
       FIELDS ( status )
       WITH CORRESPONDING #( keys )
     RESULT DATA(lt_file).

    "If Status is already set, do nothing
    DELETE lt_file WHERE status IS NOT INITIAL.
    DELETE lt_file WHERE status = 'X'.

    CHECK lt_file IS NOT INITIAL.

    DATA lv_cnt1 TYPE i.
    DATA lv_cnt2 TYPE i.
    DATA lv_next TYPE i.

    " lấy max không cộng sẵn
    SELECT SINGLE MAX( zcount )
      FROM ztb_m_zbom_rp
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt1.

    SELECT SINGLE MAX( zcount )
      FROM ztb_m_zbom_rpd
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt2.

    lv_next = COND i( WHEN lv_cnt1 >= lv_cnt2 THEN lv_cnt1 + 1 ELSE lv_cnt2 + 1 ).

    MODIFY ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
      ENTITY managefile
        UPDATE FIELDS ( status zcount )
        WITH VALUE #( FOR ls_file IN lt_file ( %tky   = ls_file-%tky
                                               status = file_status-open
                                               zcount = lv_next ) ).
  ENDMETHOD.

  METHOD getExcelData.
    DATA: lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_file_c TYPE TABLE FOR CREATE zi_m_zbom_rp\\managefile\_datafile,
          ls_file_c LIKE LINE OF lt_file_c.

    " ── 1. Read parent instance ───────────────────────────────────
    READ ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
      ENTITY managefile
      ALL FIELDS WITH
      CORRESPONDING #( keys )
      RESULT FINAL(lt_record).

    IF lt_record IS INITIAL.
      RETURN.
    ENDIF.

    FINAL(lv_filecontent) = lt_record[ 1 ]-attachment.

    CHECK sy-subrc = 0.

    " ── 2. Parse Excel ────────────────────────────────────────────
    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content(
                       iv_file_content = lv_filecontent
                     )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).
    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_file ) ).

    lo_execute->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->if_xco_xlsx_ra_operation~execute( ).

    " Bỏ header row
    IF lt_file IS NOT INITIAL.
      DELETE lt_file INDEX 1.
    ENDIF.

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE lt_record ASSIGNING FIELD-SYMBOL(<f_file>) INDEX 1.

    " ── 3. Process data Raw ───────────────────────────────────────
    DATA: lt_data_file TYPE TABLE OF zi_d_zbom_rp.

    LOOP AT lt_file INTO DATA(ls_file).
      APPEND INITIAL LINE TO lt_data_file ASSIGNING FIELD-SYMBOL(<lfs_data_file>).
      <lfs_data_file>-SalesOrder = |{ ls_file-salesorder ALPHA = IN }|.
      <lfs_data_file>-SalesOrderItem = |{ ls_file-salesorderitem ALPHA = IN }|.
      <lfs_data_file>-Material = |{ ls_file-Material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
      <lfs_data_file>-Plant = |{ ls_file-Plant ALPHA = IN }|.
      <lfs_data_file>-BillOfMaterialVariant =
        COND #( WHEN ls_file-BillOfMaterialVariant IS NOT INITIAL
                THEN |{ ls_file-BillOfMaterialVariant ALPHA = IN }|
                ELSE '01' ).
      <lfs_data_file>-BillOfMaterialVariantUsage = |{ ls_file-billofmaterialvariantusage ALPHA = IN }|.
      <lfs_data_file>-BillOfMaterialItemNumber = |{ ls_file-BillOfMaterialItemNumber ALPHA = IN }|.
      <lfs_data_file>-BillOfMaterialItemCategory = ls_file-BillOfMaterialItemCategory.
      <lfs_data_file>-Component = |{ ls_file-Component WIDTH = 18 ALIGN = RIGHT PAD = '0' }|.
      <lfs_data_file>-ComponentQuantity = ls_file-componentquantity.
      <lfs_data_file>-ComponentUnit = ls_file-componentunit.
      <lfs_data_file>-IsNetScrap = ls_file-IsNetScrap.
      <lfs_data_file>-ComponentScrapInPercent = ls_file-ComponentScrapInPercent.
      <lfs_data_file>-bomitemiscostingrelevant = ls_file-bomitemiscostingrelevant.
      <lfs_data_file>-specialprocurementtype = ls_file-specialprocurementtype.
      <lfs_data_file>-prodorderissuelocation = ls_file-prodorderissuelocation.
    ENDLOOP.

    " ── 4. Xóa duplicate trong file ──────────────────────────────
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT lt_data_file ASSIGNING FIELD-SYMBOL(<lfs_chk>).
      DATA(lv_key) = <lfs_chk>-SalesOrder
                  && <lfs_chk>-SalesOrderItem
                  && <lfs_chk>-Material
                  && <lfs_chk>-Plant
                  && <lfs_chk>-BillOfMaterialVariant
                  && <lfs_chk>-BillOfMaterialVariantUsage
                  && <lfs_chk>-BillOfMaterialItemNumber
                  && <lfs_chk>-BillOfMaterialItemCategory.

      INSERT lv_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        " Trùng → xóa khỏi table
        DELETE lt_data_file.
      ENDIF.
    ENDLOOP.

    IF lt_data_file IS INITIAL.
      RETURN.
    ENDIF.

    " ── 5. Build lt_file_c để create DataFile ────────────────────
    DATA lv_index TYPE i.

    LOOP AT lt_data_file INTO DATA(ls_data_file).
      lv_index = lv_index + 1.

      TRY.
          ls_file_c = VALUE #(
              %tky    = <f_file>-%tky
              %target = VALUE #( (
              %cid  = |CID_D_{ lv_index }|

              SalesOrder = ls_data_file-SalesOrder
              SalesOrderItem = ls_data_file-SalesOrderItem
              Material = ls_data_file-Material
              Plant = ls_data_file-Plant
              BillOfMaterialVariant = ls_data_file-BillOfMaterialVariant
              BillOfMaterialVariantUsage = ls_data_file-BillOfMaterialVariantUsage
              BillOfMaterialItemNumber = ls_data_file-BillOfMaterialItemNumber
              BillOfMaterialItemCategory = ls_data_file-BillOfMaterialItemCategory
              Component = ls_data_file-Component
              ComponentQuantity = ls_data_file-ComponentQuantity
              ComponentUnit = ls_data_file-ComponentUnit
              IsNetScrap = ls_data_file-IsNetScrap
              ComponentScrapInPercent = ls_data_file-ComponentScrapInPercent
              bomitemiscostingrelevant = ls_data_file-bomitemiscostingrelevant
              specialprocurementtype = ls_data_file-specialprocurementtype
              prodorderissuelocation = ls_data_file-prodorderissuelocation

              message                       = ls_data_file-message
              messagetype                   = ls_data_file-messagetype
            ) )
          ).
        CATCH cx_abap_context_info_error.
          CONTINUE.
      ENDTRY.

      APPEND ls_file_c TO lt_file_c.
      CLEAR ls_file_c.
    ENDLOOP.

    IF lt_file_c IS INITIAL.
      RETURN.
    ENDIF.

    " ── 6. Create DataFile records ────────────────────────────────
    MODIFY ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
      ENTITY managefile
      CREATE BY \_datafile
      FIELDS (
        SalesOrder
        SalesOrderItem
        Material
        Plant
        BillOfMaterialVariant
        BillOfMaterialVariantUsage
        BillOfMaterialItemNumber
        BillOfMaterialItemCategory
        Component
        ComponentQuantity
        ComponentUnit
        IsNetScrap
        ComponentScrapInPercent
        bomitemiscostingrelevant
        specialprocurementtype
        prodorderissuelocation

        message
        messagetype
      )
      WITH lt_file_c
      MAPPED   DATA(lt_mapped_create)
      REPORTED DATA(lt_mapped_reported)
      FAILED   DATA(lt_failed_create).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_DataFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
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

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DataFile RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DataFile RESULT result.

    METHODS PostConfirm FOR MODIFY
      IMPORTING keys FOR ACTION DataFile~PostConfirm RESULT result.

    METHODS setStatusToUpdate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR DataFile~setStatusToUpdate.
    METHODS setJob FOR MODIFY
      IMPORTING keys FOR ACTION DataFile~setJob RESULT result.

ENDCLASS.

CLASS lhc_DataFile IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD PostConfirm.
    " ── 1. SELECT ────────────────────────────────────────────────
    SELECT * FROM ztb_d_zbom_rp
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @keys
      WHERE uuid = @keys-uuid
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

      " ── 3. Check trùng key ─────────────────────────────────────────────────



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

      MODIFY ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
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

    MODIFY ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
      ENTITY managefile
      UPDATE FIELDS ( status )
      WITH VALUE #( (
        %tky-uuid = lt_data[ 1 ]-uuidfile
        %is_draft = if_abap_behv=>mk-off
        status    = lv_new_status
      ) )
      FAILED   DATA(lt_hdr_failed)
      REPORTED DATA(lt_hdr_reported).
  ENDMETHOD.

  METHOD setStatusToUpdate.
  ENDMETHOD.

  METHOD setJob.

    GET TIME STAMP FIELD DATA(ls_ts).
    " Chỉ đánh dấu status = 'J' (Job pending)
    MODIFY ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
      ENTITY datafile
      UPDATE FIELDS ( messagetype message )
      WITH VALUE #( FOR key IN keys
        ( %tky        = key-%tky
          messagetype = 'J'
          message     = |ZBOM Upload Mass { ls_ts }|
        )
      )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " Update parent status
    READ ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
      ENTITY datafile
      FIELDS ( Uuidfile )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_data).

    IF lt_data IS NOT INITIAL.
      MODIFY ENTITIES OF zi_m_zbom_rp IN LOCAL MODE
        ENTITY managefile
        UPDATE FIELDS ( status )
        WITH VALUE #( (
          %tky-uuid = lt_data[ 1 ]-Uuidfile
          %is_draft = if_abap_behv=>mk-off
          status    = file_status-inprocess
        ) )
        FAILED   DATA(lt_hdr_failed)
        REPORTED DATA(lt_hdr_reported).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
