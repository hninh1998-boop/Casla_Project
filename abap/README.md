# Upload Attachment SO – Backend (ABAP Cloud / RAP)

- **Hệ thống:** S/4HANA Cloud Public Edition – AK3 (dev client 080, test client 100)
- **Package:** `ZPK_UPL_ATT_SO` · **Transport:** `AK3K908790`
- **FS:** `Upload attachment SO.docx` (SD – Hoàng Phương Thanh, 10/2026)

Mỗi file trong thư mục này là **1 object**. Tạo trong ADT **theo đúng số thứ tự**, copy toàn bộ nội dung file vào editor. Tạo xong hết mới **Activate all** (Ctrl+Shift+F3), vì các object gọi lẫn nhau.

| # | File | Object | Cách tạo trong ADT |
|---|---|---|---|
| 01 | *(xem mục 01 bên dưới)* | Domain `ZDO_STA_UPL_ATT`, `ZDO_RES_UPL_ATT` | New > Dictionary > Domain (form, nhập tay) |
| 01b | *(xem mục 01b bên dưới)* | Message class `ZUPL_ATT_SO` | New > Other > Message Class (form, nhập tay) |
| 02 | `02_ztb_upl_att_so.tabl.asddls` | Table `ZTB_UPL_ATT_SO` | New > Dictionary > Database Table |
| 03 | `03_zabs_upl_att_so.ddls.asddls` | Abstract entity `ZABS_UPL_ATT_SO` | New > Data Definition (Define Abstract Entity) |
| 04 | `04_zvh_sta_upl_att.ddls.asddls` | CDS value help `ZVH_STA_UPL_ATT` | New > Data Definition |
| 05 | `05_zvh_res_upl_att.ddls.asddls` | CDS value help `ZVH_RES_UPL_ATT` | New > Data Definition |
| 06 | `06_zi_upl_att_so.ddls.asddls` | CDS root view `ZI_UPL_ATT_SO` | New > Data Definition (Define Root View Entity) |
| 07 | `07_zc_upl_att_so.ddls.asddls` | CDS projection `ZC_UPL_ATT_SO` | New > Data Definition (Define Projection View) |
| 08 | `08_zmde_upl_att_so.ddlx.asddlxs` | Metadata extension `ZMDE_UPL_ATT_SO` | New > Metadata Extension |
| 09 | `09_zi_upl_att_so.bdef.asbdef` | Behavior definition `ZI_UPL_ATT_SO` | Chuột phải `ZI_UPL_ATT_SO` > New Behavior Definition (Managed) |
| 10 | `10_zbp_i_upl_att_so.clas.abap` | Behavior pool `ZBP_I_UPL_ATT_SO` – tab **Global Class** | Quick fix trên dòng `implementation in class` của [09] |
| 11 | `11_zbp_i_upl_att_so.clas.locals_imp.abap` | Behavior pool `ZBP_I_UPL_ATT_SO` – tab **Local Types** | Dán đè toàn bộ tab Local Types |
| 12 | `12_zc_upl_att_so.bdef.asbdef` | Behavior definition `ZC_UPL_ATT_SO` (projection) | Chuột phải `ZC_UPL_ATT_SO` > New Behavior Definition |
| 13 | `13_zcl_call_api_upl_att_so.clas.abap` | Class `ZCL_CALL_API_UPL_ATT_SO` (gọi API) | New > ABAP Class |
| 14 | `14_zcl_job_upl_att_so.clas.abap` | Class `ZCL_JOB_UPL_ATT_SO` (Application Job) | New > ABAP Class |
| 15 | `15_zajc_upl_att_so.sajc.json`, `15_zajt_upl_att_so.sajt.json` | Job Catalog `ZAJC_UPL_ATT_SO` + Template `ZAJT_UPL_ATT_SO` | New > Application Job > Catalog Entry / Template (xem mục 15) |
| 16 | `16_zui_upl_att_so.srvd.srvdsrv` | Service definition `ZUI_UPL_ATT_SO` | Chuột phải `ZC_UPL_ATT_SO` > New Service Definition |
| 17 | *(xem mục 17)* | Service binding `ZUI_UPL_ATT_SO_OV4` | Chuột phải `ZUI_UPL_ATT_SO` > New Service Binding |
| 18 | *(xem mục 18)* | Deploy FE + IAM + Business Catalog + Role | |

---

## 01. Domain (form editor – nhập tay)

**`ZDO_STA_UPL_ATT`** – Domain - Check Status Upload Att SO · CHAR 1

| Fixed value | Text |
|---|---|
| N | New |
| R | Ready |
| E | Error |

**`ZDO_RES_UPL_ATT`** – Domain - Post Result Upload Att SO · CHAR 1

| Fixed value | Text |
|---|---|
| P | In process |
| S | Success |
| E | Error |

## 01b. Message class (form editor – nhập tay)

**`ZUPL_ATT_SO`** – Message Class - Upload Attachment SO

| Number | Short Text |
|---|---|
| 000 | `&1&2&3&4` |

Lý do cần message class: `new_message_with_text` chỉ giữ được **50 ký tự**, nên các câu tiếng Việt dài bị cắt (ví dụ "…trạng thái Read"). Behavior pool chia câu thành 4 biến v1..v4, mỗi biến 50 ký tự, nên hiển thị được tối đa **200 ký tự**.

## 15. Application Job Catalog + Template

- **Catalog Entry** `ZAJC_UPL_ATT_SO` – Description *Job - Upload Attachment SO* – Class `ZCL_JOB_UPL_ATT_SO`. Parameter `ATT_ID` được đọc tự động từ `get_parameters`.
- **Template** `ZAJT_UPL_ATT_SO` – Catalog `ZAJC_UPL_ATT_SO`.
- 2 file JSON số 15 dùng để đối chiếu nội dung, giống `ZAJC_M_OD_HEAD` / `ZAJT_M_OD_HEAD`.

## 17. Service binding

| Thuộc tính | Giá trị |
|---|---|
| Name | `ZUI_UPL_ATT_SO_OV4` |
| Description | Ser.Bind. - Upload Attachment SO - OData V4 |
| Binding Type | OData V4 - UI |
| Service Definition | `ZUI_UPL_ATT_SO` |

Activate rồi bấm **Publish**. URL service: `/sap/opu/odata4/sap/zui_upl_att_so_ov4/srvd/sap/zui_upl_att_so/0001/`

Muốn xem nhanh List Report trước khi deploy FE: bấm **Preview** trên entity `UploadAttachment`.

## 18. Deploy FE + phân quyền

1. **Deploy app FE.** App nằm ngay ở thư mục gốc `zupl_att_so/` (gồm `package.json`, `webapp/`...):
   ```bash
   cd /home/user/projects/zupl_att_so
   npm install
   npm run deploy      # BSP ZUPL_ATT_SO_OV4, package ZPK_UPL_ATT_SO, TR AK3K908790
   ```
   Deploy xong, hệ thống tự sinh UI app descriptor `ZUPL_ATT_SO_OV4_UI5R`.
2. **IAM App** `ZIAM_UPL_ATT_SO_EXT` (loại External App):
   - UI App ID: `ZUPL_ATT_SO_OV4_UI5R`
   - Services: OData V4 `ZUI_UPL_ATT_SO_OV4`
   - Bấm **Publish Locally**
3. **Business Catalog** `ZBC_UPL_ATT_SO`:
   - Thêm 2 app: `ZIAM_UPL_ATT_SO_EXT` và `ZAJC_UPL_ATT_SO_SAJC` (IAM app tự sinh từ job catalog)
   - Bấm **Publish Locally**
4. **Client 100**, app *Maintain Business Roles*:
   - Thêm `ZBC_UPL_ATT_SO` vào business role (Write / Read / Value Help = Unrestricted)
   - Gán role cho user

## Điều kiện trước (đã xác nhận)
- Bảng `ZTB_API_AUTH` ở client 100 đã có dòng user `PB9_LO`, user này đã được gán SAP_COM_0109.
- Postman `POST API_CV_ATTACHMENT_SRV/AttachmentContentSet` trả về 201 Created.

## Kịch bản test (client 100)
1. Upload `10001607_Hop dong.pdf`, `10001607.pdf`, `Bao gia_10001607.pdf`, `10001607_filetmp.txt`.
2. Upload lại `10001607.pdf`: phải hiện cảnh báo trùng File Name. Bấm OK thì chỉ upload các file còn lại.
3. **Check:** 3 file ra Ready, file `Bao gia_10001607.pdf` ra Error (SO = N/A).
4. **Post** các dòng Ready: Result chuyển In process. Sau khoảng 1 phút bấm **Go**, dòng phải ra Success và có Attachment Doc. No.
5. VA03 → SO 10001607 → Services for Object → Attachment List: thấy đủ các file và mở được.
6. Xóa 1 dòng Success, upload lại đúng file đó, Check rồi Post: job phải báo *"SO đã có file …"*.
7. Theo dõi job trong app *Application Jobs* (template `ZAJT_UPL_ATT_SO`).

## Những chỗ cần để ý khi test
- **Class 13:** dùng `set_uri_path` (có query string) trên client tạo từ host `-api`, để lệnh GET `GetAllOriginals` và lệnh POST dùng chung cookie và CSRF token. Nếu GET báo 404/400, gửi lại nội dung cột Message.
- **Nút Upload attachment** được đặt trước nút Check bằng anchor trong `manifest.json`. Nếu nút nằm sai chỗ thì chỉ là vấn đề hiển thị.
- **Job không lên lịch được:** dòng sẽ đứng ở In process, sau 30 phút mới được Post lại hoặc xóa.
