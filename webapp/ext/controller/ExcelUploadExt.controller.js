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

    return ControllerExtension.extend("zcrudpocov4.ext.controller.ExcelUploadExt", {
        downloadTemplate: async function () {
            // Load ExcelJS từ local project (CSP của S/4HANA Cloud chặn external CDN)
            if (!window.ExcelJS) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement("script");
                    script.src = sap.ui.require.toUrl("zcrudpocov4/libs/exceljs.min.js");
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet("Template");

            sheet.columns = [
                { header: "Type", key: "Type", width: 14 },
                { header: "ManufacturingOrder", key: "ManufacturingOrder", width: 20 },
                { header: "ManufacturingOrderOperation", key: "ManufacturingOrderOperation", width: 30 },
                { header: "BOMItem", key: "BOMItem", width: 18 },
                { header: "BOMItemCategory", key: "BOMItemCategory", width: 18 },
                { header: "Material", key: "Material", width: 22 },
                { header: "RequiredQuantity", key: "RequiredQuantity", width: 18 },
                { header: "BaseUnit", key: "BaseUnit", width: 12 },
                { header: "Plant", key: "Plant", width: 12 },
                { header: "StorageLocation", key: "StorageLocation", width: 18 }
            ];

            sheet.addRow({
                Type: "I/D/M\nI: Insert\nM: Modify\nD: Delete",
                ManufacturingOrder: "Điền mã LSX",
                ManufacturingOrderOperation: "Công đoạn sử dụng NVL, thường là 0010",
                BOMItem: "STT item (0010,0020)",
                BOMItemCategory: "Mặc định điền L",
                Material: "Mã NVL/BTP cần điều chỉnh",
                RequiredQuantity: "Số lượng",
                BaseUnit: "Đơn vị",
                Plant: "Plant sử dụng",
                StorageLocation: "Kho xưởng tương ứng"
            });

            // Style header
            const headerRow = sheet.getRow(1);
            headerRow.eachCell((cell) => {
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4472C4" } };
                cell.font = { name: "Calibri", size: 11, bold: true, color: { argb: "FFFFFFFF" } };
                cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                cell.border = {
                    top: { style: "thin", color: { argb: "FF000000" } },
                    left: { style: "thin", color: { argb: "FF000000" } },
                    bottom: { style: "thin", color: { argb: "FF000000" } },
                    right: { style: "thin", color: { argb: "FF000000" } }
                };
            });
            headerRow.height = 24;

            // Style hint row
            const hintRow = sheet.getRow(2);
            hintRow.eachCell((cell) => {
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFF2CC" } };
                cell.font = { name: "Calibri", size: 10, italic: true, color: { argb: "FF7F6000" } };
                cell.alignment = { vertical: "middle", horizontal: "left", wrapText: true };
                cell.border = {
                    top: { style: "thin", color: { argb: "FFBFBFBF" } },
                    left: { style: "thin", color: { argb: "FFBFBFBF" } },
                    bottom: { style: "thin", color: { argb: "FFBFBFBF" } },
                    right: { style: "thin", color: { argb: "FFBFBFBF" } }
                };
            });
            hintRow.height = 65;

            sheet.views = [{ state: "frozen", ySplit: 2 }];
            sheet.autoFilter = {
                from: { row: 1, column: 1 },
                to: { row: 1, column: sheet.columns.length }
            };

            try {
                const buffer = await workbook.xlsx.writeBuffer();
                const blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "Template_Mass Change Production Order Components.xlsx";
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
        // Action uploadExcel bound to Collection(ManageFileType)
        // → path: /ManageFile/<NS>uploadExcel(...)
        _NS: "com.sap.gateway.srvd.zui_crud_poc.v0001.",
        _ENTITY_SET: "ManageFile",
        _DIALOG_ID: "idFileUploadDialog",
        _FRAGMENT: "zcrudpocov4.ext.fragment.filedialog",

        // ===== Lifecycle ==========================================================
        override: {
            onInit: function () {
                if (this.base && this.base.onInit) {
                    this.base.onInit();
                }
            },
            editFlow: {
                onAfterActionExecution: function (oEvent) {
                    // oEvent là string dạng: "com.sap.gateway.srvd.zui_crud_poc.v0001.downloadTemplate(...)"
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