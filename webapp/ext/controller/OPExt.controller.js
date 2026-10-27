sap.ui.define([
    'sap/ui/core/mvc/ControllerExtension',
    'sap/m/MessageToast',
    'sap/m/MessageBox',
    'sap/m/BusyDialog',
    'sap/m/Dialog',
    'sap/m/Button',
    'sap/m/Label',
    'sap/m/Input',
    'sap/m/Text',
    'sap/m/VBox'
], function (
    ControllerExtension, MessageToast, MessageBox, BusyDialog,
    Dialog, Button, Label, Input, Text, VBox
) {
    'use strict';

    return ControllerExtension.extend('zciov4.ext.controller.OPExt', {

        /* ================================================================
         *  EDIT N.W / G.W - nút Edit trên bảng Items (màn hình chi tiết)
         *  Chỉ dòng ProductGroup khác 320001 được sửa; dòng 320001 tự tính (WeightAuto = true)
         * ================================================================ */
        btnEditWeight: function (oBindingContext, aSelectedContexts) {
            var that = this;
            var aContexts = aSelectedContexts || [];
            if (!aContexts.length) {
                MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
                return;
            }

            // WeightAuto là cột ẩn nên bảng không tải sẵn → phải đọc thêm từ backend rồi mới phân loại
            Promise.all(aContexts.map(function (oContext) {
                return oContext.requestProperty("WeightAuto");
            })).then(function (aAuto) {
                var aEditable = aContexts.filter(function (oContext, i) { return !aAuto[i]; });
                var aLocked = aContexts.filter(function (oContext, i) { return !!aAuto[i]; });
                that._checkAndEdit(aContexts, aEditable, aLocked);
            }).catch(function (oError) {
                MessageBox.error(oError && oError.message ? oError.message : "Không đọc được thông tin dòng đã chọn.");
            });
        },

        _checkAndEdit: function (aContexts, aEditable, aLocked) {
            var that = this;

            if (!aLocked.length) {
                this._openWeightDialog(aEditable);
                return;
            }

            var sLocked = aLocked.map(function (oContext) {
                return "• " + that._describeRow(oContext.getObject());
            }).join("\n");
            var sReason = "N.W / G.W của hàng nhóm 320001 được tính tự động nên không chỉnh sửa được.";

            if (!aEditable.length) {
                MessageBox.warning(
                    "Các dòng đã chọn đều không chỉnh sửa được:\n" + sLocked + "\n\n" + sReason,
                    { title: "Không thể chỉnh sửa" }
                );
                return;
            }

            var sContinue = "Tiếp tục với " + aEditable.length + " dòng còn lại";
            MessageBox.warning(
                aLocked.length + "/" + aContexts.length + " dòng đã chọn không chỉnh sửa được:\n" + sLocked +
                "\n\n" + sReason,
                {
                    title: "Có dòng không chỉnh sửa được",
                    actions: [sContinue, MessageBox.Action.CANCEL],
                    emphasizedAction: sContinue,
                    onClose: function (sAction) {
                        if (sAction === sContinue) {
                            that._openWeightDialog(aEditable);
                        }
                    }
                }
            );
        },

        // Mô tả 1 dòng để user nhận ra: item, lot, batch
        _describeRow: function (oRow) {
            var sText = "Item " + Number(oRow.BillingItem);
            if (oRow.LOT) {
                sText += " - Lot " + oRow.LOT;
            }
            if (oRow.Batch) {
                sText += " (batch " + oRow.Batch + ")";
            }
            return sText;
        },

        _openWeightDialog: function (aContexts) {
            var that = this;

            if (!this._weightDialog) {
                this._nwInput = new Input({ type: "Number", width: "100%" });
                this._gwInput = new Input({ type: "Number", width: "100%" });
                this._weightRows = new Text();

                this._weightDialog = new Dialog({
                    title: "Cập nhật N.W / G.W",
                    contentWidth: "28rem",
                    content: [
                        new VBox({
                            items: [
                                this._weightRows.addStyleClass("sapUiSmallMarginBottom"),
                                new Label({ text: "Net weight (KGS)", labelFor: this._nwInput }),
                                this._nwInput,
                                new Label({ text: "Gross weight (KGS)", labelFor: this._gwInput }),
                                this._gwInput
                            ]
                        }).addStyleClass("sapUiSmallMargin")
                    ],
                    beginButton: new Button({
                        text: "Save",
                        type: "Emphasized",
                        press: function () {
                            that._weightDialog.close();
                            that._callUpdWeight(that._weightContexts, {
                                NetWeight: that._nwInput.getValue() || "0",
                                GrossWeight: that._gwInput.getValue() || "0"
                            });
                        }
                    }),
                    endButton: new Button({
                        text: "Cancel",
                        press: function () { that._weightDialog.close(); }
                    })
                });
                this.getView().addDependent(this._weightDialog);
            }

            // 1 dòng thì điền sẵn giá trị đang có; nhiều dòng thì để trống (cùng giá trị cho cả nhóm)
            var oFirst = aContexts[0].getObject();
            var bSingle = aContexts.length === 1;
            this._nwInput.setValue(bSingle && oFirst.NetWeight ? String(oFirst.NetWeight) : "");
            this._gwInput.setValue(bSingle && oFirst.GrossWeight ? String(oFirst.GrossWeight) : "");
            this._weightRows.setText("Áp dụng cho " + aContexts.length + " dòng:\n" + aContexts.map(function (oContext) {
                return "• " + that._describeRow(oContext.getObject());
            }).join("\n"));

            this._weightContexts = aContexts;
            this._weightDialog.open();
        },

        _callUpdWeight: function (aContexts, oParams) {
            var oExtensionAPI = this.base.getExtensionAPI();
            var oModel = oExtensionAPI.getModel();
            var oBusy = new BusyDialog({ text: "Đang cập nhật..." });
            oBusy.open();

            var sGroupId = "UpdWeightBatchGroup";
            var aPromises = aContexts.map(function (oContext) {
                var oOperation = oModel.bindContext(
                    "com.sap.gateway.srvd.zui_ci.v0001.updWeight(...)",
                    oContext,
                    { $$groupId: sGroupId }
                );
                oOperation.setParameter("NetWeight", oParams.NetWeight);
                oOperation.setParameter("GrossWeight", oParams.GrossWeight);
                return oOperation.execute();
            });

            oModel.submitBatch(sGroupId);

            Promise.all(aPromises).then(function () {
                oBusy.close();
                MessageToast.show("Đã cập nhật N.W / G.W cho " + aContexts.length + " dòng");
                // Đọc lại trang để bảng Items hiện giá trị mới
                oExtensionAPI.refresh();
            }).catch(function (oError) {
                oBusy.close();
                console.error("[updWeight]", oError);
                MessageBox.error(oError && oError.message ? oError.message : "Đã xảy ra lỗi khi cập nhật N.W / G.W.");
            });
        }
    });
});
