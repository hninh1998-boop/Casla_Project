# Hướng dẫn test Job cập nhật Sales Person (ZE) trên SO

**FS:** Update partner function · **Hệ thống test:** AK3 client 100 · **App sử dụng:** Application Jobs, Manage Business Partner Master Data, Manage Sales Orders

## 1. Job làm gì

Mỗi đêm lúc 01:00, job tìm các khách hàng có **BP thay đổi trong ngày hôm qua** (tính theo giờ Việt Nam). Với các khách đó, job lấy các SO **loại TA (Standard Order)**, **chưa complete**, của **Sales org 6710, 6720** và so sánh Sales Person (ZE) ở **header SO** với ZE trên **BP master** (theo đúng Sales area của SO).

| Trường hợp | Kết quả trên SO | Log |
|---|---|---|
| ZE trên SO **giống** ZE trên BP | Không đổi | Information *"đã khớp master"* |
| SO **chưa có** ZE, BP **có** ZE | **Thêm** ZE theo BP | Success |
| SO và BP có ZE **khác nhau** | **Ghi đè** ZE trên SO theo BP | Success |
| SO **có** ZE, BP **không có** ZE | **Giữ nguyên** ZE trên SO | Info |
| Cập nhật không được (SO đang bị khóa...) | Không đổi | Error, kèm nguyên nhân |

> **Lưu ý quan trọng khi test:** Chạy theo lịch thì job chỉ quét BP sửa **hôm qua**. Nếu hôm nay bạn sửa BP rồi chạy job ngay mà không nhập ngày, job sẽ **không thấy** thay đổi đó. Vì vậy khi test, nhập **ngày hôm nay** vào ô *Ngày thay đổi BP* (xem bước 3).

## 2. Chuẩn bị dữ liệu test

Chọn 1–2 khách hàng thuộc Sales org 6710 hoặc 6720 có SO **loại TA (Standard Order)**, **chưa complete** (đang mở hoặc mới giao/xuất hóa đơn một phần). Với mỗi SO, mở **Manage Sales Orders** (hoặc VA03) > **Header** > tab **Partner** và ghi lại ZE hiện tại.

Mỗi kịch bản cần **sửa BP vào ngày test**, vì job chỉ xét các khách hàng có BP thay đổi. Sửa ZE trong **Manage Business Partner Master Data** > BP > **Sales Area** đúng với SO > **Partner Functions**.

| Mã | Kịch bản | Dữ liệu chuẩn bị | Kết quả mong đợi |
|---|---|---|---|
| TC1 | Ghi đè | SO đang có ZE = A. Trên BP đổi ZE thành B. | ZE trên SO đổi thành B. Log Success *"đã đổi ZE A -> B"* |
| TC2 | Thêm mới | SO chưa có ZE (xóa ZE trên SO hoặc tạo SO mới không có ZE). Trên BP có ZE = B. | SO được thêm ZE = B. Log Success *"đã thêm ZE B"* |
| TC3 | Giữ nguyên | SO đang có ZE = A. Trên BP **xóa** ZE. | ZE trên SO vẫn là A. Log Info *"chưa có ZE – giữ nguyên ZE A"* |
| TC4 | Đã khớp | ZE trên SO và BP giống nhau. Sửa thông tin khác của BP (ví dụ số điện thoại). | SO không đổi. Log Information *"ZE … đã khớp master, không cần cập nhật"* |
| TC5 | Ngoài phạm vi | SO đã complete, SO không phải loại TA, hoặc SO của sales org khác 6710/6720. Đổi ZE trên BP. | SO không đổi |
| TC6 | SO đang bị khóa | Làm như TC1, nhưng mở SO ở chế độ **Edit** và để nguyên trong lúc chạy job. | Log Error *"SO đang bị khóa…"*. Đóng SO rồi chạy lại job với số SO đó thì cập nhật thành công |
| TC7 | Chạy thử | Làm như TC1, nhưng tick ô **Chạy thử**. | SO **không đổi**. Log ghi *"[TEST] … sẽ đổi ZE A -> B"* |

## 3. Chạy job thủ công để test

1. Mở app **Application Jobs** > bấm **Create** (dấu +).
2. **Job Template:** chọn *Job Template - Update Partner Function ZE on SO*.
   - Nếu không thấy template này, báo dev/admin để gán quyền.
3. **Scheduling Options:** tick **Start Immediately**. Vào **Define Recurrence Pattern** và **bỏ lặp lại**, để job chỉ chạy 1 lần. Nếu còn lặp, ngày nào job cũng chạy lại với đúng các tham số đã nhập.
4. **Parameters:**

   **Cách nhanh nhất:** chỉ điền **Sales Order**, các ô khác để trống. Job sẽ xử lý đúng các SO đã nhập, không xét BP có thay đổi hay không, và **mỗi SO có một dòng log**.

   | Ô trên màn hình | Nhập gì khi test |
   |---|---|
   | Ngày thay đổi BP (trống=D-1) | **Để trống.** Chỉ nhập khi muốn test đúng luồng chạy đêm (sửa BP rồi để job tự tìm ra SO). Khi đó nhập **ngày sửa BP**, và job chỉ xử lý SO có BP sửa đúng ngày đó. |
   | Sales Order | Các số SO test. Nhập 10004257 là được, không cần số 0 ở đầu. |
   | Chạy thử - không update | Tick nếu chỉ muốn xem trước (TC7). Bỏ tick để cập nhật thật. |
   | Quét toàn bộ SO đang mở | **Không tick.** Ô này chỉ dùng khi go-live. Tick ô này mà để trống Sales Order thì job sẽ cập nhật **toàn bộ** SO đang mở. |

   Log khi chạy theo số SO:
   - SO đã khớp: dòng Information *"ZE … đã khớp master, không cần cập nhật"*.
   - SO được cập nhật: Success. SO không cập nhật được: Error kèm nguyên nhân.
   - SO không tìm thấy (sai số, không phải loại TA, không thuộc 6710/6720, hoặc đã complete): dòng Warning *"không xử lý – …"*.

5. Bấm **Schedule**. Chờ vài giây rồi bấm **Refresh** đến khi Status = **Finished**.

## 4. Xem kết quả

**Xem log của job:** trong app Application Jobs, bấm vào dòng job vừa chạy > biểu tượng **Log** (cột Log).

- **Dòng đầu tiên:** cho biết job đã quét BP sửa trong ngày nào. Ví dụ *"BP thay đổi ngày 2026-11-09 (giờ VN) = UTC 2026-11-08 17:00:00 -> 2026-11-09 16:59:59"*. Phần UTC là giờ quy đổi nội bộ của hệ thống, chỉ cần kiểm tra ngày giờ VN đúng là được.
- **Các dòng giữa:** mỗi SO một dòng, gồm Success, Error hoặc Info.
- **Dòng cuối cùng:** tổng kết, ví dụ *"Tổng SO: 5 – Đã đúng: 1 – Insert: 1 – Ghi đè: 2 – Giữ nguyên (master trống): 1 – Lỗi: 0"*.

**Xem trên SO:** mở lại SO trong Manage Sales Orders (hoặc VA03) > **Header** > tab **Partner**, kiểm tra dòng **ZE Sales Person**. Nếu đang mở sẵn SO thì cần thoát ra và mở lại để thấy dữ liệu mới.

## 5. Test lịch chạy hằng ngày

1. App **Application Jobs** > **Create** > chọn cùng template.
2. **Scheduling Options:**
   - **Bỏ tick** Start Immediately. Nếu để tick, job chạy ngay rồi lặp lại vào đúng giờ đó mỗi ngày.
   - **Time Zone of Job:** chọn **Etc/GMT-7** (giống job `ZJT_HHDV_DAILY` trên PRD). Đây chính là giờ Việt Nam (UTC+7): kiểu đặt tên Etc/GMT ghi dấu ngược. **Không chọn Etc/GMT+7**, vì đó là UTC-7.
   - Ngày giờ bắt đầu: **01:00** của ngày mai.
   - **Define Recurrence Pattern** > lặp lại mỗi **1 ngày**.
3. **Parameters:** để **trống toàn bộ**. Job sẽ tự lấy ngày hôm qua. Nếu nhập ngày, đêm nào job cũng chỉ quét đúng ngày đó.
4. Sau khi Schedule, mở job vừa tạo và kiểm tra mục **Run Details**: **Next Planned Start** phải là 01:00 (Etc/GMT-7).
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
