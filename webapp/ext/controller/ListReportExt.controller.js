sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (MessageToast, MessageBox) {
    'use strict';

    // ─────────────────────────────────────────────
    // 1. LẤY SMART TABLE
    // ─────────────────────────────────────────────
    function _getSmartTable(oView) {
        var aAllControls = oView.findAggregatedObjects(true);
        return aAllControls.filter(function (o) {
            return o.getMetadata().getName() === "sap.ui.comp.smarttable.SmartTable";
        })[0];
    }

    // ─────────────────────────────────────────────
    // 2. LẤY DATA TỪ SMART TABLE
    // ─────────────────────────────────────────────
    function _getTableData(oView) {
        var oSmartTable = _getSmartTable(oView);
        if (!oSmartTable) return [];

        var oTable = oSmartTable.getTable();
        var oBinding = oTable.getBinding("rows");
        if (!oBinding) return [];

        var iLength = oBinding.getLength();
        var aContexts = oBinding.getContexts(0, iLength);
        return aContexts.map(function (oCtx) { return oCtx.getObject(); });
    }

    // ─────────────────────────────────────────────
    // 3. PARSE DATE - tránh timezone shift
    // ─────────────────────────────────────────────
    function _parseDate(sISO) {
        if (!sISO) return "";

        var oDate;
        if (typeof sISO === "string") {
            // Nếu là ISO string: lấy trực tiếp phần date
            var sPart = sISO.substring(0, 10); // "2026-03-31"
            var aParts = sPart.split("-");
            return aParts[2] + "/" + aParts[1] + "/" + aParts[0];
        } else if (sISO instanceof Date) {
            // Nếu là Date object
            oDate = sISO;
        } else {
            oDate = new Date(sISO);
        }

        var dd = String(oDate.getDate()).padStart(2, "0");
        var mm = String(oDate.getMonth() + 1).padStart(2, "0");
        var yyyy = oDate.getFullYear();
        return dd + "/" + mm + "/" + yyyy;
    }

    // ─────────────────────────────────────────────
    // 4. LẤY FILTER DATA
    // ─────────────────────────────────────────────
    function _getFilterData(oView) {
        var oResult = { dateFrom: "", dateTo: "", companyName: "", companyAddress: "" };
        var oSFB = oView.byId("listReportFilter");
        if (!oSFB) return oResult;

        var oFD = oSFB.getFilterData();
        var oPostingDate = oFD.PostingDate;

        if (oPostingDate && oPostingDate.ranges && oPostingDate.ranges.length > 0) {
            var oRange = oPostingDate.ranges[0];

            // Phân biệt các case filter
            if (oRange.operation === "BT" || oRange.keyField === "BT") {
                // Between: có cả từ và đến
                oResult.dateFrom = _parseDate(oRange.value1);
                oResult.dateTo = _parseDate(oRange.value2);
            } else if (oRange.operation === "LE" || !oRange.value1) {
                // To date only
                oResult.dateFrom = "";
                oResult.dateTo = _parseDate(oRange.value2 || oRange.value1);
            } else if (oRange.operation === "GE") {
                // From date only
                oResult.dateFrom = _parseDate(oRange.value1);
                oResult.dateTo = "";
            } else {
                // Default
                oResult.dateFrom = _parseDate(oRange.value1);
                oResult.dateTo = _parseDate(oRange.value2);
            }
        }

        return oResult;
    }

    // ─────────────────────────────────────────────
    // 5. LẤY TÊN CÔNG TY QUA ODATA
    // ─────────────────────────────────────────────
    function _getCompanyName(oView, fnCallback) {
        var sCompanyName = "";
        var sCC = "";
        var oSFB = oView.byId("listReportFilter");

        if (oSFB) {
            try {
                var oField = oSFB.getControlByKey("CompanyCode");
                if (oField && oField.getTokens) {
                    var aTokens = oField.getTokens();
                    if (aTokens.length > 0) {
                        var sText = aTokens[0].getText();
                        var match = sText.match(/\((.+)\)/);
                        sCompanyName = match ? match[1] : sText;
                        sCC = aTokens[0].getKey ? aTokens[0].getKey() : "";
                    }
                }
            } catch (e) { }

            if (!sCC) {
                sCC = oSFB.getFilterData().CompanyCode || "";
            }
        }

        if (!sCC) {
            fnCallback({ name: sCompanyName, address: "" });
            return;
        }

        var oModel = oView.getModel();
        oModel.read("/ZI_COMPANYCODE_VH('" + sCC + "')", {
            success: function (oData) {
                fnCallback({
                    name: sCompanyName || oData.CompanyCodeName || "",
                    address: oData.CityName
                        ? "Địa chỉ: " + oData.CityName + ", Việt Nam"
                        : ""
                });
            },
            error: function () {
                fnCallback({ name: sCompanyName, address: "" });
            }
        });
    }
    // ─────────────────────────────────────────────
    // 6. ẨN BUTTON EXPORT CHUẨN CỦA SAP
    // ─────────────────────────────────────────────
    function _hideDefaultExportButton(oView) {
        // var aAllControls = oView.findAggregatedObjects(true);
        // aAllControls.forEach(function (o) {
        //     var sName = o.getMetadata().getName();
        //     var sId = o.getId ? o.getId() : "";

        //     // Ẩn toàn bộ MenuButton Export chuẩn
        //     if (sName === "sap.m.MenuButton") {
        //         if (sId.indexOf("btnExcelExport") >= 0) {
        //             o.setVisible(false);
        //             // Ẩn luôn DOM element để tránh arrow button còn sót
        //             var oDom = o.getDomRef ? o.getDomRef() : null;
        //             if (oDom && oDom.parentElement) {
        //                 oDom.parentElement.style.display = "none";
        //             }
        //             return;
        //         }
        //     }

        //     // Ẩn arrow button còn sót của btnExcelExport
        //     if (sName === "sap.m.Button") {
        //         if (sId.indexOf("exportExcelButton") >= 0) {
        //             return;
        //         }
        //         if (sId.indexOf("btnExcelExport") >= 0) {
        //             o.setVisible(false);
        //             return;
        //         }
        //         var sIcon = o.getIcon ? o.getIcon() : "";
        //         var sTooltip = o.getTooltip ? o.getTooltip() : "";
        //         if (
        //             sIcon === "sap-icon://excel-attachment" ||
        //             (sTooltip && sTooltip.toLowerCase().indexOf("export") >= 0)
        //         ) {
        //             o.setVisible(false);
        //         }
        //     }

        //     // Ẩn ToolbarSeparator
        //     if (sName === "sap.m.ToolbarSeparator") {
        //         var oParent = o.getParent && o.getParent();
        //         if (oParent && oParent.getId && oParent.getId().indexOf("toolbar") >= 0) {
        //             o.setVisible(false);
        //         }
        //     }
        // });
    }

    // ─────────────────────────────────────────────
    // 6. TÍNH % VÀ UPDATE MODEL
    // ─────────────────────────────────────────────
    function _calcPercentage(oTable) {
        var oBinding = oTable.getBinding("rows");
        if (!oBinding) return;

        var iLength = oBinding.getLength();
        var aContexts = oBinding.getContexts(0, iLength);

        // Chỉ tính tổng các dòng dương
        var grandVND = aContexts.reduce(function (s, ctx) {
            var v = parseFloat(ctx.getObject().RevenueVND || 0);
            return s + (v > 0 ? v : 0);
        }, 0);

        aContexts.forEach(function (ctx) {
            var revVND = parseFloat(ctx.getObject().RevenueVND || 0);
            var pct;
            if (revVND <= 0 || grandVND <= 0) {
                pct = "0.00%";
            } else {
                pct = (revVND / grandVND * 100).toFixed(2) + "%";
            }
            ctx.getModel().setProperty(ctx.getPath() + "/Percentage", pct);
        });
    }

    // ─────────────────────────────────────────────
    // 7. BUILD EXCEL
    // ─────────────────────────────────────────────
    function _buildExcel(aData, oFilterData) {
        var workbook = new ExcelJS.Workbook();
        var worksheet = workbook.addWorksheet("Báo cáo bán hàng");

        var GREEN = { argb: "FF00B050" };
        var BORDER = {
            top: { style: "thin" },
            left: { style: "thin" },
            bottom: { style: "thin" },
            right: { style: "thin" }
        };
        var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };

        // Row 1: Tên công ty
        worksheet.mergeCells("A1:H1");
        var r1 = worksheet.getCell("A1");
        r1.value = oFilterData.companyName || "";
        r1.alignment = { horizontal: "center" };

        // Row 2: Địa chỉ
        worksheet.mergeCells("A2:H2");
        var r2 = worksheet.getCell("A2");
        r2.value = oFilterData.companyAddress || "";
        r2.alignment = { horizontal: "center" };

        // Row 3: Trống
        worksheet.addRow([]);

        // Row 4: Tiêu đề
        worksheet.mergeCells("A4:H4");
        var titleCell = worksheet.getCell("A4");
        titleCell.value = "Doanh số bán hàng theo loại khách hàng và mặt hàng";
        titleCell.font = { bold: true, size: 16, name: "Cambria" };
        titleCell.alignment = CENTER;
        worksheet.getRow(4).height = 25;

        // Row 5: Thời gian
        var sDateLine = "";
        if (oFilterData.dateFrom && oFilterData.dateTo) {
            sDateLine = "Từ ngày " + oFilterData.dateFrom + " Đến ngày " + oFilterData.dateTo;
        } else if (oFilterData.dateTo) {
            sDateLine = "Đến ngày " + oFilterData.dateTo;
        } else if (oFilterData.dateFrom) {
            sDateLine = "Từ ngày " + oFilterData.dateFrom + " Đến ngày " + oFilterData.dateFrom;
        }

        worksheet.mergeCells("A5:H5");
        var r5 = worksheet.getCell("A5");
        r5.value = sDateLine;
        r5.alignment = { horizontal: "center" };

        // Row 6, 7: Trống
        worksheet.addRow([]);
        worksheet.addRow([]);

        // Row 8: Header
        var aHeaders = [
            "STT", "Đơn vị khách hàng", "Loại hàng",
            "Doanh số USD", "Doanh số VND",
            "Số lượng", "Thị Trường", "Phần trăm"
        ];
        var oHeaderRow = worksheet.getRow(8);
        oHeaderRow.height = 35;
        aHeaders.forEach(function (h, i) {
            var oCell = oHeaderRow.getCell(i + 1);
            oCell.value = h;
            oCell.fill = { type: "pattern", pattern: "solid", fgColor: GREEN };
            oCell.font = { bold: true, color: { argb: "FFFFFFFF" } };
            oCell.border = BORDER;
            oCell.alignment = CENTER;
        });

        // Chỉ tính tổng dòng dương
        var grandVND = aData.reduce(function (s, d) {
            var v = parseFloat(d.RevenueVND || 0);
            return s + (v > 0 ? v : 0);
        }, 0);

        // Data rows
        var totalUSD = 0, totalVND = 0, totalQty = 0;

        aData.forEach(function (item, idx) {
            var revUSD = parseFloat(item.RevenueUSD || 0);
            var revVND = parseFloat(item.RevenueVND || 0);
            var qty = parseFloat(item.NetQuantity || 0);
            var pct;
            if (revVND <= 0 || grandVND <= 0) {
                pct = "0.00%";
            } else {
                pct = (revVND / grandVND * 100).toFixed(2) + "%";
            }

            var customerDisplay = item.CustomerName
                ? item.Customer + " (" + item.CustomerName + ")"
                : (item.Customer || "");
            var productGrpDisplay = item.ProductGroupName
                ? item.ProductGroup + " (" + item.ProductGroupName + ")"
                : (item.ProductGroup || "");
            var districtDisplay = item.SalesDistrictName
                ? item.SalesDistrict + " (" + item.SalesDistrictName + ")"
                : (item.SalesDistrict || "");

            var oRow = worksheet.addRow([
                idx + 1,
                customerDisplay,
                productGrpDisplay,
                revUSD,
                revVND,
                qty,
                districtDisplay,
                pct
            ]);

            oRow.getCell(4).numFmt = "#,##0.00";
            oRow.getCell(5).numFmt = "#,##0.00";
            oRow.getCell(6).numFmt = "#,##0.000";
            oRow.getCell(8).alignment = { horizontal: "right" };
            oRow.eachCell(function (cell) { cell.border = BORDER; });

            totalUSD += revUSD;
            totalVND += revVND;
            totalQty += qty;
        });

        // Total row — % tổng chỉ tính trên dòng dương, không phải 100% tuyệt đối
        var oTotalRow = worksheet.addRow([
            "Cộng", "", "", totalUSD, totalVND, totalQty, "", "100.00%"
        ]);
        oTotalRow.eachCell(function (cell) {
            cell.fill = { type: "pattern", pattern: "solid", fgColor: GREEN };
            cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
            cell.border = BORDER;
            cell.alignment = CENTER;
        });
        oTotalRow.getCell(4).numFmt = "#,##0.00";
        oTotalRow.getCell(5).numFmt = "#,##0.00";
        oTotalRow.getCell(6).numFmt = "#,##0.000";

        // Column widths
        worksheet.columns = [
            { width: 6 },
            { width: 40 },
            { width: 20 },
            { width: 18 },
            { width: 22 },
            { width: 14 },
            { width: 20 },
            { width: 12 }
        ];

        // Download
        workbook.xlsx.writeBuffer().then(function (buffer) {
            var blob = new Blob([buffer], {
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            });
            var url = URL.createObjectURL(blob);
            var link = document.createElement("a");
            link.href = url;
            link.download = "DoanhSoBanHang_"
                + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
                + ".xlsx";
            link.click();
            URL.revokeObjectURL(url);
            MessageToast.show("Export thành công!");
        });
    }

    // ─────────────────────────────────────────────
    // 8. MAIN EXPORT
    // ─────────────────────────────────────────────
    function _doExport(oView) {
        var aData = _getTableData(oView);
        if (!aData.length) {
            MessageBox.error("Không có dữ liệu để export");
            return;
        }

        var oFilterData = _getFilterData(oView);

        _getCompanyName(oView, function (oInfo) {
            oFilterData.companyName = oInfo.name;
            oFilterData.companyAddress = oInfo.address;
            _buildExcel(aData, oFilterData);
        });
    }

    // ─────────────────────────────────────────────
    // 9. CONTROLLER EXTENSION
    // ─────────────────────────────────────────────
    return {

        onAfterRendering: function () {
            var oView = this.getView();
            var oSmartTable = _getSmartTable(oView);
            if (!oSmartTable) return;

            var oTable = oSmartTable.getTable();

            // ── THÊM ICON CHO BUTTON EXPORT ──
            setTimeout(function () {
                var aAllControls = oView.findAggregatedObjects(true);
                aAllControls.forEach(function (o) {
                    var sId = o.getId ? o.getId() : "";
                    if (sId.indexOf("exportExcelButton") >= 0) {
                        if (o.setIcon) o.setIcon("sap-icon://excel-attachment");
                    }
                });
            }, 1500); // cùng timeout với _hideDefaultExportButton

            // // Ẩn button Export chuẩn sau khi toolbar render xong
            // setTimeout(function () {
            //     _hideDefaultExportButton(oView);
            // }, 1500);

            // Tính % + ẩn lại button mỗi lần data load
            oSmartTable.attachDataReceived(function () {
                _calcPercentage(oTable);
                // setTimeout(function () {
                //     _hideDefaultExportButton(oView);
                // }, 500);
            });
        },
        exportExcel: function () {
            var oView = this.getView();

            if (window.ExcelJS) {
                _doExport(oView);
                return;
            }

            var script = document.createElement("script");
            script.src = sap.ui.require.toUrl("zcpsalesrp/libs/exceljs.min.js");
            script.onload = function () { _doExport(oView); };
            script.onerror = function () {
                MessageBox.error("Không load được ExcelJS library");
            };
            document.head.appendChild(script);
        }
    };
});