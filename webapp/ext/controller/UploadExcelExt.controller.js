sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/m/MessageToast",
    "sap/ui/core/Messaging",
    "sap/ui/core/message/Message",
    "sap/ui/core/message/MessageType",
    "sap/ui/core/Fragment"
], function (
    ControllerExtension,
    MessageToast,
    Messaging,
    Message,
    MessageType,
    Fragment
) {
    "use strict";

    return ControllerExtension.extend("zmodheadov4.ext.controller.UploadExcelExt", {
        downloadTemplate: async function () {
            // Load ExcelJS từ local project (CSP của S/4HANA Cloud chặn external CDN)
            if (!window.ExcelJS) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement("script");
                    script.src = sap.ui.require.toUrl("zmodheadov4/libs/exceljs.min.js");
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet("Template");

            // ===== Cấu trúc cột (key theo field CDS DataFile của ZI_M_OD_H_DATA) =====
            // group: true  → thuộc nhóm "OD Text" (banner ngang ở row1, sub-header ở row2)
            // group: false → cột độc lập, header gộp dọc row1-row2
            const aColumnDefs = [
                { key: "Od", header: "OD*", width: 12, mandatory: true, group: false },
                { key: "PlanGiDate", header: "Plan GI date", width: 14, mandatory: false, group: false },
                { key: "Incoterm", header: "Incoterm", width: 12, mandatory: false, group: false },
                { key: "IncoLoc1", header: "Inco. Loc1", width: 12, mandatory: false, group: false },
                { key: "NhaCungCapVanTai", header: "Nhà cung cấp vận tải", width: 24, mandatory: false, group: true },
                { key: "PhanLoaiPtvt", header: "Phân loại PTVT", width: 20, mandatory: false, group: true },
                { key: "SoLuongPtvt", header: "Số lượng PTVT", width: 18, mandatory: false, group: true },
                { key: "BienSoXe", header: "Biển số xe", width: 16, mandatory: false, group: true },
                { key: "SoContainer", header: "Số container", width: 18, mandatory: false, group: true },
                { key: "SoSeal", header: "Số seal", width: 16, mandatory: false, group: true },
                { key: "TareWeight", header: "Tare weight", width: 16, mandatory: false, group: true },
                { key: "Booking", header: "Booking", width: 16, mandatory: false, group: true },
                { key: "NgayTauChay", header: "Ngày tàu chạy", width: 18, mandatory: false, group: true },
                { key: "NgayGioXuatHang", header: "Ngày giờ xuất hàng", width: 22, mandatory: false, group: true },
                { key: "CutOffTime", header: "Cut-off time", width: 18, mandatory: false, group: true },
                { key: "GhiChuGiaoHang", header: "Ghi chú giao hàng", width: 22, mandatory: false, group: true },
                { key: "TyGiaLoNoiDia", header: "Tỷ giá lô nội địa", width: 18, mandatory: false, group: true }
            ];

            sheet.columns = aColumnDefs.map((c) => ({ key: c.key, width: c.width }));

            // Định dạng Text cho toàn bộ cột (tránh Excel tự chuyển General → Number/Date,
            // làm mất số 0 đầu hoặc sai định dạng khi người dùng nhập liệu)
            aColumnDefs.forEach((c, i) => {
                sheet.getColumn(i + 1).numFmt = "@";
            });

            const iFirstGroupCol = aColumnDefs.findIndex((c) => c.group) + 1;
            const iLastCol = aColumnDefs.length;
            const greyBorder = {
                top: { style: "thin", color: { argb: "FFBFBFBF" } },
                left: { style: "thin", color: { argb: "FFBFBFBF" } },
                bottom: { style: "thin", color: { argb: "FFBFBFBF" } },
                right: { style: "thin", color: { argb: "FFBFBFBF" } }
            };
            const whiteBorder = {
                top: { style: "thin", color: { argb: "FFFFFFFF" } },
                left: { style: "thin", color: { argb: "FFFFFFFF" } },
                bottom: { style: "thin", color: { argb: "FFFFFFFF" } },
                right: { style: "thin", color: { argb: "FFFFFFFF" } }
            };

            // ===== Row 1: Banner "OD Text" chỉ gộp ngang các cột thuộc nhóm =====
            sheet.getCell(1, iFirstGroupCol).value = "OD Text";
            sheet.mergeCells(1, iFirstGroupCol, 1, iLastCol);

            // ===== Các cột độc lập: header gộp dọc row1-row2, không thuộc banner =====
            aColumnDefs.forEach((c, i) => {
                const col = i + 1;
                if (c.group) {
                    // Sub-header của nhóm nằm ở row 2
                    sheet.getCell(2, col).value = c.header;
                    return;
                }
                sheet.mergeCells(1, col, 2, col);
                const cell = sheet.getCell(1, col);
                cell.value = c.header;
                cell.fill = {
                    type: "pattern",
                    pattern: "solid",
                    fgColor: { argb: c.mandatory ? "FFED7D31" : "FF4472C4" }
                };
                cell.font = { name: "Calibri", size: 11, bold: true, color: { argb: "FFFFFFFF" } };
                cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                cell.border = greyBorder;
            });

            // ===== Style banner + sub-header của nhóm "OD Text" (xanh dương) =====
            const row1 = sheet.getRow(1);
            const row2 = sheet.getRow(2);
            aColumnDefs.forEach((c, i) => {
                if (!c.group) return;
                const col = i + 1;
                [row1.getCell(col), row2.getCell(col)].forEach((cell) => {
                    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4472C4" } };
                    cell.font = { name: "Calibri", size: 11, bold: true, color: { argb: "FFFFFFFF" } };
                    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                    cell.border = whiteBorder;
                });
            });
            row1.height = 20;
            row2.height = 20;

            // ===== Row 3: chỉ cột bắt buộc (OD) mới có chữ "Bắt buộc nhập" màu đỏ nghiêng =====
            const row3 = sheet.getRow(3);
            aColumnDefs.forEach((c, i) => {
                if (!c.mandatory) return;
                const cell = row3.getCell(i + 1);
                cell.value = "Bắt buộc nhập";
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFCE4D6" } };
                cell.font = { name: "Calibri", size: 10, italic: true, color: { argb: "FFFF0000" } };
                cell.alignment = { vertical: "middle", horizontal: "center" };
                cell.border = greyBorder;
            });
            row3.height = 18;

            sheet.views = [{ state: "frozen", ySplit: 3 }];

            try {
                const buffer = await workbook.xlsx.writeBuffer();
                const blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "Template_Mass Upload OD Header.xlsx";
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);

                MessageToast.show(this._t("downloadTemplateSuccMsg", "Template downloaded successfully."));
            } catch (e) {
                MessageToast.show(this._t("downloadTemplateErrMsg", "Download failed: ") + e);
            }
        },

        // ===== Constants ==========================================================
        // Action uploadExcel bound to Collection (ManageFile)
        // → path: /ManageFile/<NS>uploadExcel(...)
        _NS: "com.sap.gateway.srvd.zui_m_od_head.v0001.",
        _ENTITY_SET: "ManageFile",
        _DIALOG_ID: "idFileUploadDialog",
        _FRAGMENT: "zmodheadov4.ext.fragment.filedialog",

        // ===== Lifecycle ==========================================================
        override: {
            onInit: function () {
                if (this.base && this.base.onInit) {
                    this.base.onInit();
                }
            }
        },

        // ===== Shortcuts ==========================================================
        _api() { return this.base.getExtensionAPI(); },
        _model() { return this._api().getModel(); },
        _i18n() { return this._api().getModel("i18n"); },
        _t(key, def) {
            const b = this._i18n()?.getResourceBundle?.();
            try { return b?.getText?.(key) ?? def ?? key; } catch (e) { return def ?? key; }
        },

        // ===== Open Upload Dialog =================================================
        async uploadexceldialog() {
            if (!this._dlg) {
                this._dlg = await this._api().loadFragment({
                    id: this._DIALOG_ID,
                    name: this._FRAGMENT,
                    controller: this
                });
            }
            this._dlg.open();
        },

        // ===== File Change ========================================================
        async onFileChange(oEvent) {
            const f = (oEvent.getParameter("files") || [])[0];
            if (!f) return;

            this._file = {
                type: f.type || "",
                name: f.name || "",
                ext: (f.name || "").split(".").pop() || ""
            };

            // fileContent là Edm.Binary → truyền base64 string
            await this._secured(() =>
                this._readAsDataUrl(f).then((url) => {
                    const m = String(url).match(/,(.*)$/);
                    this._file.content = m && m[1] ? m[1] : "";
                })
            );
        },

        // ===== Upload =============================================================
        async onUploadPress() {
            if (!this._file?.content) {
                MessageToast.show(this._t("uploadFileErrMeg", "Vui lòng chọn tệp."));
                return;
            }

            await this._secured(async () => {
                await this._invokeCollectionAction("uploadExcel", {
                    mimeType: this._file.type,
                    fileName: this._file.name,
                    fileContent: this._file.content,  // base64 cho Edm.Binary
                    fileExtension: this._file.ext
                });

                await this._refreshListReport();
                MessageToast.show(this._t("uploadFileSuccMsg", "Tải lên thành công."));
                this._resetDialog();
            });
        },

        // ===== Cancel =============================================================
        onCancelUpload() {
            this._resetDialog();
        },

        // ===== OData V4 — Bound to Collection Action =============================
        // Path: /<EntitySet>/<Namespace><ActionName>(...)
        async _invokeCollectionAction(actionName, params) {
            const path = `/${this._ENTITY_SET}/${this._NS}${actionName}(...)`;
            const op = this._model().bindContext(path);

            if (params) {
                Object.entries(params).forEach(([k, v]) => {
                    if (v !== undefined && v !== null && v !== "") {
                        op.setParameter(k, v);
                    }
                });
            }

            try {
                await op.invoke();
            } catch (e) {
                this._pushODataErrors(e);
                this._openFEMessages();
                throw e;
            }

            const ctx = op.getBoundContext?.();
            return ctx?.getObject?.() || {};
        },

        // ===== Helpers ============================================================
        _secured(fn) {
            return this._api().getEditFlow().securedExecution(fn, { busy: { set: true } });
        },

        async _refreshListReport() {
            const api = this._api();
            if (typeof api.refresh === "function") {
                await api.refresh();
                return;
            }
            if (this._model()?.refresh) {
                await this._model().refresh();
            }
        },

        _resetDialog() {
            try {
                const fu = Fragment.byId(this._DIALOG_ID, "idFileUpload");
                fu?.clear?.();
            } catch (e) { /* no-op */ }
            this._file = null;
            if (this._dlg) {
                this._dlg.close?.();
                this._dlg.destroy?.();
                this._dlg = null;
            }
        },

        _openFEMessages() {
            const h = this._api().getEditFlow?.().getMessageHandler?.();
            h?.showMessages?.();
        },

        _pushODataErrors(err) {
            const root = err?.error || err?.cause?.error || {};
            const bag = [];
            const rootMsg = root?.message || err?.message;

            if (typeof rootMsg === "string" && rootMsg.trim()) {
                bag.push(new Message({
                    message: rootMsg,
                    type: MessageType.Error,
                    persistent: true,
                    code: root?.code
                }));
            }

            if (Array.isArray(root?.details)) {
                root.details.forEach((d) => {
                    if (d?.message) {
                        bag.push(new Message({
                            message: d.message,
                            type: MessageType.Error,
                            persistent: true,
                            code: d.code,
                            target: d.target || ""
                        }));
                    }
                });
            }

            if (bag.length) {
                if (Messaging?.addMessages) {
                    Messaging.addMessages(bag);
                } else {
                    sap.ui.getCore().getMessageManager?.()?.addMessages?.(bag);
                }
            }
        },

        _readAsDataUrl(file) {
            return new Promise((resolve, reject) => {
                try {
                    const r = new FileReader();
                    r.onload = (e) => resolve(e?.target?.result || "");
                    r.onerror = reject;
                    r.readAsDataURL(file);
                } catch (e) { reject(e); }
            });
        }

    });
});
