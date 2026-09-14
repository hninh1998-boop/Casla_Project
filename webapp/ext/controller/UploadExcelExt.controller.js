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

    return ControllerExtension.extend("mcsoheader.ext.controller.UploadExcelExt", {
        downloadTemplate: async function () {
            // Load ExcelJS từ local project (CSP của S/4HANA Cloud chặn external CDN)
            if (!window.ExcelJS) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement("script");
                    script.src = sap.ui.require.toUrl("mcsoheader/libs/exceljs.min.js");
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet("Template");

            // ===== Cấu trúc cột (key theo field CDS DataFile của mc_so_header) =====
            const aColumnDefs = [
                { key: "SalesOrder", width: 14, mandatory: true },
                { key: "CustomerGroup", width: 16, mandatory: false },
                { key: "LcNumber", width: 26, mandatory: false },
                { key: "LcOpenDate", width: 14, mandatory: false },
                { key: "CommissionRate", width: 16, mandatory: false },
                { key: "ExportTrustContract", width: 26, mandatory: false }
            ];

            sheet.columns = aColumnDefs.map((c) => ({ key: c.key, width: c.width }));

            // Định dạng Text cho toàn bộ cột (tránh Excel tự chuyển General → Number/Date,
            // làm mất số 0 đầu hoặc sai định dạng khi người dùng nhập liệu)
            aColumnDefs.forEach((c, i) => {
                sheet.getColumn(i + 1).numFmt = "@";
            });

            // ===== Row 1-2: Group header — "SO*" và "Customer Group" gộp dọc 2 dòng,
            // "SO Text" gộp ngang cột 3-6, với sub-header ở dòng 2 =====
            sheet.getCell(1, 1).value = "SO*";
            sheet.mergeCells(1, 1, 2, 1);
            sheet.getCell(1, 2).value = "Customer Group";
            sheet.mergeCells(1, 2, 2, 2);
            sheet.getCell(1, 3).value = "SO Text";
            sheet.mergeCells(1, 3, 1, 6);

            const aSoTextSubHeaders = ["Số LC", "Ngày mở LC", "Tỷ lệ chi com", "Số hợp đồng ủy thác XK"];
            aSoTextSubHeaders.forEach((sText, i) => {
                sheet.getCell(2, 3 + i).value = sText;
            });

            const row1 = sheet.getRow(1);
            const row2 = sheet.getRow(2);
            [row1, row2].forEach((row) => {
                row.eachCell({ includeEmpty: true }, (cell) => {
                    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4472C4" } };
                    cell.font = { name: "Calibri", size: 11, bold: true, color: { argb: "FFFFFFFF" } };
                    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                    cell.border = {
                        top: { style: "thin", color: { argb: "FFFFFFFF" } },
                        left: { style: "thin", color: { argb: "FFFFFFFF" } },
                        bottom: { style: "thin", color: { argb: "FFFFFFFF" } },
                        right: { style: "thin", color: { argb: "FFFFFFFF" } }
                    };
                });
                row.height = 20;
            });

            // ===== Row 3: Header thật của bảng dữ liệu (bật AutoFilter),
            // chỉ cột bắt buộc mới có chữ "Bắt buộc nhập" màu đỏ nghiêng =====
            const row3 = sheet.getRow(3);
            aColumnDefs.forEach((c, i) => {
                const cell = row3.getCell(i + 1);
                cell.value = c.mandatory ? "Bắt buộc nhập" : "";
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFCE4D6" } };
                cell.font = { name: "Calibri", size: 10, italic: true, color: { argb: "FFFF0000" } };
                cell.alignment = { vertical: "middle", horizontal: "center" };
                cell.border = {
                    top: { style: "thin", color: { argb: "FFBFBFBF" } },
                    left: { style: "thin", color: { argb: "FFBFBFBF" } },
                    bottom: { style: "thin", color: { argb: "FFBFBFBF" } },
                    right: { style: "thin", color: { argb: "FFBFBFBF" } }
                };
            });
            row3.height = 18;

            // ===== AutoFilter trên dòng 3 → mũi tên dropdown như file mẫu =====
            sheet.autoFilter = `A3:${sheet.getColumn(aColumnDefs.length).letter}3`;

            sheet.views = [{ state: "frozen", ySplit: 3 }];

            try {
                const buffer = await workbook.xlsx.writeBuffer();
                const blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "Template_Mass Change Sales Order Header.xlsx";
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);

                MessageToast.show("Template downloaded successfully.");
            } catch (e) {
                MessageToast.show("Download failed: " + e);
            }
        },

        // ===== Constants ==========================================================
        // Action uploadExcel / downloadTemplate bound to Collection (ManageFile)
        // → path: /ManageFile/<NS>uploadExcel(...)
        _NS: "com.sap.gateway.srvd.zsd_mch_so_file.v0001.",
        _ENTITY_SET: "ManageFile",
        _DIALOG_ID: "idFileUploadDialog",
        _FRAGMENT: "mcsoheader.ext.fragment.filedialog",

        // ===== Lifecycle ==========================================================
        override: {
            onInit: function () {
                if (this.base && this.base.onInit) {
                    this.base.onInit();
                }
            },
            editFlow: {
                onAfterActionExecution: function (oEvent) {
                    // oEvent là string dạng: "com.sap.gateway.srvd.zsd_mch_so_file.v0001.downloadTemplate(...)"
                    if (oEvent && oEvent.split(".")[6] === "downloadTemplate") {
                        this.downloadTemplate();
                    }
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
