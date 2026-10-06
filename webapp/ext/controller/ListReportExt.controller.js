sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (MessageToast, MessageBox) {
    'use strict';

    // Các filter mà action ExportExcel nhận (ty_filter trong zbp_ce_sales_report_exp)
    var FILTER_FIELDS = ["CompanyCode", "PostingDate", "Plant", "Product", "SalesDistrict"];

    // Operation của SmartFilterBar → option của select-option
    var OPTIONS = {
        EQ: "EQ", BT: "BT", LT: "LT", LE: "LE", GT: "GT", GE: "GE",
        Contains: "CP", StartsWith: "CP", EndsWith: "CP"
    };

    // Date → YYYYMMDD, còn lại giữ nguyên dạng chuỗi
    function _toValue(vValue) {
        if (vValue instanceof Date) {
            return String(vValue.getFullYear())
                + String(vValue.getMonth() + 1).padStart(2, "0")
                + String(vValue.getDate()).padStart(2, "0");
        }
        return vValue === null || vValue === undefined ? "" : String(vValue);
    }

    function _toRange(oRange) {
        var sOption = OPTIONS[oRange.operation];
        var sLow = _toValue(oRange.value1);
        if (!sOption || !sLow) {
            return null;
        }
        if (oRange.operation === "Contains") {
            sLow = "*" + sLow + "*";
        } else if (oRange.operation === "StartsWith") {
            sLow = sLow + "*";
        } else if (oRange.operation === "EndsWith") {
            sLow = "*" + sLow;
        }
        return {
            sign: oRange.exclude ? "E" : "I",
            option: sOption,
            low: sLow,
            high: sOption === "BT" ? _toValue(oRange.value2) : ""
        };
    }

    // Giá trị 1 field trong getFilterData() → bảng range [{ sign, option, low, high }]
    function _toRanges(vFilter) {
        if (vFilter === null || vFilter === undefined || vFilter === "") {
            return [];
        }
        // Single value
        if (typeof vFilter !== "object" || vFilter instanceof Date) {
            return [{ sign: "I", option: "EQ", low: _toValue(vFilter), high: "" }];
        }
        // Interval
        if (vFilter.low !== undefined && !vFilter.ranges) {
            var sLow = _toValue(vFilter.low);
            var sHigh = _toValue(vFilter.high);
            if (!sLow) {
                return [];
            }
            return [{ sign: "I", option: sHigh ? "BT" : "EQ", low: sLow, high: sHigh }];
        }
        // Multi value / date range
        var aRanges = (vFilter.items || []).map(function (oItem) {
            return { sign: "I", option: "EQ", low: _toValue(oItem.key), high: "" };
        });
        (vFilter.ranges || []).forEach(function (oRange) {
            var oResult = _toRange(oRange);
            if (oResult) {
                aRanges.push(oResult);
            }
        });
        return aRanges;
    }

    function _getFilter(oView) {
        var oSmartFilterBar = oView.byId("listReportFilter");
        var oFilterData = oSmartFilterBar ? oSmartFilterBar.getFilterData() : {};
        var oFilter = {};
        FILTER_FIELDS.forEach(function (sField) {
            oFilter[sField] = _toRanges(oFilterData[sField]);
        });
        return oFilter;
    }

    function _download(oFile) {
        var sBinary = atob(oFile.fileContent);
        var aBytes = new Uint8Array(sBinary.length);
        for (var i = 0; i < sBinary.length; i++) {
            aBytes[i] = sBinary.charCodeAt(i);
        }
        var blob = new Blob([aBytes], { type: oFile.mimeType });
        var url = URL.createObjectURL(blob);
        var link = document.createElement("a");
        link.href = url;
        link.download = oFile.fileName + "." + oFile.fileExtension;
        link.click();
        URL.revokeObjectURL(url);
    }

    function _getErrorText(oError) {
        try {
            return JSON.parse(oError.responseText).error.message.value;
        } catch (e) {
            return oError.message || "Export thất bại";
        }
    }

    return {
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },

        exportExcel: function () {
            var oView = this.getView();
            var oModel = oView.getModel();

            if (!oModel.getMetaModel().getODataFunctionImport("ExportExcel")) {
                MessageBox.error("Service chưa có action ExportExcel");
                return;
            }

            var oFilter = _getFilter(oView);
            if (!oFilter.CompanyCode.length || !oFilter.PostingDate.length) {
                MessageBox.error("Vui lòng nhập Company Code và Posting Date");
                return;
            }

            oView.setBusy(true);
            oModel.callFunction("/ExportExcel", {
                method: "POST",
                urlParameters: { json_string: JSON.stringify(oFilter) },
                success: function (oData) {
                    oView.setBusy(false);
                    var oFile = oData && (oData.ExportExcel || oData);
                    if (!oFile || !oFile.fileContent) {
                        MessageBox.error("Không có dữ liệu để export");
                        return;
                    }
                    _download(oFile);
                    MessageToast.show("Export thành công!");
                },
                error: function (oError) {
                    oView.setBusy(false);
                    MessageBox.error(_getErrorText(oError));
                }
            });
        }
    };
});
