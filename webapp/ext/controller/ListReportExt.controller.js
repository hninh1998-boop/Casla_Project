sap.ui.define([
    "sap/m/MessageToast"
], function (MessageToast) {
    "use strict";

    return {

        onInit: function () {
            console.log(">>> ZMB51 ListReportExt: onInit FIRED");
        },

        onInitSmartFilterBarExtension: function (oEvent) {
            console.log(">>> ZMB51 ListReportExt: onInitSmartFilterBarExtension FIRED");

            this._bInitDefault = false;
            this._oSmartFilterBar = oEvent.getSource();

            this._handleFilterChange();
            this._oSmartFilterBar.attachFilterChange(this._handleFilterChange, this);
            this._oSmartFilterBar.attachAfterVariantLoad(this._onAfterVariantLoad, this);
        },

        /**
         * Tìm FilterItem theo tên property
         */
        _getFilterItemFromFilterBar: function (sFilterItemName) {
            var aFilterItems = this._oSmartFilterBar.getAllFilterItems();
            for (var i = 0; i < aFilterItems.length; i++) {
                if (aFilterItems[i].getName() === sFilterItemName) {
                    return aFilterItems[i];
                }
            }
            return null;
        },

        /**
         * Set default StockChangeType = '05' qua control dropdown (single-select)
         * Chỉ set khi control đang rỗng
         */
        _setDefaultStockChange: function () {
            var oItem = this._getFilterItemFromFilterBar("StockChangeType");
            if (!oItem) {
                return;
            }
            var oControl = this._oSmartFilterBar.determineControlByFilterItem(oItem);
            if (!oControl || !oControl.getSelectedKey) {
                return;
            }

            // Đã có giá trị rồi thì thôi
            if (oControl.getSelectedKey() !== "") {
                return;
            }

            // List nạp async -> chờ tới khi có items mới set
            var iTries = 0;
            var fnTrySet = function () {
                if (oControl.getItems && oControl.getItems().length > 0) {
                    if (oControl.getSelectedKey() === "") {
                        oControl.setSelectedKey("05");
                    }
                } else if (iTries < 50) {     // tối đa ~5s (50 x 100ms)
                    iTries++;
                    setTimeout(fnTrySet, 100);
                }
            };
            fnTrySet();
        },

        /**
         * Set default MaterialDocumentYear = năm hiện tại nếu chưa có
         */
        _setDefaultYear: function (oJSONData) {
            var oYearData = oJSONData.MaterialDocumentYear;
            var bYearEmpty = !oYearData
                || (oYearData.ranges && oYearData.ranges.length === 0
                    && oYearData.items && oYearData.items.length === 0);

            if (bYearEmpty) {
                oJSONData.MaterialDocumentYear = {
                    items: [],
                    ranges: [{
                        exclude: false,
                        keyField: "MaterialDocumentYear",
                        operation: "EQ",
                        value1: "" + new Date().getFullYear(),
                        value2: null
                    }],
                    value: null
                };
                return true;
            }
            return false;
        },

        _getCtrlConfigByKey: function (sKey) {
            var aCfg = this._oSmartFilterBar.getControlConfiguration();
            for (var i = 0; i < aCfg.length; i++) {
                if (aCfg[i].getKey && aCfg[i].getKey() === sKey) {
                    return aCfg[i];
                }
            }
            return null;
        },
        /**
                 * Set default StockChangeContext = '01' (Plant) qua control dropdown
                 * Chỉ set khi control đang rỗng
                 */
        _setDefaultStockChangeContext: function () {
            var oItem = this._getFilterItemFromFilterBar("StockChangeContext");
            if (!oItem) {
                return;
            }
            var oControl = this._oSmartFilterBar.determineControlByFilterItem(oItem);
            if (!oControl || !oControl.getSelectedKey) {
                return;
            }
            if (oControl.getSelectedKey() !== "") {
                return;
            }

            // List nạp async -> chờ tới khi có items mới set
            var iTries = 0;
            var fnTrySet = function () {
                if (oControl.getItems && oControl.getItems().length > 0) {
                    if (oControl.getSelectedKey() === "") {
                        oControl.setSelectedKey("01");
                    }
                } else if (iTries < 50) {
                    iTries++;
                    setTimeout(fnTrySet, 100);
                }
            };
            fnTrySet();
        },
        _applyStockChangeLogic: function () {
            var oSCItem = this._getFilterItemFromFilterBar("StockChangeType");
            if (!oSCItem) { return; }
            var sSC = this._oSmartFilterBar.determineControlByFilterItem(oSCItem).getSelectedKey();

            var oLevelCfg = this._getCtrlConfigByKey("StockChangeContext");
            var oLevelItem = this._getFilterItemFromFilterBar("StockChangeContext");
            var oPlantItem = this._getFilterItemFromFilterBar("Plant");
            var oSLocItem = this._getFilterItemFromFilterBar("StorageLocation");

            if (sSC === "05" || sSC === "") {
                if (oLevelCfg) { oLevelCfg.setVisible(false); }
                if (oLevelItem) { oLevelItem.setMandatory(false); }
                if (oPlantItem) { oPlantItem.setMandatory(false); }
                if (oSLocItem) { oSLocItem.setMandatory(false); }
            } else {
                if (oLevelCfg) { oLevelCfg.setVisible(true); }
                if (oLevelItem) { oLevelItem.setMandatory(true); }

                var sLevel = oLevelItem
                    ? this._oSmartFilterBar.determineControlByFilterItem(oLevelItem).getSelectedKey()
                    : "";

                if (sLevel === "01") {
                    if (oPlantItem) { oPlantItem.setMandatory(true); }
                    if (oSLocItem) { oSLocItem.setMandatory(false); }
                } else if (sLevel === "02") {
                    if (oPlantItem) { oPlantItem.setMandatory(false); }
                    if (oSLocItem) { oSLocItem.setMandatory(true); }
                } else {
                    if (oPlantItem) { oPlantItem.setMandatory(true); }
                    if (oSLocItem) { oSLocItem.setMandatory(false); }
                }
            }
        },

        /**
         * First load: set default năm + stock change, chỉ 1 lần
         */
        _handleFilterChange: function () {
            // --- Phần 1: set default chỉ 1 lần ---
            if (this._bInitDefault !== true) {
                this._bInitDefault = true;

                var oJSONData = this._oSmartFilterBar.getFilterData(true);
                if (this._setDefaultYear(oJSONData)) {
                    this._oSmartFilterBar.setFilterData(oJSONData);
                }
                this._setDefaultStockChange();
                 this._setDefaultStockChangeContext();   // '01'  ← thêm dòng này
            }

            // --- Phần 2: apply logic hiện/ẩn + required MỖI LẦN filter đổi ---
            this._applyStockChangeLogic();
        },

        /**
         * Khi load Standard variant rỗng -> fill lại năm + stock change
         */
        _onAfterVariantLoad: function () {
            if (!this._oSmartFilterBar) {
                return;
            }

            var oSmartVariantManagement = this._oSmartFilterBar.getSmartVariant();
            if (!oSmartVariantManagement) {
                return;
            }

            var oCurrentVariant = oSmartVariantManagement.getVariantByKey(
                oSmartVariantManagement.getPresentVariantId()
            );
            if (!oCurrentVariant || oCurrentVariant.getAuthor() !== "SAP") {
                return;
            }

            var oJSONData = this._oSmartFilterBar.getFilterData(true);
            if (this._setDefaultYear(oJSONData)) {
                this._oSmartFilterBar.setFilterData(oJSONData);
            }

            this._setDefaultStockChange();
        }
    };
});