CLASS zcl_crud_poc_implement DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_data TYPE STANDARD TABLE OF ztb_d_crud_poc.

    "! Xử lý toàn bộ các dòng (I/M/D) và trả kết quả về messagetype/message.
    "! Đảm bảo sau khi gọi KHÔNG còn dòng nào ở trạng thái 'J'
    "! (dòng có Type không hợp lệ → 'E'), tránh việc save_modified
    "! schedule lại job vô hạn.
    CLASS-METHODS process
      CHANGING
        ct_data TYPE tt_data.

    CLASS-METHODS insert
      CHANGING
        ct_data TYPE tt_data.

    CLASS-METHODS update
      CHANGING
        ct_data TYPE tt_data.

    CLASS-METHODS delete
      CHANGING
        ct_data TYPE tt_data.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CRUD_POC_IMPLEMENT IMPLEMENTATION.


  METHOD process.
    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    " ── 1. Chuẩn hóa Type + reset kết quả cũ (cho phép chạy lại dòng 'E') ──
    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      <ls_data>-type = to_upper( condense( <ls_data>-type ) ).
      CLEAR: <ls_data>-messagetype, <ls_data>-message.
    ENDLOOP.

    " ── 2. Tách theo Type ─────────────────────────────────────────
    DATA(lt_data_insert) = ct_data.
    DELETE lt_data_insert WHERE type <> 'I'.
    DATA(lt_data_update) = ct_data.
    DELETE lt_data_update WHERE type <> 'M'.
    DATA(lt_data_delete) = ct_data.
    DELETE lt_data_delete WHERE type <> 'D'.

    " ── 3. Xử lý ──────────────────────────────────────────────────
    insert( CHANGING ct_data = lt_data_insert ).
    update( CHANGING ct_data = lt_data_update ).
    delete( CHANGING ct_data = lt_data_delete ).

    " ── 4. Merge kết quả về ct_data (key: uuid + uuidfile) ───────
    DATA(lt_result) = lt_data_insert.
    APPEND LINES OF lt_data_update TO lt_result.
    APPEND LINES OF lt_data_delete TO lt_result.
    SORT lt_result BY uuid uuidfile.

    LOOP AT ct_data ASSIGNING <ls_data>.
      READ TABLE lt_result INTO DATA(ls_result)
           WITH KEY uuid     = <ls_data>-uuid
                    uuidfile = <ls_data>-uuidfile
           BINARY SEARCH.
      IF sy-subrc = 0 AND ls_result-messagetype IS NOT INITIAL.
        <ls_data>-messagetype = ls_result-messagetype.
        <ls_data>-message     = ls_result-message.
      ELSEIF sy-subrc <> 0.
        " Type không thuộc I/M/D → không xử lý được
        <ls_data>-messagetype = 'E'.
        <ls_data>-message     = |Type '{ <ls_data>-type }' không hợp lệ (chỉ chấp nhận I/M/D)|.
      ELSE.
        <ls_data>-messagetype = 'E'.
        <ls_data>-message     = 'Không xác định được kết quả xử lý'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD insert.
    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.


    "1. từ mã lệnh sản xuất (cột B) + Công đoạn sử dụng (cột C) trong file Excel
    " --> Select CDS I_ProductionOrderOperationTP theo where field lần lượt:
    "     I_ProductionOrderOperationTP-ProductionOrder
    "     I_ProductionOrderOperationTP-ProductionOrderOperation
    "     --> Lấy được key là OrderInternalID + OrderOperationInternalID
    SELECT FROM I_ProductionOrderOperationTP AS a
    FIELDS
        a~ProductionOrder,
        a~ProductionOrderOperation,
        a~OrderInternalID,
        a~OrderOperationInternalID
        FOR ALL ENTRIES IN @ct_data
    WHERE
        a~ProductionOrder = @ct_data-manufacturing_order
        AND a~ProductionOrderOperation = @ct_data-manufacturing_order_operation
    INTO TABLE @DATA(lt_create_keys).
    IF sy-subrc <> 0.
      LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<lfs_data>).
        <lfs_data>-messagetype = 'E'.
        <lfs_data>-message = |Không tồn tại LSX: { <lfs_data>-manufacturing_order }-{ <lfs_data>-manufacturing_order_operation }|.
      ENDLOOP.
      RETURN.
    ENDIF.

    "2. Dùng EML để create
    DATA lt_create_comp TYPE TABLE FOR CREATE i_productionorderoperationtp\_OperationComponent.

    SORT lt_create_keys BY productionorder productionorderoperation.
    LOOP AT ct_data ASSIGNING <lfs_data>.
      DATA(lv_index) = sy-tabix.

      READ TABLE lt_create_keys INTO DATA(ls_create_keys) WITH KEY
          ProductionOrder = <lfs_data>-manufacturing_order
          ProductionOrderOperation = <lfs_data>-manufacturing_order_operation.
      IF sy-subrc <> 0.
        <lfs_data>-messagetype = 'E'.
        <lfs_data>-message     = |Không tồn tại LSX: { <lfs_data>-manufacturing_order }-{ <lfs_data>-manufacturing_order_operation }|.
        CONTINUE.
      ENDIF.

      " Tìm parent entry trong lt_create_comp theo OrderInternalID + OrderOperationInternalID
      READ TABLE lt_create_comp ASSIGNING FIELD-SYMBOL(<lfs_parent>) WITH TABLE KEY entity
           COMPONENTS %key-OrderInternalID          = ls_create_keys-orderinternalid
                      %key-OrderOperationInternalID = ls_create_keys-orderoperationinternalid.

      IF sy-subrc <> 0.
        " Chưa có parent → tạo mới
        APPEND VALUE #(
          %key-OrderInternalID          = ls_create_keys-orderinternalid
          %key-OrderOperationInternalID = ls_create_keys-orderoperationinternalid
          %target                       = VALUE #( )
        ) TO lt_create_comp ASSIGNING <lfs_parent>.
      ENDIF.

      " Append component vào %target của parent
      APPEND VALUE #(
        %cid                             = |COMP_{ lv_index }|
        %data-ProductionOrder            = <lfs_data>-manufacturing_order
        %data-ProductionOrderOperation   = <lfs_data>-manufacturing_order_operation
        %data-BillOfMaterialItemCategory = <lfs_data>-bom_item_category
        %data-Material                   = <lfs_data>-material
        %data-RequiredQuantity           = <lfs_data>-required_quantity
        %data-BaseUnit                   = <lfs_data>-base_unit
        %data-Plant                      = <lfs_data>-plant
        %data-StorageLocation            = <lfs_data>-storage_location
      ) TO <lfs_parent>-%target.

    ENDLOOP.

    "3. EML Create
    MODIFY ENTITIES OF i_productionordertp PRIVILEGED
    ENTITY ProductionOrderOperation
    CREATE BY \_OperationComponent
    FIELDS (
     ProductionOrder
     ProductionOrderOperation
     BillOfMaterialItemCategory
     Material
     RequiredQuantity
     BaseUnit
     Plant
     StorageLocation
    )
    WITH lt_create_comp
    MAPPED DATA(ls_mapped)
    FAILED DATA(ls_failed)
    REPORTED DATA(ls_reported).

    "4. xử lý kết quả
    "4.1. Build message map từ REPORTED theo %cid
    TYPES: BEGIN OF ty_msg,
             cid TYPE abp_behv_cid,
             msg TYPE string,
           END OF ty_msg.
    DATA lt_msg_map TYPE SORTED TABLE OF ty_msg WITH UNIQUE KEY cid.

    LOOP AT ls_reported-productionordercomponent INTO DATA(ls_rep).
      DATA(lv_msg_text) = COND string(
          WHEN ls_rep-%msg IS BOUND
          THEN ls_rep-%msg->if_message~get_longtext( )
          ELSE 'Lỗi không xác định'
      ).

      READ TABLE lt_msg_map ASSIGNING FIELD-SYMBOL(<fs_msg>)
           WITH KEY cid = ls_rep-%cid.
      IF sy-subrc = 0.
        <fs_msg>-msg = |{ <fs_msg>-msg }; { lv_msg_text }|.
      ELSE.
        INSERT VALUE #( cid = ls_rep-%cid
                        msg = lv_msg_text ) INTO TABLE lt_msg_map.
      ENDIF.
    ENDLOOP.

    "4.2. Loop ct_data, write back message theo %cid
    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<lfs_result>).
      DATA(lv_result_idx) = sy-tabix.

      " Skip nếu đã có error từ bước 2 (LSX không tồn tại)
      IF <lfs_result>-messagetype = 'E'.
        CONTINUE.
      ENDIF.

      DATA(lv_cid) = |COMP_{ lv_result_idx }|.

      " Kiểm tra row có nằm trong FAILED không
      READ TABLE ls_failed-productionordercomponent WITH KEY cid
           COMPONENTS %cid = lv_cid
           TRANSPORTING NO FIELDS.

      IF sy-subrc = 0.
        " Failed
        READ TABLE lt_msg_map WITH KEY cid = lv_cid INTO DATA(ls_msg).
        <lfs_result>-messagetype = 'E'.
        <lfs_result>-message     = COND #(
            WHEN sy-subrc = 0 AND ls_msg-msg IS NOT INITIAL
            THEN ls_msg-msg
            ELSE 'Tạo Component thất bại (không có message chi tiết)' ).
      ELSE.
        " Success
        <lfs_result>-messagetype = 'S'.
        <lfs_result>-message     = 'Tạo Component thành công'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD update.
    " Bảng rỗng → FOR ALL ENTRIES sẽ bỏ WHERE và đọc toàn bộ CDS
    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    "Validate --> yêu cầu điền tất cả các field
    "...

    "Từ Production Order + BOM Item Number + gán cứng Mvt = 261 hoặc 543
    "   --> tìm ngược lại lấy được số reservation
    SELECT FROM I_ProductionOrderOpComponentTP AS a
    FIELDS
        a~ProductionOrder,
        a~BillOfMaterialItemNumber,
        a~Reservation,
        a~ReservationItem,
        a~ReservationRecordType
        FOR ALL ENTRIES IN @ct_data
    WHERE
        a~ProductionOrder = @ct_data-manufacturing_order
        AND a~BillOfMaterialItemNumber = @ct_data-bom_item
        AND a~GoodsMovementType IN ('543','261')
    INTO TABLE @DATA(lt_udt_keys).

    IF sy-subrc <> 0.
      LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<lfs_data>).
        <lfs_data>-messagetype = 'E'.
        <lfs_data>-message = |Không tồn tại LSX: { <lfs_data>-manufacturing_order }-{ <lfs_data>-bom_item }|.
      ENDLOOP.
      RETURN.
    ELSE.
      SORT lt_udt_keys BY productionorder billofmaterialitemnumber.
    ENDIF.

    LOOP AT ct_data ASSIGNING <lfs_data>.
      " Skip nếu đã có error từ bước validate
      IF <lfs_data>-messagetype = 'E'.
        CONTINUE.
      ENDIF.

      "Tìm key Reservation tương ứng
      READ TABLE lt_udt_keys ASSIGNING FIELD-SYMBOL(<lfs_key>)
           WITH KEY productionorder          = <lfs_data>-manufacturing_order
                    billofmaterialitemnumber = <lfs_data>-bom_item
           BINARY SEARCH.
      IF sy-subrc <> 0.
        <lfs_data>-messagetype = 'E'.
        <lfs_data>-message     = |Không tìm thấy reservation cho LSX: { <lfs_data>-manufacturing_order }-{ <lfs_data>-bom_item }|.
        CONTINUE.
      ENDIF.
      "Chạy API PATCH
      DATA: lv_endpoint TYPE string,
            lv_body     TYPE string.

      lv_endpoint =
         '/sap/opu/odata/sap/API_PRODUCTION_ORDER_2_SRV'
         && |/A_ProductionOrderComponent_4(Reservation='{ <lfs_key>-Reservation }',|
         && |ReservationItem='{ <lfs_key>-ReservationItem }',|
         && |ReservationRecordType='{ <lfs_key>-ReservationRecordType }')|.
      lv_body =
          |\{|
          && |"Material": "{ <lfs_data>-material }",|
          && |"RequiredQuantity": "{ <lfs_data>-required_quantity }",|
          && |"BaseUnit": "{ <lfs_data>-base_unit }",|
          && |"Plant": "{ <lfs_data>-plant }",|
          && |"StorageLocation": "{ <lfs_data>-storage_location }"|
          && |\}|.
      DATA(lv_result) = zcl_call_api_crud_poc=>main(
                          iv_body     = lv_body
                          iv_endpoint = lv_endpoint
                          iv_method   = 'PATCH'
                        ).
      IF zcl_call_api_crud_poc=>code = 200
          OR zcl_call_api_crud_poc=>code = 201
          OR zcl_call_api_crud_poc=>code = 202
          OR zcl_call_api_crud_poc=>code = 204.
        " ── Success ──────────────────────────────────────────────────
        <lfs_data>-messagetype = 'S'.
        <lfs_data>-message     = 'Success'.
      ELSE.
        " ── Error — parse message từ response JSON ───────────────────
        <lfs_data>-messagetype = 'E'.

        " Thử parse error message từ response
        " Response format: {"error":{"message":{"value":"..."}}}
        DATA(lv_msg) = ||.
        FIND REGEX '"value"\s*:\s*"([^"]*)"' IN lv_result SUBMATCHES lv_msg.
        IF sy-subrc = 0 AND lv_msg IS NOT INITIAL.
          <lfs_data>-message = lv_msg.
        ELSE.
          <lfs_data>-message = |API Error HTTP { zcl_call_api_crud_poc=>code }|.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD delete.
    " Bảng rỗng → FOR ALL ENTRIES sẽ bỏ WHERE và đọc toàn bộ CDS
    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    "Validate --> yêu cầu điền tất cả các field
    "...

    "Từ Production Order + BOM Item Number + gán cứng Mvt = 261 hoặc 543
    "   --> tìm ngược lại lấy được số reservation
    SELECT FROM I_ProductionOrderOpComponentTP AS a
    FIELDS
        a~ProductionOrder,
        a~BillOfMaterialItemNumber,
        a~Reservation,
        a~ReservationItem,
        a~ReservationRecordType
        FOR ALL ENTRIES IN @ct_data
    WHERE
        a~ProductionOrder = @ct_data-manufacturing_order
        AND a~BillOfMaterialItemNumber = @ct_data-bom_item
        AND a~GoodsMovementType IN ('543','261')
    INTO TABLE @DATA(lt_del_keys).

    IF sy-subrc <> 0.
      LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<lfs_data>).
        <lfs_data>-messagetype = 'E'.
        <lfs_data>-message = |Không tồn tại LSX: { <lfs_data>-manufacturing_order }-{ <lfs_data>-bom_item }|.
      ENDLOOP.
      RETURN.
    ELSE.
      SORT lt_del_keys BY productionorder billofmaterialitemnumber.
    ENDIF.

    LOOP AT ct_data ASSIGNING <lfs_data>.
      " Skip nếu đã có error từ bước validate
      IF <lfs_data>-messagetype = 'E'.
        CONTINUE.
      ENDIF.

      "Tìm key Reservation tương ứng
      READ TABLE lt_del_keys ASSIGNING FIELD-SYMBOL(<lfs_key>)
           WITH KEY productionorder          = <lfs_data>-manufacturing_order
                    billofmaterialitemnumber = <lfs_data>-bom_item
           BINARY SEARCH.
      IF sy-subrc <> 0.
        <lfs_data>-messagetype = 'E'.
        <lfs_data>-message     = |Không tìm thấy reservation cho LSX: { <lfs_data>-manufacturing_order }-{ <lfs_data>-bom_item }|.
        CONTINUE.
      ENDIF.
      "Chạy API PATCH
      DATA: lv_endpoint TYPE string.

      lv_endpoint =
         '/sap/opu/odata/sap/API_PRODUCTION_ORDER_2_SRV'
         && |/A_ProductionOrderComponent_4(Reservation='{ <lfs_key>-Reservation }',|
         && |ReservationItem='{ <lfs_key>-ReservationItem }',|
         && |ReservationRecordType='{ <lfs_key>-ReservationRecordType }')|.

      DATA(lv_result) = zcl_call_api_crud_poc=>main(
                          iv_endpoint = lv_endpoint
                          iv_method   = 'DELETE'
                        ).
      IF zcl_call_api_crud_poc=>code = 200
          OR zcl_call_api_crud_poc=>code = 201
          OR zcl_call_api_crud_poc=>code = 202
          OR zcl_call_api_crud_poc=>code = 204.
        " ── Success ──────────────────────────────────────────────────
        <lfs_data>-messagetype = 'S'.
        <lfs_data>-message     = 'Success'.
      ELSE.
        " ── Error — parse message từ response JSON ───────────────────
        <lfs_data>-messagetype = 'E'.

        " Thử parse error message từ response
        " Response format: {"error":{"message":{"value":"..."}}}
        DATA(lv_msg) = ||.
        FIND REGEX '"value"\s*:\s*"([^"]*)"' IN lv_result SUBMATCHES lv_msg.
        IF sy-subrc = 0 AND lv_msg IS NOT INITIAL.
          <lfs_data>-message = lv_msg.
        ELSE.
          <lfs_data>-message = |API Error HTTP { zcl_call_api_crud_poc=>code }|.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
