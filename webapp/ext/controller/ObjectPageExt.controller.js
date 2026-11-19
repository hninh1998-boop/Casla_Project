sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/m/Dialog",
    "sap/m/VBox",
    "sap/m/Button",
    "sap/m/Text",
    "sap/m/Label",
    "sap/m/Input",
    "sap/m/Select",
    "sap/m/CheckBox",
    "sap/ui/core/Item",
    "sap/base/Log"
], function (
    ControllerExtension, MessageToast, MessageBox, BusyDialog, Dialog, VBox, Button, Text, Label, Input, Select,
    CheckBox, Item, Log
) {
    "use strict";

    // Fiori Elements V4 chỉ tự hiện Edit / Save khi entity có draft hoặc sticky session.
    // Custom entity CO không có draft → sửa bằng popup, ghi bằng PATCH chuẩn (behavior update) trong 1 $batch.
    var HEADER_FIELDS = [
        ["CONo", "NO"],
        ["Description", "Description (ô 8 - xóa trắng = lấy lại tên theo PH_SALES)"],
        ["RefNo", "REF NO. (ô 8 - EUR1)"],
        ["ArtNo", "ART NO. (ô 8 - EUR1)"]
    ];
    var HTS_OPTIONS = [["", "(trống)"], ["420222", "420222"], ["420292", "420292"]];
    // Trường nào in trên form nào (giống Change header ở màn hình ngoài); không khai báo = mọi form
    var FIELD_FORMS = {
        IssuedRetro: ["EUR1", "EUR1.UK"],
        RefNo: ["EUR1"],
        ArtNo: ["EUR1"]
    };
    var ITEM_FIELDS = [
        ["Quantity", "Quantity (PCS)"],
        ["CTNS", "CTNS"],
        ["GrossWeight", "Gross Weight (KGS)"]
    ];
    var GROUP_ID = "COEditGroup";

    return ControllerExtension.extend("zcoov4.ext.controller.ObjectPageExt", {

        _errorText: function (oError, sDefault) {
            return oError && oError.message ? oError.message : sDefault;
        },

        _createDialog: function (sTitle, aItems, fnSave) {
            var that = this;
            var oDialog = new Dialog({
                title: sTitle,
                contentWidth: "28rem",
                content: [new VBox({ items: aItems }).addStyleClass("sapUiSmallMargin")],
                beginButton: new Button({ text: "Save", type: "Emphasized", press: fnSave }),
                endButton: new Button({ text: "Cancel", press: function () { oDialog.close(); } })
            });
            that.getView().addDependent(oDialog);
            return oDialog;
        },

        // Ghi các thay đổi [{ context, field, value }] trong 1 $batch rồi đọc lại trang
        _patch: function (aChanges) {
            var oExtensionAPI = this.base.getExtensionAPI();
            var oModel = oExtensionAPI.getModel();
            var that = this;
            if (!aChanges.length) {
                MessageToast.show("Không có giá trị nào thay đổi.");
                return Promise.resolve();
            }
            var oBusy = new BusyDialog({ text: "Đang lưu..." });
            oBusy.open();

            var aPromises = aChanges.map(function (oChange) {
                return oChange.context.setProperty(oChange.field, oChange.value, GROUP_ID);
            });
            oModel.submitBatch(GROUP_ID);

            return Promise.all(aPromises).then(function () {
                oBusy.close();
                MessageToast.show("Đã lưu.");
                // Đọc lại để cột Source / số lấy từ biên bản cập nhật theo backend
                return oExtensionAPI.refresh();
            }).catch(function (oError) {
                oBusy.close();
                oModel.resetChanges(GROUP_ID);
                Log.error("[CO Edit] " + that._errorText(oError, ""));
                MessageBox.error(that._errorText(oError, "Đã xảy ra lỗi khi lưu."));
            });
        },

        /* ================================================================
         *  HEADER - NO / HS code / Issued Retrospectively / REF NO. / ART NO. (ZTB_CO_TEXT)
         * ================================================================ */
        btnEditHeader: function () {
            var that = this;
            var oContext = this.base.getExtensionAPI().getBindingContext();
            if (!oContext) { return; }

            if (!this._headerDialog) {
                this._headerInputs = {};
                this._fieldControls = {};   // trường → các control để ẩn / hiện theo form
                var aItems = [];
                this._htsSelect = new Select({
                    width: "100%",
                    items: HTS_OPTIONS.map(function (aOption) {
                        return new Item({ key: aOption[0], text: aOption[1] });
                    })
                });
                aItems.push(new Label({ text: "HS Code", labelFor: this._htsSelect }), this._htsSelect);
                // Ô 7 (FS v0.02): tích = in "ISSUED RETROSPECTIVELY" (chỉ EUR1 / UK)
                this._retroCheck = new CheckBox({ text: "ISSUED RETROSPECTIVELY (ô 7)" })
                    .addStyleClass("sapUiSmallMarginTop");
                this._fieldControls.IssuedRetro = [this._retroCheck];
                aItems.push(this._retroCheck);
                HEADER_FIELDS.forEach(function (aField) {
                    var oInput = new Input({ width: "100%" });
                    var oLabel = new Label({ text: aField[1], labelFor: oInput }).addStyleClass("sapUiSmallMarginTop");
                    that._headerInputs[aField[0]] = oInput;
                    that._fieldControls[aField[0]] = [oLabel, oInput];
                    aItems.push(oLabel, oInput);
                });
                this._headerDialog = this._createDialog("Edit CO Information", aItems, function () {
                    that._headerDialog.close();
                    that._saveHeader();
                });
            }

            var oData = oContext.getObject() || {};
            HEADER_FIELDS.forEach(function (aField) {
                that._headerInputs[aField[0]].setValue(oData[aField[0]] || "");
            });
            this._htsSelect.setSelectedKey(oData.HTSCode || "");
            this._retroCheck.setSelected(!!oData.IssuedRetro);
            // Chỉ hiện trường in trên form của Pro-forma này (UK / EAV: ẩn REF NO., ART NO.; EAV: ẩn ô 7)
            Object.keys(this._fieldControls).forEach(function (sField) {
                var aForms = FIELD_FORMS[sField];
                var bVisible = !aForms || !oData.FormType || aForms.indexOf(oData.FormType) >= 0;
                that._fieldControls[sField].forEach(function (oControl) { oControl.setVisible(bVisible); });
            });
            this._headerDialog.open();
        },

        _saveHeader: function () {
            var oContext = this.base.getExtensionAPI().getBindingContext();
            var oData = oContext.getObject() || {};
            var aChanges = [];
            var fnAdd = function (sField, sValue) {
                if (sValue !== (oData[sField] || "")) {
                    aChanges.push({ context: oContext, field: sField, value: sValue });
                }
            };
            HEADER_FIELDS.forEach(function (aField) {
                fnAdd(aField[0], this._headerInputs[aField[0]].getValue().trim());
            }, this);
            fnAdd("HTSCode", this._htsSelect.getSelectedKey());
            var bRetro = this._retroCheck.getSelected();
            if (bRetro !== !!oData.IssuedRetro) {
                aChanges.push({ context: oContext, field: "IssuedRetro", value: bRetro });
            }
            this._patch(aChanges);
        },

        /* ================================================================
         *  ITEM - Quantity / CTNS / Gross weight (ZTB_CO_ITEM)
         *  Để trống = giữ nguyên; nhập 0 = bỏ số nhập tay, lấy lại theo Biên bản đóng Container
         * ================================================================ */
        btnEditItems: function (oContextOrEvent, aSelectedContexts) {
            var that = this;
            var aContexts = aSelectedContexts || [];
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng item.");
                return;
            }

            if (!this._itemDialog) {
                this._itemInputs = {};
                this._itemHint = new Text().addStyleClass("sapUiSmallMarginBottom");
                var aItems = [this._itemHint];
                ITEM_FIELDS.forEach(function (aField) {
                    var oInput = new Input({ width: "100%", type: "Number" });
                    that._itemInputs[aField[0]] = oInput;
                    aItems.push(new Label({ text: aField[1], labelFor: oInput }).addStyleClass("sapUiSmallMarginTop"),
                        oInput);
                });
                this._itemDialog = this._createDialog("Edit Items", aItems, function () {
                    that._saveItems();
                });
            }

            // 1 dòng: hiện sẵn giá trị đang có; nhiều dòng: để trống (chỉ ghi ô có nhập)
            var bSingle = aContexts.length === 1;
            var oData = bSingle ? (aContexts[0].getObject() || {}) : {};
            this._itemHint.setText((bSingle ? "Item " + oData.BillingItem + ". " : aContexts.length + " dòng item. ") +
                "Để trống = giữ nguyên, nhập 0 = lấy lại số theo Biên bản đóng Container.");
            ITEM_FIELDS.forEach(function (aField) {
                var vValue = bSingle ? oData[aField[0]] : "";
                that._itemInputs[aField[0]].setValue(vValue === null || vValue === undefined ? "" : String(Number(vValue)))
                    .setValueState("None");
            });
            this._itemContexts = aContexts;
            this._itemDialog.open();
        },

        _saveItems: function () {
            var that = this;
            var oValues = {};
            var bValid = true;
            ITEM_FIELDS.forEach(function (aField) {
                var oInput = that._itemInputs[aField[0]];
                var sValue = oInput.getValue().trim();
                if (sValue === "") { return; }
                var fValue = Number(sValue);
                if (isNaN(fValue) || fValue < 0) {
                    oInput.setValueState("Error").setValueStateText("Nhập số không âm");
                    bValid = false;
                    return;
                }
                oInput.setValueState("None");
                oValues[aField[0]] = String(fValue);
            });
            if (!bValid) { return; }
            this._itemDialog.close();

            var aChanges = [];
            this._itemContexts.forEach(function (oContext) {
                var oData = oContext.getObject() || {};
                Object.keys(oValues).forEach(function (sField) {
                    if (Number(oData[sField]) !== Number(oValues[sField])) {
                        aChanges.push({ context: oContext, field: sField, value: oValues[sField] });
                    }
                });
            });
            this._patch(aChanges);
        }
    });
});
