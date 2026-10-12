sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog"
], function (ControllerExtension, MessageToast, MessageBox, BusyDialog) {
    "use strict";

    var ACTION_PATH = "/zce_sales_da/com.sap.gateway.srvd.zui_sales_da.v0001.ExportExcel(...)";

    // Các filter mà action ExportExcel nhận (ty_filter trong zbp_ce_sales_da)
    var FILTER_FIELDS = ["ToChucBanHang", "NgayChungTu", "SoToKhai", "DoiTuongCongNo", "MaVatTu", "BillingDocument"];
    var DATE_FIELDS = ["NgayChungTu"];

    // Operator của sap.ui.model.Filter → sign / option của select-option
    var OPERATORS = {
        EQ: { sign: "I", option: "EQ" },
        NE: { sign: "E", option: "EQ" },
        BT: { sign: "I", option: "BT" },
        NB: { sign: "E", option: "BT" },
        LT: { sign: "I", option: "LT" },
        LE: { sign: "I", option: "LE" },
        GT: { sign: "I", option: "GT" },
        GE: { sign: "I", option: "GE" },
        Contains: { sign: "I", option: "CP", prefix: "*", suffix: "*" },
        NotContains: { sign: "E", option: "CP", prefix: "*", suffix: "*" },
        StartsWith: { sign: "I", option: "CP", suffix: "*" },
        NotStartsWith: { sign: "E", option: "CP", suffix: "*" },
        EndsWith: { sign: "I", option: "CP", prefix: "*" },
        NotEndsWith: { sign: "E", option: "CP", prefix: "*" }
    };

    // Ngày → YYYYMMDD, còn lại giữ nguyên dạng chuỗi
    function _toValue(vValue, bDate) {
        if (vValue === null || vValue === undefined) {
            return "";
        }
        if (vValue instanceof Date) {
            return String(vValue.getFullYear())
                + String(vValue.getMonth() + 1).padStart(2, "0")
                + String(vValue.getDate()).padStart(2, "0");
        }
        var sValue = String(vValue);
        if (bDate) {
            // Edm.Date của OData V4: YYYY-MM-DD
            return sValue.substring(0, 10).replace(/-/g, "");
        }
        return sValue;
    }

    function _toRange(oFilter, sPath) {
        var sOperator = oFilter.getOperator ? oFilter.getOperator() : oFilter.sOperator;
        var oOperator = OPERATORS[sOperator];
        if (!oOperator) {
            return null;
        }
        var bDate = DATE_FIELDS.indexOf(sPath) >= 0;
        var sLow = _toValue(oFilter.getValue1 ? oFilter.getValue1() : oFilter.oValue1, bDate);
        if (!sLow) {
            return null;
        }
        return {
            sign: oOperator.sign,
            option: oOperator.option,
            low: (oOperator.prefix || "") + sLow + (oOperator.suffix || ""),
            high: oOperator.option === "BT" ? _toValue(oFilter.getValue2 ? oFilter.getValue2() : oFilter.oValue2, bDate) : ""
        };
    }

    // Filter của filter bar là cây lồng nhau → gom về từng field
    function _collect(oFilter, oResult) {
        if (!oFilter) {
            return;
        }
        var aSubFilters = oFilter.getFilters ? oFilter.getFilters() : oFilter.aFilters;
        if (aSubFilters && aSubFilters.length) {
            aSubFilters.forEach(function (oSubFilter) {
                _collect(oSubFilter, oResult);
            });
            return;
        }
        var sPath = oFilter.getPath ? oFilter.getPath() : oFilter.sPath;
        if (!sPath || !oResult[sPath]) {
            return;
        }
        var oRange = _toRange(oFilter, sPath);
        if (oRange) {
            oResult[sPath].push(oRange);
        }
    }

    function _decodeBase64(sBase64) {
        var sValue = (sBase64 || "").replace(/_/g, "/").replace(/-/g, "+");
        var iPad = sValue.length % 4;
        if (iPad) {
            sValue += "=".repeat(4 - iPad);
        }
        var sBinary = atob(sValue);
        var aBytes = new Uint8Array(sBinary.length);
        for (var i = 0; i < sBinary.length; i++) {
            aBytes[i] = sBinary.charCodeAt(i);
        }
        return aBytes;
    }

    return ControllerExtension.extend("zsalesdaov4.ext.controller.ListReportExt", {

        // Filter đang chọn trên filter bar → { Field: [{ sign, option, low, high }] }
        _getFilter: function () {
            var oResult = {};
            FILTER_FIELDS.forEach(function (sField) {
                oResult[sField] = [];
            });
            var oFilterInfo = this.base.getExtensionAPI().getFilters() || {};
            (oFilterInfo.filters || []).forEach(function (oFilter) {
                _collect(oFilter, oResult);
            });
            return oResult;
        },

        _download: function (oFile) {
            var sMimeType = oFile.MimeType || "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            var oBlob = new Blob([_decodeBase64(oFile.FileContent)], { type: sMimeType });
            var sUrl = URL.createObjectURL(oBlob);
            var oLink = document.createElement("a");
            oLink.href = sUrl;
            oLink.download = (oFile.FileName || "BaoCaoDoanhThuDa") + "." + (oFile.FileExtension || "xlsx");
            document.body.appendChild(oLink);
            oLink.click();
            document.body.removeChild(oLink);
            setTimeout(function () { URL.revokeObjectURL(sUrl); }, 1000);
        },

        // File xlsx sinh hoàn toàn ở backend (zcl_ce_sales_da_xlsx), FE chỉ gửi filter rồi nhận file
        exportExcel: function () {
            var that = this;
            var oFilter;

            try {
                oFilter = this._getFilter();
            } catch (oError) {
                MessageBox.error("Không đọc được filter trên màn hình.");
                return;
            }

            if (!oFilter.ToChucBanHang.length || !oFilter.NgayChungTu.length) {
                MessageBox.error("Vui lòng nhập Tổ chức bán hàng và Ngày chứng từ");
                return;
            }

            var oModel = this.base.getExtensionAPI().getModel();
            var oOperation = oModel.bindContext(ACTION_PATH);
            oOperation.setParameter("JsonString", JSON.stringify(oFilter));

            var oBusy = new BusyDialog({ text: "Đang export..." });
            oBusy.open();

            (oOperation.invoke ? oOperation.invoke() : oOperation.execute()).then(function () {
                oBusy.close();
                var oFile = oOperation.getBoundContext().getObject();
                if (!oFile || !oFile.FileContent) {
                    MessageBox.warning("Không có dữ liệu để export");
                    return;
                }
                that._download(oFile);
                MessageToast.show("Export thành công!");
            }).catch(function (oError) {
                oBusy.close();
                MessageBox.error(oError && oError.message ? oError.message : "Đã xảy ra lỗi khi export Excel.");
            });
        }
    });
});
