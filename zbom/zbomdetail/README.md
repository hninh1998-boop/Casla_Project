## Application Details
|               |
| ------------- |
|**Nguồn gốc**<br>Dựng lại bằng tay theo template List Report Page V2 của SAP Fiori Application Generator 1.33.0 (cùng phiên bản với `zbom_spplant`), vì source gốc không còn|
|**Template Used**<br>List Report Page V2|
|**Service URL**<br>https://my426517.s4hana.cloud.sap/sap/opu/odata/sap/ZUI_ZBOM_DETAIL_V2|
|**Module Name**<br>zbomdetail|
|**Application Title**<br>Báo cáo ZBOM - Detail|
|**Namespace**<br>zbomdetail|
|**UI5 Theme**<br>sap_horizon|
|**UI5 Version**<br>1.148.10|
|**Enable TypeScript**<br>False|
|**Add Eslint configuration**<br>True, see https://www.npmjs.com/package/@sap-ux/eslint-plugin-fiori-tools#rules for the eslint rules.|
|**Main Entity**<br>ExplodeZBOMDetail|

## zbomdetail

Báo cáo ZBOM - Detail: danh sách khai triển BOM đa cấp của một BOM. Mở từ nút "Detail List Item" trên app `zbom_ov2` (intent `DetailListZBOM-display`). Các field của dòng header được truyền sang làm filter ẩn.

### Các tên phải giữ nguyên

Backend `ZPK_ZBOM_DETAIL` đã đăng ký app theo các tên dưới đây. Đổi bất kỳ tên nào thì tile, catalog hoặc điều hướng từ `zbom_ov2` sẽ không chạy.

| Ở đâu | Giá trị | Khớp với |
|---|---|---|
| `manifest.json` → `sap.app.id` | `zbomdetail.zbomdetail` | `appId` trong `ZBOMDETAIL_UI5R` |
| `manifest.json` → inbound | `DetailListZBOM` / `display` | target mapping `ZBOMDETAIL_UI5R`, nút trên `zbom_ov2` |
| `ui5-deploy.yaml` → `app.name` | `ZBOMDETAIL` | IAM app `ZIAM_ZBOM_DETAIL_EXT` (UI app `ZBOMDETAIL_UI5R`) |
| `ui5-deploy.yaml` → `package` | `ZPK_ZBOM_DETAIL` | |

`transport` trong `ui5-deploy.yaml` đang là `REPLACE_WITH_TRANSPORT`. Thay bằng TR thật trước khi deploy.

### Starting the app

```
    npm start
```

- It is also possible to run the application using mock data:

```
    npm run start-mock
```

Hai file trong `webapp/localService/mainService/` không tải từ hệ thống mà được dựng lại từ CDS:

- `metadata.xml`: lấy từ `ZCE_ZBOM_DETAIL`. Kiểu và label dữ liệu lấy theo `ExplodeZBOMItemType` trong metadata của `zbom_ov2` (cùng field, cùng data element). Bản này bỏ các entity SAP tự sinh cho export PDF.
- `ZUI_ZBOM_DETAIL_V2_VAN.xml`: lấy từ `ZCE_ZBOM_DETAIL_ME`.

Muốn thay bằng bản thật thì lưu từ hệ thống (đăng nhập trên trình duyệt):

- `metadata.xml`: https://my426517.s4hana.cloud.sap/sap/opu/odata/sap/ZUI_ZBOM_DETAIL_V2/$metadata
- `ZUI_ZBOM_DETAIL_V2_VAN.xml`: https://my426517.s4hana.cloud.sap/sap/opu/odata/IWFND/CATALOGSERVICE;v=2/Annotations(TechnicalName='ZUI_ZBOM_DETAIL_V2_VAN',Version='0001')/$value/

#### Pre-requisites:

1. Active NodeJS LTS (Long Term Support) version and associated supported NPM version.  (See https://nodejs.org)
