sap.ui.define([
    "sap/m/MessageToast"
], function (MessageToast) {
    "use strict";

    return {

        /**
         * Standard controller hook - fire khi view khởi tạo
         */
        onInit: function () {
            console.log(">>> ZMAPIM ListReportExt: onInit FIRED");
        },

        /**
         * Fiori Elements hook - fire khi SmartFilterBar init xong
         * Đăng ký listener để set default năm hiện tại
         */
        onInitSmartFilterBarExtension: function (oEvent) {
            console.log(">>> ZMAPIM ListReportExt: onInitSmartFilterBarExtension FIRED");

            this._bInitYear = false;
            this._oSmartFilterBar = oEvent.getSource();

            // Set default ngay first call
            this._handleFilterChange();

            // Attach listener cho các lần sau
            this._oSmartFilterBar.attachFilterChange(this._handleFilterChange, this);
            this._oSmartFilterBar.attachAfterVariantLoad(this._onAfterVariantLoad, this);
        },

        /**
         * Set default FiscalYear = năm hiện tại ở first load
         * Chỉ set 1 lần khi field chưa có giá trị
         */
        _handleFilterChange: function () {
            if (this._bInitYear === true) {
                return;
            }
            this._bInitYear = true;

            var oJSONData = this._oSmartFilterBar.getFilterData(true);
            console.log(">>> ZMAPIM: Current FiscalYear =", JSON.stringify(oJSONData.FiscalYear));

            // Chỉ set default nếu FiscalYear chưa có giá trị
            var bIsEmpty = !oJSONData.FiscalYear
                || (oJSONData.FiscalYear.ranges
                    && oJSONData.FiscalYear.ranges.length === 0
                    && oJSONData.FiscalYear.items
                    && oJSONData.FiscalYear.items.length === 0);

            if (bIsEmpty) {
                var sCurrentYear = "" + new Date().getFullYear();

                oJSONData.FiscalYear = {
                    items: [],
                    ranges: [{
                        exclude: false,
                        keyField: "FiscalYear",
                        operation: "EQ",
                        value1: sCurrentYear,
                        value2: null
                    }],
                    value: null
                };
                this._oSmartFilterBar.setFilterData(oJSONData);
                console.log(">>> ZMAPIM: Set default FiscalYear =", sCurrentYear);
            } else {
                console.log(">>> ZMAPIM: FiscalYear already has value, skip default");
            }
        },

        /**
         * Khi user load Standard variant của SAP mà variant đó rỗng
         * -> auto fill năm hiện tại
         */
        _onAfterVariantLoad: function () {
            console.log(">>> ZMAPIM: _onAfterVariantLoad FIRED");

            if (!this._oSmartFilterBar) {
                return;
            }

            var oJSONData = this._oSmartFilterBar.getFilterData(true);
            var oSmartVariantManagement = this._oSmartFilterBar.getSmartVariant();

            if (!oSmartVariantManagement) {
                return;
            }

            var oCurrentVariant = oSmartVariantManagement.getVariantByKey(
                oSmartVariantManagement.getPresentVariantId()
            );

            var bShouldFill = oJSONData.FiscalYear
                && oJSONData.FiscalYear.ranges
                && oJSONData.FiscalYear.ranges.length === 0
                && oJSONData.FiscalYear.items
                && oJSONData.FiscalYear.items.length === 0
                && oCurrentVariant
                && oCurrentVariant.getAuthor() === "SAP";

            if (bShouldFill) {
                var sCurrentYear = "" + new Date().getFullYear();

                oJSONData.FiscalYear = {
                    items: [],
                    ranges: [{
                        exclude: false,
                        keyField: "FiscalYear",
                        operation: "EQ",
                        value1: sCurrentYear,
                        value2: null
                    }],
                    value: null
                };
                this._oSmartFilterBar.setFilterData(oJSONData);
                console.log(">>> ZMAPIM: Variant load - Set FiscalYear =", sCurrentYear);
            }
        }
    };
});