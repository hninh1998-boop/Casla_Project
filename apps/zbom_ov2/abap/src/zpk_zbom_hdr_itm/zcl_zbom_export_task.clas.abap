CLASS zcl_zbom_export_task DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_abap_parallel.

    TYPES tt_items TYPE STANDARD TABLE OF zce_zbom_detail WITH DEFAULT KEY.

    DATA mt_headers TYPE zcl_zbom_export_sel=>tt_headers READ-ONLY.
    DATA mv_offset  TYPE i READ-ONLY.
    DATA mt_items   TYPE tt_items READ-ONLY.
    DATA mv_done    TYPE abap_boolean READ-ONLY.

    METHODS constructor
      IMPORTING it_headers TYPE zcl_zbom_export_sel=>tt_headers
                iv_offset  TYPE i.
ENDCLASS.


CLASS zcl_zbom_export_task IMPLEMENTATION.

  METHOD constructor.
    mt_headers = it_headers.
    mv_offset  = iv_offset.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    " Một nhóm header, chạy trong session riêng do CL_ABAP_PARALLEL cấp.
    " Dùng lại nguyên explode_header_for_export, không đổi logic khai triển.
    DATA(lo_detail) = NEW zcl_zbom_detail_ce( ).

    LOOP AT mt_headers INTO DATA(ls_header).
      " mv_offset + vị trí trong nhóm = số thứ tự header trong cả chunk,
      " để TreeView đánh số giống hệt khi chạy tuần tự.
      DATA(lv_tabix) = mv_offset + sy-tabix.

      TRY.
          APPEND LINES OF lo_detail->explode_header_for_export(
            iv_billofmaterial             = CONV #( ls_header-BillOfMaterial )
            iv_billofmaterialcategory     = CONV #( ls_header-BillOfMaterialCategory )
            iv_billofmaterialvariantusage = CONV #( ls_header-BillOfMaterialVariantUsage )
            iv_material                   = CONV #( ls_header-Material )
            iv_plant                      = CONV #( ls_header-Plant )
            iv_salesorder                 = CONV #( ls_header-SalesOrder )
            iv_salesorderitem             = CONV #( ls_header-SalesOrderItem )
            iv_requiredquantity           = CONV #( ls_header-RequiredQuantityHeader )
            iv_tabix                      = lv_tabix ) TO mt_items.
        CATCH cx_root.
          " Header lỗi thì bỏ qua, giống hành vi khi chạy tuần tự.
      ENDTRY.
    ENDLOOP.

    mv_done = abap_true.
  ENDMETHOD.

ENDCLASS.

