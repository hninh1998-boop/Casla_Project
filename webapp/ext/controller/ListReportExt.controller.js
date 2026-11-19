sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/m/PDFViewer",
    "sap/m/Dialog",
    "sap/m/Toolbar",
    "sap/m/ToolbarSpacer",
    "sap/m/Select",
    "sap/m/VBox",
    "sap/m/Button",
    "sap/m/Text",
    "sap/m/Label",
    "sap/m/Input",
    "sap/ui/core/Item",
    "sap/ui/core/HTML",
    "sap/ui/core/util/File",
    "sap/base/Log"
], function (
    ControllerExtension, MessageToast, MessageBox, BusyDialog, PDFViewer, Dialog, Toolbar,
    ToolbarSpacer, Select, VBox, Button, Text, Label, Input, Item, HTML, File, Log
) {
    "use strict";

    var NAMESPACE = "com.sap.gateway.srvd.zui_co.v0001.";

    // Các trường nhập tay ở header (ZTB_CO_TEXT) sửa được bằng nút Change header
    var TEXT_FIELDS = [
        ["CONo", "NO"],
        ["Description", "Description (ô 8)"],
        ["RefNo", "REF NO. (ô 8 - EUR1)"],
        ["ArtNo", "ART NO. (ô 8 - EUR1)"]
    ];
    // HS code chỉ chọn 1 trong 2 giá trị (FS); "" = giữ nguyên, "D" = xóa
    var HTS_OPTIONS = [
        ["", "(giữ nguyên)"],
        ["420222", "420222"],
        ["420292", "420292"],
        ["D", "(xóa)"]
    ];
    // Ô 7 (FS v0.02): ô tích "ISSUED RETROSPECTIVELY"
    var RETRO_OPTIONS = [
        ["", "(giữ nguyên)"],
        ["X", "Tích - in ISSUED RETROSPECTIVELY"],
        ["D", "Bỏ tích"]
    ];

    return ControllerExtension.extend("zcoov4.ext.controller.ListReportExt", {

        _getSelectedContexts: function () {
            var oExtensionAPI = this.base.getExtensionAPI();
            return oExtensionAPI.getSelectedContexts ? oExtensionAPI.getSelectedContexts() : [];
        },

        _errorText: function (oError, sDefault) {
            return oError && oError.message ? oError.message : sDefault;
        },

        /* ================================================================
         *  CHANGE HEADER - sửa NO / HS code / Issued Retrospectively / REF NO. / ART NO. cho nhiều Pro-forma cùng lúc
         *  (sửa từng Pro-forma thì vào màn hình chi tiết → Edit / Save)
         *  Ghi bằng PATCH chuẩn của entity (behavior update), gom 1 $batch
         * ================================================================ */
        btnChangeHeader: function () {
            var that = this;
            var aContexts = this._getSelectedContexts();
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }

            if (!this._textDialog) {
                this._textInputs = {};
                var aItems = [
                    new Text({ text: "Để trống = giữ nguyên giá trị đang có, nhập D = xóa giá trị." })
                        .addStyleClass("sapUiSmallMarginBottom")
                ];

                this._htsSelect = new Select({
                    width: "100%",
                    items: HTS_OPTIONS.map(function (aOption) {
                        return new Item({ key: aOption[0], text: aOption[1] });
                    })
                });
                aItems.push(new Label({ text: "HS Code", labelFor: this._htsSelect }));
                aItems.push(this._htsSelect);

                this._retroSelect = new Select({
                    width: "100%",
                    items: RETRO_OPTIONS.map(function (aOption) {
                        return new Item({ key: aOption[0], text: aOption[1] });
                    })
                });
                aItems.push(new Label({ text: "Issued Retrospectively (ô 7)", labelFor: this._retroSelect })
                    .addStyleClass("sapUiSmallMarginTop"));
                aItems.push(this._retroSelect);

                TEXT_FIELDS.forEach(function (aField) {
                    var oInput = new Input({ width: "100%" });
                    that._textInputs[aField[0]] = oInput;
                    aItems.push(new Label({ text: aField[1], labelFor: oInput }).addStyleClass("sapUiSmallMarginTop"));
                    aItems.push(oInput);
                });

                this._textDialog = new Dialog({
                    title: "Change header",
                    contentWidth: "28rem",
                    content: [new VBox({ items: aItems }).addStyleClass("sapUiSmallMargin")],
                    beginButton: new Button({
                        text: "Save",
                        type: "Emphasized",
                        press: function () {
                            var oChanges = that._getHeaderChanges();
                            if (!Object.keys(oChanges).length) {
                                MessageToast.show("Chưa nhập giá trị nào để thay đổi.");
                                return;
                            }
                            that._textDialog.close();
                            that._saveHeaderChanges(that._textContexts, oChanges);
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
            var oRow = aContexts[0].getObject() || {};
            TEXT_FIELDS.forEach(function (aField) {
                that._textInputs[aField[0]].setValue("").setPlaceholder(oRow[aField[0]] || "");
            });
            this._htsSelect.setSelectedKey("");
            this._retroSelect.setSelectedKey("");

            this._textContexts = aContexts;
            this._textDialog.open();
        },

        // Chỉ các trường người dùng có nhập; "D" → chuỗi rỗng (xóa)
        _getHeaderChanges: function () {
            var oChanges = {};
            Object.keys(this._textInputs).forEach(function (sKey) {
                var sValue = this._textInputs[sKey].getValue().trim();
                if (sValue) {
                    oChanges[sKey] = sValue.toUpperCase() === "D" ? "" : sValue;
                }
            }, this);
            var sHts = this._htsSelect.getSelectedKey();
            if (sHts) {
                oChanges.HTSCode = sHts === "D" ? "" : sHts;
            }
            var sRetro = this._retroSelect.getSelectedKey();
            if (sRetro) {
                oChanges.IssuedRetro = sRetro === "X";
            }
            return oChanges;
        },

        _saveHeaderChanges: function (aContexts, oChanges) {
            var that = this;
            var oExtensionAPI = this.base.getExtensionAPI();
            var oModel = oExtensionAPI.getModel();
            var aFields = Object.keys(oChanges);
            var sGroupId = "ChangeHeaderGroup";
            var oBusy = new BusyDialog({ text: "Đang cập nhật " + aContexts.length + " Pro-forma..." });
            oBusy.open();

            // Mỗi Pro-forma 1 context riêng (không đụng vào binding của bảng): đọc các trường cần sửa rồi PATCH
            var aBindings = aContexts.map(function (oContext) {
                return oModel.bindContext(oContext.getPath(), null, {
                    $$updateGroupId: sGroupId,
                    $select: aFields
                });
            });

            Promise.all(aBindings.map(function (oBinding) {
                return oBinding.getBoundContext().requestObject();
            })).then(function () {
                var aPatches = [];
                aBindings.forEach(function (oBinding) {
                    var oContext = oBinding.getBoundContext();
                    aFields.forEach(function (sField) {
                        aPatches.push(oContext.setProperty(sField, oChanges[sField], sGroupId));
                    });
                });
                oModel.submitBatch(sGroupId);
                return Promise.all(aPatches);
            }).then(function () {
                oBusy.close();
                MessageToast.show("Đã cập nhật " + aContexts.length + " Pro-forma.");
                oExtensionAPI.refresh();
            }).catch(function (oError) {
                oBusy.close();
                oModel.resetChanges(sGroupId);
                Log.error("[ChangeHeader] " + that._errorText(oError, ""));
                MessageBox.error(that._errorText(oError, "Đã xảy ra lỗi khi cập nhật header."));
            }).finally(function () {
                aBindings.forEach(function (oBinding) { oBinding.destroy(); });
            });
        },

        /* ================================================================
         *  PRINT PDF / EXPORT EXCEL - gọi action PrintPDF / ExportExcel cho các Pro-forma đang chọn
         *  Gửi chung 1 $batch → backend gom thành file (form EUR1 / EUR1.UK theo Sales District)
         * ================================================================ */
        btnPrintPDF: function () {
            var that = this;
            this._callFileAction("PrintPDF", function (aFiles) {
                var aPdf = aFiles.map(function (oFile) {
                    var oConv = that._b64ToSources(oFile.FileContent, oFile.MimeType || "application/pdf");
                    return {
                        name: oFile.FileName || "CO",
                        ext: oFile.FileExtension || "pdf",
                        mimeType: oFile.MimeType || "application/pdf",
                        blob: oConv.blob,
                        url: oConv.url
                    };
                });
                MessageToast.show("Đã tạo " + aPdf.length + " file PDF.");
                that._openPdfPreview(aPdf);
            });
        },

        btnExportExcel: function () {
            var that = this;
            this._callFileAction("ExportExcel", function (aFiles) {
                aFiles.forEach(function (oFile) { that._downloadFile(oFile, "CO"); });
                MessageToast.show("Export thành công!");
            });
        },

        _callFileAction: function (sActionName, fnSuccess) {
            var that = this;
            var aContexts = this._getSelectedContexts();
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }

            var oModel = this.base.getExtensionAPI().getModel();
            var oBusy = new BusyDialog({ text: "Đang xử lý " + aContexts.length + " Pro-forma..." });
            oBusy.open();

            var sGroupId = sActionName + "Group";
            var aPromises = aContexts.map(function (oContext) {
                var oOperation = oModel.bindContext(NAMESPACE + sActionName + "(...)", oContext,
                    { $$groupId: sGroupId });
                return oOperation.execute().then(function () {
                    return oOperation.getBoundContext().getObject();
                });
            });
            oModel.submitBatch(sGroupId);

            Promise.all(aPromises).then(function (aResults) {
                oBusy.close();
                // Backend có thể trả cùng 1 file cho nhiều dòng → bỏ trùng theo tên file
                var oSeen = {};
                var aFiles = aResults.filter(function (oResult) {
                    if (!oResult || !oResult.FileContent) { return false; }
                    var sKey = (oResult.FileName || "") + "|" + oResult.FileContent.length;
                    if (oSeen[sKey]) { return false; }
                    oSeen[sKey] = true;
                    return true;
                });
                if (!aFiles.length) {
                    MessageBox.warning("Không có nội dung file nào được trả về.");
                    return;
                }
                fnSuccess(aFiles);
            }).catch(function (oError) {
                oBusy.close();
                Log.error("[" + sActionName + "] " + that._errorText(oError, ""));
                MessageBox.error(that._errorText(oError, "Đã xảy ra lỗi khi tạo file."));
            });
        },

        /* ================================================================
         *  HELPERS - base64 → Blob, tải file, xem PDF
         * ================================================================ */
        _b64ToSources: function (sBase64, sMime) {
            var s = (sBase64 || "").replace(/_/g, "/").replace(/-/g, "+");
            var iPad = s.length % 4;
            if (iPad) { s += "=".repeat(4 - iPad); }
            var sBin = atob(s);
            var aBytes = new Uint8Array(sBin.length);
            for (var i = 0; i < sBin.length; i++) { aBytes[i] = sBin.charCodeAt(i); }
            var oBlob = new Blob([aBytes], { type: sMime || "application/pdf" });
            return { blob: oBlob, url: URL.createObjectURL(oBlob) };
        },

        _downloadFile: function (oFile, sDefaultName) {
            var sMimeType = oFile.MimeType || "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            var oConv = this._b64ToSources(oFile.FileContent, sMimeType);
            var oLink = document.createElement("a");
            oLink.href = oConv.url;
            oLink.download = (oFile.FileName || sDefaultName) + "." + (oFile.FileExtension || "xlsx");
            document.body.appendChild(oLink);
            oLink.click();
            document.body.removeChild(oLink);
            setTimeout(function () { URL.revokeObjectURL(oConv.url); }, 1000);
        },

        _waitPdfLoaded: function (oViewer, iTimeoutMs) {
            return new Promise(function (resolve, reject) {
                var iTimer;
                var fnDone = function () {
                    oViewer.detachLoaded(fnLoaded);
                    oViewer.detachError(fnError);
                    if (iTimer) { clearTimeout(iTimer); }
                };
                var fnLoaded = function () { fnDone(); resolve(); };
                var fnError = function () { fnDone(); reject(new Error("viewer error")); };
                oViewer.attachLoaded(fnLoaded);
                oViewer.attachError(fnError);
                iTimer = setTimeout(function () { fnDone(); reject(new Error("viewer timeout")); }, iTimeoutMs || 900);
            });
        },

        // PDFViewer đôi khi không load được blob URL → dùng iframe thay thế
        _presentFile: function (oFile) {
            var that = this;
            var sSrc = oFile.url + "#page=1&zoom=page-fit";
            var oBusy = new BusyDialog({ text: "Loading PDF..." });
            oBusy.open();

            this._pdfViewer.setVisible(false);
            this._stack.removeAllItems();
            this._stack.addItem(this._pdfViewer);
            this._pdfViewer.setTitle(oFile.name + "." + oFile.ext);
            this._pdfViewer.setSource(sSrc);

            this._waitPdfLoaded(this._pdfViewer, 900).then(function () {
                that._pdfViewer.setVisible(true);
                oBusy.close();
            }).catch(function () {
                if (!that._html) { that._html = new HTML(); }
                that._html.setContent("<iframe style='border:0;width:100%;height:100%;' " +
                    "referrerpolicy='no-referrer' src='" + sSrc + "'></iframe>");
                that._stack.removeAllItems();
                that._stack.addItem(that._html);
                oBusy.close();
            });
        },

        _openPdfPreview: function (aFiles) {
            var that = this;

            if (!this._pdfDialog) {
                this._pdfViewer = new PDFViewer({ width: "100%", height: "100%" });
                this._pdfSelect = new Select({
                    width: "350px",
                    change: function (oEvent) {
                        var oFile = that._pdfFiles[Number(oEvent.getParameter("selectedItem").getKey())];
                        if (oFile) { that._presentFile(oFile); }
                    }
                });
                this._stack = new VBox({ width: "100%", height: "100%", renderType: "Bare", fitContainer: true })
                    .addStyleClass("pdfFill");

                this._pdfDialog = new Dialog({
                    contentWidth: "98vw",
                    contentHeight: "96vh",
                    stretch: true,
                    resizable: true,
                    draggable: true,
                    horizontalScrolling: false,
                    verticalScrolling: false,
                    customHeader: new Toolbar({
                        content: [
                            new Text({ text: "Preview PDF" }),
                            new ToolbarSpacer(),
                            new Text({ text: "Chọn file:" }),
                            this._pdfSelect,
                            new ToolbarSpacer(),
                            new Button({
                                text: "Download",
                                icon: "sap-icon://download",
                                press: function () {
                                    var oFile = that._pdfFiles[Number(that._pdfSelect.getSelectedKey())];
                                    if (oFile) {
                                        File.save(oFile.blob, oFile.name, oFile.ext, oFile.mimeType, "utf-8");
                                    }
                                }
                            }),
                            new Button({
                                text: "Close",
                                type: "Transparent",
                                press: function () { that._pdfDialog.close(); }
                            })
                        ]
                    }),
                    content: [this._stack],
                    afterClose: function () { that._cleanupPdfPreview(); }
                }).addStyleClass("pdfDialogFull");
                this.getView().addDependent(this._pdfDialog);
            }

            this._pdfFiles = aFiles;
            this._pdfSelect.destroyItems();
            aFiles.forEach(function (oFile, i) {
                that._pdfSelect.addItem(new Item({ key: String(i), text: oFile.name + "." + oFile.ext }));
            });
            this._pdfSelect.setSelectedKey("0");
            this._presentFile(aFiles[0]);
            this._pdfDialog.open();
        },

        _cleanupPdfPreview: function () {
            (this._pdfFiles || []).forEach(function (oFile) {
                try { URL.revokeObjectURL(oFile.url); } catch (e) { /* ignore */ }
            });
            this._pdfFiles = [];
        }
    });
});
