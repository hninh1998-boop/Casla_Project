# ZSALES_V3 – Báo cáo bán hàng v3 (BE)

Package: `ZPK_SALES_V3` · Hệ thống: S/4HANA Cloud Public Edition · OData V4

## 1. Danh sách object

| # | Object | Loại | File |
|---|---|---|---|
| 1 | `ZSALES_V3` | Message Class | (tạo tay, xem mục 2.1) |
| 2 | `ZCX_SALES_V3` | Exception Class | `zcx_sales_v3.clas.abap` |
| 3 | `ZCE_SALES_V3` | Custom Entity | `zce_sales_v3.ddls.asddls` |
| 4 | `ZCL_CE_SALES_V3` | Query Provider Class | `zcl_ce_sales_v3.clas.abap` |
| 5 | `ZCE_SALES_V3` | Metadata Extension | `zce_sales_v3.ddlx.asddlx` |
| 6 | `ZUI_SALES_V3` | Service Definition | `zui_sales_v3.srvd.assrvd` |
| 7 | `ZUI_SALES_V3_O4` | Service Binding (OData V4 - UI) | (tạo tay, xem mục 2.6) |
| 8 | `ZPR_SALES_V3` | Fiori app (BSP) + LADI `ZPR_SALES_V3_UI5R` | thư mục gốc `zpr_sales_v3/`, deploy bằng `npm run deploy` |
| 9 | `ZCE_SALES_V3` | Behavior Definition (unmanaged, action `ExportExcel`) | `zce_sales_v3.bdef.asbdef` |
| 10 | `ZABS_SALES_V3_PARAM` | Abstract Entity – tham số export | `zabs_sales_v3_param.ddls.asddls` |
| 11 | `ZABS_SALES_V3_RESULT` | Abstract Entity – kết quả export | `zabs_sales_v3_result.ddls.asddls` |
| 12 | `ZBP_CE_SALES_V3` | Behavior Pool | `zbp_ce_sales_v3.clas.abap` + `zbp_ce_sales_v3.clas.locals_imp.abap` |
| 13 | `ZCL_CE_SALES_V3_XLSX` | Class sinh file xlsx theo template | `zcl_ce_sales_v3_xlsx.clas.abap` |

Value help dùng lại của v2: `ZI_COMPANYCODE_VH`, `ZI_PLANT_BY_CC_VH`, `ZI_SALESDISTRICT_VH`.

## 2. Thứ tự tạo trên ADT

1. **Message Class `ZSALES_V3`**: thêm message
   - `001` – `Bạn không có quyền xem dữ liệu Company Code &1`
2. **Exception Class `ZCX_SALES_V3`**: dán source, activate.
3. **Custom Entity `ZCE_SALES_V3`**: dán source, activate. Lúc này có warning vì class chưa tồn tại, chưa cần quan tâm.
4. **Class `ZCL_CE_SALES_V3`**: dán source, activate.
5. **Metadata Extension `ZCE_SALES_V3`**: dán source, activate.
6. **Service Definition `ZUI_SALES_V3`**: dán source, activate.
7. **Service Binding `ZUI_SALES_V3_O4`**: chọn Binding Type = **OData V4 - UI**, Service Definition = `ZUI_SALES_V3`, activate rồi bấm **Publish**.
8. Chọn entity `zce_sales_v3`, bấm **Preview** để test.

## 3. Phân quyền theo Company Code (step-by-step)

Có 2 lớp chặn:
- **Lớp 1 – DCL của SAP**: `I_GLAccountLineItemSemTag` có `@AccessControl.authorizationCheck: #CHECK`, nên SELECT tự lọc theo quyền của user.
- **Lớp 2 – trong class**: `check_authority` kiểm tra `F_BKPF_BUK` (ACTVT = 03). Không có quyền thì báo lỗi message `ZSALES_V3/001`.

### Bước 1 – IAM App (ADT)
1. Chuột phải package `ZPK_SALES_V3` → New → Other ABAP Repository Object → **IAM App**.
2. Name: `ZIAM_SALES_V3`, Application Type: **External App**. Hệ thống tự thêm hậu tố `_EXT`.
3. Tab **Overview** → **Launchpad App Descriptor Item ID**: `ZPR_SALES_V3_UI5R`. LADI này được tạo tự động khi deploy app Fiori; thiếu bước này thì app không hiện trên Launchpad.
4. Tab **Services** → Add → Service Type `OData V4` → chọn `ZUI_SALES_V3_O4`.
5. Tab **Restriction Types** → thêm `BUKRS` – Company Code, tick **Read** và **F4** (Write không cần vì báo cáo chỉ đọc).
   Có nút *Propose Restriction Types* thì bấm để hệ thống gợi ý.
   - Từ bản 2608 ("App as Entity"), restriction type được gán ở **IAM App**, không gán ở Business Catalog nữa.
   - Tab **Authorizations** để trống: danh sách *Add Authorization Object* trống là bình thường, không cần thêm `F_BKPF_BUK` bằng tay.
6. Save → Activate → **Publish Locally**.

### Bước 2 – Business Catalog (ADT)
1. New → **Business Catalog**: `ZBC_SALES_V3`, mô tả "Business Catalog - Sales V3".
2. Tab **Apps** → Add → chọn IAM App `ZIAM_SALES_V3_EXT`.
3. Tab **Restriction Types**: catalog mới (có dòng *"Restriction Types assigned to migrated catalog will not have any effect"*) **không gán ở đây**; restriction đã gán ở IAM App (bước 1.5).
   Catalog cũ chưa migrated (kiểu `ZBC_ASSET_RP`) mới gán `BUKRS` ở tab này.
4. Save → **Publish Locally**.

### Bước 3 – Business Role (Fiori Launchpad, app *Maintain Business Roles*)
1. **New**, hoặc mở role đang dùng cho báo cáo v1/v2. Ví dụ ID: `ZBR_SALES_V3`.
2. Tab **Assigned Business Catalogs** → Add → `ZBC_SALES_V3`.
3. **Maintain Restrictions** (nếu không thấy *Company Code* ở đây thì IAM App chưa gán restriction type `BUKRS` hoặc chưa Publish Locally):
   - Access category **Read**: chọn *Restricted*.
   - Restriction field **Company Code**: nhập các Company Code được xem, ví dụ `1000`.
4. Tab **Assigned Business Users** → thêm user → **Save**.

### Bước 4 – Kiểm tra
| Trường hợp | Kết quả mong đợi |
|---|---|
| User có quyền Company Code 1000, chạy 1000 | Có dữ liệu |
| Cùng user, chạy Company Code 2000 | Báo lỗi "Bạn không có quyền xem dữ liệu Company Code 2000" |
| User có quyền company code nhưng báo cáo vẫn rỗng | DCL của `I_GLAccountLineItemSemTag` còn kiểm tra object khác (ví dụ quyền theo loại tài khoản / ledger). Mở Access Control của view trong ADT để xem, rồi thêm object đó vào IAM App. |

> Lưu ý: nếu `AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'` báo lỗi "not released" khi activate, xóa method `check_authority` và dòng gọi nó. Khi đó chỉ còn lớp 1 (DCL): vẫn chặn đúng, nhưng user không có quyền sẽ thấy báo cáo rỗng thay vì thông báo lỗi.

## 4. Logic tóm tắt (theo FS v3.0)

- **Nguồn**: `I_GLAccountLineItemSemTag`, Ledger `0L`, Hierarchy `ZPL`, Semantic Tag `PL_RESULT`, TK `511*`, `521*`, `632*`, Posting Date trong khoảng. Không loại chứng từ hủy.
- **Gộp nhóm**:
  - TH1: có Plant, Product hoặc Sales District → gộp theo `Plant + Product + Sales District`.
  - TH2: cả 3 trống → gộp theo từng G/L, cột Mã hàng = số G/L, Tên hàng / ĐVT / Loại hàng để trống.
- **Công thức** (cộng tổng theo nhóm, không lấy trị tuyệt đối):
  - Số lượng = (−Σ Quantity 511) − Σ Quantity 521 (511 đổi dấu từng line, 521 để nguyên, không lấy trị tuyệt đối)
  - Doanh thu USD = (−Σ 511) − Σ 521 (511 đổi dấu từng line, 521 để nguyên, không lấy trị tuyệt đối), chỉ tính line item có Transaction Currency = USD
  - Doanh thu VND = (−Σ 511) − Σ 521 (như Doanh thu USD), tính theo Company Code Currency (VND)
  - Giá vốn VND = Σ 632, giữ nguyên dấu (không lấy trị tuyệt đối)
- **Text**: theo ngôn ngữ đăng nhập (`sy-langu`). Plant / Loại hàng / Thị trường hiển thị dạng `mã(tên)`.
- **Sắp xếp mặc định**: dòng TH1 trước (Plant → Mã hàng → Sales District), dòng TH2 xếp cuối (theo G/L). STT đánh theo thứ tự hiển thị.
- Dòng có cả 4 cột số bằng 0 thì bị bỏ.

## 5. Export Excel (làm theo ZPK_SALES_DA)

Thứ tự tạo trên ADT:
1. Sửa `ZCE_SALES_V3` thành `define root custom entity`, activate.
2. Tạo `ZABS_SALES_V3_PARAM`, `ZABS_SALES_V3_RESULT`, activate.
3. Tạo `ZCL_CE_SALES_V3_XLSX`. Lúc này chưa activate được vì còn thiếu behavior pool, cứ save.
4. Tạo Behavior Definition `ZCE_SALES_V3` (chuột phải entity → New Behavior Definition), dán source.
5. Quick fix tạo `ZBP_CE_SALES_V3`, dán 2 phần: Global Class + Local Types (`locals_imp`).
6. Mass activate tất cả (Ctrl+Shift+F3).
7. Mở Service Binding `ZUI_SALES_V3_O4`, kiểm tra entity đã có action `ExportExcel`.

Luồng chạy: nút **Export Excel** (FE) gửi filter đang chọn dạng JSON → action `ExportExcel` →
`ZCL_CE_SALES_V3=>get_data` (dùng chung với màn hình) → `ZCL_CE_SALES_V3_XLSX=>build` → trả file base64 → FE tải file.

## 6. Vấn đề đang chờ BA chốt: TK 521 không lên báo cáo

- **Hiện tượng**: 6711 / 100000010 / Sales District 24, Posting Date đến 30/09/2026.
  - Pivot: 511 = (61,566,417), 521 = 2,861,600 → Doanh thu VND đúng phải là 58,704,817.
  - Báo cáo ra 61,566,417 (thiếu 521).
- **Nguyên nhân** (đã kiểm tra bằng SQL Console): line TK `5211002000` mang Semantic Tag `NTINC_ALAC`, không phải `PL_RESULT` → điều kiện `SemanticTag = 'PL_RESULT'` trong FS loại hết 521.
- **Phương án đề xuất** (chưa áp dụng, chờ BA):
  - Giữ `Ledger = 0L`, `Hierarchy = ZPL`, bỏ điều kiện `SemanticTag`.
  - Thêm CTE `WITH +items AS ( SELECT DISTINCT ... )` theo khóa line item (Ledger, SourceLedger, CompanyCode, FiscalYear, AccountingDocument, LedgerGLLineItem) để mỗi line chỉ cộng 1 lần khi có nhiều tag.
  - Phương án khác: lọc tag riêng cho từng nhóm TK (511/632 = `PL_RESULT`, 521 = `NTINC_ALAC`), hoặc sửa hierarchy `ZPL` để 521 nằm dưới `PL_RESULT`.
