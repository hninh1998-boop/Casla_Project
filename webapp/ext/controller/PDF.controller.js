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
    'sap/ui/core/HTML',
    'sap/ui/core/util/File',
    'sap/m/MultiComboBox',
    'sap/m/Label',
    'sap/m/Input'
], function (
    ControllerExtension, MessageToast, MessageBox, BusyDialog,
    PDFViewer, Dialog, Toolbar, ToolbarSpacer, Select, VBox,
    Button, Text, Item, HTML, File, MultiComboBox, Label, Input
) {
    'use strict';

    // Dropdown của mục 10.HTS CODE và 12. trên form (FS v4) - tích được nhiều giá trị
    var HTS_CODES = ["6810990020", "6810990040", "70200060"];
    var QUARTZ_SLABS = [
        "QUARTZ SLABS",
        "QUARTZ SLABS SAMPLES",
        "QUARTZ SLABS AND QUARTZ SLABS SAMPLES",
        "CUT-TO-SIZE QUARTZ SLABS OF THE TYPE USED FOR COUNTERTOPS",
        "GLASS SLABS",
        "GLASS SAMPLES",
        "GLASS SLABS & GLASS SAMPLES"
    ];

    return ControllerExtension.extend('zciov4.ext.controller.PDF', {

        override: {
            onInit: function () {
                // this.base.getExtensionAPI() chỉ available SAU khi view đã init đầy đủ,
                // nên không cache oModel ở đây - lấy lại trong từng hàm dùng.
            }
        },

        /* ================================================================
         *  HELPERS - decode base64 -> Blob/ObjectURL, iframe fallback, load-watcher
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
        /* ================================================================
         *  POPUP "THÔNG TIN IN" - tích chọn 10.HTS CODE / 12. trước khi in
         *  Dùng chung cho Export PDF và Export Excel; giá trị gửi xuống backend qua parameter zabs_ci_param
         * ================================================================ */
        _askPrintParams: function (fnContinue) {
            var that = this;

            if (!this._paramDialog) {
                // Dropdown chọn nhiều: mỗi option có checkbox bên trong danh sách xổ xuống
                // showSelectAll: dòng "Select All" đầu danh sách để tích / bỏ tích tất cả
                var fnBox = function (aValues) {
                    return new MultiComboBox({
                        width: "100%",
                        showSelectAll: true,
                        items: aValues.map(function (sValue) {
                            return new Item({ key: sValue, text: sValue });
                        })
                    });
                };
                this._htsBox = fnBox(HTS_CODES);
                this._slabsBox = fnBox(QUARTZ_SLABS);

                this._paramDialog = new Dialog({
                    title: "Thông tin in",
                    contentWidth: "36rem",
                    content: [
                        new VBox({
                            items: [
                                new Label({ text: "10. HTS CODE", design: "Bold", labelFor: this._htsBox }),
                                this._htsBox,
                                new Label({ text: "12.", design: "Bold", labelFor: this._slabsBox })
                                    .addStyleClass("sapUiSmallMarginTop"),
                                this._slabsBox
                            ]
                        }).addStyleClass("sapUiSmallMargin")
                    ],
                    beginButton: new Button({
                        text: "OK",
                        type: "Emphasized",
                        press: function () {
                            that._paramDialog.close();
                            that._fnParamContinue(that._getPrintParams());
                        }
                    }),
                    endButton: new Button({
                        text: "Cancel",
                        press: function () { that._paramDialog.close(); }
                    })
                });
                this.getView().addDependent(this._paramDialog);
            }

            // Giữ lựa chọn lần trước để user không phải tích lại
            this._fnParamContinue = fnContinue;
            this._paramDialog.open();
        },

        // Các giá trị đang chọn → chuỗi, nhiều giá trị cách nhau bằng ", "
        _getPrintParams: function () {
            return {
                HTSCode: this._htsBox.getSelectedKeys().join(", "),
                QuartzSlabs: this._slabsBox.getSelectedKeys().join(", ")
            };
        },

        _getSelectedContexts: function () {
            var oExtensionAPI = this.base.getExtensionAPI();
            return oExtensionAPI.getSelectedContexts ? oExtensionAPI.getSelectedContexts() : [];
        },

        /* ================================================================
         *  CẬP NHẬT THÔNG TIN IN - Invoice#, MB/L, HB/L, ETA (cấp header, lưu theo Pro-forma invoice)
         *  Gọi action updCIText rồi refresh cả bảng, để mọi dòng cùng invoice hiện giá trị mới ngay
         * ================================================================ */
        btnUpdateText: function () {
            var that = this;
            var aContexts = this._getSelectedContexts();
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }

            // Mỗi Pro-forma invoice chỉ cần gọi 1 lần
            var oSeen = {};
            var aInvoiceContexts = aContexts.filter(function (oContext) {
                var sInvoice = oContext.getObject().ProFormaInvoice;
                if (oSeen[sInvoice]) { return false; }
                oSeen[sInvoice] = true;
                return true;
            });

            if (!this._textDialog) {
                var fnInput = function () { return new Input({ width: "100%" }); };
                this._textInputs = {
                    InvoiceNo: fnInput(),
                    MBL: fnInput(),
                    HBL: fnInput(),
                    ETA: fnInput()
                };
                var aItems = [
                    new Text({ text: "Để trống = giữ nguyên giá trị đang có, nhập D = xóa giá trị." })
                        .addStyleClass("sapUiSmallMarginBottom")
                ];
                [["InvoiceNo", "Invoice#"], ["MBL", "MB/L#"], ["HBL", "HB/L#"], ["ETA", "ETA"]]
                    .forEach(function (aField) {
                        aItems.push(new Label({ text: aField[1], labelFor: that._textInputs[aField[0]] }));
                        aItems.push(that._textInputs[aField[0]]);
                    });

                this._textDialog = new Dialog({
                    title: "Cập nhật thông tin in",
                    contentWidth: "28rem",
                    content: [new VBox({ items: aItems }).addStyleClass("sapUiSmallMargin")],
                    beginButton: new Button({
                        text: "Cập nhật thông tin in",
                        type: "Emphasized",
                        press: function () {
                            that._textDialog.close();
                            that._callUpdateText(that._textContexts, that._getTextParams());
                        }
                    }),
                    endButton: new Button({
                        text: "Cancel",
                        press: function () { that._textDialog.close(); }
                    })
                });
                this.getView().addDependent(this._textDialog);
            }

            // Ô để trống mỗi lần mở; placeholder hiện giá trị đang có của dòng đầu tiên
            var oRow = aInvoiceContexts[0].getObject();
            this._textInputs.InvoiceNo.setValue("").setPlaceholder(oRow.Invoice || "");
            this._textInputs.MBL.setValue("").setPlaceholder(oRow.MBL || "");
            this._textInputs.HBL.setValue("").setPlaceholder(oRow.HBL || "");
            this._textInputs.ETA.setValue("").setPlaceholder(oRow.ETA || "");

            this._textContexts = aInvoiceContexts;
            this._textDialog.open();
        },

        _getTextParams: function () {
            var oParams = {};
            Object.keys(this._textInputs).forEach(function (sKey) {
                oParams[sKey] = this._textInputs[sKey].getValue().trim();
            }, this);
            return oParams;
        },

        _callUpdateText: function (aContexts, oParams) {
            var oExtensionAPI = this.base.getExtensionAPI();
            var oModel = oExtensionAPI.getModel();
            var oBusy = new BusyDialog({ text: "Đang cập nhật..." });
            oBusy.open();

            var sGroupId = "UpdateTextBatchGroup";
            var aPromises = aContexts.map(function (oContext) {
                var oOperation = oModel.bindContext(
                    "com.sap.gateway.srvd.zui_ci.v0001.updCIText(...)",
                    oContext,
                    { $$groupId: sGroupId }
                );
                Object.keys(oParams).forEach(function (sKey) {
                    oOperation.setParameter(sKey, oParams[sKey]);
                });
                return oOperation.execute();
            });

            oModel.submitBatch(sGroupId);

            Promise.all(aPromises).then(function () {
                oBusy.close();
                MessageToast.show("Cập nhật thông tin in thành công");
                // Đọc lại cả bảng để mọi dòng cùng Pro-forma invoice hiện giá trị mới (không phải bấm Go)
                oExtensionAPI.refresh();
            }).catch(function (oError) {
                oBusy.close();
                console.error("[updCIText]", oError);
                MessageBox.error(oError && oError.message ? oError.message : "Đã xảy ra lỗi khi cập nhật thông tin in.");
            });
        },

        /* ================================================================
         *  MAIN ACTIONS - btnPrintPDF (Commercial Invoice) / btnPrintPackingList (Packing List)
         * ================================================================ */
        btnPrintPDF: function () {
            var aContexts = this._getSelectedContexts();
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }
            var that = this;
            this._askPrintParams(function (oParams) {
                that._callPrintPdfAction(aContexts, "btnPrintPDF", "Commercial_Invoice_", oParams);
            });
        },

        btnPrintPackingList: function () {
            var aContexts = this._getSelectedContexts();
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }
            var that = this;
            this._askPrintParams(function (oParams) {
                that._callPrintPdfAction(aContexts, "PDFPackingList", "Packing_List_", oParams);
            });
        },

        /* ================================================================
         *  EXPORT EXCEL - menu Export > Commercial Invoice / Packing List
         *  File xlsx sinh hoàn toàn ở backend (zcl_ce_ci_xlsx), FE chỉ nhận base64 rồi tải về
         * ================================================================ */
        btnExportExcelCI: function () {
            this._exportExcel("ExportExcelCI", "Commercial_Invoice");
        },

        btnExportExcelPL: function () {
            this._exportExcel("ExportExcelPL", "Packing_List");
        },

        _exportExcel: function (sActionName, sDefaultName) {
            var that = this;
            var aContexts = this._getSelectedContexts();
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }

            this._askPrintParams(function (oParams) {
                that._runExportExcel(aContexts, sActionName, sDefaultName, oParams);
            });
        },

        _runExportExcel: function (aContexts, sActionName, sDefaultName, oParams) {
            var that = this;
            var oModel = this.base.getExtensionAPI().getModel();
            var oBusy = new BusyDialog({ text: "Đang export " + aContexts.length + " dòng..." });
            oBusy.open();

            // Gửi tất cả dòng đã chọn trong 1 $batch → backend gom thành 1 file
            var sGroupId = "ExportExcelBatchGroup";
            var aPromises = aContexts.map(function (oContext) {
                var oOperation = oModel.bindContext(
                    "com.sap.gateway.srvd.zui_ci.v0001." + sActionName + "(...)",
                    oContext,
                    { $$groupId: sGroupId }
                );
                oOperation.setParameter("HTSCode", oParams.HTSCode);
                oOperation.setParameter("QuartzSlabs", oParams.QuartzSlabs);
                return oOperation.execute().then(function () {
                    return oOperation.getBoundContext().getObject();
                });
            });

            oModel.submitBatch(sGroupId);

            Promise.all(aPromises).then(function (aResults) {
                oBusy.close();

                // Backend trả cùng 1 file cho mọi dòng, nội dung chỉ nằm ở 1 dòng
                var oFile = aResults.filter(function (oResult) {
                    return oResult && oResult.FileContent;
                })[0];

                if (!oFile) {
                    MessageBox.warning("Không có dữ liệu để export (chỉ export item có item category TAN).");
                    return;
                }

                that._downloadFile(oFile, sDefaultName);
                MessageToast.show("Export thành công!");
            }).catch(function (oError) {
                oBusy.close();
                console.error("[" + sActionName + "]", oError);
                MessageBox.error(oError && oError.message ? oError.message : "Đã xảy ra lỗi khi export Excel.");
            });
        },

        _downloadFile: function (oFile, sDefaultName) {
            var sMimeType = oFile.MimeType || "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            var conv = this._b64ToSources(oFile.FileContent, sMimeType);
            var oLink = document.createElement("a");
            oLink.href = conv.url;
            oLink.download = (oFile.FileName || sDefaultName) + "." + (oFile.FileExtension || "xlsx");
            document.body.appendChild(oLink);
            oLink.click();
            document.body.removeChild(oLink);
            setTimeout(function () { URL.revokeObjectURL(conv.url); }, 1000);
        },

        /* ================================================================
         *  GỌI ACTION - OData V4 (Dùng $batch gửi full dữ liệu & lọc trùng file ở Frontend)
         * ================================================================ */
        _callPrintPdfAction: function (aContexts, sActionName, sDefaultPrefix, oParams) {
            var that = this;
            var oModel = this.base.getExtensionAPI().getModel();

            var oBusy = new BusyDialog({ text: "Đang xử lý " + aContexts.length + " dòng..." });
            oBusy.open();

            var sGroupId = "PrintPdfBatchGroup";
            var aPromises = [];

            aContexts.forEach(function (oContext) {
                var oOperation = oModel.bindContext(
                    "com.sap.gateway.srvd.zui_ci.v0001." + sActionName + "(...)",
                    oContext,
                    { $$groupId: sGroupId }
                );
                oOperation.setParameter("HTSCode", oParams.HTSCode);
                oOperation.setParameter("QuartzSlabs", oParams.QuartzSlabs);

                var pExecute = oOperation.execute().then(function () {
                    var oResult = oOperation.getBoundContext().getObject();
                    return {
                        proFormaInvoice: oContext.getObject().ProFormaInvoice,
                        result: oResult
                    };
                });

                aPromises.push(pExecute);
            });

            oModel.submitBatch(sGroupId);

            Promise.all(aPromises).then(function (aResults) {
                oBusy.close();

                var aPdfFiles = [];
                var oSeen = {};

                aResults.forEach(function (oItem) {
                    var sKey = oItem.proFormaInvoice;
                    var oResult = oItem.result;

                    if (oResult && oResult.FileContent && !oSeen[sKey]) {
                        oSeen[sKey] = true;

                        var conv = that._b64ToSources(oResult.FileContent, oResult.MimeType || "application/pdf");

                        aPdfFiles.push({
                            name: oResult.FileName || (sDefaultPrefix + sKey),
                            ext: oResult.FileExtension || "pdf",
                            mimeType: oResult.MimeType || "application/pdf",
                            blob: conv.blob,
                            url: conv.url
                        });
                    }
                });

                if (aPdfFiles.length > 0) {
                    MessageToast.show("Đã tạo thành công " + aPdfFiles.length + " file PDF.");
                    that._openPdfPreview(aPdfFiles);
                } else {
                    MessageBox.warning("Không có nội dung file nào được trả về.");
                }
            }).catch(function (oError) {
                oBusy.close();
                console.error("[btnPrintPDF]", oError);
                MessageBox.error(oError && oError.message ? oError.message : "Đã xảy ra lỗi khi tạo PDF.");
            });
        },

        /* ================================================================
         *  PDF PREVIEW DIALOG
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
                            File.save(
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
