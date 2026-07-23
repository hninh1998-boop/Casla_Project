sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/m/MessageToast",
    "sap/ui/core/Messaging",
    "sap/ui/core/message/Message",
    "sap/ui/core/message/MessageType",
    "sap/ui/core/Fragment",
    "sap/ui/model/Sorter"          // ← THÊM DÒNG NÀY
], function (
    ControllerExtension,
    MessageToast,
    Messaging,
    Message,
    MessageType,
    Fragment,
    Sorter                          // ← THÊM THAM SỐ NÀY
) {
    "use strict";

    return ControllerExtension.extend("mchso.ext.controller.UploadExcelExt", {
        downloadTemplate: async function () {
            // Load ExcelJS từ local project (CSP của S/4HANA Cloud chặn external CDN)
            if (!window.ExcelJS) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement("script");
                    script.src = sap.ui.require.toUrl("mchso/libs/exceljs.min.js");
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet("Template");

            // ===== Cấu trúc cột (13 cột, key theo field CDS ZC_D_MCH_SO_U_DATA) =====
            sheet.columns = [
                { key: "SalesOrder", width: 16 },                // 1  SO
                { key: "SalesOrderItem", width: 14 },            // 2  SO item
                { key: "Material", width: 30 },                  // 3  Material
                { key: "Plant", width: 30 },                     // 4  Plant
                { key: "OrderQuantity", width: 18 },             // 5  Order Quantity
                { key: "ConditionType", width: 24 },             // 6  Conditon Type
                { key: "ConditionAmount", width: 26 },           // 7  Amount
                { key: "Currency", width: 22 },                  // 8  Crcy
                { key: "ConditionPricingUnit", width: 22 },      // 9  Per
                { key: "TextPriceApproval", width: 22 },         // 10 Số duyệt giá
                { key: "TextOrderTolerance", width: 24 },        // 11 Dung sai đơn hàng
                { key: "TextSalesNoteCustomer", width: 30 },     // 12 Sales Note for Customer
                { key: "CustomerReference", width: 20 }          // 13 Customer Reference
            ];

            // ===== Row 1: Group header =====
            const row1 = sheet.getRow(1);
            row1.getCell(1).value = "SO*";
            row1.getCell(2).value = "SO item*";
            row1.getCell(3).value = "Material";
            row1.getCell(4).value = "Plant";
            row1.getCell(5).value = "Order Quantity";
            row1.getCell(6).value = "Pricing Element			";
            row1.getCell(10).value = "SO Item Text";
            row1.getCell(13).value = "Customer Reference";

            // ===== Row 2: Column header =====
            const row2 = sheet.getRow(2);
            row2.getCell(6).value = "Conditon Type*";
            row2.getCell(7).value = "Amount";
            row2.getCell(8).value = "Crcy";
            row2.getCell(9).value = "Per";
            row2.getCell(10).value = "Số duyệt giá";
            row2.getCell(11).value = "Dung sai đơn hàng";
            row2.getCell(12).value = "Sales Note for Customer";

            // ===== Row 3: Hint row =====
            const row3 = sheet.getRow(3);
            row3.getCell(1).value = "Bắt buộc nhập";                                              // SO*
            row3.getCell(2).value = "Bắt buộc nhập";                                              // SO item*
            row3.getCell(3).value = "Chỉ update khi SO chưa điền plant";                          // Material
            row3.getCell(4).value = "Chỉ update khi KHSX chưa tạo BOM order";                     // Plant
            row3.getCell(5).value = "Số lượng";                                                   // Order Quantity
            row3.getCell(6).value = {
                richText: [
                    { text: "Loại đơn giá\n", font: { name: "Calibri", size: 10, italic: true, color: { argb: "FF7F6000" } } },
                    { text: "Bắt buộc nếu đổi Amount/Crcy/Per", font: { name: "Calibri", size: 10, italic: true, bold: true, color: { argb: "FFFF0000" } } }
                ]
            };                                                                                    // Condition Type*
            row3.getCell(7).value = "Đơn giá\n* Chỉ update khi chưa tạo billing";                 // Amount
            row3.getCell(8).value = "Loại tiền\n* Chỉ update khi chưa tạo billing";               // Crcy
            row3.getCell(9).value = "* Chỉ update khi chưa tạo billing";                          // Per
            row3.getCell(10).value = "";                                                          // Số duyệt giá
            row3.getCell(11).value = "";                                                          // Dung sai đơn hàng
            row3.getCell(12).value = "";                                                          // Sales Note for Customer
            row3.getCell(13).value = "Số KHSX";                                                   // Customer Reference

            // Bật wrap text cho các ô có nhiều dòng để hiển thị đúng như mẫu
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 13].forEach((col) => {
                row3.getCell(col).alignment = { wrapText: true, vertical: "top", horizontal: "left" };
            });

            // ===== Merge cells =====
            sheet.mergeCells("A1:A2"); // SO
            sheet.mergeCells("B1:B2"); // SO item
            sheet.mergeCells("C1:C2"); // Material
            sheet.mergeCells("D1:D2"); // Plant
            sheet.mergeCells("E1:E2"); // Order Quantity (row3 = hint riêng)
            sheet.mergeCells("F1:I1"); // Đơn giá
            sheet.mergeCells("J1:L1"); // SO Item Text
            sheet.mergeCells("M1:M2"); // Customer Reference (row3 = hint riêng)

            // ===== Style: 3 header rows (group + column header) =====
            [row1, row2].forEach((row) => {
                row.eachCell({ includeEmpty: true }, (cell) => {
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
            });
            row1.height = 22;
            row2.height = 22;

            // ===== Style: hint row =====
            row3.eachCell({ includeEmpty: true }, (cell) => {
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
            row3.height = 50;

            // Tô đỏ cho các ô "Bắt buộc nhập"
            [1, 2].forEach((col) => {
                row3.getCell(col).font = { name: "Calibri", size: 10, italic: true, bold: true, color: { argb: "FFFF0000" } };
            });

            sheet.views = [{ state: "frozen", ySplit: 3 }];
            sheet.autoFilter = {
                from: { row: 3, column: 1 },
                to: { row: 3, column: sheet.columns.length }
            };

            try {
                const buffer = await workbook.xlsx.writeBuffer();
                const blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "Template_Mass Change Sales Order.xlsx";
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
        // Action uploadExcel / downloadTemplate bound to Collection (ZC_M_MCH_SO_U_FILE)
        // → path: /ZC_M_MCH_SO_U_FILE/<NS>uploadExcel(...)
        _NS: "com.sap.gateway.srvd.zsd_m_mch_so_u_file.v0001.",
        _ENTITY_SET: "ZC_M_MCH_SO_U_FILE",
        _DIALOG_ID: "idFileUploadDialog",
        _FRAGMENT: "mchso.ext.fragment.filedialog",

        // ===== Lifecycle ==========================================================
        override: {
            onInit: function () {
                if (this.base && this.base.onInit) {
                    this.base.onInit();
                }
            },
            editFlow: {
                onAfterActionExecution: function (oEvent) {
                    // oEvent là string dạng: "com.sap.gateway.srvd.zsd_m_mch_so_u_file.v0001.downloadTemplate(...)"
                    if (oEvent && oEvent.split(".")[6] === "downloadTemplate") {
                        this.downloadTemplate();
                    }
                }
            },
            // routing: {
            //     onAfterBinding: function (oBindingContext) {
            //         const oTable = this._api().getTable(); // xem lưu ý bên dưới
            //         if (!oTable) return;

            //         const oBinding = oTable.getRowBinding
            //             ? oTable.getRowBinding()   // sap.ui.mdc.Table
            //             : oTable.getBinding("items"); // sap.m.Table fallback

            //         if (oBinding) {
            //             oBinding.sort(new Sorter("createddate", true));
            //         }
            //     }
            // }
            routing: {
                onAfterBinding: function (oBindingContext, mParameters) {
                    var oView = this.base.getView();
                    // Tìm sap.ui.mdc.Table trong view (List Report V4)
                    var oTable = oView.findAggregatedObjects(true, function (oCtrl) {
                        return oCtrl.isA("sap.ui.mdc.Table");
                    })[0];
                    if (!oTable) { return; }

                    var oBinding = oTable.getRowBinding(); // mdc.Table
                    if (oBinding && oBinding.sort) {
                        oBinding.sort(new Sorter("createddate", true));
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
                // MessageToast.show(this._t("uploadFileSuccMsg", "Tải lên thành công."));
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