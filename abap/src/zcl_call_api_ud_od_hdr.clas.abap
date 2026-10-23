CLASS zcl_call_api_ud_od_hdr DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES BEGIN OF ty_header.
    TYPES Uuid TYPE sysuuid_x16.
    TYPES UuidFile TYPE sysuuid_x16.
    TYPES Od TYPE c LENGTH 10.
    TYPES PlanGiDate TYPE string.
    TYPES IncoVers TYPE string.
    TYPES Incoterm TYPE string.
    TYPES IncoLoc1 TYPE string.
    TYPES IncoLoc2 TYPE string.
    TYPES NhaCungCapVanTai TYPE string.
    TYPES PhanLoaiPtvt TYPE string.
    TYPES SoLuongPtvt TYPE string.
    TYPES BienSoXe TYPE string.
    TYPES SoContainer TYPE string.
    TYPES SoSeal TYPE string.
    TYPES TareWeight TYPE string.
    TYPES Booking TYPE string.
    TYPES NgayTauChay TYPE string.
    TYPES NgayGioXuatHang TYPE string.
    TYPES CutOffTime TYPE string.
    TYPES GhiChuGiaoHang TYPE string.
    TYPES TyGiaLoNoiDia TYPE string.
    TYPES HasPlanGiDate TYPE abap_boolean.
    TYPES HasIncoVers TYPE abap_boolean.
    TYPES HasIncoterm TYPE abap_boolean.
    TYPES HasIncoLoc1 TYPE abap_boolean.
    TYPES HasIncoLoc2 TYPE abap_boolean.
    TYPES HasNhaCungCapVanTai TYPE abap_boolean.
    TYPES HasPhanLoaiPtvt TYPE abap_boolean.
    TYPES HasSoLuongPtvt TYPE abap_boolean.
    TYPES HasBienSoXe TYPE abap_boolean.
    TYPES HasSoContainer TYPE abap_boolean.
    TYPES HasSoSeal TYPE abap_boolean.
    TYPES HasTareWeight TYPE abap_boolean.
    TYPES HasBooking TYPE abap_boolean.
    TYPES HasNgayTauChay TYPE abap_boolean.
    TYPES HasNgayGioXuatHang TYPE abap_boolean.
    TYPES HasCutOffTime TYPE abap_boolean.
    TYPES HasGhiChuGiaoHang TYPE abap_boolean.
    TYPES HasTyGiaLoNoiDia TYPE abap_boolean.
    TYPES MessageType TYPE c LENGTH 1.
    TYPES Message TYPE string.
    TYPES END OF ty_header.
    TYPES tt_header TYPE STANDARD TABLE OF ty_header WITH EMPTY KEY.

    CLASS-METHODS update_header CHANGING ct_data TYPE tt_header.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES BEGIN OF ty_error_message.
    TYPES value TYPE string.
    TYPES END OF ty_error_message.

    TYPES BEGIN OF ty_error_flat_detail.
    TYPES code TYPE string.
    TYPES message TYPE string.
    TYPES END OF ty_error_flat_detail.

    TYPES BEGIN OF ty_error_flat_response.
    TYPES error TYPE ty_error_flat_detail.
    TYPES END OF ty_error_flat_response.

    TYPES BEGIN OF ty_error_detail_item.
    TYPES code        TYPE string.
    TYPES message     TYPE string.
    TYPES propertyref TYPE string.
    TYPES severity    TYPE string.
    TYPES target      TYPE string.
    TYPES END OF ty_error_detail_item.
    TYPES tt_error_detail_item TYPE STANDARD TABLE OF ty_error_detail_item WITH EMPTY KEY.

    TYPES BEGIN OF ty_inner_error.
    TYPES errordetails TYPE tt_error_detail_item.
    TYPES END OF ty_inner_error.

    TYPES BEGIN OF ty_error_v2_detail.
    TYPES code       TYPE string.
    TYPES message    TYPE ty_error_message.
    TYPES innererror TYPE ty_inner_error.
    TYPES END OF ty_error_v2_detail.

    TYPES BEGIN OF ty_error_v2_response.
    TYPES error TYPE ty_error_v2_detail.
    TYPES END OF ty_error_v2_response.

    TYPES BEGIN OF ty_hdr_read_d.
    TYPES PlannedGoodsIssueDate     TYPE string.
    TYPES GoodsIssueTime            TYPE string.
    TYPES Shippinglocationtimezone  TYPE string.
    TYPES IncotermsClassification   TYPE string.
    TYPES IncotermsTransferLocation TYPE string.
    TYPES END OF ty_hdr_read_d.

    TYPES BEGIN OF ty_hdr_read.
    TYPES d TYPE ty_hdr_read_d.
    TYPES END OF ty_hdr_read.

    TYPES BEGIN OF ty_text_task.
    TYPES text_id TYPE string.
    TYPES label   TYPE string.
    TYPES has     TYPE abap_boolean.
    TYPES value   TYPE string.
    TYPES END OF ty_text_task.
    TYPES tt_text_task TYPE STANDARD TABLE OF ty_text_task WITH EMPTY KEY.

    CONSTANTS c_service_root TYPE string
      VALUE `/sap/opu/odata/sap/API_OUTBOUND_DELIVERY_SRV;v=2/`.
    CONSTANTS c_entity_header TYPE string   VALUE `A_OutbDeliveryHeader`.
    CONSTANTS c_entity_text   TYPE string   VALUE `A_OutbDeliveryHeaderText`.
    CONSTANTS c_nav_text      TYPE string   VALUE `to_DeliveryDocumentText`.
    CONSTANTS c_language      TYPE string   VALUE `EN`.
    CONSTANTS c_api_name      TYPE string   VALUE `API_OUTBOUND_DELIVERY_SRV`.
    CONSTANTS c_max_message   TYPE i        VALUE 5000.
    CONSTANTS c_err_locked    TYPE string   VALUE `LE_SHP_ODATA_API_OD/041`.
    CONSTANTS c_epoch         TYPE d        VALUE '19700101'.
    CONSTANTS c_ms_per_day    TYPE int8     VALUE 86400000.
    CONSTANTS c_tz_utc        TYPE timezone VALUE 'UTC'.
    CONSTANTS c_len_incoterm  TYPE i        VALUE 3.
    CONSTANTS c_len_inco_loc  TYPE i        VALUE 70.

    CONSTANTS:
      BEGIN OF text_id,
        nha_cung_cap_van_tai TYPE string VALUE `Z031`,
        phan_loai_ptvt       TYPE string VALUE `Z034`,
        so_luong_ptvt        TYPE string VALUE `Z033`,
        bien_so_xe           TYPE string VALUE `Z005`,
        so_container         TYPE string VALUE `Z006`,
        so_seal              TYPE string VALUE `Z029`,
        tare_weight          TYPE string VALUE `Z045`,
        booking              TYPE string VALUE `Z047`,
        ngay_tau_chay        TYPE string VALUE `Z010`,
        ngay_gio_xuat_hang   TYPE string VALUE `Z007`,
        cut_off_time         TYPE string VALUE `Z008`,
        ghi_chu_giao_hang    TYPE string VALUE `Z009`,
        ty_gia_lo_noi_dia    TYPE string VALUE `Z046`,
      END OF text_id.

    CLASS-METHODS build_text_tasks IMPORTING is_data         TYPE ty_header
                                   RETURNING VALUE(rt_tasks) TYPE tt_text_task.
    CLASS-METHODS update_header_fields IMPORTING is_data   TYPE ty_header
                                       CHANGING  ct_errors TYPE string_table.
    CLASS-METHODS update_header_text IMPORTING is_data TYPE ty_header iv_text_id TYPE string iv_text TYPE string
      EXPORTING ev_message TYPE string RETURNING VALUE(rv_ok) TYPE abap_bool.
    CLASS-METHODS read_header IMPORTING iv_od TYPE ty_header-Od
      EXPORTING es_hdr TYPE ty_hdr_read_d ev_ts TYPE timestamp
      RETURNING VALUE(rv_raw) TYPE string.
    CLASS-METHODS do_call IMPORTING iv_endpoint TYPE string iv_method TYPE string iv_body TYPE string OPTIONAL
      EXPORTING ev_code TYPE i ev_response TYPE string ev_message TYPE string RETURNING VALUE(rv_ok) TYPE abap_bool.
    CLASS-METHODS do_call_retry IMPORTING iv_endpoint TYPE string iv_method TYPE string iv_body TYPE string OPTIONAL
      EXPORTING ev_code TYPE i ev_response TYPE string ev_message TYPE string RETURNING VALUE(rv_ok) TYPE abap_bool.
    CLASS-METHODS to_date IMPORTING iv_value TYPE string EXPORTING ev_date TYPE d
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    CLASS-METHODS from_v2_ms IMPORTING iv_literal TYPE string RETURNING VALUE(rv_ms) TYPE int8.
    CLASS-METHODS iso_to_time IMPORTING iv_literal TYPE string RETURNING VALUE(rv_time) TYPE t.
    CLASS-METHODS error_text IMPORTING iv_response TYPE string RETURNING VALUE(rv_message) TYPE string.
    CLASS-METHODS escape_json IMPORTING iv_text TYPE string RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS ZCL_CALL_API_UD_OD_HDR IMPLEMENTATION.


  METHOD update_header.
    DATA errors  TYPE string_table.
    DATA message TYPE string.
    DATA ok      TYPE abap_bool.

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<row>).
      CLEAR errors.

      " Text trước: tránh để call text đầu tiên dính lock của PATCH header
      LOOP AT build_text_tasks( <row> ) INTO DATA(task) WHERE has = abap_true.
        ok = update_header_text( EXPORTING is_data    = <row>
                                           iv_text_id = task-text_id
                                           iv_text    = task-value
                                 IMPORTING ev_message = message ).
        IF ok = abap_false.
          APPEND |{ task-label }: { message }| TO errors.
        ENDIF.
      ENDLOOP.

      " Header field gộp một PATCH, chạy sau cùng
      update_header_fields( EXPORTING is_data   = <row>
                            CHANGING  ct_errors = errors ).

      IF errors IS INITIAL.
        <row>-MessageType = 'S'.
        <row>-Message     = 'Success'.
      ELSE.
        DATA(full_message) = concat_lines_of( table = errors sep = '; ' ).
        <row>-MessageType = 'E'.
        <row>-Message = substring( val = full_message
                                   len = nmin( val1 = c_max_message
                                               val2 = strlen( full_message ) ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_text_tasks.
    rt_tasks = VALUE #(
      ( text_id = text_id-nha_cung_cap_van_tai label = `Nhà cung cấp vận tải`
        has = is_data-HasNhaCungCapVanTai      value = is_data-NhaCungCapVanTai )
      ( text_id = text_id-phan_loai_ptvt       label = `Phân loại PTVT`
        has = is_data-HasPhanLoaiPtvt          value = is_data-PhanLoaiPtvt )
      ( text_id = text_id-so_luong_ptvt        label = `Số lượng PTVT`
        has = is_data-HasSoLuongPtvt           value = is_data-SoLuongPtvt )
      ( text_id = text_id-bien_so_xe           label = `Biển số xe`
        has = is_data-HasBienSoXe              value = is_data-BienSoXe )
      ( text_id = text_id-so_container         label = `Số container`
        has = is_data-HasSoContainer           value = is_data-SoContainer )
      ( text_id = text_id-so_seal              label = `Số seal`
        has = is_data-HasSoSeal                value = is_data-SoSeal )
      ( text_id = text_id-tare_weight          label = `Tare weight`
        has = is_data-HasTareWeight            value = is_data-TareWeight )
      ( text_id = text_id-booking              label = `Booking`
        has = is_data-HasBooking               value = is_data-Booking )
      ( text_id = text_id-ngay_tau_chay        label = `Ngày tàu chạy`
        has = is_data-HasNgayTauChay           value = is_data-NgayTauChay )
      ( text_id = text_id-ngay_gio_xuat_hang   label = `Ngày giờ xuất hàng`
        has = is_data-HasNgayGioXuatHang       value = is_data-NgayGioXuatHang )
      ( text_id = text_id-cut_off_time         label = `Cut-off time`
        has = is_data-HasCutOffTime            value = is_data-CutOffTime )
      ( text_id = text_id-ghi_chu_giao_hang    label = `Ghi chú giao hàng`
        has = is_data-HasGhiChuGiaoHang        value = is_data-GhiChuGiaoHang )
      ( text_id = text_id-ty_gia_lo_noi_dia    label = `Tỷ giá lô nội địa`
        has = is_data-HasTyGiaLoNoiDia         value = is_data-TyGiaLoNoiDia ) ).
  ENDMETHOD.


  METHOD update_header_fields.
    DATA: code       TYPE i,
          response   TYPE string,
          parts      TYPE string_table,
          gi_date    TYPE d,
          target_ts  TYPE timestamp,
          stored_ts  TYPE timestamp,
          before_hdr TYPE ty_hdr_read_d,
          after_hdr  TYPE ty_hdr_read_d,
          tz         TYPE timezone,
          has_date   TYPE abap_bool.

    IF is_data-HasPlanGiDate = abap_false
       AND is_data-HasIncoterm = abap_false
       AND is_data-HasIncoLoc1 = abap_false.
      RETURN.
    ENDIF.

    DATA(incoterm) = condense( is_data-Incoterm ).
    DATA(inco_loc1) = condense( is_data-IncoLoc1 ).

    DATA(before_raw) = read_header( EXPORTING iv_od  = is_data-Od
                                    IMPORTING es_hdr = before_hdr ).
    tz = before_hdr-Shippinglocationtimezone.

    " Plan GI date: cặp date/time UTC tính theo múi giờ shipping location
    IF is_data-HasPlanGiDate = abap_true.
      IF to_date( EXPORTING iv_value = is_data-PlanGiDate
                  IMPORTING ev_date  = gi_date ) = abap_false.
        APPEND |Plan GI date: định dạng không hợp lệ "{ is_data-PlanGiDate }", cần DD/MM/YYYY| TO ct_errors.
      ELSEIF tz IS INITIAL.
        APPEND |Plan GI date: không xác định được múi giờ shipping location; got [{ before_raw }]| TO ct_errors.
      ELSE.
        CONVERT DATE gi_date TIME '000000'
          INTO TIME STAMP target_ts TIME ZONE tz.

        DATA(ts) = |{ target_ts }|.
        APPEND |"PlannedGoodsIssueDate":"{ ts+0(4) }-{ ts+4(2) }-{ ts+6(2) }T00:00:00"| TO parts.
        APPEND |"GoodsIssueTime":"PT{ ts+8(2) }H{ ts+10(2) }M{ ts+12(2) }S"| TO parts.
        has_date = abap_true.
      ENDIF.
    ENDIF.

    IF is_data-HasIncoterm = abap_true.
      IF strlen( incoterm ) > c_len_incoterm.
        APPEND |Incoterm: "{ incoterm }" dài quá { c_len_incoterm } ký tự| TO ct_errors.
      ELSE.
        APPEND |"IncotermsClassification":"{ escape_json( incoterm ) }"| TO parts.
      ENDIF.
    ENDIF.

    IF is_data-HasIncoLoc1 = abap_true.
      IF strlen( inco_loc1 ) > c_len_inco_loc.
        APPEND |Inco. Loc1: "{ inco_loc1 }" dài quá { c_len_inco_loc } ký tự| TO ct_errors.
      ELSE.
        APPEND |"IncotermsTransferLocation":"{ escape_json( inco_loc1 ) }"| TO parts.
      ENDIF.
    ENDIF.

    IF parts IS INITIAL.
      RETURN.
    ENDIF.

    DATA(endpoint) = |{ c_service_root }{ c_entity_header }(DeliveryDocument='{ is_data-Od }')|.
    DATA(body)     = |\{ { concat_lines_of( table = parts sep = `,` ) } \}|.

    DATA: patch_message TYPE string.

    IF do_call_retry( EXPORTING iv_endpoint = endpoint
                                iv_method   = 'PATCH'
                                iv_body     = body
                      IMPORTING ev_message  = patch_message
                                ev_code     = code
                                ev_response = response ) = abap_false.
      APPEND |Header fields: { patch_message }| TO ct_errors.
      RETURN.
    ENDIF.

    " Đọc lại và đối chiếu từng field đã gửi
    DATA(after_raw) = read_header( EXPORTING iv_od  = is_data-Od
                                   IMPORTING es_hdr = after_hdr
                                             ev_ts  = stored_ts ).

    IF has_date = abap_true AND stored_ts <> target_ts.
      APPEND |Plan GI date: sent { target_ts } stored { stored_ts } tz={ tz }; | &&
             |before=[{ before_raw }] after=[{ after_raw }]| TO ct_errors.
    ENDIF.

    IF is_data-HasIncoterm = abap_true
       AND to_upper( condense( after_hdr-IncotermsClassification ) ) <> to_upper( incoterm ).
      APPEND |Incoterm: sent "{ incoterm }" stored "{ after_hdr-IncotermsClassification }"| TO ct_errors.
    ENDIF.

    IF is_data-HasIncoLoc1 = abap_true
       AND condense( after_hdr-IncotermsTransferLocation ) <> inco_loc1.
      APPEND |Inco. Loc1: sent "{ inco_loc1 }" stored "{ after_hdr-IncotermsTransferLocation }"| TO ct_errors.
    ENDIF.
  ENDMETHOD.


  METHOD update_header_text.
    DATA: code          TYPE i,
          response      TYPE string,
          patch_message TYPE string,
          post_message  TYPE string.

    " Entity text dùng OD không leading zeros, khác với entity header
    DATA(od_plain) = condense( |{ is_data-Od ALPHA = OUT }| ).

    DATA(text_url) = |{ c_service_root }{ c_entity_text }| &&
                     |(DeliveryDocument='{ od_plain }',| &&
                     |TextElement='{ iv_text_id }',| &&
                     |Language='{ c_language }')|.

    rv_ok = do_call_retry(
      EXPORTING iv_endpoint = text_url
                iv_method   = 'PATCH'
                iv_body     = |\{ "TextElementText":"{ escape_json( iv_text ) }" \}|
      IMPORTING ev_message  = patch_message
                ev_code     = code
                ev_response = response ).

    IF rv_ok = abap_true.
      CLEAR ev_message.
      RETURN.
    ENDIF.

    " Chỉ 404 mới có nghĩa là text chưa tồn tại (URL đã đúng)
    IF code <> 404.
      ev_message = |PATCH { patch_message }|.
      RETURN.
    ENDIF.

    DATA(create_url) = |{ c_service_root }{ c_entity_header }| &&
                       |(DeliveryDocument='{ is_data-Od }')/{ c_nav_text }|.
    DATA(body) = |\{ "TextElement":"{ iv_text_id }",| &&
                 |"Language":"{ c_language }",| &&
                 |"TextElementText":"{ escape_json( iv_text ) }" \}|.

    rv_ok = do_call_retry(
      EXPORTING iv_endpoint = create_url
                iv_method   = 'POST'
                iv_body     = body
      IMPORTING ev_message  = post_message
                ev_code     = code
                ev_response = response ).

    IF rv_ok = abap_false.
      ev_message = |PATCH { patch_message } / POST { post_message }|.
    ELSE.
      CLEAR ev_message.
    ENDIF.
  ENDMETHOD.


  METHOD read_header.
    DATA: code     TYPE i,
          message  TYPE string,
          response TYPE string.

    CLEAR: es_hdr, ev_ts.

    DATA(endpoint) = |{ c_service_root }{ c_entity_header }| &&
                     |(DeliveryDocument='{ iv_od }')?$format=json|.

    IF do_call( EXPORTING iv_endpoint = endpoint
                          iv_method   = 'GET'
                IMPORTING ev_code     = code
                          ev_response = response
                          ev_message  = message ) = abap_false.
      rv_raw = |GET failed: { message }|.
      RETURN.
    ENDIF.

    TRY.
        DATA(hdr) = VALUE ty_hdr_read( ).
        /ui2/cl_json=>deserialize( EXPORTING json = response CHANGING data = hdr ).

        es_hdr = hdr-d.
        rv_raw = |{ hdr-d-PlannedGoodsIssueDate } { hdr-d-GoodsIssueTime } | &&
                 |tz={ hdr-d-Shippinglocationtimezone } | &&
                 |inco={ hdr-d-IncotermsClassification }/{ hdr-d-IncotermsTransferLocation }|.

        DATA(ms) = from_v2_ms( hdr-d-PlannedGoodsIssueDate ).
        IF ms > 0.
          DATA(gi_date) = c_epoch + CONV i( ms DIV c_ms_per_day ).
          CONVERT DATE gi_date TIME iso_to_time( hdr-d-GoodsIssueTime )
            INTO TIME STAMP ev_ts TIME ZONE c_tz_utc.
        ENDIF.
      CATCH cx_root.
        rv_raw = response.
    ENDTRY.
  ENDMETHOD.


  METHOD do_call.
    ev_response = zcl_call_api=>call_api( iv_body     = iv_body
                                          iv_endpoint = iv_endpoint
                                          iv_apiName  = c_api_name
                                          iv_method   = iv_method ).
    ev_code = zcl_call_api=>code.
    rv_ok = xsdbool( ev_code = 200 OR ev_code = 201 OR ev_code = 204 ).
    IF rv_ok = abap_false.
      ev_message = |HTTP { ev_code }: { error_text( ev_response ) }|.
    ENDIF.
  ENDMETHOD.


  METHOD do_call_retry.
    rv_ok = do_call( EXPORTING iv_endpoint = iv_endpoint
                               iv_method   = iv_method
                               iv_body     = iv_body
                     IMPORTING ev_code     = ev_code
                               ev_response = ev_response
                               ev_message  = ev_message ).

    IF rv_ok = abap_true OR ev_response NS c_err_locked.
      RETURN.
    ENDIF.

    " Chứng từ còn bị khoá bởi call ngay trước đó -> thử lại một lần
    rv_ok = do_call( EXPORTING iv_endpoint = iv_endpoint
                               iv_method   = iv_method
                               iv_body     = iv_body
                     IMPORTING ev_code     = ev_code
                               ev_response = ev_response
                               ev_message  = ev_message ).
  ENDMETHOD.


  METHOD to_date.
    CLEAR ev_date.
    rv_ok = abap_false.

    DATA(value) = condense( iv_value ).
    IF strlen( value ) <> 10.
      RETURN.
    ENDIF.
    IF value+2(1) <> '/' OR value+5(1) <> '/'.
      RETURN.
    ENDIF.
    IF NOT ( value+0(2) CO '0123456789'
             AND value+3(2) CO '0123456789'
             AND value+6(4) CO '0123456789' ).
      RETURN.
    ENDIF.

    DATA(day)   = CONV i( value+0(2) ).
    DATA(month) = CONV i( value+3(2) ).
    DATA(year)  = CONV i( value+6(4) ).
    IF month < 1 OR month > 12 OR day < 1 OR day > 31 OR year < 1900 OR year > 9999.
      RETURN.
    ENDIF.

    DATA(candidate) = CONV d( |{ value+6(4) }{ value+3(2) }{ value+0(2) }| ).
    " Ngày không hợp lệ (31/02) bị normalize -> so sánh ngược để phát hiện
    IF candidate+0(4) <> value+6(4)
       OR candidate+4(2) <> value+3(2)
       OR candidate+6(2) <> value+0(2).
      RETURN.
    ENDIF.

    ev_date = candidate.
    rv_ok   = abap_true.
  ENDMETHOD.


  METHOD from_v2_ms.
    CLEAR rv_ms.

    DATA(v) = iv_literal.
    REPLACE ALL OCCURRENCES OF `\` IN v WITH ``.
    IF v NS `/Date(`.
      RETURN.
    ENDIF.

    DATA(p1) = find( val = v sub = `(` ).
    DATA(p2) = find( val = v sub = `)` ).
    IF p1 < 0 OR p2 <= p1.
      RETURN.
    ENDIF.

    DATA(num) = substring( val = v off = p1 + 1 len = p2 - p1 - 1 ).
    IF num CS `+`.
      SPLIT num AT `+` INTO num DATA(offset_part).
    ENDIF.
    IF num IS INITIAL OR NOT num CO `0123456789`.
      RETURN.
    ENDIF.

    rv_ms = CONV int8( num ).
  ENDMETHOD.


  METHOD iso_to_time.
    CLEAR rv_time.
    FIND REGEX `PT(\d\d)H(\d\d)M(\d\d)S` IN iv_literal
      SUBMATCHES DATA(hh) DATA(mm) DATA(ss).
    IF sy-subrc = 0.
      rv_time = |{ hh }{ mm }{ ss }|.
    ENDIF.
  ENDMETHOD.


  METHOD error_text.
    IF iv_response IS INITIAL.
      rv_message = 'API returned no response'.
      RETURN.
    ENDIF.

    " V2 Gateway: message ngoài thường chung chung, chi tiết nằm ở errordetails
    TRY.
        DATA(v2_response) = VALUE ty_error_v2_response( ).
        /ui2/cl_json=>deserialize(
          EXPORTING json = iv_response
          CHANGING  data = v2_response ).

        DATA details TYPE string_table.
        LOOP AT v2_response-error-innererror-errordetails INTO DATA(detail)
             WHERE message IS NOT INITIAL.
          APPEND |[{ detail-code }] { detail-message }| TO details.
        ENDLOOP.

        IF details IS NOT INITIAL.
          rv_message = concat_lines_of( table = details sep = ` | ` ).
          RETURN.
        ENDIF.

        IF v2_response-error-message-value IS NOT INITIAL.
          rv_message = |[{ v2_response-error-code }] { v2_response-error-message-value }|.
          RETURN.
        ENDIF.
      CATCH cx_root.
    ENDTRY.

    TRY.
        DATA(flat_response) = VALUE ty_error_flat_response( ).
        /ui2/cl_json=>deserialize(
          EXPORTING json = iv_response
          CHANGING  data = flat_response ).
        IF flat_response-error-message IS NOT INITIAL.
          rv_message = flat_response-error-message.
          RETURN.
        ENDIF.
      CATCH cx_root.
    ENDTRY.

    rv_message = iv_response.
  ENDMETHOD.


  METHOD escape_json.
    rv_text = iv_text.
    REPLACE ALL OCCURRENCES OF `\` IN rv_text WITH `\\`.
    REPLACE ALL OCCURRENCES OF `"` IN rv_text WITH `\"`.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_text WITH `\n`.
  ENDMETHOD.
ENDCLASS.
