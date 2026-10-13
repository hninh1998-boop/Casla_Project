CLASS zcl_pr_1_implement DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_data TYPE STANDARD TABLE OF ztb_d_pr_1 WITH EMPTY KEY.

    CLASS-METHODS processing_api
      CHANGING
        ct_data TYPE tt_data.

    CLASS-METHODS get_new_status
      IMPORTING
        it_data       TYPE tt_data
      EXPORTING
        ev_new_status TYPE abap_boolean.
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS get_endpoint_body_header
      IMPORTING
        is_data_grp TYPE zcl_pr_1_top=>ty_data_grp
      EXPORTING
        ev_endpoint TYPE string
        ev_body     TYPE string.

    CLASS-METHODS insert_header
      IMPORTING
        is_data_grp TYPE zcl_pr_1_top=>ty_data_grp
      EXPORTING
        ev_endpoint TYPE string
        ev_body     TYPE string.

    CLASS-METHODS update_header
      IMPORTING
        is_data_grp TYPE zcl_pr_1_top=>ty_data_grp
      EXPORTING
        ev_endpoint TYPE string
        ev_body     TYPE string.

    CLASS-METHODS insert_body_item
      IMPORTING
        iv_tabix     TYPE sy-tabix
        is_data      TYPE ztb_d_pr_1
      EXPORTING
        ev_body_item TYPE string.

    CLASS-METHODS validate_date
      EXPORTING
        ev_error TYPE abap_boolean
      CHANGING
        cs_data  TYPE ztb_d_pr_1
        cv_index TYPE i.
ENDCLASS.



CLASS ZCL_PR_1_IMPLEMENT IMPLEMENTATION.


  METHOD processing_api.
    DATA: lv_index     TYPE i,
          lv_body_item TYPE string.

    "Processing API
    "   Đối với Insert: Insert cả Header + Item
    "   Đối với Update:  Chỉ Update Header
    LOOP AT ct_data INTO DATA(ls_group) GROUP BY ( type = ls_group-type
                                                   PurchaseRequisition = ls_group-purchase_requisition
                                                   PurchaseRequisitionType = ls_group-purchase_requisition_type
                                                   PurReqnDescription = ls_group-pur_reqn_description
                                                   PurReqnHeaderNote = ls_group-pur_reqn_header_note )
        ASSIGNING FIELD-SYMBOL(<lfs_data_grp>).

      "1. Get data header - Insert + Update
      get_endpoint_body_header( EXPORTING is_data_grp = <lfs_data_grp>
                                IMPORTING ev_endpoint = DATA(lv_endpoint)
                                          ev_body     = DATA(lv_body) ).

      "2. Get data item - only for case Insert
      CLEAR: lv_index,
             lv_body_item.

      LOOP AT GROUP <lfs_data_grp> ASSIGNING FIELD-SYMBOL(<lfs_data>).
        CLEAR: <lfs_data>-message,
               <lfs_data>-messagetype.

        CHECK <lfs_data>-type = 'I'.

        "Validate: Type I bắt buộc phải có Requisitioner Name
        IF <lfs_data>-requested_by IS INITIAL.
          <lfs_data>-messagetype = 'E'.
          <lfs_data>-message     = 'Requisitioner Name là bắt buộc khi Type = I'.
          CONTINUE.
        ENDIF.

        lv_index += 1.

        validate_date( IMPORTING ev_error = DATA(lv_error)
                       CHANGING  cs_data  = <lfs_data>
                                 cv_index = lv_index ).
        IF lv_error = 'X'.
          CLEAR: lv_error.
        ELSE.
          insert_body_item( EXPORTING iv_tabix     = lv_index
                                      is_data      = <lfs_data>
                            IMPORTING ev_body_item = lv_body_item ).
        ENDIF.
      ENDLOOP.

      IF lv_body_item IS NOT INITIAL.
        lv_body_item = lv_body_item && ']'.
      ENDIF.
      lv_body = lv_body && lv_body_item && |\}|.

      "3. Call API
      DATA(lv_method) = COND string( WHEN <lfs_data_grp>-type = 'I'
                                     THEN 'POST' ELSE 'PATCH' ).
      DATA(lv_result) = zcl_call_api_pr_1=>main( iv_body     = lv_body
                                                 iv_endpoint = lv_endpoint
                                                 iv_method   = lv_method ).
      "4. Get message result
      zcl_utility_ninhnh=>get_api_message( EXPORTING iv_result      = lv_result
                                                     iv_code        = zcl_call_api_pr_1=>code
                                           IMPORTING ev_messagetype = DATA(lv_messagetype)
                                                     ev_message     = DATA(lv_message) ).
      IF lv_messagetype = 'S' AND <lfs_data_grp>-type = 'I'.
        FIND REGEX '"PurchaseRequisition"\s*:\s*"(\d+)"'
        IN lv_result
        SUBMATCHES DATA(lv_pr).
      ENDIF.

      LOOP AT GROUP <lfs_data_grp> ASSIGNING <lfs_data>.
        CHECK <lfs_data>-messagetype IS INITIAL.
        <lfs_data>-messagetype = lv_messagetype.
        <lfs_data>-message = COND #( WHEN lv_messagetype = 'S' AND <lfs_data>-type = 'I'
                                     THEN |Tạo thành công PR { lv_pr } Item { <lfs_data>-purchase_requisition_item }|
                                     ELSE lv_message ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_endpoint_body_header.
    CASE is_data_grp-type.
      WHEN 'I'.
        insert_header( EXPORTING is_data_grp = is_data_grp
                       IMPORTING ev_endpoint = ev_endpoint
                                 ev_body     = ev_body ).
      WHEN 'M'.
        update_header( EXPORTING is_data_grp = is_data_grp
                       IMPORTING ev_endpoint = ev_endpoint
                                 ev_body     = ev_body ).
    ENDCASE.
  ENDMETHOD.


  METHOD insert_header.
    ev_endpoint = '/sap/opu/odata4/sap/api_purchaserequisition_2/srvd_a2x/sap/purchaserequisition/0001/PurchaseReqn'.

    "Chỉ đưa vào body những field user có điền trong file
    ev_body = |\{|.
    IF is_data_grp-PurchaseRequisitionType IS NOT INITIAL.
      ev_body = ev_body && |"PurchaseRequisitionType": "{ is_data_grp-PurchaseRequisitionType }",|.
    ENDIF.
    IF is_data_grp-PurReqnDescription IS NOT INITIAL.
      ev_body = ev_body && |"PurReqnDescription": "{ is_data_grp-PurReqnDescription }",|.
    ENDIF.
    IF is_data_grp-PurReqnHeaderNote IS NOT INITIAL.
      ev_body = ev_body && |"PurReqnHeaderNote": "{ is_data_grp-PurReqnHeaderNote }",|.
    ENDIF.
  ENDMETHOD.


  METHOD update_header.
    ev_endpoint =
      '/sap/opu/odata4/sap/api_purchaserequisition_2/srvd_a2x/sap/purchaserequisition/0001/PurchaseReqn'
      && |/{ is_data_grp-purchaserequisition }|.

    ev_body = |\{|.
    IF is_data_grp-PurReqnDescription IS NOT INITIAL.
      ev_body = ev_body && |"PurReqnDescription": "{ is_data_grp-PurReqnDescription }",|.
    ENDIF.
    IF is_data_grp-PurReqnHeaderNote IS NOT INITIAL.
      ev_body = ev_body && |"PurReqnHeaderNote": "{ is_data_grp-PurReqnHeaderNote }",|.
    ENDIF.
    IF ev_body CS ','.
      ev_body = substring( val = ev_body len = strlen( ev_body ) - 1 ).
    ENDIF.
  ENDMETHOD.


  METHOD insert_body_item.
    IF iv_tabix = 1.
      ev_body_item = |"_PurchaseRequisitionItem": [|.
    ELSE.
      ev_body_item = ev_body_item && ','.
    ENDIF.

    "Chỉ đưa vào body những field user có điền trong file
    DATA(lv_item) = |\{|.
    IF is_data-purchase_requisition_item IS NOT INITIAL.
      lv_item = lv_item && |"PurchaseRequisitionItem": "{ is_data-purchase_requisition_item }",|.
    ENDIF.
    IF is_data-material IS NOT INITIAL.
      lv_item = lv_item && |"Material": "{ is_data-material }",|.
    ENDIF.
    IF is_data-requested_quantity IS NOT INITIAL.
      lv_item = lv_item && |"RequestedQuantity": { is_data-requested_quantity },|.
    ENDIF.
    IF is_data-base_unit IS NOT INITIAL.
      zcl_utility_ninhnh=>get_uom_isocode( EXPORTING iv_uom         = is_data-base_unit
                                           IMPORTING ev_uom_isocode = DATA(lv_uom_isocode) ).
      lv_item = lv_item && |"BaseUnit": "{ is_data-base_unit }",|.
      lv_item = lv_item && |"BaseUnitISOCode": "{ lv_uom_isocode }",|.
    ENDIF.
    IF is_data-plant IS NOT INITIAL.
      lv_item = lv_item && |"Plant": "{ is_data-plant }",|.
    ENDIF.
    IF is_data-storage_location IS NOT INITIAL.
      lv_item = lv_item && |"StorageLocation": "{ is_data-storage_location }",|.
    ENDIF.
    IF is_data-purchase_requisition_price IS NOT INITIAL.
      lv_item = lv_item && |"PurchaseRequisitionPrice": { is_data-purchase_requisition_price },|.
    ENDIF.
    IF is_data-pur_reqn_price_quantity IS NOT INITIAL.
      lv_item = lv_item && |"PurReqnPriceQuantity": { is_data-pur_reqn_price_quantity },|.
    ENDIF.
    IF is_data-pur_reqn_item_currency IS NOT INITIAL.
      lv_item = lv_item && |"PurReqnItemCurrency": "{ is_data-pur_reqn_item_currency }",|.
    ENDIF.
    IF is_data-purchasing_group IS NOT INITIAL.
      lv_item = lv_item && |"PurchasingGroup": "{ is_data-purchasing_group }",|.
    ENDIF.
    IF is_data-delivery_date IS NOT INITIAL.
      lv_item = lv_item && |"DeliveryDate": "{ is_data-delivery_date+6(4) }|
                                             && |-{ is_data-delivery_date+3(2) }|
                                             && |-{ is_data-delivery_date+0(2) }",|.
    ENDIF.
    IF is_data-requirement_tracking IS NOT INITIAL.
      lv_item = lv_item && |"RequirementTracking": "{ is_data-requirement_tracking }",|.
    ENDIF.
    IF is_data-requested_by IS NOT INITIAL.
      lv_item = lv_item && |"RequisitionerName": "{ is_data-requested_by }",|.
    ENDIF.
    IF lv_item CS ','.
      lv_item = substring( val = lv_item len = strlen( lv_item ) - 1 ).
    ENDIF.

    ev_body_item = ev_body_item && lv_item && |\}|.
  ENDMETHOD.


  METHOD validate_date.
    "Để trống thì bỏ qua, chỉ check định dạng khi user có điền
    IF cs_data-delivery_date IS INITIAL.
      RETURN.
    ENDIF.

    IF strlen( cs_data-delivery_date ) = 10
       AND cs_data-delivery_date+2(1) = '.'
       AND cs_data-delivery_date+5(1) = '.'
       AND cs_data-delivery_date+0(2) CO '0123456789'
       AND cs_data-delivery_date+3(2) CO '0123456789'
       AND cs_data-delivery_date+6(4) CO '0123456789'.
    ELSE.
      cs_data-messagetype = 'E'.
      cs_data-message = 'Lỗi định dạng ngày tháng'.
      cv_index -= 1.

      ev_error = 'X'.
    ENDIF.
  ENDMETHOD.


  METHOD get_new_status.
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

    " Lấy UUIDFILE từ record đầu tiên (tất cả cùng 1 parent)
    DATA(lv_all_success) = abap_true.

    READ TABLE it_data INTO DATA(ls_uuidfile) INDEX 1.
    IF sy-subrc = 0.
      SELECT FROM ztb_d_pr_1 WITH PRIVILEGED ACCESS
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
      THEN file_status-completed    " D = Done
      ELSE file_status-inprocess    " P = In process
    ).
  ENDMETHOD.
ENDCLASS.
