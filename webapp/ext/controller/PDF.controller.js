sap.ui.define([
    'sap/ui/core/mvc/ControllerExtension',
    'sap/m/MessageToast',
    'sap/m/MessageBox',
    'sap/m/BusyDialog',
    'sap/m/PDFViewer',
    'sap/m/Dialog',
    'sap/m/Toolbar',
    'sap/m/ToolbarSpacer',
    'sap/m/Select',
    'sap/m/VBox',
    'sap/m/Button',
    'sap/m/Text',
    'sap/ui/core/Item',
    'sap/ui/core/HTML'
], function (
    ControllerExtension, MessageToast, MessageBox, BusyDialog,
    PDFViewer, Dialog, Toolbar, ToolbarSpacer, Select, VBox,
    Button, Text, Item, HTML
) {
    'use strict';

    return ControllerExtension.extend('empxnsl.ext.controller.PDF', {

        override: {
            onInit: function () {
                // this.base.getExtensionAPI() chỉ available SAU khi view đã init đầy đủ,
                // nên không cache oModel ở đây - lấy lại trong từng hàm dùng.
            }
        },

        /* ================================================================
         *  HELPERS - giữ nguyên 100% từ mẫu V2, không đổi logic
         * ================================================================ */

        _b64ToSources: function (b64, mime) {
            var s = (b64 || "").replace(/_/g, "/").replace(/-/g, "+");
            var pad = s.length % 4;
            if (pad) { s += "=".repeat(4 - pad); }
            var bin = atob(s);
            var u8 = new Uint8Array(bin.length);
            for (var i = 0; i < bin.length; i++) { u8[i] = bin.charCodeAt(i); }
            var type = mime || "application/pdf";
            var blob = new Blob([u8], { type: type });
            return {
                blob: blob,
                url: URL.createObjectURL(blob)
            };
        },

        _buildPdfIframeHtml: function (src) {
            var fit = "#page=1&zoom=page-fit";
            return "<iframe style='border:0;width:100%;height:100%;' " +
                "referrerpolicy='no-referrer' loading='eager' " +
                "src='" + src + fit + "'></iframe>";
        },

        _waitPdfLoaded: function (viewer, timeoutMs) {
            return new Promise(function (resolve, reject) {
                var tm;
                var done = function () {
                    viewer.detachLoaded(onLoaded);
                    viewer.detachError(onError);
                    if (tm) { clearTimeout(tm); }
                };
                var onLoaded = function () { done(); resolve(); };
                var onError = function () { done(); reject(new Error("viewer error")); };
                viewer.attachLoaded(onLoaded);
                viewer.attachError(onError);
                tm = setTimeout(function () { done(); reject(new Error("viewer timeout")); }, timeoutMs || 900);
            });
        },

        /* ================================================================
         *  LẤY SELECTED CONTEXTS - Fiori Elements V4
         * ================================================================ */
        _getSelectedContexts: function () {
            var oExtensionAPI = this.base.getExtensionAPI();
            return oExtensionAPI.getSelectedContexts ? oExtensionAPI.getSelectedContexts() : [];
        },

        /* ================================================================
         *  MAIN ACTION - btnPrintPDF (không cần dialog nhập tham số)
         * ================================================================ */
        btnPrintPDF: function () {
            var aContexts = this._getSelectedContexts();
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }

            this._callPrintPdfAction(aContexts);
        },

        /* ================================================================
         *  GỌI ACTION - OData V4 (Dùng $batch gửi full dữ liệu & Lọc trùng file ở Frontend)
         * ================================================================ */
        _callPrintPdfAction: function (aContexts) {
            var that = this;
            var oModel = this.base.getExtensionAPI().getModel();

            var oBusy = new BusyDialog({ text: "Đang xử lý " + aContexts.length + " dòng..." });
            oBusy.open();

            // 1. Định nghĩa tên Batch Group để gom tất cả các dòng vào chung 1 Request HTTP
            var sGroupId = "PrintPdfBatchGroup";
            var aPromises = [];

            // 2. Duyệt qua từng dòng đã chọn để gán vào nhóm Batch
            aContexts.forEach(function (oContext) {
                var oOperation = oModel.bindContext("com.sap.gateway.srvd.zui_employee_o4.v0001.btnPrintPDF(...)", oContext, {
                    $$groupId: sGroupId
                });

                var pExecute = oOperation.execute().then(function () {
                    var oResult = oOperation.getBoundContext().getObject();
                    return {
                        employeeCode: oContext.getObject().EmployeeCode,
                        result: oResult
                    };
                });

                aPromises.push(pExecute);
            });

            // 3. Kích hoạt bắn duy nhất 1 request $batch lên RAP Backend
            oModel.submitBatch(sGroupId);

            // 4. Chờ toàn bộ các dòng trong batch được Backend xử lý xong và trả về kết quả
            Promise.all(aPromises).then(function (aResults) {
                oBusy.close();

                var aPdfFiles = [];
                var oSeenEmployees = {};

                // 5. Duyệt kết quả trả về để LỌC TRÙNG THEO EMPLOYEE CODE
                aResults.forEach(function (oItem) {
                    var sEmployeeCode = oItem.employeeCode;
                    var oResult = oItem.result;

                    if (oResult && oResult.fileContent && !oSeenEmployees[sEmployeeCode]) {

                        oSeenEmployees[sEmployeeCode] = true;

                        var conv = that._b64ToSources(oResult.fileContent, oResult.mimeType || "application/pdf");

                        aPdfFiles.push({
                            name: oResult.fileName || ("EMP_" + sEmployeeCode),
                            ext: oResult.fileExtension || "pdf",
                            mimeType: oResult.mimeType || "application/pdf",
                            blob: conv.blob,
                            url: conv.url
                        });
                    }
                });

                // 6. Mở Dialog hiển thị danh sách PDF
                if (aPdfFiles.length > 0) {
                    MessageToast.show("Đã tạo thành công " + aPdfFiles.length + " file PDF.");
                    that._openPdfPreview(aPdfFiles);
                } else {
                    MessageBox.warning("Không có nội dung file nào được trả về.");
                }

            }).catch(function (oError) {
                oBusy.close();
                console.error("[btnPrintPDF Batch Multi]", oError);
                MessageBox.error(oError && oError.message ? oError.message : "Đã xảy ra lỗi khi tạo PDF.");
            });
        },

        /* ================================================================
         *  PDF PREVIEW DIALOG - giữ nguyên 100% từ mẫu V2
         * ================================================================ */
        _presentFile: function (file) {
            var that = this;
            var src = (file.url || file.data) + "#page=1&zoom=page-fit";

            this._pdfViewer.setVisible(false);
            var busy = new BusyDialog({ text: "Loading PDF..." });
            busy.open();

            this._usingHtml = false;
            this._stack.removeAllItems();
            this._stack.addItem(this._pdfViewer);
            this._pdfViewer.setTitle(file.name + (file.ext ? "." + file.ext : ""));
            this._pdfViewer.setSource(src);

            this._waitPdfLoaded(this._pdfViewer, 900)
                .then(function () {
                    that._pdfViewer.setVisible(true);
                    busy.close();
                })
                .catch(function () {
                    if (!that._html) { that._html = new HTML(); }
                    that._html.setContent(that._buildPdfIframeHtml(src));
                    that._stack.removeAllItems();
                    that._stack.addItem(that._html);
                    that._usingHtml = true;
                    busy.close();
                });
        },

        _openPdfPreview: function (files) {
            var that = this;

            if (!this._pdfDialog) {
                this._pdfViewer = new PDFViewer({ width: "100%", height: "100%" });

                this._pdfSelect = new Select({
                    width: "350px",
                    change: function (oEvent) {
                        var idx = Number(oEvent.getParameter("selectedItem").getKey());
                        var f = that._pdfFiles[idx];
                        if (f) { that._presentFile(f); }
                    }
                });

                var btnDownload = new Button({
                    text: "Download",
                    icon: "sap-icon://download",
                    press: function () {
                        var idx = Number(that._pdfSelect.getSelectedKey());
                        var f = that._pdfFiles[idx];
                        if (f) {
                            sap.ui.core.util.File.save(
                                f.blob, f.name, f.ext || "pdf",
                                f.mimeType || "application/pdf", "utf-8"
                            );
                        }
                    }
                });

                var btnClose = new Button({
                    text: "Close",
                    type: "Transparent",
                    press: function () { that._pdfDialog.close(); }
                });

                var header = new Toolbar({
                    content: [
                        new Text({ text: "Preview PDFs" }),
                        new ToolbarSpacer(),
                        new Text({ text: "Chọn file:" }),
                        this._pdfSelect,
                        new ToolbarSpacer(),
                        btnDownload,
                        btnClose
                    ]
                });

                this._stack = new VBox({
                    width: "100%",
                    height: "100%",
                    renderType: "Bare",
                    fitContainer: true
                }).addStyleClass("pdfFill");
                this._stack.addItem(this._pdfViewer);

                this._pdfDialog = new Dialog({
                    contentWidth: "98vw",
                    contentHeight: "96vh",
                    stretch: true,
                    resizable: true,
                    draggable: true,
                    horizontalScrolling: false,
                    verticalScrolling: false,
                    customHeader: header,
                    content: [this._stack],
                    afterOpen: function () {
                        that._stack.setWidth("100%");
                        that._stack.setHeight("100%");
                        that._pdfViewer.setWidth("100%");
                        that._pdfViewer.setHeight("100%");
                    },
                    afterClose: function () {
                        that._cleanupPdfPreview();
                    }
                }).addStyleClass("pdfDialogFull");
            }

            this._usingHtml = false;
            this._pdfFiles = files;

            this._pdfSelect.destroyItems();
            files.forEach(function (f, i) {
                that._pdfSelect.addItem(new Item({
                    key: String(i),
                    text: f.name + (f.ext ? "." + f.ext : "")
                }));
            });

            this._pdfSelect.setSelectedKey("0");
            this._presentFile(files[0]);
            this._pdfDialog.open();
        },

        _cleanupPdfPreview: function () {
            if (this._pdfFiles && this._pdfFiles.length) {
                this._pdfFiles.forEach(function (f) {
                    try {
                        if (f.url) { URL.revokeObjectURL(f.url); }
                    } catch (e) { /* ignore */ }
                });
            }
            this._pdfFiles = [];
        }
    });
});
