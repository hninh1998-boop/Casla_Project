CLASS zcl_pr_2_implement DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS earlynumbering_create
      IMPORTING
        entities TYPE zcl_pr_2_top=>tt_entities
      CHANGING
        mapped   TYPE zcl_pr_2_top=>tt_mapped
        reported TYPE zcl_pr_2_top=>tt_reported
        failed   TYPE zcl_pr_2_top=>tt_failed.

    CLASS-METHODS uploadExcelPR2
      IMPORTING
        keys       TYPE zcl_pr_2_top=>tt_keys
      EXPORTING
        et_mn_file TYPE zcl_pr_2_top=>tt_mn_file.

    CLASS-METHODS setStatusToOpenPR2
      EXPORTING
        ev_next TYPE i.

    CLASS-METHODS get_file_create
      IMPORTING
        iv_filecontent TYPE zde_attachment
        it_record      TYPE zcl_pr_2_top=>tt_record
      EXPORTING
        et_file_c      TYPE zcl_pr_2_top=>tt_file_c.

    CLASS-METHODS processing_api
      CHANGING
        ct_data TYPE zcl_pr_2_top=>tt_data.

    CLASS-METHODS get_new_status
      IMPORTING
        it_data       TYPE zcl_pr_2_top=>tt_data
      EXPORTING
        ev_new_status TYPE abap_boolean.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS parse_excel
      IMPORTING
        iv_filecontent TYPE zde_attachment
      EXPORTING
        et_file        TYPE zcl_pr_2_top=>tt_file_upload.

    CLASS-METHODS process_data_raw
      IMPORTING
        it_file      TYPE zcl_pr_2_top=>tt_file_upload
      EXPORTING
        et_data_file TYPE zcl_pr_2_top=>tt_data_file.

    CLASS-METHODS del_duplicate_data_file
      CHANGING
        ct_data_file TYPE zcl_pr_2_top=>tt_data_file.

    CLASS-METHODS build_file_create
      IMPORTING
        it_record    TYPE zcl_pr_2_top=>tt_record
        it_data_file TYPE zcl_pr_2_top=>tt_data_file
      EXPORTING
        et_file_c    TYPE zcl_pr_2_top=>tt_file_c.

    CLASS-METHODS insert
      CHANGING
        cs_data TYPE ztb_d_pr_2.

    CLASS-METHODS validate_date
      EXPORTING
        ev_error TYPE abap_boolean
      CHANGING
        cs_data  TYPE ztb_d_pr_2.

    CLASS-METHODS processing_insert
      CHANGING cs_data TYPE ztb_d_pr_2.

    CLASS-METHODS processing_update
      CHANGING cs_data TYPE ztb_d_pr_2.

    CLASS-METHODS update
      CHANGING
        cs_data TYPE ztb_d_pr_2.

    CLASS-METHODS get_body_item
      IMPORTING
        is_data TYPE ztb_d_pr_2
      EXPORTING
        ev_body TYPE string.

    CLASS-METHODS processing_delete
      CHANGING cs_data TYPE ztb_d_pr_2.
ENDCLASS.



CLASS ZCL_PR_2_IMPLEMENT IMPLEMENTATION.


  METHOD earlynumbering_create.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<f_entities>) WHERE uuid IS NOT INITIAL.
      APPEND CORRESPONDING #( <f_entities> ) TO mapped-managefilepr2.
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
                          %is_draft = <f_entities>-%is_draft ) TO reported-managefilepr2.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft ) TO failed-managefilepr2.
          EXIT.
      ENDTRY.

      APPEND VALUE #( %cid      = <f_entities>-%cid
                      %key      = <f_entities>-%key
                      %is_draft = <f_entities>-%is_draft ) TO mapped-managefilepr2.
    ENDLOOP.
  ENDMETHOD.


  METHOD uploadexcelpr2.
    DATA lt_file TYPE STANDARD TABLE OF zcl_pr_2_top=>ty_file_upload.

    DATA: ls_mn_file LIKE LINE OF et_mn_file,
          lt_file_c  TYPE TABLE FOR CREATE zi_m_pr_2\_datafile,
          ls_file_c  LIKE LINE OF lt_file_c.

    DATA: lt_keys TYPE TABLE FOR READ IMPORT zi_m_pr_2.

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
      DELETE lt_file INDEX 1. "Delete Line 1
      DELETE lt_file INDEX 1. "Delete Line 2
    ENDIF.

    DATA: lv_error TYPE abap_boolean VALUE IS INITIAL.

    IF NOT lv_error = abap_true.
      ls_mn_file-Countline = lines( lt_file ).
      APPEND ls_mn_file TO et_mn_file.
    ENDIF.
  ENDMETHOD.


  METHOD setstatustoopenpr2.
    DATA lv_cnt1 TYPE i.
    DATA lv_cnt2 TYPE i.

    " lấy max không cộng sẵn
    SELECT SINGLE MAX( zcount )
      FROM ztb_m_pr_2
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt1.

    SELECT SINGLE MAX( zcount )
      FROM ztb_m_pr_2d
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt2.

    ev_next = COND i( WHEN lv_cnt1 >= lv_cnt2 THEN lv_cnt1 + 1 ELSE lv_cnt2 + 1 ).
  ENDMETHOD.


  METHOD parse_excel.
    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content(
                       iv_file_content = iv_filecontent
                     )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).
    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( et_file ) ).

    lo_execute->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->if_xco_xlsx_ra_operation~execute( ).

    " Bỏ header row
    IF et_file IS NOT INITIAL.
      DELETE et_file INDEX 1.
      DELETE et_file INDEX 1.
    ENDIF.
  ENDMETHOD.


  METHOD process_data_raw.
    LOOP AT it_file INTO DATA(ls_file).
      APPEND INITIAL LINE TO et_data_file ASSIGNING FIELD-SYMBOL(<lfs_data_file>).

      <lfs_data_file>-Type                    = ls_file-type.
      <lfs_data_file>-PurchaseRequisition     = |{ ls_file-PurchaseRequisition ALPHA = IN }|.
      <lfs_data_file>-PurchaseRequisitionItem = |{ ls_file-PurchaseRequisitionItem ALPHA = IN }|.

      IF ls_file-material IS NOT INITIAL.
        <lfs_data_file>-Material = COND #( WHEN ls_file-material CO '0123456789'
                                           THEN |{ ls_file-Material WIDTH = 18 ALIGN = RIGHT PAD = '0' }|
                                           ELSE ls_file-material ).
      ENDIF.

      <lfs_data_file>-RequestedQuantity = ls_file-RequestedQuantity.

      zcl_utility_ninhnh=>convert_uome_to_uom( EXPORTING iv_uom_e = CONV I_UnitOfMeasure-UnitOfMeasure_E( ls_file-BaseUnit )
                                               IMPORTING ev_uom   = <lfs_data_file>-BaseUnit ).

      <lfs_data_file>-Plant                    = |{ ls_file-Plant ALPHA = IN }|.
      <lfs_data_file>-StorageLocation          = |{ ls_file-storagelocation ALPHA = IN }|.
      <lfs_data_file>-PurchaseRequisitionPrice = ls_file-PurchaseRequisitionPrice.
      <lfs_data_file>-PurReqnPriceQuantity     = ls_file-PurReqnPriceQuantity.
      <lfs_data_file>-PurReqnItemCurrency      = ls_file-PurReqnItemCurrency.
      <lfs_data_file>-PurchasingGroup          = |{ ls_file-PurchasingGroup ALPHA = IN }|.
      <lfs_data_file>-DeliveryDate             = ls_file-DeliveryDate.
      <lfs_data_file>-RequirementTracking      = ls_file-RequirementTracking.
      <lfs_data_file>-RequisitionerName        = ls_file-RequisitionerName.

      "Validate: Type I bắt buộc phải có Requisitioner Name
      IF <lfs_data_file>-Type = 'I' AND <lfs_data_file>-RequisitionerName IS INITIAL.
        <lfs_data_file>-message     = 'Requisitioner Name là bắt buộc khi Type = I'.
        <lfs_data_file>-messagetype = 'E'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD del_duplicate_data_file.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT ct_data_file INTO DATA(ls_seen_dup).
      DATA(lv_key) =
        ls_seen_dup-type
        && ls_seen_dup-PurchaseRequisition
        && ls_seen_dup-PurchaseRequisitionItem
        && ls_seen_dup-Material
        && ls_seen_dup-RequestedQuantity
        && ls_seen_dup-BaseUnit
        && ls_seen_dup-Plant
        && ls_seen_dup-StorageLocation
        && ls_seen_dup-PurchaseRequisitionPrice
        && ls_seen_dup-PurReqnPriceQuantity
        && ls_seen_dup-PurReqnItemCurrency
        && ls_seen_dup-PurchasingGroup
        && ls_seen_dup-DeliveryDate
        && ls_seen_dup-RequirementTracking
        && ls_seen_dup-RequisitionerName.

      INSERT lv_key INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        " Trùng → xóa khỏi table
        DELETE ct_data_file.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_file_create.
    DATA lv_index TYPE i.

    READ TABLE it_record INTO DATA(ls_record) INDEX 1.

    LOOP AT it_data_file INTO DATA(ls_data_file).
      lv_index = lv_index + 1.

      APPEND INITIAL LINE TO et_file_c ASSIGNING FIELD-SYMBOL(<lfs_file_c>).
      TRY.
          <lfs_file_c> = VALUE #(
              %tky    = ls_record-%tky
              %target = VALUE #( (
              %cid    = |CID_D_{ lv_index }|

              Type                      = ls_data_file-Type
              PurchaseRequisition       = ls_data_file-PurchaseRequisition
              PurchaseRequisitionItem   = ls_data_file-PurchaseRequisitionItem
              Material                  = ls_data_file-Material
              RequestedQuantity         = ls_data_file-RequestedQuantity
              BaseUnit                  = ls_data_file-BaseUnit
              Plant                     = ls_data_file-Plant
              StorageLocation           = ls_data_file-StorageLocation
              PurchaseRequisitionPrice  = ls_data_file-PurchaseRequisitionPrice
              PurReqnPriceQuantity      = ls_data_file-PurReqnPriceQuantity
              PurReqnItemCurrency       = ls_data_file-PurReqnItemCurrency
              PurchasingGroup           = ls_data_file-PurchasingGroup
              DeliveryDate              = ls_data_file-DeliveryDate
              RequirementTracking       = ls_data_file-RequirementTracking
              RequisitionerName         = ls_data_file-RequisitionerName

              message     = ls_data_file-message
              messagetype = ls_data_file-messagetype
            ) )
          ).
        CATCH cx_abap_context_info_error.
          DELETE et_file_c INDEX lines( et_file_c ).
          CONTINUE.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_file_create.
    parse_excel( EXPORTING iv_filecontent = iv_filecontent
                 IMPORTING et_file        = DATA(lt_file) ).

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.

    process_data_raw( EXPORTING it_file      = lt_file
                      IMPORTING et_data_file = DATA(lt_data_file) ).

    del_duplicate_data_file( CHANGING ct_data_file = lt_data_file ).

    IF lt_data_file IS INITIAL.
      RETURN.
    ENDIF.

    build_file_create( EXPORTING it_record    = it_record
                                 it_data_file = lt_data_file
                       IMPORTING et_file_c    = et_file_c ).
  ENDMETHOD.


  METHOD processing_api.
    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<lfs_data>).
      CASE <lfs_data>-type.
        WHEN 'I'.
          processing_insert( CHANGING cs_data = <lfs_data> ).
        WHEN 'M'.
          WAIT UP TO 1 SECONDS.
          processing_update( CHANGING cs_data = <lfs_data> ).
        WHEN 'D'.
          WAIT UP TO 1 SECONDS.
          processing_delete( CHANGING cs_data = <lfs_data> ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_new_status.
    " Lấy UUIDFILE từ record đầu tiên (tất cả cùng 1 parent)
    DATA(lv_all_success) = abap_true.

    READ TABLE it_data INTO DATA(ls_uuidfile) INDEX 1.
    IF sy-subrc = 0.
      SELECT FROM ztb_d_pr_2 WITH PRIVILEGED ACCESS
      FIELDS *
      WHERE uuidfile = @ls_uuidfile-uuidfile
      INTO TABLE @DATA(lt_total_file).
    ENDIF.

    LOOP AT lt_total_file ASSIGNING FIELD-SYMBOL(<lfs_total_file>).
      READ TABLE it_data INTO DATA(ls_child_data) WITH KEY uuid = <lfs_total_file>-uuid.
      IF sy-subrc = 0.
        <lfs_total_file>-messagetype = ls_child_data-messagetype.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_total_file INTO DATA(ls_child).
      IF ls_child-messagetype <> 'S'.
        lv_all_success = abap_false.
      ENDIF.
    ENDLOOP.

    ev_new_status = COND #(
      WHEN lv_all_success = abap_true
      THEN zcl_pr_2_top=>file_status-completed    " D = Done
      ELSE zcl_pr_2_top=>file_status-inprocess    " P = In process
    ).
  ENDMETHOD.


  METHOD insert.
    DATA: lv_endpoint TYPE string,
          lv_body     TYPE string.

    "1. Get Endpoint
    lv_endpoint =
        '/sap/opu/odata4/sap/api_purchaserequisition_2/srvd_a2x/sap/purchaserequisition/0001/PurchaseReqn'
        && |/{ cs_data-purchase_requisition }|
        && '/_PurchaseRequisitionItem'.

    "2. Get Body
    get_body_item( EXPORTING is_data = cs_data
                   IMPORTING ev_body = lv_body ).

    "3. Call API POST
    DATA(lv_result) = zcl_call_api_pr_2=>main( iv_body     = lv_body
                                               iv_endpoint = lv_endpoint
                                               iv_method   = 'POST' ).
    "4. Get Message Result
    zcl_utility_ninhnh=>get_api_message( EXPORTING iv_result      = lv_result
                                                   iv_code        = zcl_call_api_pr_2=>code
                                         IMPORTING ev_messagetype = cs_data-messagetype
                                                   ev_message     = DATA(lv_message) ).
    IF cs_data-messagetype = 'S'.
      FIND REGEX '"PurchaseRequisitionItem"\s*:\s*"(\d+)"'
      IN lv_result
      SUBMATCHES DATA(lv_pr_item).
      cs_data-message = |Tạo mới thành công PR { cs_data-purchase_requisition } item { lv_pr_item }|.
    ELSE.
      cs_data-message = lv_message.
    ENDIF.
  ENDMETHOD.


  METHOD validate_date.
    IF cs_data-delivery_date IS NOT INITIAL.
      IF strlen( cs_data-delivery_date ) = 10
         AND cs_data-delivery_date+2(1) = '.'
         AND cs_data-delivery_date+5(1) = '.'
         AND cs_data-delivery_date+0(2) CO '0123456789'
         AND cs_data-delivery_date+3(2) CO '0123456789'
         AND cs_data-delivery_date+6(4) CO '0123456789'.
      ELSE.
        cs_data-messagetype = 'E'.
        cs_data-message = 'Lỗi định dạng ngày tháng'.

        ev_error = 'X'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD processing_insert.
    "Validate: Type I bắt buộc phải có Requisitioner Name
    IF cs_data-requisitioner_name IS INITIAL.
      cs_data-messagetype = 'E'.
      cs_data-message     = 'Requisitioner Name là bắt buộc khi Type = I'.
      RETURN.
    ENDIF.

    "Validate date
    validate_date( IMPORTING ev_error = DATA(lv_error)
                   CHANGING  cs_data  = cs_data ).
    IF lv_error = 'X'.
      CLEAR: lv_error.
    ELSE.
      "API insert
      insert( CHANGING cs_data = cs_data ).
    ENDIF.
  ENDMETHOD.


  METHOD processing_update.
    "Validate date
    validate_date( IMPORTING ev_error = DATA(lv_error)
                   CHANGING  cs_data  = cs_data ).
    IF lv_error = 'X'.
      CLEAR: lv_error.
    ELSE.
      "API insert
      update( CHANGING cs_data = cs_data ).
    ENDIF.
  ENDMETHOD.


  METHOD update.
    DATA: lv_endpoint TYPE string.

    "1. Get Endpoint
    lv_endpoint =
        '/sap/opu/odata4/sap/api_purchaserequisition_2/srvd_a2x/sap/purchaserequisition/0001/PurchaseReqnItem'
        && |/{ cs_data-purchase_requisition }|
        && |/{ cs_data-purchase_requisition_item }|.

    "2. Get body
    get_body_item(
      EXPORTING
        is_data = cs_data
      IMPORTING
        ev_body = DATA(lv_body)
    ).
    "3. Call API PATCH
    DATA(lv_result) = zcl_call_api_pr_2=>main(
                        iv_body     = lv_body
                        iv_endpoint = lv_endpoint
                        iv_method   = 'PATCH'
                      ).
    "4. Get Message Result
    zcl_utility_ninhnh=>get_api_message(
      EXPORTING
        iv_result      = lv_result
        iv_code        = zcl_call_api_pr_2=>code
      IMPORTING
        ev_messagetype = cs_data-messagetype
        ev_message     = cs_data-message
    ).
  ENDMETHOD.


  METHOD get_body_item.
    "Chỉ đưa vào body những field user có điền trong file
    ev_body =
        |\{|
        && |"PurchaseRequisition": "{ is_data-purchase_requisition }",|.
    IF is_data-material IS NOT INITIAL.
      ev_body = ev_body && |"Material": "{ is_data-material }",|.
    ENDIF.
    IF is_data-requested_quantity IS NOT INITIAL.
      ev_body = ev_body && |"RequestedQuantity": { is_data-requested_quantity },|.
    ENDIF.
    IF is_data-base_unit IS NOT INITIAL.
      zcl_utility_ninhnh=>get_uom_isocode( EXPORTING iv_uom         = is_data-base_unit
                                           IMPORTING ev_uom_isocode = DATA(lv_uom_isocode) ).
      ev_body = ev_body && |"BaseUnit": "{ is_data-base_unit }",|.
      ev_body = ev_body && |"BaseUnitISOCode": "{ lv_uom_isocode }",|.
    ENDIF.
    IF is_data-plant IS NOT INITIAL.
      ev_body = ev_body && |"Plant": "{ is_data-plant }",|.
    ENDIF.
    IF is_data-storage_location IS NOT INITIAL.
      ev_body = ev_body && |"StorageLocation": "{ is_data-storage_location }",|.
    ENDIF.
    IF is_data-purchase_requisition_price IS NOT INITIAL.
      ev_body = ev_body && |"PurchaseRequisitionPrice": { is_data-purchase_requisition_price },|.
    ENDIF.
    IF is_data-pur_reqn_price_quantity IS NOT INITIAL.
      ev_body = ev_body && |"PurReqnPriceQuantity": { is_data-pur_reqn_price_quantity },|.
    ENDIF.
    IF is_data-pur_reqn_item_currency IS NOT INITIAL.
      ev_body = ev_body && |"PurReqnItemCurrency": "{ is_data-pur_reqn_item_currency }",|.
    ENDIF.
    IF is_data-purchasing_group IS NOT INITIAL.
      ev_body = ev_body && |"PurchasingGroup": "{ is_data-purchasing_group }",|.
    ENDIF.
    IF is_data-delivery_date IS NOT INITIAL.
      ev_body = ev_body && |"DeliveryDate": "{ is_data-delivery_date+6(4) }|
                                             && |-{ is_data-delivery_date+3(2) }|
                                             && |-{ is_data-delivery_date+0(2) }",|.
    ENDIF.
    IF is_data-requirement_tracking IS NOT INITIAL.
      ev_body = ev_body && |"RequirementTracking": "{ is_data-requirement_tracking }",|.
    ENDIF.
    IF is_data-requisitioner_name IS NOT INITIAL.
      ev_body = ev_body && |"RequisitionerName": "{ is_data-requisitioner_name }",|.
    ENDIF.
    IF ev_body CS ','.
      ev_body = substring( val = ev_body len = strlen( ev_body ) - 1 ).
    ENDIF.
    ev_body = ev_body && |\}|.
  ENDMETHOD.


  METHOD processing_delete.
    DATA: lv_endpoint TYPE string,
          lv_body     TYPE string.
    "1. Get Endpoint
    lv_endpoint =
        '/sap/opu/odata4/sap/api_purchaserequisition_2/srvd_a2x/sap/purchaserequisition/0001/PurchaseReqnItem'
        && |/{ cs_data-purchase_requisition }|
        && |/{ cs_data-purchase_requisition_item }|.

    "2. Get Body
    lv_body =
        |\{|
        && |"IsDeleted": true|
        && |\}|.
    "3. Call API PATCH
    DATA(lv_result) = zcl_call_api_pr_2=>main(
                        iv_body     = lv_body
                        iv_endpoint = lv_endpoint
                        iv_method   = 'PATCH'
                      ).
    "4. Get Message Result
    zcl_utility_ninhnh=>get_api_message(
      EXPORTING
        iv_result      = lv_result
        iv_code        = zcl_call_api_pr_2=>code
      IMPORTING
        ev_messagetype = cs_data-messagetype
        ev_message     = cs_data-message
    ).
  ENDMETHOD.
ENDCLASS.
