sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog"
], function (MessageToast, MessageBox, BusyDialog) {
    'use strict';

    // Entity set của bảng chính trên List Report (khớp manifest sap.ui.generic.app).
    var MAIN_ENTITY_SET = "zce_asset_kk";

    // Static action sinh file excel ở backend (zce_asset_kk.bdef → ExportExcel → zcl_ce_asset_kk_xlsx)
    var EXPORT_ACTION = "ExportExcel";

    // Tên file mặc định khi backend không trả tên
    var DEFAULT_FILE_NAME = "DuLieuKiemKeTaiSan";

    // Operator của sap.ui.model.Filter → sign / option của select-option
    var FILTER_OPERATORS = {
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

    return {
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
            hideStandardExport(this.getView());
        },
        exportExcel: function () {
            mainExport(this.getView());
        }
    };


    //////////////////////////////////////////////////////////////////////////
    // Ẩn nút Export chuẩn của SmartTable (export ở trình duyệt, gọi lại backend
    // nhiều lần) → chỉ còn 1 nút "Export" sinh file ở backend.
    //
    // Toolbar của SmartTable dựng xong sau khi load metadata → gắn vào sự kiện
    // "initialise" (và thử luôn 1 lần nếu đã dựng xong).
    function hideStandardExport(oView) {
        var oSmartTable = findMainSmartTable(oView);
        if (!oSmartTable || oSmartTable._bKkExportHidden) { return; }
        oSmartTable._bKkExportHidden = true;

        function hide() {
            var oToolbar = oSmartTable.getToolbar && oSmartTable.getToolbar();
            if (!oToolbar || !oToolbar.getContent) { return; }
            oToolbar.getContent().forEach(function (oControl) {
                var sId = oControl.getId() || "";
                if (/btnExcelExport$/.test(sId) || /-btnExcelExport-internalSplitBtn$/.test(sId)) {
                    oControl.setVisible(false);
                }
            });
        }

        oSmartTable.attachInitialise(hide);
        hide();
    }


    //////////////////////////////////////////////////////////////////////////
    // Main Logic Export Excel
    //
    // File xlsx sinh hoàn toàn ở backend (static action ExportExcel → zcl_ce_asset_kk_xlsx),
    // FE chỉ gửi filter + sort đang áp trên bảng rồi nhận file về (giống app Kế hoạch đóng cont).
    function mainExport(oView) {
        var oRaw = getRaw(oView);

        if (!oRaw) {
            MessageBox.warning("Vui lòng nhấn \"Go\" để tải dữ liệu trước khi Export");
            return;
        }
        if (!oRaw.totalLength) {
            MessageBox.warning("Không có dữ liệu để Export");
            return;
        }

        var oParam;
        try {
            oParam = buildExportParam(oRaw);
        } catch (oError) {
            MessageBox.error("Không đọc được filter trên màn hình.");
            return;
        }

        var oBusy = new BusyDialog({
            title: "Đang xuất Excel",
            text: "Đang tạo file Excel..."
        });
        oBusy.open();

        function closeBusy() {
            oBusy.close();
            oBusy.destroy();
        }

        oRaw.model.callFunction("/" + EXPORT_ACTION, {
            method: "POST",
            urlParameters: { JsonString: JSON.stringify(oParam) },
            success: function (oData) {
                closeBusy();
                var oFile = getExportFile(oData);
                if (!oFile || !oFile.FileContent) {
                    MessageBox.warning("Không có dữ liệu để Export");
                    return;
                }
                downloadFile(oFile);
                MessageToast.show("Export thành công!");
            },
            error: function (oError) {
                closeBusy();
                MessageBox.error("Lỗi export: " + getErrorMessage(oError));
            }
        });
    }


    //////////////////////////////////////////////////////////////////////////
    // Tìm SmartTable của bảng chính
    //
    // CHÚ Ý: view List Report còn chứa các value-help dialog (F4) của các field
    // filter dùng annotation ValueList (Nhóm tài sản, Phòng ban, Nhà máy, Mã tài sản...).
    // Các dialog này được dựng bằng SmartFilterBar + SmartTable riêng và gắn làm
    // dependent của control filter → vẫn nằm trong view tree. Sau khi user đã mở
    // 1 trong các F4 đó, findAggregatedObjects(true) có thể trả về SmartTable của
    // value help TRƯỚC SmartTable dữ liệu chính → phải lọc đúng SmartTable bind vào MAIN_ENTITY_SET.
    function findMainSmartTable(oView) {
        var aAll = oView.findAggregatedObjects(true);
        var oFound = null;

        for (var i = 0; i < aAll.length; i++) {
            if (aAll[i].getMetadata().getName() !== "sap.ui.comp.smarttable.SmartTable") {
                continue;
            }
            var oST = aAll[i];
            var sES = (oST.getEntitySet && oST.getEntitySet()) || "";
            var sTblPath = (oST.getTableBindingPath && oST.getTableBindingPath()) || "";
            var oInner = oST.getTable && oST.getTable();
            var oBnd = oInner && (oInner.getBinding("rows") || oInner.getBinding("items"));
            var sBndPath = oBnd ? (oBnd.getPath() || "") : "";

            var bMatch = sES === MAIN_ENTITY_SET
                || sTblPath === MAIN_ENTITY_SET || sTblPath === "/" + MAIN_ENTITY_SET
                || sBndPath === MAIN_ENTITY_SET || sBndPath === "/" + MAIN_ENTITY_SET;

            if (bMatch) {
                oFound = oST;
                if (oBnd) { break; }   // ưu tiên cái đã có binding
            }
        }
        return oFound;
    }

    // Lấy model + filter + sort đang áp trên bảng chính
    function getRaw(oView) {
        var oSmartTable = findMainSmartTable(oView);
        if (!oSmartTable) { return null; }

        var oTable = oSmartTable.getTable();
        var oBinding = oTable && (oTable.getBinding("rows") || oTable.getBinding("items"));
        if (!oBinding) { return null; }

        // Gộp cả application filters (từ SmartFilterBar) lẫn control filters (vd
        // filter trên header cột) để export đúng những gì đang hiển thị.
        var aFilters = []
            .concat(oBinding.aApplicationFilters || [])
            .concat(oBinding.aFilters || []);

        return {
            model: oBinding.getModel(),
            filters: aFilters,
            sorters: oBinding.aSorters || [],
            totalLength: oBinding.getLength()
        };
    }


    //////////////////////////////////////////////////////////////////////////
    // Filter + sort của bảng → tham số JsonString của action ExportExcel
    // (ty_export_param trong zbp_ce_asset_kk):
    // { filters: [{ name: "COMPANYCODE", range: [{ sign, option, low, high }] }],
    //   sort:    [{ name: "MATAISAN", descending: false }] }
    function buildExportParam(oRaw) {
        var oRanges = {};
        var aNames = [];
        oRaw.filters.forEach(function (oFilter) {
            collectFilter(oFilter, oRanges, aNames);
        });

        return {
            filters: aNames.map(function (sName) {
                return { name: sName, range: oRanges[sName] };
            }),
            sort: oRaw.sorters.map(function (oSorter) {
                return {
                    name: (oSorter.sPath || "").toUpperCase(),
                    descending: !!oSorter.bDescending
                };
            }).filter(function (oSort) {
                return !!oSort.name;
            })
        };
    }

    // Filter của bảng là cây lồng nhau (AND giữa các field, OR giữa các giá trị) → gom về
    // từng field, giống cách backend nhận filter khi query màn hình (get_as_ranges)
    function collectFilter(oFilter, oRanges, aNames) {
        if (!oFilter) { return; }
        var aSubFilters = oFilter.aFilters || (oFilter.getFilters && oFilter.getFilters());
        if (aSubFilters && aSubFilters.length) {
            aSubFilters.forEach(function (oSubFilter) {
                collectFilter(oSubFilter, oRanges, aNames);
            });
            return;
        }
        if (!oFilter.sPath) { return; }

        var oRange = toRange(oFilter);
        if (!oRange) { return; }

        var sName = oFilter.sPath.toUpperCase();
        if (!oRanges[sName]) {
            oRanges[sName] = [];
            aNames.push(sName);
        }
        oRanges[sName].push(oRange);
    }

    function toRange(oFilter) {
        var oOperator = FILTER_OPERATORS[oFilter.sOperator];
        if (!oOperator) { return null; }

        var sLow = toFilterValue(oFilter.oValue1);
        // Chỉ EQ / NE được phép để trống (điều kiện "<trống>" trên filter bar)
        if (!sLow && oOperator.option !== "EQ") { return null; }

        return {
            sign: oOperator.sign,
            option: oOperator.option,
            low: (oOperator.prefix || "") + sLow + (oOperator.suffix || ""),
            high: oOperator.option === "BT" ? toFilterValue(oFilter.oValue2) : ""
        };
    }

    // Ngày → YYYYMMDD. OData V2 có thể trả ngày dạng 00:00 UTC hoặc 00:00 giờ local
    // → cộng 12 tiếng rồi lấy theo UTC thì luôn ra đúng ngày user đã chọn.
    function toFilterValue(vValue) {
        if (vValue === null || vValue === undefined) { return ""; }
        if (vValue instanceof Date) {
            var oDate = new Date(vValue.getTime() + 12 * 3600 * 1000);
            return String(oDate.getUTCFullYear())
                + String(oDate.getUTCMonth() + 1).padStart(2, "0")
                + String(oDate.getUTCDate()).padStart(2, "0");
        }
        return String(vValue);
    }


    //////////////////////////////////////////////////////////////////////////
    // Kết quả action (complex type) → { MimeType, FileName, FileContent, FileExtension }
    function getExportFile(oData) {
        if (!oData) { return null; }
        if (oData[EXPORT_ACTION]) { return oData[EXPORT_ACTION]; }
        if (oData.results && oData.results.length) { return oData.results[0]; }
        return oData;
    }

    function decodeBase64(sBase64) {
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

    function downloadFile(oFile) {
        var sMimeType = oFile.MimeType || "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        var oBlob = new Blob([decodeBase64(oFile.FileContent)], { type: sMimeType });
        var sUrl = URL.createObjectURL(oBlob);
        var oLink = document.createElement("a");
        oLink.href = sUrl;
        oLink.download = (oFile.FileName || DEFAULT_FILE_NAME) + "." + (oFile.FileExtension || "xlsx");
        document.body.appendChild(oLink);
        oLink.click();
        document.body.removeChild(oLink);
        setTimeout(function () { URL.revokeObjectURL(sUrl); }, 1000);
    }

    // Lỗi trả về từ backend (failed / reported của action) → message hiển thị cho user
    function getErrorMessage(oError) {
        var sText = oError && oError.responseText;
        if (sText) {
            try {
                var oParsed = JSON.parse(sText);
                var oErr = oParsed.error || {};
                var aDetails = (oErr.innererror && oErr.innererror.errordetails) || [];
                if (aDetails.length && aDetails[0].message) {
                    return aDetails[0].message;
                }
                if (oErr.message && oErr.message.value) {
                    return oErr.message.value;
                }
            } catch (e) { /* responseText không phải JSON */ }
        }
        return (oError && oError.message) || "Có lỗi xảy ra";
    }
});
