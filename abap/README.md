# Backend (ABAP) – Mass Change Production Order

Bản sao các object backend mà app Fiori này phụ thuộc. Thư mục này chỉ để tham chiếu:
không được build/deploy cùng app, và sửa file ở đây không làm thay đổi hệ thống.

- Hệ thống: `https://my426501.s4hana.cloud.sap`
- Package: `ZPK_MASSCHANGE_PRODUCT_ORDER`
- Service: `/sap/opu/odata4/sap/zsb_masschange_product_order/srvd/sap/zsd_masschange_product_order/0001/`

## Đã có

Source lấy từ hệ thống ngày 2026-10-05.

| File | Object | Trạng thái |
|---|---|---|
| `zc_masschange_product_order.ddls.asddls` | CDS view `ZC_MASSCHANGE_PRODUCT_ORDER` | **Đã sửa, chưa activate** (thêm `YY1_KDAUF_ORD`, `YY1_KDPOS_ORD`) |
| `zc_masschange_product_order.ddlx.asddlxs` | Metadata Extension | **Đã sửa, chưa activate** |
| `zbp_c_masschange_product_order.clas.locals_imp.abap` | Local types của class `ZBP_C_MASSCHANGE_PRODUCT_ORDER` | **Đã sửa, chưa activate** |
| `zc_masschange_product_order.bdef.asbdef` | Behavior Definition | Giống hệ thống |
| `zi_file_abs.ddls.asddls` | Abstract entity `ZI_FILE_ABS` | Giống hệ thống |
| `zsd_masschange_product_order.srvd.assrvd` | Service Definition | Giống hệ thống |
| `zcl_productionorderlongtext.clas.abap` | Class lấy etag / long text qua API | Giống hệ thống |
| `zcl_utility.clas.abap` | Class tiện ích (`to_json_date`) | Giống hệ thống |
| `yy1_bd_cobadicfl_mfgorder_hupd.custom_logic.abap` | Custom Logic chạy khi cập nhật header lệnh sản xuất (BAdI `BD_COBADICFL_MFGORDER_HUPD`) | Giống hệ thống |
| `yy1_bd_cobadicfl_mfgorder_hcr.custom_logic.abap` | Custom Logic chạy khi tạo lệnh sản xuất (BAdI `BD_COBADICFL_MFGORDER_HCR`) | Giống hệ thống |
| `ztb_api_auth.tabl.asddls` | Bảng thông tin xác thực API (chỉ cấu trúc) | Giống hệ thống |

## Thay đổi đang chờ: thêm field "Tên thành phẩm" (`YY1_MaterialName_ORD`)

Custom field `YY1_MaterialName`, Text (50), business context Order Master Data (`FINS_ORDER`), đã Published.

Nội dung thay đổi theo từng file:

- **CDS view**: thêm `YY1_MaterialName_ORD` sau `YY1_Thu_Tu_ORD`.
- **Metadata Extension**: thêm cột và field Object Page "Tên thành phẩm" ở vị trí 75 (sau "Số thứ tự").
- **`downloadtemplate`**: thêm cột F "Tên thành phẩm" vào file Excel.
- **`excelupload`**: đọc thêm cột F; báo lỗi nếu dài quá 50 ký tự; gửi `YY1_MaterialName_ORD` trong PATCH khi ô có giá trị (ô trống = giữ nguyên).

Thứ tự thực hiện trên hệ thống:

1. App Custom Fields: bật field cho `I_ManufacturingOrder` và cho `API_PRODUCTION_ORDER_2_SRV`, rồi Publish. (Đã xong trên AK3/100, kiểm tra ngày 2026-10-05.)
2. Dán và activate CDS view. (Đã xong, transport `AK3K908243`.)
3. Dán và activate Metadata Extension.
4. Dán và activate phần Local Types của class.

## Thay đổi đang chờ: thêm field Sales Order (`YY1_KDAUF_ORD`) và Sales Order Item (`YY1_KDPOS_ORD`)

Custom field `YY1_KDAUF` và `YY1_KDPOS`, Text (20), business context Order Master Data (`FINS_ORDER`).
Ngày 2026-10-22: `YY1_KDPOS` đã Published, `YY1_KDAUF` đang ở trạng thái **Changed** (chưa Publish).

Nội dung thay đổi theo từng file:

- **CDS view**: thêm `YY1_KDAUF_ORD`, `YY1_KDPOS_ORD` sau `YY1_MaterialName_ORD`.
- **Metadata Extension**: thêm cột và field Object Page ở vị trí 76, 77.
- **`downloadtemplate`**: thêm cột G "Sales Order (KDAUF)" và cột H "Sales Order Item (KDPOS)".
- **`excelupload`**: đọc thêm cột G, H; báo lỗi nếu dài quá 20 ký tự; gửi `YY1_KDAUF_ORD` / `YY1_KDPOS_ORD` trong PATCH khi ô có giá trị (ô trống = giữ nguyên). Giá trị gửi nguyên như trong ô, không thêm số 0 ở đầu.

Thứ tự thực hiện trên hệ thống:

1. App Custom Fields: Publish `YY1_KDAUF`; kiểm tra cả hai field đã bật cho `I_ManufacturingOrder` và `API_PRODUCTION_ORDER_2_SRV`, rồi Publish.
2. Dán và activate CDS view. (Đã dán ngày 2026-10-22.)
3. Dán và activate Metadata Extension. (Đã dán ngày 2026-10-22.)
4. Dán và activate phần Local Types của class. (Đã dán ngày 2026-10-22; cần dán lại bản có kiểm tra độ dài 20.)

## Vấn đề đang mở: upload không đổi được "Tên thành phẩm" (2026-10-05)

- Hiện tượng: PATCH `YY1_MaterialName_ORD` qua `API_PRODUCTION_ORDER_2_SRV` trả 204, etag của lệnh đổi, nhưng field giữ giá trị cũ. Thử trên các lệnh 10010000145 đến 10010000149.
- Nguyên nhân: Custom Logic `YY1_BD_COBADICFL_MFGORDER_HUPD` chạy ở mỗi lần cập nhật lệnh và gán lại
  `yy1_materialname_ord = salesorderitemtext` của dòng sales order gắn với lệnh (dòng 37 trong file).
- Phạm vi: chỉ các lệnh có sales order item. Lệnh không gắn sales order không bị ghi đè.
- Chưa sửa: cần quyết định nghiệp vụ (xem trao đổi với người phụ trách Custom Logic).

## Còn thiếu

| # | Object | Tên file nên đặt | Cần cho |
|---|---|---|---|
| 1 | Abstract entity `ZC_DOWNLOAD_PARAM` | `zc_download_param.ddls.asddls` | Tham chiếu (đã biết có field `json_string`) |

## Thông tin service (từ `$metadata`, lấy ngày 2026-10-05)

Entity set `zc_MASSCHANGE_PRODUCT_ORDER`, khóa `ManufacturingOrder`, chỉ đọc (không create/update/delete, không draft).

| Field | Kiểu |
|---|---|
| `ManufacturingOrder` | String(12) |
| `MfgOrderPlannedStartDate` | Date |
| `MfgOrderPlannedEndDate` | Date |
| `YY1_So_May_ORD` | String(40) |
| `YY1_Thu_Tu_ORD` | String(2) |
| `Material` | String(18) |
| `ProductDescription` | String(40) |
| `SalesOrder` | String(10) |
| `SalesOrderItem` | String(6) |
| `MfgOrderPlannedTotalQty` | Decimal(13,3), đơn vị `ProductionUnit` |
| `ActualDeliveredQuantity` | Decimal(13,3), đơn vị `ProductionUnit` |
| `MfgOrderConfirmedYieldQty` | Decimal(13,3), đơn vị `ProductionUnit` |
| `ProductionPlant` | String(4) |
| `ManufacturingOrderType` | String(4) |
| `IsCompletelyDelivered` | Boolean |
| `ProductionUnit` | String(3) |
| `btnSet` | String(10), ẩn |

| Action | Gắn với | Tham số | Kết quả |
|---|---|---|---|
| `ExcelUpload` | Collection (static) | `mimeType`, `fileName`, `fileContent` (Binary), `fileExtension` | Không |
| `DownloadTemplate` | Collection (static) | `json_string` = `[{"ManufacturingOrder":"..."}]` | `ZI_FILE_ABS` |
| `setDeliveryComplete` | Từng dòng | Không | Không |

`ZI_FILE_ABS`: `fileContent` (Binary), `fileExtension`, `fileName`, `mimeType`.
