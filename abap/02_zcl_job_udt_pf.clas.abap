"! <p>Job - Đồng bộ Partner function ZE (Sales Person) từ BP master sang SO chưa complete</p>
"! FS: Update partner function (SD – Hoàng Phương Thanh, 11/2026)
"! <ul>
"! <li>SO loại TA, Sales org 6710, 6720 – chỉ partner function ZE ở header SO</li>
"! <li>SO có OverallSDProcessStatus = A / B</li>
"! <li>(1) = ZE trên SO, (2) = ZE trên master (I_CustSalesPartnerFunc)</li>
"! <li>(1)=(2): bỏ qua | (2) trống: giữ nguyên | (1) trống: insert | khác nhau: ghi đè</li>
"! </ul>
CLASS zcl_job_udt_pf DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES ty_so_range TYPE RANGE OF i_salesorder-salesorder.

    TYPES: BEGIN OF ty_sel,
             change_date TYPE d,              " Ngày thay đổi BP theo giờ VN, trống = D-1
             so_range    TYPE ty_so_range,
             test        TYPE abap_boolean,
             full        TYPE abap_boolean,
           END OF ty_sel.

    " Khoảng thời gian lọc BP, quy đổi sang UTC (đơn vị lưu LastChangeDate/Time của hệ thống)
    TYPES: BEGIN OF ty_window,
             date_from TYPE d,
             time_from TYPE t,
             date_to   TYPE d,
             time_to   TYPE t,
           END OF ty_window.

    TYPES: BEGIN OF ty_so,
             sales_order  TYPE i_salesorder-salesorder,
             sold_to      TYPE i_salesorder-soldtoparty,
             sales_org    TYPE i_salesorder-salesorganization,
             distr_chan   TYPE i_salesorder-distributionchannel,
             division     TYPE i_salesorder-organizationdivision,
             so_ze_pf     TYPE i_salesorderpartner-partnerfunction, " có giá trị = SO đã có dòng ZE
             so_ze        TYPE i_salesorderpartner-customer,
             master_ze    TYPE i_custsalespartnerfunc-bpcustomernumber,
             default_flag TYPE i_custsalespartnerfunc-defaultpartner,
             counter      TYPE i_custsalespartnerfunc-partnercounter,
           END OF ty_so,
           tt_so TYPE STANDARD TABLE OF ty_so WITH EMPTY KEY.

    TYPES: BEGIN OF ty_count,
             total   TYPE i,
             same    TYPE i,
             keep    TYPE i,
             insert  TYPE i,
             update  TYPE i,
             error   TYPE i,
           END OF ty_count.

    " Tham số job (tối đa 8 ký tự)
    CONSTANTS c_par_date TYPE c LENGTH 8 VALUE 'P_DATE'.
    CONSTANTS c_par_so   TYPE c LENGTH 8 VALUE 'S_SO'.
    CONSTANTS c_par_test TYPE c LENGTH 8 VALUE 'P_TEST'.
    CONSTANTS c_par_full TYPE c LENGTH 8 VALUE 'P_FULL'.

    CONSTANTS c_pf_ze          TYPE i_salesorderpartner-partnerfunction VALUE 'ZE'.
    CONSTANTS c_sorg_6710      TYPE i_salesorder-salesorganization VALUE '6710'.
    CONSTANTS c_sorg_6720      TYPE i_salesorder-salesorganization VALUE '6720'.
    " Giá trị lưu trong DB là TA (Standard Order); màn hình tiếng Anh hiển thị là OR
    CONSTANTS c_so_type_ta     TYPE i_salesorder-salesordertype VALUE 'TA'.
    CONSTANTS c_sts_not_yet   TYPE i_salesorder-overallsdprocessstatus VALUE 'A'.
    CONSTANTS c_sts_partially  TYPE i_salesorder-overallsdprocessstatus VALUE 'B'.

    " Ngày D-1 tính theo giờ thực tế Việt Nam, không theo ngày hệ thống (UTC)
    CONSTANTS c_tz_vn      TYPE c LENGTH 6 VALUE 'UTC+7'.
    CONSTANTS c_tz_utc     TYPE c LENGTH 6 VALUE 'UTC'.
    CONSTANTS c_time_start TYPE t VALUE '000000'.
    CONSTANTS c_time_end   TYPE t VALUE '235959'.

    CONSTANTS c_log_object   TYPE if_bali_header_setter=>ty_object VALUE 'ZAL_UDT_PF'.
    CONSTANTS c_log_subobject TYPE if_bali_header_setter=>ty_subobject VALUE 'ZSUB_UDT_PF'.

    DATA mo_log   TYPE REF TO if_bali_log.
    DATA mt_out   TYPE string_table.
    DATA ms_count TYPE ty_count.

    METHODS run
      IMPORTING is_sel    TYPE ty_sel
                iv_in_job TYPE abap_boolean.

    METHODS select_sales_orders
      IMPORTING is_window    TYPE ty_window
                it_so_range  TYPE ty_so_range
      RETURNING VALUE(rt_so) TYPE tt_so.

    METHODS process_so
      IMPORTING is_so   TYPE ty_so
                iv_test TYPE abap_boolean.

    "! Insert / ghi đè ZE trên header SO, commit riêng từng SO
    "! @parameter rv_error | Trống = thành công, ngược lại là nguyên nhân lỗi
    METHODS update_so
      IMPORTING is_so           TYPE ty_so
                iv_insert       TYPE abap_boolean
      RETURNING VALUE(rv_error) TYPE string.

    METHODS collect_msgs
      IMPORTING it_reported TYPE ANY TABLE
      CHANGING  ct_text     TYPE string_table.

    METHODS log_init
      IMPORTING iv_ext_id TYPE string.

    METHODS log_add
      IMPORTING iv_severity TYPE if_bali_constants=>ty_severity
                iv_text     TYPE string.

    METHODS log_save
      IMPORTING iv_in_job TYPE abap_boolean.
ENDCLASS.



CLASS zcl_job_udt_pf IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname        = c_par_date
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'D'
        length         = 8
        param_text     = 'Ngày thay đổi BP (trống=D-1)'
        changeable_ind = abap_true )
      ( selname        = c_par_so
        kind           = if_apj_dt_exec_object=>select_option
        datatype       = 'C'
        length         = 10
        param_text     = 'Sales Order'
        changeable_ind = abap_true )
      ( selname        = c_par_test
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'C'
        length         = 1
        param_text     = 'Chạy thử - không update'
        checkbox_ind   = abap_true
        changeable_ind = abap_true )
      ( selname        = c_par_full
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'C'
        length         = 1
        param_text     = 'Quét toàn bộ SO đang mở'
        checkbox_ind   = abap_true
        changeable_ind = abap_true ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    DATA ls_sel TYPE ty_sel.

    LOOP AT it_parameters INTO DATA(ls_par).
      CASE ls_par-selname.
        WHEN c_par_date.
          " Ô ngày để trống vẫn được job truyền vào (low = space) -> bỏ qua, nếu không
          " change_date = '        ' (không phải INITIAL) làm khoảng ngày thành 0000-00-00
          IF ls_par-low IS NOT INITIAL.
            ls_sel-change_date = ls_par-low.
          ENDIF.
        WHEN c_par_so.
          " User nhập 10004257 -> chuyển về 0010004257 (trừ khi dùng pattern *)
          APPEND VALUE #( sign   = ls_par-sign
                          option = ls_par-option
                          low    = COND #( WHEN ls_par-option = 'CP' THEN ls_par-low
                                           ELSE |{ CONV i_salesorder-salesorder( ls_par-low ) ALPHA = IN }| )
                          high   = COND #( WHEN ls_par-high IS INITIAL THEN ls_par-high
                                           ELSE |{ CONV i_salesorder-salesorder( ls_par-high ) ALPHA = IN }| ) )
                 TO ls_sel-so_range.
        WHEN c_par_test.
          ls_sel-test = xsdbool( ls_par-low = abap_true ).
        WHEN c_par_full.
          ls_sel-full = xsdbool( ls_par-low = abap_true ).
      ENDCASE.
    ENDLOOP.

    run( is_sel = ls_sel iv_in_job = abap_true ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    " Chạy thử trong ADT (F9): mặc định TEST MODE – chỉ so sánh, KHÔNG update SO.
    " Muốn test update thật 1 SO: bỏ test = abap_true và thêm so_range.
    run( is_sel    = VALUE #( test = abap_true
                              " so_range = VALUE #( ( sign = 'I' option = 'EQ' low = '0010004257' ) )
                            )
         iv_in_job = abap_false ).
    out->write( mt_out ).
  ENDMETHOD.


  METHOD run.
    DATA lv_now        TYPE timestamp.
    DATA lv_ts_from    TYPE timestamp.
    DATA lv_ts_to      TYPE timestamp.
    DATA lv_today_vn   TYPE d.
    DATA lv_change_vn  TYPE d.
    DATA ls_window     TYPE ty_window.

    CLEAR: ms_count, mt_out.

    " Ngày hôm nay theo giờ thực tế VN (hệ thống Public Cloud chạy UTC:
    " job 01:00 giờ VN = 18:00 UTC hôm trước, nên không dùng ngày hệ thống)
    GET TIME STAMP FIELD lv_now.
    CONVERT TIME STAMP lv_now TIME ZONE c_tz_vn INTO DATE lv_today_vn.

    " Chỉ dùng ngày nhập vào khi là ngày thật (không phải toàn space / toàn số 0)
    DATA(lv_has_date) = xsdbool( is_sel-change_date CN ' 0' ).
    IF lv_has_date = abap_true.
      lv_change_vn = is_sel-change_date.
    ELSE.
      lv_change_vn = lv_today_vn - 1.
    ENDIF.

    " Nhập số SO mà không nhập ngày -> xử lý đúng các SO đó, không xét BP có thay đổi hay không
    " (dùng khi chạy Immediately để check / chạy lại SO lỗi)
    DATA(lv_by_so) = xsdbool( is_sel-full = abap_false
                              AND is_sel-so_range IS NOT INITIAL
                              AND lv_has_date = abap_false ).

    IF is_sel-full = abap_true OR lv_by_so = abap_true.
      " Không lọc theo BP thay đổi -> khoảng thời gian bao toàn bộ
      ls_window = VALUE #( date_from = '00000000' time_from = c_time_start
                           date_to   = '99991231' time_to   = c_time_end ).
    ELSE.
      " Ngày D-1 giờ VN: 00:00:00 -> 23:59:59 (UTC+7), quy đổi sang UTC để so với LastChangeDate/Time
      CONVERT DATE lv_change_vn TIME c_time_start INTO TIME STAMP lv_ts_from TIME ZONE c_tz_vn.
      CONVERT DATE lv_change_vn TIME c_time_end   INTO TIME STAMP lv_ts_to   TIME ZONE c_tz_vn.
      CONVERT TIME STAMP lv_ts_from TIME ZONE c_tz_utc INTO DATE ls_window-date_from TIME ls_window-time_from.
      CONVERT TIME STAMP lv_ts_to   TIME ZONE c_tz_utc INTO DATE ls_window-date_to   TIME ls_window-time_to.
    ENDIF.

    DATA(lv_test_txt) = COND string( WHEN is_sel-test = abap_true THEN ` – CHẠY THỬ, không update` ).

    log_init( |UDT_PF { lv_change_vn DATE = ISO }{ lv_test_txt }| ).
    log_add( iv_severity = if_bali_constants=>c_severity_information
             iv_text     = COND string(
                             WHEN is_sel-full = abap_true
                             THEN |Quét toàn bộ SO TA đang mở (6710, 6720)|
                               && COND string( WHEN is_sel-so_range IS NOT INITIAL THEN ` – giới hạn theo danh sách SO` )
                             WHEN lv_by_so = abap_true
                             THEN |Xử lý theo danh sách SO nhập vào (không xét ngày thay đổi BP)|
                             ELSE |BP thay đổi ngày { lv_change_vn DATE = ISO } (giờ VN)|
                               && | = UTC { ls_window-date_from DATE = ISO } { ls_window-time_from TIME = ISO }|
                               && | -> { ls_window-date_to DATE = ISO } { ls_window-time_to TIME = ISO }| )
                        && lv_test_txt ).

    DATA(lt_so) = select_sales_orders( is_window   = ls_window
                                       it_so_range = is_sel-so_range ).
    ms_count-total = lines( lt_so ).

    LOOP AT lt_so INTO DATA(ls_so).
      process_so( is_so = ls_so iv_test = is_sel-test ).
    ENDLOOP.

    " SO nhập đích danh (EQ) nhưng không lấy được -> báo rõ lý do thay vì im lặng
    LOOP AT is_sel-so_range INTO DATA(ls_so_sel) WHERE sign = 'I' AND option = 'EQ'.
      IF NOT line_exists( lt_so[ sales_order = ls_so_sel-low ] ).
        log_add( iv_severity = if_bali_constants=>c_severity_warning
                 iv_text     = |SO { ls_so_sel-low ALPHA = OUT }: không xử lý – không tồn tại, không phải loại TA,|
                            && | không thuộc 6710/6720 hoặc đã complete|
                            && COND string( WHEN lv_has_date = abap_true AND is_sel-full = abap_false
                                            THEN `, hoặc BP khách hàng không thay đổi trong ngày đã nhập` ) ).
      ENDIF.
    ENDLOOP.

    log_add( iv_severity = COND #( WHEN ms_count-error > 0 THEN if_bali_constants=>c_severity_warning
                                   ELSE if_bali_constants=>c_severity_status )
             iv_text     = |Tổng SO: { ms_count-total } – Đã đúng: { ms_count-same }|
                        && | – Insert: { ms_count-insert } – Ghi đè: { ms_count-update }|
                        && | – Giữ nguyên (master trống): { ms_count-keep } – Lỗi: { ms_count-error }| ).
    log_save( iv_in_job ).
  ENDMETHOD.


  METHOD select_sales_orders.
    " Bước 1 + 2 + 3 gom trong 1 câu SQL:
    "   SO TA đang mở của 6710/6720 có Sold-to nằm trong danh sách BP thay đổi
    "   + ZE hiện tại trên header SO (1) + ZE trên master theo Sold-to & Sales area (2)
    SELECT so~SalesOrder           AS sales_order,
           so~SoldToParty          AS sold_to,
           so~SalesOrganization    AS sales_org,
           so~DistributionChannel  AS distr_chan,
           so~OrganizationDivision AS division,
           sp~PartnerFunction      AS so_ze_pf,
           sp~Customer             AS so_ze,
           mp~BPCustomerNumber     AS master_ze,
           mp~DefaultPartner       AS default_flag,
           mp~PartnerCounter       AS counter
      FROM i_salesorder AS so
      LEFT OUTER JOIN i_salesorderpartner AS sp
        ON  sp~SalesOrder      = so~SalesOrder
        AND sp~PartnerFunction = 'ZE'
      LEFT OUTER JOIN i_custsalespartnerfunc AS mp
        ON  mp~Customer            = so~SoldToParty
        AND mp~SalesOrganization   = so~SalesOrganization
        AND mp~DistributionChannel = so~DistributionChannel
        AND mp~Division            = so~OrganizationDivision
        AND mp~PartnerFunction     = 'ZE'
      WHERE so~SalesOrderType         = @c_so_type_ta
        AND so~SalesOrganization      IN ( @c_sorg_6710, @c_sorg_6720 )
        AND so~OverallSDProcessStatus IN ( @c_sts_not_yet, @c_sts_partially )
        AND so~SalesOrder             IN @it_so_range
        " BP thay đổi trong khoảng [from, to] (UTC) – ngày D-1 giờ VN vắt qua 2 ngày UTC
        " nên phải xét cả LastChangeTime, không lọc riêng LastChangeDate được
        AND so~SoldToParty IN ( SELECT BusinessPartner
                                  FROM i_businesspartner
                                  WHERE (    LastChangeDate > @is_window-date_from
                                          OR (     LastChangeDate  = @is_window-date_from
                                               AND LastChangeTime >= @is_window-time_from ) )
                                    AND (    LastChangeDate < @is_window-date_to
                                          OR (     LastChangeDate  = @is_window-date_to
                                               AND LastChangeTime <= @is_window-time_to ) ) )
      ORDER BY so~SalesOrder, mp~DefaultPartner DESCENDING, mp~PartnerCounter
      INTO CORRESPONDING FIELDS OF TABLE @rt_so.

    " BA confirm master chỉ có 1 ZE / sales area. Phòng trường hợp nhập trùng:
    " ưu tiên dòng Default partner, sau đó counter nhỏ nhất
    DELETE ADJACENT DUPLICATES FROM rt_so COMPARING sales_order.
  ENDMETHOD.


  METHOD process_so.
    " (1) = (2) -> không update
    IF is_so-so_ze = is_so-master_ze.
      ms_count-same += 1.
      " Ghi log mọi SO (kể cả SO đã khớp) để user thấy kết quả từng SO
      log_add( iv_severity = if_bali_constants=>c_severity_information
               iv_text     = COND string(
                               WHEN is_so-so_ze IS INITIAL
                               THEN |SO { is_so-sales_order ALPHA = OUT }: SO và master đều chưa có ZE, không cần cập nhật|
                               ELSE |SO { is_so-sales_order ALPHA = OUT }: ZE { is_so-so_ze ALPHA = OUT }|
                                 && | đã khớp master, không cần cập nhật| ) ).
      RETURN.
    ENDIF.

    " TH1: (1) có, (2) không -> giữ nguyên, chu kỳ sau master có ZE thì update theo
    IF is_so-master_ze IS INITIAL.
      ms_count-keep += 1.
      log_add( iv_severity = if_bali_constants=>c_severity_information
               iv_text     = |SO { is_so-sales_order ALPHA = OUT }: master KH { is_so-sold_to ALPHA = OUT }|
                          && | ({ is_so-sales_org }/{ is_so-distr_chan }/{ is_so-division }) chưa có ZE|
                          && | – giữ nguyên ZE { is_so-so_ze ALPHA = OUT }| ).
      RETURN.
    ENDIF.

    " TH2: SO chưa có dòng ZE -> insert | TH3: đã có dòng ZE -> ghi đè
    " Xét theo dòng ZE có tồn tại hay không, không theo mã KH: có SO đã có dòng ZE nhưng
    " field Customer trống -> nếu insert sẽ lỗi "Partner function ZE can only occur 1 times"
    DATA(lv_insert) = xsdbool( is_so-so_ze_pf IS INITIAL ).
    DATA(lv_change) = COND string(
      WHEN lv_insert = abap_true
      THEN |thêm ZE { is_so-master_ze ALPHA = OUT }|
      WHEN is_so-so_ze IS INITIAL
      THEN |ghi ZE { is_so-master_ze ALPHA = OUT } vào dòng ZE đang có (chưa có mã KH)|
      ELSE |đổi ZE { is_so-so_ze ALPHA = OUT } -> { is_so-master_ze ALPHA = OUT }| ).

    IF iv_test = abap_true.
      IF lv_insert = abap_true.
        ms_count-insert += 1.
      ELSE.
        ms_count-update += 1.
      ENDIF.
      log_add( iv_severity = if_bali_constants=>c_severity_information
               iv_text     = |[TEST] SO { is_so-sales_order ALPHA = OUT }: sẽ { lv_change }| ).
      RETURN.
    ENDIF.

    DATA(lv_error) = update_so( is_so = is_so iv_insert = lv_insert ).

    IF lv_error IS INITIAL.
      IF lv_insert = abap_true.
        ms_count-insert += 1.
      ELSE.
        ms_count-update += 1.
      ENDIF.
      log_add( iv_severity = if_bali_constants=>c_severity_status
               iv_text     = |SO { is_so-sales_order ALPHA = OUT }: đã { lv_change }| ).
    ELSE.
      ms_count-error += 1.
      log_add( iv_severity = if_bali_constants=>c_severity_error
               iv_text     = |SO { is_so-sales_order ALPHA = OUT }: lỗi { lv_change } – { lv_error }| ).
    ENDIF.
  ENDMETHOD.


  METHOD update_so.
    DATA ls_failed   TYPE RESPONSE FOR FAILED EARLY i_salesordertp.
    DATA ls_reported TYPE RESPONSE FOR REPORTED EARLY i_salesordertp.
    DATA lt_text     TYPE string_table.

    IF iv_insert = abap_true.
      MODIFY ENTITIES OF i_salesordertp
        ENTITY SalesOrder
          CREATE BY \_Partner
          FIELDS ( PartnerFunction Customer )
          WITH VALUE #( ( SalesOrder = is_so-sales_order
                          %target    = VALUE #( ( %cid            = 'ZE'
                                                  PartnerFunction = c_pf_ze
                                                  Customer        = is_so-master_ze ) ) ) )
        FAILED ls_failed
        REPORTED ls_reported.
    ELSE.
      MODIFY ENTITIES OF i_salesordertp
        ENTITY SalesOrderPartner
          UPDATE FIELDS ( Customer )
          WITH VALUE #( ( SalesOrder      = is_so-sales_order
                          PartnerFunction = c_pf_ze
                          Customer        = is_so-master_ze ) )
        FAILED ls_failed
        REPORTED ls_reported.
    ENDIF.

    IF ls_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF i_salesordertp
        FAILED   DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).
      IF sy-subrc = 0 AND ls_commit_failed IS INITIAL.
        RETURN.
      ENDIF.
      collect_msgs( EXPORTING it_reported = ls_commit_reported-salesorder
                    CHANGING  ct_text     = lt_text ).
      collect_msgs( EXPORTING it_reported = ls_commit_reported-salesorderpartner
                    CHANGING  ct_text     = lt_text ).
    ELSE.
      collect_msgs( EXPORTING it_reported = ls_reported-salesorder
                    CHANGING  ct_text     = lt_text ).
      collect_msgs( EXPORTING it_reported = ls_reported-salesorderpartner
                    CHANGING  ct_text     = lt_text ).
      IF lt_text IS INITIAL
         AND (    line_exists( ls_failed-salesorder[ %fail-cause = if_abap_behv=>cause-locked ] )
               OR line_exists( ls_failed-salesorderpartner[ %fail-cause = if_abap_behv=>cause-locked ] ) ).
        INSERT `SO đang bị khóa (user khác đang sửa), chạy lại job với tham số S_SO` INTO TABLE lt_text.
      ENDIF.
    ENDIF.

    " Dọn transaction buffer để SO lỗi không ảnh hưởng SO tiếp theo
    ROLLBACK ENTITIES.

    rv_error = COND #( WHEN lt_text IS INITIAL THEN `Cập nhật thất bại, hệ thống không trả thông báo lỗi`
                       ELSE concat_lines_of( table = lt_text sep = `; ` ) ).
  ENDMETHOD.


  METHOD collect_msgs.
    FIELD-SYMBOLS <lo_msg> TYPE REF TO if_abap_behv_message.

    LOOP AT it_reported ASSIGNING FIELD-SYMBOL(<ls_row>).
      ASSIGN COMPONENT '%MSG' OF STRUCTURE <ls_row> TO <lo_msg>.
      IF sy-subrc <> 0 OR <lo_msg> IS NOT BOUND.
        CONTINUE.
      ENDIF.
      IF <lo_msg>->m_severity = if_abap_behv_message=>severity-error.
        DATA(lv_text) = <lo_msg>->if_message~get_text( ).
        IF NOT line_exists( ct_text[ table_line = lv_text ] ).
          INSERT lv_text INTO TABLE ct_text.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD log_init.
    TRY.
        mo_log = cl_bali_log=>create_with_header(
                   header = cl_bali_header_setter=>create( object      = c_log_object
                                                           subobject   = c_log_subobject
                                                           external_id = CONV #( iv_ext_id ) ) ).
      CATCH cx_bali_runtime INTO DATA(lx_bali).
        CLEAR mo_log.
        INSERT |Không tạo được Application Log: { lx_bali->get_text( ) }| INTO TABLE mt_out.
    ENDTRY.
  ENDMETHOD.


  METHOD log_add.
    INSERT |{ iv_severity }: { iv_text }| INTO TABLE mt_out.

    IF mo_log IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        mo_log->add_item( item = cl_bali_free_text_setter=>create( severity = iv_severity
                                                                   text     = CONV #( iv_text ) ) ).
      CATCH cx_bali_runtime INTO DATA(lx_bali).
        " Lỗi ghi log không được làm dừng job, chỉ đưa ra output
        INSERT |Lỗi ghi log: { lx_bali->get_text( ) }| INTO TABLE mt_out.
    ENDTRY.
  ENDMETHOD.


  METHOD log_save.
    IF mo_log IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        cl_bali_log_db=>get_instance( )->save_log( log                        = mo_log
                                                   assign_to_current_appl_job = iv_in_job ).
      CATCH cx_bali_runtime INTO DATA(lx_bali).
        INSERT |Không lưu được Application Log: { lx_bali->get_text( ) }| INTO TABLE mt_out.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
