sap.ui.define([
    "sap/ui/core/Fragment",
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (Fragment, MessageToast, MessageBox) {
    "use strict";

    return {
        // ── Mở/đóng Menu ─────────────────────────────────────────────
        onMassChange: function (oEvent) {
            console.log("onMassChange called");
            var oButton = oEvent.getSource();
            var oView = this.getView();
            var that = this;

            if (!this._oMenuFragment) {
                Fragment.load({
                    name: "zbomrp.ext.fragment.TableToolbar",
                    controller: this
                }).then(function (oMenu) {
                    that._oMenuFragment = oMenu;
                    oView.addDependent(oMenu);
                    oMenu.openBy(oButton);
                }).catch(function (oError) {
                    MessageBox.error("Fragment load failed: " + oError.message);
                });
            } else {
                if (this._oMenuFragment.isOpen()) {
                    this._oMenuFragment.close();
                } else {
                    this._oMenuFragment.openBy(oButton);
                }
            }

            // Trong onMassChange, sau khi menu load xong
            // Ẩn Edit/Delete menu item dựa trên auth
            if (that._oAuth) {
                var aMenuItems = oMenu.getItems ? oMenu.getItems() : [];
                aMenuItems.forEach(function (oItem) {
                    if (oItem.getText() === "Edit" && !that._oAuth.edit) {
                        oItem.setVisible(false);
                    }
                    if (oItem.getText() === "Delete" && !that._oAuth.delete) {
                        oItem.setVisible(false);
                    }
                });
            }
        },

        // ── Edit → gọi BE ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
        // ── Helper: tạo 1 attribute row ──────────────────────────────
        _createAttrRow: function (iIndex) {
            var that = this;
            var oSelect = new sap.m.Select({
                width: "220px",
                items: [
                    new sap.ui.core.Item({ text: "Component", key: "Component" }),
                    new sap.ui.core.Item({ text: "Component Quantity", key: "ComponentQuantity" }),
                    new sap.ui.core.Item({ text: "Component Scrap (%)", key: "ComponentScrap" }),
                    new sap.ui.core.Item({ text: "Special Procurement", key: "SpecialProcurementType" }),
                    new sap.ui.core.Item({ text: "Relevancy to Costing", key: "BOMItemIsCostingRelevant" }),
                    new sap.ui.core.Item({ text: "Component UoM", key: "ComponentUOM" }),
                    new sap.ui.core.Item({ text: "Storage Location", key: "ProdOrderIssueLocation" }),
                ]
            });
            var oInput = new sap.m.Input({
                placeholder: "Value",
                width: "200px"
            }).addStyleClass("sapUiSmallMarginBegin");

            var oClearBox = new sap.m.CheckBox({
                text: "Clear Values"
            }).addStyleClass("sapUiSmallMarginBegin");

            // Nút xóa row (ⓧ)
            var oDeleteBtn = new sap.m.Button({
                icon: "sap-icon://sys-cancel",
                type: "Transparent",
                press: function () {
                    var oContainer = Fragment.byId(
                        that.getView().getId(), "attrRowsContainer"
                    );
                    oContainer.removeItem(oRow);

                    var aItems = oContainer.getItems();

                    if (aItems.length === 1) {
                        // Chỉ còn 1 row → ẩn nút xóa, hiện nút +
                        aItems[0].getItems()[3].setEnabled(false);  // 👈 disable
                        aItems[0].getItems()[4].setVisible(true);  // 👈 restore dấu +
                    } else {
                        // Nhiều row → đảm bảo row cuối có dấu +, các row khác không có
                        aItems.forEach(function (r, idx) {
                            r.getItems()[3].setEnabled(true);  // 👈 enable tất cả
                            r.getItems()[4].setVisible(idx === aItems.length - 1);  // chỉ row cuối có dấu +
                        });
                    }
                }
            }).addStyleClass("sapUiSmallMarginBegin");

            // Nút thêm row (+) — chỉ hiện ở row cuối
            var oAddBtn = new sap.m.Button({
                icon: "sap-icon://add",
                type: "Transparent",
                press: function () {
                    var oContainer = Fragment.byId(
                        that.getView().getId(), "attrRowsContainer"
                    );
                    var aItems = oContainer.getItems();

                    // Ẩn dấu + ở tất cả rows hiện tại, enable dấu x
                    aItems.forEach(function (r) {
                        r.getItems()[3].setEnabled(true);   // enable x
                        r.getItems()[4].setVisible(false);  // ẩn +
                    });

                    // Thêm row mới — row mới luôn có dấu +, có dấu x
                    var oNewRow = that._createAttrRow(aItems.length);
                    oNewRow.getItems()[3].setEnabled(true);   // enable x
                    oNewRow.getItems()[4].setVisible(true);   // hiện +
                    oContainer.addItem(oNewRow);
                }
            }).addStyleClass("sapUiTinyMarginBegin");

            var oRow = new sap.m.HBox({
                alignItems: "Center",
                items: [oSelect, oInput, oClearBox, oDeleteBtn, oAddBtn]
            }).addStyleClass("sapUiTinyMarginBottom");

            return oRow;
        },

        // ── Reset rows về 1 row ban đầu ──────────────────────────────
        _resetAttrRows: function () {
            var oContainer = Fragment.byId(this.getView().getId(), "attrRowsContainer");
            oContainer.removeAllItems();
            var oFirstRow = this._createAttrRow(0);
            // Row đầu tiên: ẩn nút xóa
            oFirstRow.getItems()[3].setEnabled(false);
            oContainer.addItem(oFirstRow);
        },

        _showValidationError: function (sMsg) {
            var oStrip = Fragment.byId(this.getView().getId(), "validationErrorStrip");
            if (oStrip) {
                oStrip.setText(sMsg);
                oStrip.setVisible(true);
            } else {
                // Fallback nếu fragment chưa có strip
                MessageBox.error(sMsg);
            }
        },

        _clearValidationError: function () {
            var oStrip = Fragment.byId(this.getView().getId(), "validationErrorStrip");
            if (oStrip) {
                oStrip.setVisible(false);
                oStrip.setText("");
            }
        },

        _validateAttrs: function (aAttrs) {
            // Regex: số thập phân hợp lệ (ví dụ: 12, 12.5, .5, 0)
            var rDecimal = /^\d+(\.\d+)?$/;

            for (var i = 0; i < aAttrs.length; i++) {
                var oAttr = aAttrs[i];
                if (oAttr.clear) continue; // Clear Values → bỏ qua validate

                var sLabel = oAttr.key === "ComponentQuantity"
                    ? "Component Quantity"
                    : oAttr.key === "ComponentScrap"
                        ? "Component Scrap (%)"
                        : null;

                // Chỉ validate các numeric field
                if (oAttr.key === "ComponentQuantity" || oAttr.key === "ComponentScrap") {
                    var sVal = oAttr.value.trim();
                    if (sVal === "" || sVal === "0") continue; // empty/0 → OK
                    if (!rDecimal.test(sVal)) {
                        return "Field \"" + sLabel + "\" (dòng " + (i + 1) + "): "
                            + "\"" + sVal + "\" không hợp lệ — chỉ được nhập số (ví dụ: 12 hoặc 12.5).";
                    }
                }
            }
            return null; // null = không có lỗi
        },

        // ── Main processing của edit pop up ──────────────────────────────────────────────────────────────────────────────────────────
        onEditMassChange: function () {
            if (this._oAuth && !this._oAuth.edit) {
                MessageBox.error("Bạn không có quyền Edit.");
                return;
            }
            var oView = this.getView();
            var that = this;

            // Lấy selected rows và lưu lại
            var aSmartTables = oView.findAggregatedObjects(true, function (o) {
                return o.isA("sap.ui.comp.smarttable.SmartTable");
            });
            if (aSmartTables.length === 0) {
                MessageToast.show("Không tìm thấy SmartTable");
                return;
            }

            // Thay toàn bộ block lấy selected trong onEditMassChange
            var oTable = aSmartTables[0]._oTable || aSmartTables[0].getTable();
            var aSelected = [];

            // Approach: dùng _oSelection (internal selection plugin của SmartTable)
            var oSelPlugin = oTable._getSelectionPlugin ? oTable._getSelectionPlugin() : null;

            if (oSelPlugin && oSelPlugin.getSelectedIndices) {
                var aSelectedIndices = oSelPlugin.getSelectedIndices();
                aSelectedIndices.forEach(function (iIndex) {
                    var oCtx = oTable.getContextByIndex(iIndex);
                    if (oCtx) aSelected.push(oCtx.getObject());
                });
            } else {
                // Fallback DOM-based
                oTable.getRows().forEach(function (oRow) {
                    var oDomRef = oRow.getDomRef();
                    if (oDomRef && oDomRef.classList.contains("sapUiTableRowSel")) {
                        var oCtx = oRow.getBindingContext();
                        if (oCtx) aSelected.push(oCtx.getObject());
                    }
                });
            }

            // Lưu selected để dùng trong onConfirmEdit
            this._aEditSelected = aSelected;

            // Mở dialog
            if (!this._oEditDialog) {
                Fragment.load({
                    id: oView.getId(),
                    name: "zbomrp.ext.fragment.EditDialog",
                    controller: this
                }).then(function (oDialog) {
                    that._oEditDialog = oDialog;
                    oView.addDependent(oDialog);
                    Fragment.byId(oView.getId(), "infoStrip")
                        .setText(that._aEditSelected.length + " BOM item will be edited.");
                    that._resetAttrRows();
                    oDialog.open();
                });
            } else {
                Fragment.byId(oView.getId(), "infoStrip")
                    .setText(this._aEditSelected.length + " BOM item will be edited.");
                this._resetAttrRows();
                this._oEditDialog.open();
            }
        },

        onSimulateEdit: function () {
            MessageToast.show("Simulate clicked - chưa implement");
        },

        onConfirmEdit: function () {
            var oView = this.getView();
            var oModel = oView.getModel();
            var that = this;

            this._clearValidationError();

            // ── 1. Thu thập attrs ────────────────────────────────────────────
            var oContainer = Fragment.byId(oView.getId(), "attrRowsContainer");
            var aAttrs = [];
            oContainer.getItems().forEach(function (oRow) {
                var sKey = oRow.getItems()[0].getSelectedKey();
                var sValue = oRow.getItems()[1].getValue().trim();
                var bClear = oRow.getItems()[2].getSelected();
                if (sKey) {
                    aAttrs.push({ key: sKey, value: sValue, clear: bClear });
                }
            });

            if (aAttrs.length === 0) {
                this._showValidationError("Vui lòng chọn ít nhất 1 attribute để edit.");
                return;
            }

            // ── 2. Validate kiểu dữ liệu ────────────────────────────────────
            var sValidationError = this._validateAttrs(aAttrs);
            if (sValidationError) {
                this._showValidationError(sValidationError);
                return;
            }

            // ── 3. Đọc mode xử lý từ RadioButtonGroup ───────────────────────
            var oRbBackground = Fragment.byId(oView.getId(), "rbBackground");
            var bRunInBackground = oRbBackground ? oRbBackground.getSelected() : false;
            
            var sRunInBackground = bRunInBackground ? "true" : "false";
            // var sRunNow = bRunInBackground ? "false" : "true";
            var sRunNow = !bRunInBackground;

            // ── 4. Build oParam (first-wins) ─────────────────────────────────
            var oParam = {
                Component: "",
                ComponentQuantity: "0",
                ComponentScrap: "0",
                SpecialProcurementType: "",
                BOMItemIsCostingRelevant: "",
                ComponentUOM: "",
                ProdOrderIssueLocation: ""
            };
            var oParamSet = {
                Component: false,
                ComponentQuantity: false,
                ComponentScrap: false,
                SpecialProcurementType: false,
                BOMItemIsCostingRelevant: false,
                ComponentUOM: false,
                ProdOrderIssueLocation: false
            };

            aAttrs.forEach(function (oAttr) {
                if (oAttr.clear) return;
                if (oParamSet[oAttr.key]) return;
                switch (oAttr.key) {
                    case "Component":
                        oParam.Component = oAttr.value;
                        oParamSet.Component = true;
                        break;
                    case "ComponentQuantity":
                        oParam.ComponentQuantity = oAttr.value || "0";
                        oParamSet.ComponentQuantity = true;
                        break;
                    case "ComponentScrap":
                        if (oAttr.clear === true) {
                            oParam.ComponentScrap = "0";
                        } else {
                            oParam.ComponentScrap = oAttr.value || "0";
                            oParamSet.ComponentScrap = true;
                        }
                        break;
                    case "SpecialProcurementType":
                        if (oAttr.clear === true) {
                            oParam.SpecialProcurementType = "";
                        } else {
                            oParam.SpecialProcurementType = oAttr.value || "";
                            oParamSet.SpecialProcurementType = true;
                        }
                        break;
                    case "BOMItemIsCostingRelevant":
                        if (oAttr.clear === true) {
                            oParam.BOMItemIsCostingRelevant = "";
                        } else {
                            oParam.BOMItemIsCostingRelevant = oAttr.value || "";
                            oParamSet.BOMItemIsCostingRelevant = true;
                        }
                        break;
                    case "ComponentUOM":
                        if (oAttr.clear === true) {
                            oParam.ComponentUOM = "";
                        } else {
                            oParam.ComponentUOM = oAttr.value || "";
                            oParamSet.ComponentUOM = true;
                        }
                        break;
                    case "ProdOrderIssueLocation":
                        if (oAttr.clear === true) {
                            oParam.ProdOrderIssueLocation = "";
                        } else {
                            oParam.ProdOrderIssueLocation = oAttr.value || "";
                            oParamSet.ProdOrderIssueLocation = true;
                        }
                        break;
                }
            });

            // ── 4b. Build edit flags ─────────────────────────────────
            var oEditFlags = {
                EditComponent: false,
                EditComponentQuantity: false,
                EditComponentScrap: false,
                EditSpecialProcurementType: false,
                EditBOMItemIsCostingRelevant: false,
                EditComponentUOM: false,
                EditProdOrderIssueLocation: false
            };

            aAttrs.forEach(function (oAttr) {
                switch (oAttr.key) {
                    case "Component":
                        oEditFlags.EditComponent = true;
                        break;
                    case "ComponentQuantity":
                        oEditFlags.EditComponentQuantity = true;
                        break;
                    case "ComponentScrap":
                        oEditFlags.EditComponentScrap = true;
                        break;
                    case "SpecialProcurementType":
                        oEditFlags.EditSpecialProcurementType = true;
                        break;
                    case "BOMItemIsCostingRelevant":
                        oEditFlags.EditBOMItemIsCostingRelevant = true;
                        break;
                    case "ComponentUOM":
                        oEditFlags.EditComponentUOM = true;
                        break;
                    case "ProdOrderIssueLocation":
                        oEditFlags.EditProdOrderIssueLocation = true;
                        break;
                }
            });


            // ── 5. Tạo JobText nếu background ───────────────────────────────
            var sJobText = "";
            if (bRunInBackground) {
                var oNow = new Date();
                var sDateTime = oNow.getFullYear()
                    + ("0" + (oNow.getMonth() + 1)).slice(-2)
                    + ("0" + oNow.getDate()).slice(-2)
                    + " "
                    + ("0" + oNow.getHours()).slice(-2)
                    + ("0" + oNow.getMinutes()).slice(-2)
                    + ("0" + oNow.getSeconds()).slice(-2);
                sJobText = "ZEDIT Mass BOM (" + sDateTime + ")";
            }

            // ── 6. Gọi EditMassChange ────────────────────────────────────────
            var aSelected = this._aEditSelected;
            var aPromises = [];

            aSelected.forEach(function (oData) {
                aPromises.push(new Promise(function (resolve, reject) {
                    oModel.callFunction("/EditMassChange", {
                        method: "POST",
                        urlParameters: {
                            LineItem: oData.LineItem,
                            Material: oData.Material,
                            Plant: oData.Plant,
                            BillOfMaterialVariantUsage: oData.BillOfMaterialVariantUsage,
                            BillOfMaterialVariant: oData.BillOfMaterialVariant,
                            SalesOrder: oData.SalesOrder,
                            SalesOrderItem: oData.SalesOrderItem,
                            BillOfMaterialItemNumber: oData.BillOfMaterialItemNumber,
                            BillOfMaterialItemNodeNumber: oData.BillOfMaterialItemNodeNumber,
                            BOMItemInternalChangeCount: oData.BOMItemInternalChangeCount,
                            BillOfMaterial: oData.BillOfMaterial,
                            BillOfMaterialCategory: oData.BillOfMaterialCategory,
                            
                            Component: oParam.Component,
                            ComponentQuantity: oParam.ComponentQuantity,
                            ComponentScrap: oParam.ComponentScrap,
                            SpecialProcurementType: oParam.SpecialProcurementType,
                            BOMItemIsCostingRelevant: oParam.BOMItemIsCostingRelevant,
                            ComponentUOM: oParam.ComponentUOM,
                            ProdOrderIssueLocation: oParam.ProdOrderIssueLocation,

                            RunInBackground: sRunInBackground,
                            RunNow: sRunNow,
                            JobText: sJobText,

                            EditComponent: oEditFlags.EditComponent,
                            EditComponentQuantity: oEditFlags.EditComponentQuantity,
                            EditComponentScrap: oEditFlags.EditComponentScrap,
                            EditSpecialProcurementType: oEditFlags.EditSpecialProcurementType,
                            EditBOMItemIsCostingRelevant: oEditFlags.EditBOMItemIsCostingRelevant,
                            EditComponentUOM: oEditFlags.EditComponentUOM,
                            EditProdOrderIssueLocation: oEditFlags.EditProdOrderIssueLocation
                        },
                        success: function (oResult) { resolve(oResult); },
                        error: function (oError) { reject(oError); }
                    });
                }));
            });

            // ── 7. Xử lý kết quả ────────────────────────────────────────────
            Promise.all(aPromises)
                .then(function () {
                    that._oEditDialog.close();
                    if (bRunInBackground) {
                        MessageBox.success("Background job đã được tạo:\n" + sJobText);
                    } else {
                        MessageToast.show("Edit thành công: " + aSelected.length + " dòng");
                    }
                    var aSmartTables = oView.findAggregatedObjects(true, function (o) {
                        return o.isA("sap.ui.comp.smarttable.SmartTable");
                    });
                    if (aSmartTables.length > 0) {
                        aSmartTables[0].rebindTable();
                    }
                })
                .catch(function (oError) {
                    var sMsg = "";
                    try {
                        var oParsed = JSON.parse(oError.responseText);
                        sMsg = oParsed.error && oParsed.error.message && oParsed.error.message.value
                            ? oParsed.error.message.value
                            : oError.responseText;
                    } catch (e) {
                        sMsg = oError.responseText || oError.message || "Unknown error";
                    }
                    that._showValidationError("BE error: " + sMsg);
                });
        },

        onCancelEdit: function () {
            if (this._oEditDialog) {
                this._oEditDialog.close();
            }
        },

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ── Delete Mass Change ───────────────────────────────────────
        onDeleteMassChange: function () {
            if (this._oAuth && !this._oAuth.delete) {
                MessageBox.error("Bạn không có quyền Delete.");
                return;
            }

            var oView = this.getView();
            var that = this;

            // Lấy selected rows
            var aSmartTables = oView.findAggregatedObjects(true, function (o) {
                return o.isA("sap.ui.comp.smarttable.SmartTable");
            });
            if (aSmartTables.length === 0) {
                MessageToast.show("Không tìm thấy SmartTable");
                return;
            }

            // Thay toàn bộ block lấy selected trong onDeleteMassChange
            var oTable = aSmartTables[0]._oTable || aSmartTables[0].getTable();
            var aSelected = [];

            // Approach: dùng _oSelection (internal selection plugin của SmartTable)
            var oSelPlugin = oTable._getSelectionPlugin ? oTable._getSelectionPlugin() : null;

            if (oSelPlugin && oSelPlugin.getSelectedIndices) {
                var aSelectedIndices = oSelPlugin.getSelectedIndices();
                aSelectedIndices.forEach(function (iIndex) {
                    var oCtx = oTable.getContextByIndex(iIndex);
                    if (oCtx) aSelected.push(oCtx.getObject());
                });
            } else {
                // Fallback DOM-based
                oTable.getRows().forEach(function (oRow) {
                    var oDomRef = oRow.getDomRef();
                    if (oDomRef && oDomRef.classList.contains("sapUiTableRowSel")) {
                        var oCtx = oRow.getBindingContext();
                        if (oCtx) aSelected.push(oCtx.getObject());
                    }
                });
            }

            this._aDeleteSelected = aSelected;

            // Mở dialog
            if (!this._oDeleteDialog) {
                Fragment.load({
                    id: oView.getId(),
                    name: "zbomrp.ext.fragment.DeleteDialog",
                    controller: this
                }).then(function (oDialog) {
                    that._oDeleteDialog = oDialog;
                    oView.addDependent(oDialog);
                    Fragment.byId(oView.getId(), "deleteInfoStrip")
                        .setText(that._aDeleteSelected.length + " BOM item will be deleted.");
                    oDialog.open();
                });
            } else {
                Fragment.byId(oView.getId(), "deleteInfoStrip")
                    .setText(this._aDeleteSelected.length + " BOM item will be deleted.");
                this._clearDeleteValidationError();
                this._oDeleteDialog.open();
            }
        },

        _showDeleteValidationError: function (sMsg) {
            var oStrip = Fragment.byId(this.getView().getId(), "deleteValidationErrorStrip");
            if (oStrip) {
                oStrip.setText(sMsg);
                oStrip.setVisible(true);
            } else {
                MessageBox.error(sMsg);
            }
        },

        _clearDeleteValidationError: function () {
            var oStrip = Fragment.byId(this.getView().getId(), "deleteValidationErrorStrip");
            if (oStrip) {
                oStrip.setVisible(false);
                oStrip.setText("");
            }
        },

        onSimulateDelete: function () {
            MessageToast.show("Simulate clicked - chưa implement");
        },

        onConfirmDelete: function () {
            var oView = this.getView();
            var oModel = oView.getModel();
            var that = this;

            this._clearDeleteValidationError();

            // Đọc mode
            var oRbBackground = Fragment.byId(oView.getId(), "deleteRbBackground");
            var bRunInBackground = oRbBackground ? oRbBackground.getSelected() : false;
            var sRunInBackground = bRunInBackground ? "true" : "false";
            var sRunNow = bRunInBackground ? "false" : "true";

            // Tạo JobText nếu background
            var sJobText = "";
            if (bRunInBackground) {
                var oNow = new Date();
                var sDateTime = oNow.getFullYear()
                    + ("0" + (oNow.getMonth() + 1)).slice(-2)
                    + ("0" + oNow.getDate()).slice(-2)
                    + " "
                    + ("0" + oNow.getHours()).slice(-2)
                    + ("0" + oNow.getMinutes()).slice(-2)
                    + ("0" + oNow.getSeconds()).slice(-2);
                sJobText = "ZDELETE Mass BOM (" + sDateTime + ")";
            }

            var aSelected = this._aDeleteSelected;
            var aPromises = [];

            aSelected.forEach(function (oData) {
                aPromises.push(new Promise(function (resolve, reject) {
                    oModel.callFunction("/DeleteMassChange", {
                        method: "POST",
                        urlParameters: {
                            Material: oData.Material,
                            Plant: oData.Plant,
                            BillOfMaterialVariantUsage: oData.BillOfMaterialVariantUsage,
                            BillOfMaterialVariant: oData.BillOfMaterialVariant,
                            SalesOrder: oData.SalesOrder,
                            SalesOrderItem: oData.SalesOrderItem,
                            BillOfMaterialItemNumber: oData.BillOfMaterialItemNumber,
                            BillOfMaterialItemNodeNumber: oData.BillOfMaterialItemNodeNumber,
                            BOMItemInternalChangeCount: oData.BOMItemInternalChangeCount,
                            BillOfMaterial: oData.BillOfMaterial,
                            BillOfMaterialCategory: oData.BillOfMaterialCategory,
                            JobText: sJobText,
                            RunInBackground: sRunInBackground,
                            RunNow: sRunNow
                        },
                        success: function (oResult) { resolve(oResult); },
                        error: function (oError) { reject(oError); }
                    });
                }));
            });

            Promise.all(aPromises)
                .then(function () {
                    that._oDeleteDialog.close();
                    if (bRunInBackground) {
                        MessageBox.success("Background job đã được tạo:\n" + sJobText);
                    } else {
                        MessageToast.show("Delete thành công: " + aSelected.length + " dòng");
                    }
                    var aSmartTables = oView.findAggregatedObjects(true, function (o) {
                        return o.isA("sap.ui.comp.smarttable.SmartTable");
                    });
                    if (aSmartTables.length > 0) {
                        aSmartTables[0].rebindTable();
                    }
                })
                .catch(function (oError) {
                    var sMsg = "";
                    try {
                        var oParsed = JSON.parse(oError.responseText);
                        sMsg = oParsed.error && oParsed.error.message && oParsed.error.message.value
                            ? oParsed.error.message.value
                            : oError.responseText;
                    } catch (e) {
                        sMsg = oError.responseText || oError.message || "Unknown error";
                    }
                    that._showDeleteValidationError("BE error: " + sMsg);
                });
        },

        onCancelDelete: function () {
            if (this._oDeleteDialog) {
                this._oDeleteDialog.close();
            }
        },

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////
        onAddItem: function () {
            var that = this;
            var oView = this.getView();
            var oModel = oView.getModel();

            // Lấy 1 selected row bất kỳ để gọi action (cần key)
            var aSmartTables = oView.findAggregatedObjects(true, function (o) {
                return o.isA("sap.ui.comp.smarttable.SmartTable");
            });
            if (aSmartTables.length === 0) return;

            var oTable = aSmartTables[0]._oTable || aSmartTables[0].getTable();
            var oCtx = oTable.getContextByIndex(0);
            if (!oCtx) {
                // Không có data → gọi trực tiếp, BE sẽ block nếu không có quyền
                this._navigateToAddItem();
                return;
            }

            var oData = oCtx.getObject();

            // Gọi AddMassChange để check quyền qua get_global_authorizations
            oModel.callFunction("/AddMassChange", {
                method: "POST",
                urlParameters: {
                    Material: oData.Material,
                    Plant: oData.Plant,
                    BillOfMaterialVariantUsage: oData.BillOfMaterialVariantUsage,
                    BillOfMaterialVariant: oData.BillOfMaterialVariant,
                    SalesOrder: oData.SalesOrder,
                    SalesOrderItem: oData.SalesOrderItem,
                    BillOfMaterialItemNumber: oData.BillOfMaterialItemNumber,
                    BillOfMaterialItemNodeNumber: oData.BillOfMaterialItemNodeNumber,
                    BOMItemInternalChangeCount: oData.BOMItemInternalChangeCount,
                    BillOfMaterial: oData.BillOfMaterial,
                    BillOfMaterialCategory: oData.BillOfMaterialCategory
                },
                success: function () {
                    // Quyền OK → navigate
                    that._navigateToAddItem();
                },
                error: function (oError) {
                    var sMsg = "Bạn không có quyền Add Item.";
                    try {
                        var oParsed = JSON.parse(oError.responseText);
                        if (oParsed.error && oParsed.error.message && oParsed.error.message.value) {
                            sMsg = oParsed.error.message.value;
                        }
                    } catch (e) { /* ignore */ }
                    MessageBox.error(sMsg);
                }
            });
        },

        _navigateToAddItem: function () {
            var oCrossAppNav = sap.ushell.Container.getService("CrossApplicationNavigation");
            oCrossAppNav.toExternal({
                target: {
                    semanticObject: "zupload_zbom_rp",
                    action: "display"
                }
            });
        },

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////
        onBeforeRebindTableExtension: function () {
            var that = this;
            var oModel = this.getView().getModel();

            if (this._bAuthChecked) return;

            debugger;
            oModel.callFunction("/CheckAuth", {
                method: "POST",
                // Debug: check xem button ID thực sự là gì
                success: function (oResult) {
                    that._bAuthChecked = true;
                    that._oAuth = {
                        edit: oResult.EditAllowed === true || oResult.EditAllowed === "true",
                        delete: oResult.DeleteAllowed === true || oResult.DeleteAllowed === "true",
                        add: oResult.AddAllowed === true || oResult.AddAllowed === "true"
                    };

                    // Tìm button bằng findAggregatedObjects
                    var oView = that.getView();
                    var aButtons = oView.findAggregatedObjects(true, function (o) {
                        return o.isA("sap.m.Button") && (
                            o.getId().indexOf("idMassChangeButton") > -1 ||
                            o.getId().indexOf("idAddItemButton") > -1
                        );
                    });

                    console.log("Found buttons:", aButtons.map(function (b) {
                        return b.getId() + " => " + b.getText();
                    }));

                    aButtons.forEach(function (oBtn) {
                        if (oBtn.getId().indexOf("idMassChangeButton") > -1) {
                            if (!that._oAuth.edit && !that._oAuth.delete) {
                                oBtn.setVisible(false);
                            }
                        }
                        if (oBtn.getId().indexOf("idAddItemButton") > -1) {
                            if (!that._oAuth.add) {
                                oBtn.setVisible(false);
                            }
                        }
                    });
                },
                error: function () {
                    // Nếu lỗi → ẩn hết để an toàn
                    that._oAuth = { edit: false, delete: false, add: false };
                }
            });
        }
    };
});