# Hướng dẫn test Job cập nhật Sales Person (ZE) trên SO

**FS:** Update partner function · **Hệ thống test:** AK3 client 100 · **App sử dụng:** Application Jobs, Manage Business Partner Master Data, Manage Sales Orders

## 1. Job làm gì

Mỗi đêm lúc 01:00, job tìm các khách hàng có **BP thay đổi trong ngày hôm qua** (tính theo giờ Việt Nam). Với các khách đó, job lấy các SO **chưa complete** của **Sales org 6710, 6720** và so sánh Sales Person (ZE) ở **header SO** với ZE trên **BP master** (theo đúng Sales area của SO).

| Trường hợp | Kết quả trên SO | Log |
|---|---|---|
| ZE trên SO **giống** ZE trên BP | Không đổi | Không ghi dòng nào |
| SO **chưa có** ZE, BP **có** ZE | **Thêm** ZE theo BP | Success |
| SO và BP có ZE **khác nhau** | **Ghi đè** ZE trên SO theo BP | Success |
| SO **có** ZE, BP **không có** ZE | **Giữ nguyên** ZE trên SO | Info |
| Cập nhật không được (SO đang bị khóa...) | Không đổi | Error, kèm nguyên nhân |

> **Lưu ý quan trọng khi test:** Chạy theo lịch thì job chỉ quét BP sửa **hôm qua**. Nếu hôm nay bạn sửa BP rồi chạy job ngay mà không nhập ngày, job sẽ **không thấy** thay đổi đó. Vì vậy khi test, nhập **ngày hôm nay** vào ô *Ngày thay đổi BP* (xem bước 3).

## 2. Chuẩn bị dữ liệu test

Chọn 1–2 khách hàng thuộc Sales org 6710 hoặc 6720 có SO **chưa complete** (đang mở hoặc mới giao/xuất hóa đơn một phần). Với mỗi SO, mở **Manage Sales Orders** (hoặc VA03) > **Header** > tab **Partner** và ghi lại ZE hiện tại.

Mỗi kịch bản cần **sửa BP vào ngày test**, vì job chỉ xét các khách hàng có BP thay đổi. Sửa ZE trong **Manage Business Partner Master Data** > BP > **Sales Area** đúng với SO > **Partner Functions**.

| Mã | Kịch bản | Dữ liệu chuẩn bị | Kết quả mong đợi |
|---|---|---|---|
| TC1 | Ghi đè | SO đang có ZE = A. Trên BP đổi ZE thành B. | ZE trên SO đổi thành B. Log Success *"đã đổi ZE A -> B"* |
| TC2 | Thêm mới | SO chưa có ZE (xóa ZE trên SO hoặc tạo SO mới không có ZE). Trên BP có ZE = B. | SO được thêm ZE = B. Log Success *"đã thêm ZE B"* |
| TC3 | Giữ nguyên | SO đang có ZE = A. Trên BP **xóa** ZE. | ZE trên SO vẫn là A. Log Info *"chưa có ZE – giữ nguyên ZE A"* |
| TC4 | Đã khớp | ZE trên SO và BP giống nhau. Sửa thông tin khác của BP (ví dụ số điện thoại). | SO không đổi, log không có dòng cho SO này |
| TC5 | Ngoài phạm vi | SO đã complete, hoặc SO của sales org khác 6710/6720. Đổi ZE trên BP. | SO không đổi |
| TC6 | SO đang bị khóa | Làm như TC1, nhưng mở SO ở chế độ **Edit** và để nguyên trong lúc chạy job. | Log Error *"SO đang bị khóa…"*. Đóng SO rồi chạy lại job với số SO đó thì cập nhật thành công |
| TC7 | Chạy thử | Làm như TC1, nhưng tick ô **Chạy thử**. | SO **không đổi**. Log ghi *"[TEST] … sẽ đổi ZE A -> B"* |

## 3. Chạy job thủ công để test

1. Mở app **Application Jobs** > bấm **Create** (dấu +).
2. **Job Template:** chọn *Job Template - Update Partner Function ZE on SO*.
   - Nếu không thấy template này, báo dev/admin để gán quyền.
3. **Scheduling Options:** chọn **Start Immediately**.
4. **Parameters:**

   | Ô trên màn hình | Nhập gì khi test |
   |---|---|
   | Ngày thay đổi BP (trống=D-1) | **Ngày hôm nay** (ngày bạn sửa BP) |
   | Sales Order | Các số SO test. Nên nhập để job chỉ xử lý SO của bạn, không đụng SO khác. Nhập 10004257 là được, không cần số 0 ở đầu. |
   | Chạy thử - không update | Tick nếu chỉ muốn xem trước (TC7). Bỏ tick để cập nhật thật. |
   | Quét toàn bộ SO đang mở | **Không tick** (chỉ dùng khi go-live) |

5. Bấm **Schedule**. Chờ vài giây rồi bấm **Refresh** đến khi Status = **Finished**.

## 4. Xem kết quả

**Xem log của job:** trong app Application Jobs, bấm vào dòng job vừa chạy > biểu tượng **Log** (cột Log).

- **Dòng đầu tiên:** cho biết job đã quét BP sửa trong ngày nào. Ví dụ *"BP thay đổi ngày 2026-11-09 (giờ VN) = UTC 2026-11-08 17:00:00 -> 2026-11-09 16:59:59"*. Phần UTC là giờ quy đổi nội bộ của hệ thống, chỉ cần kiểm tra ngày giờ VN đúng là được.
- **Các dòng giữa:** mỗi SO một dòng, gồm Success, Error hoặc Info.
- **Dòng cuối cùng:** tổng kết, ví dụ *"Tổng SO: 5 – Đã đúng: 1 – Insert: 1 – Ghi đè: 2 – Giữ nguyên (master trống): 1 – Lỗi: 0"*.

**Xem trên SO:** mở lại SO trong Manage Sales Orders (hoặc VA03) > **Header** > tab **Partner**, kiểm tra dòng **ZE Sales Person**. Nếu đang mở sẵn SO thì cần thoát ra và mở lại để thấy dữ liệu mới.

## 5. Test lịch chạy hằng ngày

1. App **Application Jobs** > **Create** > chọn cùng template.
2. **Scheduling Options:** bật **Recurrence** > **Daily**, giờ bắt đầu **01:00**.
3. **Parameters:** để **trống toàn bộ**. Job sẽ tự lấy ngày hôm qua. Nếu nhập ngày, đêm nào job cũng chỉ quét đúng ngày đó.
4. **Kiểm tra múi giờ trước khi tạo lịch:** góc phải trên > **Settings** > **Language & Region** > Time Zone phải là **giờ Việt Nam (UTC+7)**. Nếu đang là UTC thì "01:00" sẽ chạy lúc 08:00 sáng giờ VN.
5. **Cách kiểm tra:**
   - Hôm nay: sửa ZE trên BP của một khách có SO đang mở.
   - Sáng hôm sau: vào Application Jobs xem lần chạy lúc 01:00. Dòng đầu log phải ghi **ngày hôm qua**, và SO đã được cập nhật.

## 6. Các điểm đã thống nhất với nghiệp vụ

- Chỉ cập nhật ZE ở **header** SO, không xét item.
- SO đã giao hoặc xuất hóa đơn **một phần** vẫn được cập nhật. Delivery và hóa đơn đã tạo thì giữ ZE cũ.
- Nếu user sửa tay ZE trên SO, lần sau BP của khách có bất kỳ thay đổi nào thì ZE trên SO sẽ bị ghi đè theo BP.
- SO bị lỗi (ví dụ đang bị khóa) **không** tự chạy lại ở đêm sau. Cần chạy thủ công với số SO đó (như bước 3).

## 7. Khi kết quả không như mong đợi

Gửi cho dev các thông tin sau:
- Số SO và số BP khách hàng
- ZE trước và sau khi sửa BP, kèm thời điểm sửa BP
- Ảnh chụp màn hình log của job (cả dòng đầu và dòng cuối)
- Các tham số đã nhập khi chạy job
