sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (MessageToast, MessageBox) {
    'use strict';

    // Static action của zce_sales_report_exp (BDEF) → function import trong service OData V2
    var EXPORT_ACTION = "ExportExcel";
    var XLSX_MIME_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    // Filter gửi xuống BE trong json_string (xem ty_filter trong zbp_ce_sales_report_exp)
    var FILTER_FIELDS = ["CompanyCode", "FiscalYear", "Plant", "Product", "SalesDistrict"];
    // Filter kiểu ngày (date range): gửi xuống dạng YYYYMMDD
    var DATE_FILTER_FIELD = "PostingDate";

    function _rangeFromCondition(oRange) {
        var sSign = oRange.exclude ? "E" : "I";
        var sLow = oRange.value1 == null ? "" : String(oRange.value1);
        var sHigh = oRange.value2 == null ? "" : String(oRange.value2);

        switch (oRange.operation) {
            case "Contains":
                return { sign: sSign, option: "CP", low: "*" + sLow + "*", high: "" };
            case "StartsWith":
                return { sign: sSign, option: "CP", low: sLow + "*", high: "" };
            case "EndsWith":
                return { sign: sSign, option: "CP", low: "*" + sLow, high: "" };
            default:
                // EQ, BT, LT, LE, GT, GE dùng chung tên với option của ABAP
                return { sign: sSign, option: oRange.operation, low: sLow, high: sHigh };
        }
    }

    // Đổi giá trị 1 field của SmartFilterBar.getFilterData() thành bảng range sign/option/low/high
    function _toRanges(vValue) {
        if (vValue === undefined || vValue === null || vValue === "") {
            return [];
        }

        // Single value
        if (typeof vValue !== "object") {
            return [{ sign: "I", option: "EQ", low: String(vValue), high: "" }];
        }

        // Interval: { low, high }, hoặc low = "1-3" khi nhập tay
        if (vValue.low !== undefined) {
            var sLow = vValue.low == null ? "" : String(vValue.low);
            var sHigh = vValue.high == null ? "" : String(vValue.high);
            if (!sHigh && sLow.indexOf("-") > 0) {
                var aParts = sLow.split("-");
                sLow = aParts[0].trim();
                sHigh = aParts[1].trim();
            }
            if (!sLow) {
                return [];
            }
            return [{ sign: "I", option: sHigh ? "BT" : "EQ", low: sLow, high: sHigh }];
        }

        // Multiple values: { items: [{ key }], ranges: [{ exclude, operation, value1, value2 }] }
        var aRanges = [];
        (vValue.items || []).forEach(function (oItem) {
            aRanges.push({ sign: "I", option: "EQ", low: String(oItem.key), high: "" });
        });
        (vValue.ranges || []).forEach(function (oRange) {
            aRanges.push(_rangeFromCondition(oRange));
        });
        return aRanges;
    }

    function _pad(iValue) {
        return (iValue < 10 ? "0" : "") + iValue;
    }

    // Date → "YYYYMMDD"
    // SmartFilterBar có thể trả ngày theo giờ local hoặc đã quy về UTC (00:00:00 / 23:59:59 UTC)
    // → nếu giờ UTC rơi đúng đầu / cuối ngày thì lấy ngày theo UTC, ngược lại lấy theo local
    function _toAbapDate(vDate) {
        if (!(vDate instanceof Date) || isNaN(vDate.getTime())) {
            return "";
        }
        var iUtcSeconds = vDate.getUTCHours() * 3600 + vDate.getUTCMinutes() * 60 + vDate.getUTCSeconds();
        if (iUtcSeconds === 0 || iUtcSeconds === 86399) {
            return vDate.getUTCFullYear() + _pad(vDate.getUTCMonth() + 1) + _pad(vDate.getUTCDate());
        }
        return vDate.getFullYear() + _pad(vDate.getMonth() + 1) + _pad(vDate.getDate());
    }

    // Lấy các filter lá của 1 field từ cây sap.ui.model.Filter
    function _collectFilters(aFilters, sPath, aResult) {
        (aFilters || []).forEach(function (oFilter) {
            if (oFilter.aFilters) {
                _collectFilters(oFilter.aFilters, sPath, aResult);
            } else if (oFilter.sPath === sPath) {
                aResult.push(oFilter);
            }
        });
        return aResult;
    }

    // Khoảng ngày đang chọn (Year to Date, From / To, Today...) đã được SmartFilterBar đổi ra ngày cụ thể
    function _dateRanges(oSmartFilterBar, sField) {
        var aRanges = [];
        _collectFilters(oSmartFilterBar.getFilters([sField]), sField, []).forEach(function (oFilter) {
            var sLow = _toAbapDate(oFilter.oValue1);
            var sHigh = _toAbapDate(oFilter.oValue2);
            if (!sLow) {
                return;
            }
            // EQ, BT, LT, LE, GT, GE dùng chung tên với option của ABAP
            aRanges.push({ sign: "I", option: oFilter.sOperator, low: sLow, high: sHigh });
        });
        return aRanges;
    }

    function _buildFilterJson(oSmartFilterBar) {
        var oFilterData = oSmartFilterBar.getFilterData() || {};
        var mFilter = {};
        FILTER_FIELDS.forEach(function (sField) {
            mFilter[sField] = _toRanges(oFilterData[sField]);
        });
        mFilter[DATE_FILTER_FIELD] = _dateRanges(oSmartFilterBar, DATE_FILTER_FIELD);
        return JSON.stringify(mFilter);
    }

    function _saveFile(sBase64, sFileName, sMimeType) {
        // OData V2 trả Edm.Binary dạng base64; đổi luôn base64url nếu có
        var sBinary = atob(sBase64.replace(/-/g, "+").replace(/_/g, "/"));
        var aBytes = new Uint8Array(sBinary.length);
        for (var i = 0; i < sBinary.length; i++) {
            aBytes[i] = sBinary.charCodeAt(i);
        }
        var sUrl = URL.createObjectURL(new Blob([aBytes], { type: sMimeType }));
        var oLink = document.createElement("a");
        oLink.href = sUrl;
        oLink.download = sFileName;
        oLink.click();
        URL.revokeObjectURL(sUrl);
    }

    function _getErrorText(oError) {
        try {
            return JSON.parse(oError.responseText).error.message.value;
        } catch (e) {
            return (oError && oError.message) || "Export không thành công";
        }
    }

    return {
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },

        // Nút "Export": BE lấy dữ liệu theo filter và sinh file xlsx, FE chỉ lưu file
        exportExcel: function () {
            var oView = this.getView();
            var oSmartFilterBar = oView.byId("listReportFilter");

            if (!oSmartFilterBar) {
                MessageBox.error("Không tìm thấy filter bar");
                return;
            }

            oView.setBusy(true);
            oView.getModel().callFunction("/" + EXPORT_ACTION, {
                method: "POST",
                urlParameters: {
                    json_string: _buildFilterJson(oSmartFilterBar)
                },
                success: function (oData) {
                    oView.setBusy(false);
                    var oFile = (oData && oData[EXPORT_ACTION]) || oData;
                    if (!oFile || !oFile.fileContent) {
                        MessageBox.error("Không có dữ liệu để export");
                        return;
                    }
                    _saveFile(
                        oFile.fileContent,
                        (oFile.fileName || "BaoCaoBanHang") + "." + (oFile.fileExtension || "xlsx"),
                        oFile.mimeType || XLSX_MIME_TYPE
                    );
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
