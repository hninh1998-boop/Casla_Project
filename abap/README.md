# Job Update Partner Function ZE trên SO – Backend (ABAP Cloud)

- **Hệ thống:** S/4HANA Cloud Public Edition – AK3 (dev client 080, test client 100)
- **FS:** `Update partner function.docx` (SD – Hoàng Phương Thanh, 11/2026)
- **Loại:** Chỉ có Application Job, **không có app Fiori**. Log xem trong app chuẩn **Application Jobs**.

Tạo các object trong ADT **theo đúng số thứ tự** rồi Activate.

| # | File | Object | Cách tạo trong ADT |
|---|---|---|---|
| 01 | *(xem mục 01)* | Application Log Object `ZAL_UDT_PF` + subobject `ZSUB_UDT_PF` | New > Other > Application Log Object (form, nhập tay) |
| 02 | `02_zcl_job_udt_pf.clas.abap` | Class `ZCL_JOB_UDT_PF` | New > ABAP Class |
| 03 | `03_zajc_udt_pf.sajc.json`, `03_zajt_udt_pf.sajt.json` | Job Catalog `ZAJC_UDT_PF` + Template `ZAJT_UDT_PF` | New > Application Job > Catalog Entry / Template |
| 04 | *(xem mục 04)* | Lên lịch job 01:00 hằng ngày | App **Application Jobs** |

---

## Logic (theo FS, đã chốt với BA)

| Bước | Xử lý |
|---|---|
| 1 | `I_BusinessPartner` – BP thay đổi trong ngày **D-1 theo giờ thực tế VN** (00:00:00 → 23:59:59 UTC+7), xem ghi chú UTC |
| 2 | `I_SalesOrder` – `SalesOrderType` = **TA**, SoldToParty thuộc bước 1, SalesOrg **6710 / 6720**, `OverallSDProcessStatus` **A / B** |
| 3 | (1) = `I_SalesOrderPartner` ZE ở **header** SO · (2) = `I_CustSalesPartnerFunc` ZE theo Sold-to + Sales area, lấy `BPCustomerNumber` (ZE là partner type **KU**) |
| 4 | (1)=(2): bỏ qua · (2) trống: **giữ nguyên** (TH1) · (1) trống: **insert** (TH2) · khác nhau: **ghi đè** (TH3) |
| 5 | Update qua EML `I_SalesOrderTP`, **commit từng SO**, nên một SO lỗi không ảnh hưởng các SO khác |

Bước 1, 2, 3 gom trong **một câu SQL** (subquery BP + LEFT JOIN partner SO + LEFT JOIN master).

Đã chốt với BA:
- Master chỉ có 1 ZE trên mỗi sales area. Code vẫn phòng trường hợp trùng: ưu tiên dòng Default partner, sau đó counter nhỏ nhất.
- Item không xét.
- Status B vẫn update. Chấp nhận SO khác với OD và billing đã tạo.
- ZE do user sửa tay trên SO vẫn bị ghi đè theo master khi BP thay đổi. Đây là ý muốn của nghiệp vụ.
- Dùng `I_CustSalesPartnerFunc` (released) thay cho `YY1_CUSTOMERPARTNERFUNTION`.

**Ghi chú UTC:** Public Cloud chạy và lưu `LastChangeDate` / `LastChangeTime` theo giờ **UTC**. Trong khi đó D-1 trong FS là ngày hôm qua **theo giờ thực tế VN**. Job xử lý như sau:
1. Lấy ngày hôm nay theo giờ VN (`UTC+7`), trừ 1 để ra D-1. Không dùng ngày hệ thống, vì job 01:00 giờ VN là 18:00 UTC ngày hôm trước.
2. Khoảng D-1 00:00:00 → 23:59:59 giờ VN được đổi sang UTC. Ví dụ D-1 = 06/11: từ **05/11 17:00:00** đến **06/11 16:59:59** UTC.
3. Lọc BP theo **cả** `LastChangeDate` và `LastChangeTime` trong khoảng UTC đó, vì một ngày giờ VN nằm vắt qua 2 ngày UTC.

Dòng đầu tiên của log in ra khoảng thời gian này để đối chiếu.

## Tham số job

| Tham số | Ý nghĩa |
|---|---|
| `P_DATE` | Ngày thay đổi BP theo giờ VN. **Để trống = D-1**. Lịch chạy định kỳ **phải để trống**, vì giá trị nhập sẽ bị lưu cố định cho mọi lần chạy. Chỉ nhập khi chạy bù một ngày bị lỡ (ví dụ đêm đó job lỗi): mỗi ngày bị lỡ chạy 1 lần. |
| `S_SO` | Chạy riêng các SO này (nhập 10004257 hay 0010004257 đều được). **Nếu để trống `P_DATE`**, job xử lý các SO này mà không xét BP thay đổi, dùng khi chạy Immediately để check hoặc chạy lại SO lỗi. SO nhập đích danh mà không tìm thấy thì log Warning. |
| `P_TEST` | Chạy thử: chỉ so sánh và ghi log `[TEST] … sẽ thêm/đổi …`, **không update** |
| `P_FULL` | Quét **toàn bộ** SO TA đang mở của 6710/6720, bỏ qua điều kiện BP thay đổi. Dùng cho **lần đồng bộ đầu tiên khi go-live**. |

## 01. Application Log Object (form editor – nhập tay)

| Thuộc tính | Giá trị |
|---|---|
| Name | `ZAL_UDT_PF` |
| Description | App Log - Update Partner Function SO |
| Subobject | `ZSUB_UDT_PF` – Update ZE Sales Person |

## 02. Class `ZCL_JOB_UDT_PF`

- Implement `if_apj_dt_exec_object` (khai báo tham số), `if_apj_rt_exec_object` (chạy job) và `if_oo_adt_classrun`.
- **F9 trong ADT** chạy ở **test mode** (không update) và in kết quả ra Console. Muốn test update thật một SO: sửa `main` để bỏ `test = abap_true` và mở dòng `so_range`.

**Cần kiểm tra khi activate** (tên field và entity viết theo tài liệu API released, cần xác nhận trên AK3):
- `I_BusinessPartner` có field `LastChangeTime` (lấy từ BUT000-CHTIM).
- **Giờ lưu là UTC:** sửa một BP lúc khoảng 08:00 giờ VN, rồi xem `LastChangeTime` của BP đó trong Data Preview. Nếu hiển thị 01:00 thì đúng là UTC và logic quy đổi chuẩn.
- `I_CustSalesPartnerFunc` có các field `BPCustomerNumber`, `DefaultPartner`, `PartnerCounter`. Nếu tên khác, sửa trong `select_sales_orders`.
- `I_SalesOrderTP`: entity `SalesOrderPartner`, association `\_Partner`, field `Customer`. Nếu RAP báo không cho UPDATE field `Customer`, đổi TH3 thành **DELETE + CREATE BY \_Partner** trong cùng một lần `MODIFY ENTITIES`.

## 03. Application Job Catalog + Template

- **Catalog Entry** `ZAJC_UDT_PF` – *Job - Update Partner Function ZE on SO* – Class `ZCL_JOB_UDT_PF`.
- **Template** `ZAJT_UDT_PF` – Catalog `ZAJC_UDT_PF`, để trống toàn bộ tham số.
- 2 file JSON số 03 chỉ dùng để đối chiếu nội dung. Tạo object qua wizard của ADT.

## 04. Lên lịch & phân quyền

1. Gán Job Catalog vào IAM App hoặc Business Catalog (giống `ZAJC_UPL_ATT_SO`) để user thấy template trong app **Application Jobs**.
2. App **Application Jobs** > Create > chọn template `ZAJT_UDT_PF` > bỏ tick Start Immediately > Recurrence **Daily 01:00** > để trống toàn bộ tham số.
3. **Time Zone of Job = `Etc/GMT-7`** (giờ VN, giống `ZJT_HHDV_DAILY` trên PRD). Etc/GMT ghi dấu ngược, nên `Etc/GMT-7` là UTC+7, còn `Etc/GMT+7` là UTC-7. Timezone của job chỉ quyết định **giờ job bắt đầu chạy**. Khi đang chạy, ngày hệ thống và LastChangeDate/Time vẫn là UTC, nên code vẫn phải tự quy đổi D-1 sang giờ VN (xem Ghi chú UTC).
4. **User chạy job = user tạo lịch.** EML không dùng `PRIVILEGED` nên user này phải có quyền **sửa Sales Order** của 6710/6720. Nên dùng user kỹ thuật hoặc user dùng chung, tránh user cá nhân để không bị ảnh hưởng khi người đó nghỉ việc.
5. **Go-live:** chạy 1 lần với `P_TEST = X` + `P_FULL = X` để xem trước, rồi chạy lại `P_FULL = X` để đồng bộ thật. Sau đó mới bật lịch hằng ngày.

## Đọc log

App **Application Jobs** > chọn lần chạy > **Log**:

| Mức | Nội dung |
|---|---|
| Success | `SO 10004257: đã đổi ZE CL100192 -> CL100200` / `đã thêm ZE …` |
| Error | `SO …: lỗi đổi ZE … – <nguyên nhân từ hệ thống / SO đang bị khóa>` |
| Info | `SO …: master KH … (6710/10/00) chưa có ZE – giữ nguyên ZE …` (TH1) |
| Tổng kết (dòng cuối) | `Tổng SO: n – Đã đúng – Insert – Ghi đè – Giữ nguyên – Lỗi` |

Mọi SO job quét được đều có 1 dòng log, kể cả SO đã khớp (Information *"đã khớp master"*). SO bị khóa lúc chạy sẽ báo Error. Vì job chỉ quét BP thay đổi trong D-1, đêm sau SO đó **không** tự được xử lý lại. Cần chạy tay với `S_SO` = các SO lỗi.
