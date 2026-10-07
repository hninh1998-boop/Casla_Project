CLASS zcl_ce_cont_top DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: tt_result   TYPE STANDARD TABLE OF zce_cont,
           ry_string   TYPE RANGE OF string,
           tt_longtext TYPE TABLE FOR READ RESULT i_outbounddeliverytp\\outbounddelivery\_text.

    TYPES: BEGIN OF ty_key,
             so                 TYPE I_SalesOrderitem-SalesOrder,
             SOItem             TYPE I_SalesOrderitem-SalesOrderItem,
             SoLenhXuatHang     TYPE I_OutboundDeliveryItem-OutboundDelivery,
             SoLenhXuatHangItem TYPE I_OutboundDeliveryItem-OutboundDeliveryItem,
           END OF ty_key,
           tt_key TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.

    TYPES: BEGIN OF ty_base,
             "Key
             so                          TYPE I_SalesOrderItem-SalesOrder,
             soitem                      TYPE I_SalesOrderItem-SalesOrderItem,
             solenhxuathang              TYPE I_OutboundDeliveryItem-OutboundDelivery,
             solenhxuathangitem          TYPE I_OutboundDeliveryItem-OutboundDeliveryItem,

             "Base
             ngaygiaohangdukien          TYPE I_SalesOrderItem-RequestedDeliveryDate,
             mahang                      TYPE I_SalesOrderItem-Product,
             tenhang                     TYPE I_SalesOrderItem-SalesOrderItemText,
             DiaDiemDongHang             TYPE I_SalesOrderItem-Plant,
             DiaDiemDongHangContName     TYPE zi_cont_text-DiaDiemDongHangContName,
             SoLuongTrenLenhXuatHang     TYPE I_OutboundDeliveryItem-ActualDeliveryQuantity,
             DeliveryQuantityUnit        TYPE I_OutboundDeliveryItem-DeliveryQuantityUnit,
             DongDauThung                TYPE string,
             NguoiPhuTrach               TYPE string,
             Cont                        TYPE string,
             KeHoachDongCont             TYPE string,
             GhiChuKhac                  TYPE string,
             GhiChuGiaoHang              TYPE string,
             NgayTauChay                 TYPE string,
             ThoiGianCatMang             TYPE string,
             SortOrder                   TYPE zi_cont_text-SortOrder,
             CompanyCodeName             TYPE I_CompanyCode-CompanyCodeName,
             Ngay                        TYPE I_DeliveryDocument-PlannedGoodsIssueDate,
             SoLuongChuaLenLenhXuatHang  TYPE I_SalesOrderScheduleLine-OpenConfdDelivQtyInBaseUnit,
             DeliveredQuantityInBaseUnit TYPE I_SalesOrderScheduleLine-DeliveredQuantityInBaseUnit,
             IsConfirmedDelivSchedLine   TYPE I_SalesOrderScheduleLine-IsConfirmedDelivSchedLine,
             TrangThaiOD                 TYPE I_OverallGoodsMovementStatusT-OverallGoodsMovementStatusDesc,
             Plant                       TYPE I_SalesOrderItem-Plant,
             PlantName                   TYPE I_CnsldtnPlantT-PlantName,
           END OF ty_base,
           tt_base TYPE STANDARD TABLE OF ty_base WITH EMPTY KEY.

    TYPES: BEGIN OF ty_kichthuoctui,
             "Key
             so                 TYPE I_SalesOrderItem-SalesOrder,
             soitem             TYPE I_SalesOrderItem-SalesOrderItem,
             solenhxuathang     TYPE I_OutboundDeliveryItem-OutboundDelivery,
             solenhxuathangitem TYPE I_OutboundDeliveryItem-OutboundDeliveryItem,
             mahang             TYPE I_SalesOrderItem-Product,

             kichthuoctui       TYPE I_ClfnObjectCharcValue-CharcValue,
           END OF ty_kichthuoctui,
           tt_kichthuoctui TYPE STANDARD TABLE OF ty_kichthuoctui WITH EMPTY KEY.

    TYPES: BEGIN OF ty_quantity,
             "Key
             so                          TYPE I_SalesOrderItem-SalesOrder,
             soitem                      TYPE I_SalesOrderItem-SalesOrderItem,
             solenhxuathang              TYPE I_OutboundDeliveryItem-OutboundDelivery,
             solenhxuathangitem          TYPE I_OutboundDeliveryItem-OutboundDeliveryItem,

             soluongchualenlenhsanxuat   TYPE I_SalesOrderScheduleLine-OpenConfdDelivQtyInBaseUnit,
             DeliveredQuantityInBaseUnit TYPE I_SalesOrderScheduleLine-DeliveredQuantityInBaseUnit,
           END OF ty_quantity,
           tt_quantity TYPE STANDARD TABLE OF ty_quantity.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_CE_CONT_TOP IMPLEMENTATION.
ENDCLASS.
