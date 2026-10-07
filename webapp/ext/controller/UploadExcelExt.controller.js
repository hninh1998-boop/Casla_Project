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

    return ControllerExtension.extend("mcofaupl.ext.controller.UploadExcelExt", {
        downloadTemplate: async function () {
            // Load ExcelJS từ local project (CSP của S/4HANA Cloud chặn external CDN)
            if (!window.ExcelJS) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement("script");
                    script.src = sap.ui.require.toUrl("mcofaupl/libs/exceljs.min.js");
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet("Template");

            // ===== Cấu trúc cột (29 cột, key theo field CDS DataType của mco_fa_upl) =====
            // header: "Tên tiếng Anh\nMô tả tiếng Việt", mandatory: "R" (required) | "O" (optional),
            // hint: độ dài tối đa hoặc định dạng nhập liệu
            const aColumnDefs = [
                { key: "CompanyCode", width: 14, header: "Company Code\nMã công ty", mandatory: "R", hint: "4" },
                { key: "AssetClass", width: 14, header: "Asset Class\nNhóm tài sản", mandatory: "R", hint: "8" },
                { key: "PostCapitalization", width: 16, header: "Post Capitalization\nTích chọn \"X\" nếu Tài sản được hình thành từ năm trước", mandatory: "O", hint: "T/F" },
                { key: "FixedAssetDescription", width: 30, header: "Asset Description\nTên TSCĐ/CCDC/XDCBDD", mandatory: "R", hint: "50" },
                { key: "AdditionalDescription", width: 30, header: "Additional Description\nTên TSCĐ/CCDC/XDCBDD bổ sung", mandatory: "O", hint: "50" },
                { key: "BaseUnitIsoCode", width: 14, header: "Base Unit of Measure\nĐơn vị tính của tài sản", mandatory: "O", hint: "3" },
                { key: "SerialNumber", width: 18, header: "Serial Number\nSố ký hiệu trên mã tài sản ", mandatory: "O", hint: "18" },
                { key: "OrderDate", width: 16, header: "Ordered On\nNgày nhận đặt đơn tài sản ", mandatory: "O", hint: "DD.MM.YYY" },
                { key: "EvalGroup1", width: 20, header: "Evaluation Group 1\nBộ phận chi tiết sử dụng tài sản ", mandatory: "O", hint: "20" },
                { key: "EvalGroup2", width: 20, header: "Evaluation Group 2\nSố khung tài sản", mandatory: "O", hint: "20" },
                { key: "EvalGroup3", width: 20, header: "Evaluation Group 3\nSố máy tài sản", mandatory: "O", hint: "20" },
                { key: "InventoryNumber", width: 18, header: "Inventory Number\nMã lưu kho", mandatory: "O", hint: "T/F" },
                { key: "LastInventoryDate", width: 16, header: "Last Inventory On\nNgày kiểm kê gần nhất", mandatory: "O", hint: "DD.MM.YYY" },
                { key: "InventoryNote", width: 22, header: "Inventory Note\nGhi chú cho lần kiểm kê gần nhất", mandatory: "O", hint: "15" },
                { key: "InventoryIsCounted", width: 16, header: "Asset Is Inventory-Relevant\nTích chọn nếu có kiểm kê", mandatory: "O", hint: "T/F" },
                { key: "CostCenter", width: 14, header: "Cost Center\nPhòng ban chịu chi phí khấu hao", mandatory: "O", hint: "10" },
                { key: "ProfitCenter", width: 14, header: "Profit Center\nTrung tâm lợi nhuận chi phí", mandatory: "R", hint: "10" },
                { key: "Plant", width: 12, header: "Plant\nNhà máy quản lý tài sản", mandatory: "O", hint: "4" },
                { key: "Room", width: 14, header: "Room\nPhòng lưu trữ tài sản ", mandatory: "O", hint: "8" },
                { key: "Segment", width: 14, header: "Segment\nLĩnh vực", mandatory: "O", hint: "10" },
                { key: "AssetLocation", width: 16, header: "Location\nVị trí đặt tài sản ", mandatory: "O", hint: "10" },
                { key: "Supplier", width: 22, header: "Supplier\nMã nhà cung cấp tài sản (nếu tài sản được mua ngoài)", mandatory: "O", hint: "10" },
                { key: "AssetIsAcquiredUsed", width: 16, header: "Asset Was Acquired Used\nTích \"X\" nếu tài sản cũ đã qua sử dụng", mandatory: "O", hint: "T/F" },
                { key: "ManufacturerName", width: 22, header: "Manufacturer of Asset\nNhà sản xuất (nếu muốn quản lý)", mandatory: "O", hint: "30" },
                { key: "CapitalizationDate", width: 16, header: "Capitalized on \nNgày đưa vào sử dụng", mandatory: "O", hint: "DD.MM.YYYY" },
                { key: "DeactivationDate", width: 16, header: "Deactived on\nNgày hết hiệu lực sử dụng ", mandatory: "O", hint: "DD.MM.YYYY" },
                { key: "UsefulLifeYears", width: 20, header: "Useful Life in Years\nThời gian khấu hao theo năm (Nhập số năm nếu thời gian khấu hao >=12 tháng)", mandatory: "R", hint: "3" },
                { key: "UsefulLifePeriods", width: 18, header: "Useful Life in Period\nThời gian khấu hao lẻ tháng", mandatory: "R", hint: "2" },
                { key: "DepreciationStartDate", width: 20, header: "Start Date of Depreciation Calculation\nSố ngày bắt đầu khấu hao lẻ của tài sản", mandatory: "O", hint: "DD.MM.YYYY" }
            ];

            // ===== Nhóm cột (theo tab nghiệp vụ chuẩn SAP Asset Accounting) =====
            const aGroups = [
                { text: "General/Inventory Data", from: 1, to: 15 },
                { text: "Time-Dependent Data", from: 16, to: 20 },
                { text: "Origin", from: 21, to: 24 },
                { text: "Ledger", from: 25, to: 26 },
                { text: "Valuation", from: 27, to: 29 }
            ];

            sheet.columns = aColumnDefs.map((c) => ({ key: c.key, width: c.width }));

            // ===== Row 1: Group header (merge theo từng nhóm) =====
            const row1 = sheet.getRow(1);
            aGroups.forEach((g) => {
                row1.getCell(g.from).value = g.text;
                sheet.mergeCells(1, g.from, 1, g.to);
            });

            // ===== Row 2: Column header (Tên tiếng Anh + mô tả tiếng Việt) =====
            const row2 = sheet.getRow(2);
            aColumnDefs.forEach((c, i) => {
                const aParts = c.header.split("\n");
                const sEng = aParts[0] || "";
                const sVn = aParts.slice(1).join("\n");

                row2.getCell(i + 1).value = {
                    richText: [
                        { text: sEng + "\n", font: { name: "Times New Roman", size: 13, bold: true, color: { argb: "FF000000" } } },
                        { text: sVn, font: { name: "Times New Roman", size: 12, bold: false, color: { argb: "FF000000" } } }
                    ]
                };
            });

            // ===== Row 3: Mandatory flag (R = bắt buộc, O = tuỳ chọn) =====
            const row3 = sheet.getRow(3);
            aColumnDefs.forEach((c, i) => {
                row3.getCell(i + 1).value = c.mandatory;
            });

            // ===== Row 4: Hint - độ dài tối đa / định dạng nhập liệu =====
            const row4 = sheet.getRow(4);
            aColumnDefs.forEach((c, i) => {
                row4.getCell(i + 1).value = c.hint;
            });

            // ===== Style: Group header (row1) - có nền xanh =====
            row1.eachCell({ includeEmpty: true }, (cell) => {
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4472C4" } };
                cell.font = { name: "Times New Roman", size: 11, bold: true, color: { argb: "FFFFFFFF" } };
                cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                cell.border = {
                    top: { style: "thin", color: { argb: "FF000000" } },
                    left: { style: "thin", color: { argb: "FF000000" } },
                    bottom: { style: "thin", color: { argb: "FF000000" } },
                    right: { style: "thin", color: { argb: "FF000000" } }
                };
            });
            row1.height = 20;

            // ===== Style: Column header (row2) - không nền, màu chữ theo R/O =====
            row2.eachCell({ includeEmpty: true }, (cell) => {
                cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                cell.border = {
                    top: { style: "thin", color: { argb: "FF000000" } },
                    left: { style: "thin", color: { argb: "FF000000" } },
                    bottom: { style: "thin", color: { argb: "FF000000" } },
                    right: { style: "thin", color: { argb: "FF000000" } }
                };
            });

            // ===== Style: Mandatory row - chữ "R" màu đỏ, "O" giữ màu mặc định =====
            aColumnDefs.forEach((c, i) => {
                const cell = row3.getCell(i + 1);
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFE2EFDA" } };
                cell.font = {
                    name: "Calibri",
                    size: 10,
                    bold: true,
                    color: { argb: c.mandatory === "R" ? "FFFF0000" : "FF375623" }
                };
                cell.alignment = { vertical: "middle", horizontal: "center" };
                cell.border = {
                    top: { style: "thin", color: { argb: "FFBFBFBF" } },
                    left: { style: "thin", color: { argb: "FFBFBFBF" } },
                    bottom: { style: "thin", color: { argb: "FFBFBFBF" } },
                    right: { style: "thin", color: { argb: "FFBFBFBF" } }
                };
            });
            row3.height = 18;

            // ===== Style: Hint row =====
            row4.eachCell({ includeEmpty: true }, (cell) => {
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFF2CC" } };
                cell.font = { name: "Calibri", size: 10, italic: true, color: { argb: "FF7F6000" } };
                cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                cell.border = {
                    top: { style: "thin", color: { argb: "FFBFBFBF" } },
                    left: { style: "thin", color: { argb: "FFBFBFBF" } },
                    bottom: { style: "thin", color: { argb: "FFBFBFBF" } },
                    right: { style: "thin", color: { argb: "FFBFBFBF" } }
                };
            });
            row4.height = 18;

            sheet.views = [{ state: "frozen", ySplit: 4 }];

            try {
                const buffer = await workbook.xlsx.writeBuffer();
                const blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "Template_Fixed Asset Upload.xlsx";
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
        _NS: "com.sap.gateway.srvd.zsd_m_mco_fa_upl.v0001.",
        _ENTITY_SET: "ManageFile",
        _DIALOG_ID: "idFileUploadDialog",
        _FRAGMENT: "mcofaupl.ext.fragment.filedialog",

        // ===== Lifecycle ==========================================================
        override: {
            onInit: function () {
                if (this.base && this.base.onInit) {
                    this.base.onInit();
                }
            },
            editFlow: {
                onAfterActionExecution: function (oEvent) {
                    // oEvent là string dạng: "com.sap.gateway.srvd.zsd_m_mco_fa_upl.v0001.downloadTemplate(...)"
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
