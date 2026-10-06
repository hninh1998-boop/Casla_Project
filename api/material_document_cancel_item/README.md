# Material Document - Cancel Item

- Service: `API_MATERIAL_DOCUMENT_SRV` (OData V2), function import `CancelItem`
- Endpoint: `https://<host>-api.s4hana.cloud.sap/sap/opu/odata/sap/API_MATERIAL_DOCUMENT_SRV`
- Auth: Basic - user/password lấy từ `ZTB_API_AUTH` (không lưu trong file)
- Code gọi API: `abap/src/zcl_m_can_matdoc_api.clas.abap`
- Nút **Cancel Item** (`cancelItem`): chứng từ thường hủy bằng EML `I_MaterialDocumentTP` (gom các item cùng
  chứng từ vào 1 chứng từ hủy); chứng từ chuyển kho / chuyển plant (311, 301, ...) hủy bằng `CancelItem` vì EML báo
  `Canceling of subcontracting item 0003 on item level not possible`. `CancelItem` hủy cả cặp dòng xuất + dòng nhận,
  đã xác nhận với 4900005985 item 3 → 4900005990 item 1, 2.
- Nút **Cancel cả chứng từ** (`cancelHeader`): function import `Cancel` (mức header), hủy tất cả item chưa hủy.

## File trong thư mục

| File | Nội dung |
|---|---|
| `1_get_csrf_token.sh` | GET service root với `x-csrf-token: fetch` để lấy token + cookie |
| `2_post_cancel_item.sh` | POST `CancelItem` với token của bước 1 - đã test Postman, HTTP 200 |
| `3_post_cancel_header.sh` | POST `Cancel` (cả chứng từ) với token của bước 1 - chưa test Postman |

## Lưu ý (đã xác nhận qua Postman, AK3/100)

- Tham số nằm trên URL, giá trị bọc trong nháy đơn (`%27`): `MaterialDocumentYear`, `MaterialDocument`, `MaterialDocumentItem`.
- `PostingDate` (không bắt buộc, dạng `datetime'2025-08-14T00:00:00'`): ngày hạch toán của chứng từ đảo; không truyền thì API lấy ngày hiện tại.
  Code đang truyền Posting Date của chính dòng bị hủy. Tham số này chưa test qua Postman.
- `MaterialDocument` tối đa 10 ký tự - gửi thừa ký tự (`'49000000001'`) → HTTP 400 `Malformed URI literal syntax`.
- Token gắn với session cookie → GET và POST phải dùng chung cookie.
- Response OK trả về item của **chứng từ đảo** vừa tạo:
  `{ "d": { "MaterialDocumentYear": "2026", "MaterialDocument": "4900005980", "MaterialDocumentItem": "1", ... } }`
- Response lỗi: `{ "error": { "code": "...", "message": { "lang": "en", "value": "..." } } }`
