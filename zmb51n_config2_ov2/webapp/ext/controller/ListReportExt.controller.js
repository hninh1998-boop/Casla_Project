sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/ui/core/Fragment",
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/ui/core/BusyIndicator",
    "sap/ui/export/Spreadsheet"
], function (ControllerExtension, Fragment, MessageToast, MessageBox, BusyIndicator, Spreadsheet) {
    "use strict";

    return ControllerExtension.extend("zmb51nconfig2ov2.ext.controller.ListReportExt", {

        override: {
            onInit: function () {
                var oView = this.base.getView(),
                    oUploadButton = oView.byId("idUploadExcelButton"),
                    oDownloadButton = oView.byId("idDownloadTemplateButton");

                // Gắn sự kiện press trực tiếp bằng JS: thuộc tính "press" khai báo trong
                // manifest.json (breakout action) không được XML preprocessor của
                // sap.suite.ui.generic.template resolve thành event handler một cách tin cậy.
                if (oUploadButton) {
                    oUploadButton.attachPress(this.onUploadExcelPress, this);
                }
                if (oDownloadButton) {
                    oDownloadButton.attachPress(this.onDownloadTemplatePress, this);
                }
            }
        },

        onDownloadTemplatePress: function () {
            // eslint-disable-next-line no-console
            console.log("[ZMB51N] onDownloadTemplatePress fired");
            try {
                // Cột khớp với field/label trong annotation.xml của ZC_ZMB51_loai
                var aColumns = [
                    { label: "Nhom", property: "Nhom", type: "string" },
                    { label: "ClassType", property: "ClassType", type: "string" },
                    { label: "TargetField", property: "TargetField", type: "string" },
                    { label: "Item", property: "Item", type: "string" },
                    { label: "SubGroup", property: "SubGroup", type: "string" },
                    { label: "CharName", property: "CharName", type: "string" }
                ];
                var oSettings = {
                    workbook: { columns: aColumns },
                    dataSource: [{}],
                    fileName: "ZMB51N_Charc_Template.xlsx",
                    showProgress: false
                };
                var oSpreadsheet = new Spreadsheet(oSettings);
                oSpreadsheet.build().then(function () {
                    MessageToast.show("Tải template thành công");
                }).catch(function (oError) {
                    // eslint-disable-next-line no-console
                    console.error("[ZMB51N] Spreadsheet build failed", oError);
                    MessageBox.error("Tải template thất bại: " + oError);
                }).finally(function () {
                    oSpreadsheet.destroy();
                });
            } catch (oError) {
                // eslint-disable-next-line no-console
                console.error("[ZMB51N] onDownloadTemplatePress threw synchronously", oError);
                MessageBox.error("Không thể tạo file template: " + oError.message);
            }
        },

        onUploadExcelPress: function () {
            var oView = this.base.getView();

            if (!this._oUploadDialogPromise) {
                this._oUploadDialogPromise = Fragment.load({
                    id: oView.getId(),
                    name: "zmb51nconfig2ov2.ext.fragment.UploadExcelDialog",
                    controller: this
                }).then(function (oDialog) {
                    oView.addDependent(oDialog);
                    return oDialog;
                });
            }

            this._resetUploadState();
            this._oUploadDialogPromise.then(function (oDialog) {
                oDialog.open();
            });
        },

        onFileChange: function (oEvent) {
            var oFile = oEvent.getParameter("files") && oEvent.getParameter("files")[0],
                that = this;

            this._sFileContent = "";
            if (!oFile) {
                return;
            }

            this._sFileName = oFile.name;
            this._sMimeType = oFile.type;

            var oReader = new FileReader();
            oReader.onload = function (oLoadEvent) {
                // kết quả dạng "data:<mimeType>;base64,<nội dung>" -> chỉ giữ phần base64
                that._sFileContent = oLoadEvent.target.result.split(",")[1];
            };
            oReader.readAsDataURL(oFile);
        },

        onUploadExcelSubmit: function () {
            var oView = this.base.getView(),
                oModel = oView.getModel(),
                that = this;

            if (!this._sFileContent) {
                MessageBox.error("Vui lòng chọn file Excel trước khi tải lên.");
                return;
            }

            // TODO: xác nhận lại tên FunctionImport và tên tham số sau khi service được publish lại
            // từ static action UploadExcel(zabs_zmb51_loai) trong BDEF ZI_ZMB51N_LOAI.
            var sFunctionImportName = "UploadExcel";
            if (!oModel.getMetaModel().getODataFunctionImport(sFunctionImportName)) {
                // callFunction() chỉ log lỗi ra console khi FunctionImport không tồn tại trong
                // metadata - nó không gọi success/error callback, nên nếu không chặn ở đây trước
                // thì BusyIndicator sẽ quay mãi không dừng. Kiểm tra trước để báo lỗi rõ ràng.
                MessageBox.error(
                    "Không tìm thấy FunctionImport '" + sFunctionImportName + "' trong metadata của service. " +
                    "Vui lòng kiểm tra lại tên action đã publish ở backend (BDEF ZI_ZMB51N_LOAI)."
                );
                return;
            }

            BusyIndicator.show(0);
            var mParams = {
                MimeType: that._sMimeType,
                FileName: that._sFileName,
                FileContent: that._sFileContent
            };
            // eslint-disable-next-line no-console
            console.log("[ZMB51N] calling /" + sFunctionImportName + " with", mParams);
            oModel.callFunction("/" + sFunctionImportName, {
                method: "POST",
                urlParameters: mParams,
                success: function () {
                    BusyIndicator.hide();
                    MessageToast.show("Tải dữ liệu lên thành công");
                    that.onUploadDialogClose();
                    try {
                        // refresh(true): ép model bỏ qua cache nội bộ, refetch mọi binding.
                        // rebindTable(): ép SmartTable tạo lại binding + hiện data mới.
                        oModel.refresh(true);
                        that.base.extensionAPI.rebindTable();
                        // eslint-disable-next-line no-console
                        console.log("[ZMB51N] refresh(true) + rebindTable() called after upload success");
                    } catch (oRefreshError) {
                        // eslint-disable-next-line no-console
                        console.error("[ZMB51N] failed to refresh table after upload", oRefreshError);
                    }
                },
                error: function (oError) {
                    BusyIndicator.hide();
                    // eslint-disable-next-line no-console
                    console.error("[ZMB51N] /UploadExcel call failed", oError);
                    MessageBox.error("Tải dữ liệu lên thất bại: " + (oError && oError.responseText ? oError.responseText : "Vui lòng kiểm tra file và thử lại."));
                }
            });
        },

        onUploadDialogClose: function () {
            this._resetUploadState();
            this._oUploadDialogPromise.then(function (oDialog) {
                oDialog.close();
            });
        },

        _resetUploadState: function () {
            var oFileUploader = this.base.getView().byId("idExcelFileUploader");
            if (oFileUploader) {
                oFileUploader.clear();
            }
            this._sFileContent = "";
            this._sFileName = "";
            this._sMimeType = "";
        }
    });
});
