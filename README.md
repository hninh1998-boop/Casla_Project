# ZBOM

Toàn bộ source của nhóm chức năng ZBOM: backend ABAP (package `ZPK_ZBOM`) và các app Fiori dùng nó.

```
zbom (branch)
├── .abapgit.xml   abapGit, starting folder = /abap/src/
├── abap/src/      backend ZPK_ZBOM, mỗi folder là một package con
└── apps/          app Fiori, mỗi folder là một app độc lập
```

## App và backend tương ứng

| Folder | App trên launchpad | Package BE | Service |
|---|---|---|---|
| `apps/zbom_ov2` | Báo cáo chi tiết BOM đa cấp | `ZPK_ZBOM_HDR_ITM` | `ZUI_ZBOM_V2` |
| `apps/zbomrp` | Báo cáo BOM chi tiết | `ZPK_ZBOM_RP` | `ZUI_ZBOM_RP_V2` |
| `apps/zbom_crud_auth` | Phân quyền thêm/sửa/xóa BOM | `ZPK_ZBOM_RP` | `ZUI_ZBOM_AUTH_V2` |
| `apps/zbom_spplant` | ZBOM - Config Special Procurement | `ZPK_ZBOM_SP` | `ZUI_ZBOM_SPPLANT_OV2` |
| `apps/zupload_zbom_rp` | ZUPLOAD - Add BOM Item | `ZPK_ZUPLOAD_ZBOM_RP` | `ZUI_UPLOAD_ZBOM_RP_V4` |
| `apps/zbomdetail` *(chưa có source)* | Báo cáo ZBOM - Detail | `ZPK_ZBOM_DETAIL` | `ZUI_ZBOM_DETAIL_V2` |

## Làm việc với một app

- Mở đúng folder app trong BAS (File > Open Folder > `apps/<app>`), rồi `npm install`, `npm start`. Deploy bằng `npm run deploy`; cấu hình deploy nằm trong `ui5-deploy.yaml` của từng app.
- Xem lịch sử riêng của một app: `git log -- apps/<app>`
- Chỉ tải về một app: `git sparse-checkout set apps/<app>`
- Ghi tên app ở đầu commit message, ví dụ `[zbom_ov2] ...`, để lọc lịch sử cho dễ.

## Backend

`abap/src/` giữ nguyên cấu trúc abapGit của repo `ZPK_ZBOM`. `.abapgit.xml` ở thư mục gốc đã đặt starting folder là `/abap/src/`, nên abapGit trên BE có thể link thẳng vào branch này (abapGit chỉ đọc `/abap/src/`, bỏ qua `apps/`).

Khi BE vẫn còn link với repo `ZPK_ZBOM`, `abap/` ở đây là bản sao và phải đồng bộ tay sau mỗi lần đẩy BE.
