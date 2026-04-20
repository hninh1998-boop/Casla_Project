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
            var sPart = sISO.substring(0, 10);
            var aParts = sPart.split("-");
            return aParts[2] + "/" + aParts[1] + "/" + aParts[0];
        } else if (sISO instanceof Date) {
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
            oResult.dateFrom = _parseDate(oRange.value1);
            oResult.dateTo = _parseDate(oRange.value2);
            if (!oResult.dateTo) {
                oResult.dateTo = oResult.dateFrom;
            }
        }

        return oResult;
    }

    // ─────────────────────────────────────────────
    // 5. LẤY TÊN CÔNG TY QUA ODATA
    // ─────────────────────────────────────────────
    function _getCompanyName(oView, fnCallback) {
        var oSFB = oView.byId("listReportFilter");
        var sCC = oSFB ? oSFB.getFilterData().CompanyCode : "";

        if (!sCC) {
            fnCallback({ name: "", address: "" });
            return;
        }

        var oModel = oView.getModel();
        oModel.read("/ZI_COMPANYCODE_VH('" + sCC + "')", {
            success: function (oData) {
                fnCallback({
                    name: oData.CompanyCodeName || "",
                    address: oData.CityName ? "Dia chi : " + oData.CityName : ""
                });
            },
            error: function () {
                fnCallback({ name: "", address: "" });
            }
        });
    }

    // ─────────────────────────────────────────────
    // 6. ẨN BUTTON EXPORT CHUẨN CỦA SAP
    // ─────────────────────────────────────────────
    function _hideDefaultExportButton(oView) {
        var aAllControls = oView.findAggregatedObjects(true);
        aAllControls.forEach(function (o) {
            var sName = o.getMetadata().getName();
            var sId = o.getId ? o.getId() : "";

            if (sName === "sap.m.MenuButton") {
                if (sId.indexOf("btnExcelExport") >= 0) {
                    o.setVisible(false);
                    var oDom = o.getDomRef ? o.getDomRef() : null;
                    if (oDom && oDom.parentElement) {
                        oDom.parentElement.style.display = "none";
                    }
                    return;
                }
            }

            if (sName === "sap.m.Button") {
                if (sId.indexOf("exportExcelButton") >= 0) return;
                if (sId.indexOf("ExportPDFButton") >= 0) return;
                if (sId.indexOf("btnExcelExport") >= 0) {
                    o.setVisible(false);
                    return;
                }
                var sIcon = o.getIcon ? o.getIcon() : "";
                var sTooltip = o.getTooltip ? o.getTooltip() : "";
                if (
                    sIcon === "sap-icon://excel-attachment" ||
                    (sTooltip && sTooltip.toLowerCase().indexOf("export") >= 0)
                ) {
                    o.setVisible(false);
                }
            }

            if (sName === "sap.m.ToolbarSeparator") {
                var oParent = o.getParent && o.getParent();
                if (oParent && oParent.getId && oParent.getId().indexOf("toolbar") >= 0) {
                    o.setVisible(false);
                }
            }
        });
    }

    // ─────────────────────────────────────────────
    // 7. TÍNH % VÀ UPDATE MODEL
    // ─────────────────────────────────────────────
    function _calcPercentage(oTable) {
        var oBinding = oTable.getBinding("rows");
        if (!oBinding) return;

        var iLength = oBinding.getLength();
        var aContexts = oBinding.getContexts(0, iLength);

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
    // 8. BUILD EXCEL
    // ─────────────────────────────────────────────
    function _buildExcel(aData, oFilterData) {
        var workbook = new ExcelJS.Workbook();
        var worksheet = workbook.addWorksheet("Bao cao ban hang");

        var GREEN = { argb: "FF00B050" };
        var BORDER = {
            top: { style: "thin" },
            left: { style: "thin" },
            bottom: { style: "thin" },
            right: { style: "thin" }
        };
        var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };

        worksheet.mergeCells("A1:H1");
        var r1 = worksheet.getCell("A1");
        r1.value = oFilterData.companyName || "";
        r1.alignment = { horizontal: "center" };

        worksheet.mergeCells("A2:H2");
        var r2 = worksheet.getCell("A2");
        r2.value = oFilterData.companyAddress || "";
        r2.alignment = { horizontal: "center" };

        worksheet.addRow([]);

        worksheet.mergeCells("A4:H4");
        var titleCell = worksheet.getCell("A4");
        titleCell.value = "Doanh so ban hang theo loai khach hang va mat hang";
        titleCell.font = { bold: true, size: 14 };
        titleCell.alignment = CENTER;
        worksheet.getRow(4).height = 25;

        worksheet.mergeCells("A5:H5");
        var r5 = worksheet.getCell("A5");
        r5.value = "Tu ngay " + (oFilterData.dateFrom || "...") +
            " Den ngay " + (oFilterData.dateTo || "...");
        r5.alignment = { horizontal: "center" };

        worksheet.addRow([]);
        worksheet.addRow([]);

        var aHeaders = [
            "STT", "Don vi khach hang", "Loai hang",
            "Doanh so USD", "Doanh so VND",
            "So luong", "Thi Truong", "Phan tram"
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

        var grandVND = aData.reduce(function (s, d) {
            var v = parseFloat(d.RevenueVND || 0);
            return s + (v > 0 ? v : 0);
        }, 0);

        var totalUSD = 0, totalVND = 0, totalQty = 0;

        aData.forEach(function (item, idx) {
            var revUSD = parseFloat(item.RevenueUSD || 0);
            var revVND = parseFloat(item.RevenueVND || 0);
            var qty = parseFloat(item.NetQuantity || 0);
            var pct = (revVND > 0 && grandVND > 0)
                ? (revVND / grandVND * 100).toFixed(2) + "%"
                : "0.00%";

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

        var oTotalRow = worksheet.addRow([
            "Cong", "", "", totalUSD, totalVND, totalQty, "", "100.00%"
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

        worksheet.columns = [
            { width: 6 }, { width: 40 }, { width: 20 },
            { width: 18 }, { width: 22 }, { width: 14 },
            { width: 20 }, { width: 12 }
        ];

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
            MessageToast.show("Export Excel thanh cong!");
        });
    }

    // ─────────────────────────────────────────────
    // 9. BUILD PDF
    // ─────────────────────────────────────────────
    function _buildPDF(aData, oFilterData) {
        var jsPDF = window.jspdf.jsPDF;
        var doc = new jsPDF({ orientation: "landscape", unit: "mm", format: "a4" });

        var pageWidth = doc.internal.pageSize.getWidth();

        // Header
        doc.setFontSize(11);
        doc.setFont("helvetica", "normal");
        doc.text(oFilterData.companyName || "", pageWidth / 2, 12, { align: "center" });

        doc.setFontSize(9);
        doc.text(oFilterData.companyAddress || "", pageWidth / 2, 18, { align: "center" });

        doc.setFontSize(13);
        doc.setFont("helvetica", "bold");
        doc.text(
            "Doanh so ban hang theo loai khach hang va mat hang",
            pageWidth / 2, 28, { align: "center" }
        );

        doc.setFontSize(9);
        doc.setFont("helvetica", "normal");
        doc.text(
            "Tu ngay " + (oFilterData.dateFrom || "...") + "  Den ngay " + (oFilterData.dateTo || "..."),
            pageWidth / 2, 35, { align: "center" }
        );

        // Tính totals
        var grandVND = aData.reduce(function (s, d) {
            var v = parseFloat(d.RevenueVND || 0);
            return s + (v > 0 ? v : 0);
        }, 0);

        var totalUSD = 0, totalVND = 0, totalQty = 0;

        var aBody = aData.map(function (item, idx) {
            var revUSD = parseFloat(item.RevenueUSD || 0);
            var revVND = parseFloat(item.RevenueVND || 0);
            var qty    = parseFloat(item.NetQuantity || 0);
            var pct    = (revVND > 0 && grandVND > 0)
                ? (revVND / grandVND * 100).toFixed(2) + "%"
                : "0.00%";

            totalUSD += revUSD;
            totalVND += revVND;
            totalQty += qty;

            var customerDisplay = item.CustomerName
                ? item.Customer + " (" + item.CustomerName + ")"
                : (item.Customer || "");
            var productGrpDisplay = item.ProductGroupName
                ? item.ProductGroup + " (" + item.ProductGroupName + ")"
                : (item.ProductGroup || "");
            var districtDisplay = item.SalesDistrictName
                ? item.SalesDistrict + " (" + item.SalesDistrictName + ")"
                : (item.SalesDistrict || "");

            return [
                idx + 1,
                customerDisplay,
                productGrpDisplay,
                revUSD.toLocaleString("en-US", { minimumFractionDigits: 2 }),
                revVND.toLocaleString("en-US", { minimumFractionDigits: 2 }),
                qty.toLocaleString("en-US", { minimumFractionDigits: 3 }),
                districtDisplay,
                pct
            ];
        });

        // Total row
        aBody.push([
            "Cong", "", "",
            totalUSD.toLocaleString("en-US", { minimumFractionDigits: 2 }),
            totalVND.toLocaleString("en-US", { minimumFractionDigits: 2 }),
            totalQty.toLocaleString("en-US", { minimumFractionDigits: 3 }),
            "", "100.00%"
        ]);

        var iTotalRowIndex = aBody.length - 1;

        doc.autoTable({
            startY: 40,
            head: [[
                "STT", "Don vi khach hang", "Loai hang",
                "Doanh so USD", "Doanh so VND",
                "So luong", "Thi Truong", "Phan tram"
            ]],
            body: aBody,
            styles: {
                fontSize: 7,
                cellPadding: 1.5,
                lineColor: [200, 200, 200],
                lineWidth: 0.1
            },
            headStyles: {
                fillColor: [0, 176, 80],
                textColor: 255,
                fontStyle: "bold",
                halign: "center"
            },
            columnStyles: {
                0: { halign: "center", cellWidth: 10 },
                1: { cellWidth: 55 },
                2: { cellWidth: 30 },
                3: { halign: "right", cellWidth: 25 },
                4: { halign: "right", cellWidth: 30 },
                5: { halign: "right", cellWidth: 22 },
                6: { cellWidth: 30 },
                7: { halign: "right", cellWidth: 18 }
            },
            willDrawCell: function (data) {
                // Tô màu xanh cho total row
                if (data.row.index === iTotalRowIndex && data.section === "body") {
                    data.cell.styles.fillColor = [0, 176, 80];
                    data.cell.styles.textColor = 255;
                    data.cell.styles.fontStyle = "bold";
                }
            }
        });

        var sFileName = "DoanhSoBanHang_"
            + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
            + ".pdf";
        // doc.save(sFileName);

// Thay doc.save(sFileName) bằng đoạn này:
var sFileName = "DoanhSoBanHang_"
    + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
    + ".pdf";

// Tạo blob URL để preview
var pdfBlob = doc.output("blob");
var sPdfUrl = URL.createObjectURL(pdfBlob);

// Dùng sap.m.PDFViewer trong Dialog
sap.ui.require(["sap/m/PDFViewer", "sap/m/Dialog", "sap/m/Button"], function (PDFViewer, Dialog, Button) {
    var oPDFViewer = new PDFViewer({
        source: sPdfUrl,
        title: "Preview - " + sFileName,
        height: "600px"
    });

    var oDialog = new Dialog({
        title: "Preview PDF",
        contentWidth: "900px",
        contentHeight: "650px",
        content: [oPDFViewer],
        buttons: [
            new Button({
                text: "Tai xuong",
                icon: "sap-icon://download",
                type: "Emphasized",
                press: function () {
                    doc.save(sFileName);
                    URL.revokeObjectURL(sPdfUrl);
                    oDialog.close();
                }
            }),
            new Button({
                text: "Dong",
                press: function () {
                    URL.revokeObjectURL(sPdfUrl);
                    oDialog.close();
                    oDialog.destroy();
                }
            })
        ],
        afterClose: function () {
            URL.revokeObjectURL(sPdfUrl);
            oDialog.destroy();
        }
    });

    oDialog.open();
});        
        MessageToast.show("Export PDF thanh cong!");
    }

    // ─────────────────────────────────────────────
    // 10. MAIN EXPORT EXCEL
    // ─────────────────────────────────────────────
    function _doExport(oView) {
        var aData = _getTableData(oView);
        if (!aData.length) {
            MessageBox.error("Khong co du lieu de export");
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
    // 11. MAIN EXPORT PDF
    // ─────────────────────────────────────────────
    function _doExportPDF(oView) {
        var aData = _getTableData(oView);
        if (!aData.length) {
            MessageBox.error("Khong co du lieu de export");
            return;
        }
        var oFilterData = _getFilterData(oView);
        _getCompanyName(oView, function (oInfo) {
            oFilterData.companyName = oInfo.name;
            oFilterData.companyAddress = oInfo.address;
            _buildPDF(aData, oFilterData);
        });
    }

    // ─────────────────────────────────────────────
    // 12. CONTROLLER EXTENSION
    // ─────────────────────────────────────────────
    return {

        onAfterRendering: function () {
            var oView = this.getView();
            var oSmartTable = _getSmartTable(oView);
            if (!oSmartTable) return;

            var oTable = oSmartTable.getTable();

            // Thêm icon cho button Export Excel
            setTimeout(function () {
                var aAllControls = oView.findAggregatedObjects(true);
                aAllControls.forEach(function (o) {
                    var sId = o.getId ? o.getId() : "";
                    if (sId.indexOf("exportExcelButton") >= 0) {
                        if (o.setIcon) o.setIcon("sap-icon://excel-attachment");
                    }
                    if (sId.indexOf("ExportPDFButton") >= 0) {
                        if (o.setIcon) o.setIcon("sap-icon://pdf-attachment");
                    }
                });
            }, 1500);

            // Ẩn button Export chuẩn
            setTimeout(function () {
                _hideDefaultExportButton(oView);
            }, 1500);

            // Tính % + ẩn lại button mỗi lần data load
            oSmartTable.attachDataReceived(function () {
                _calcPercentage(oTable);
                setTimeout(function () {
                    _hideDefaultExportButton(oView);
                }, 500);
            });
        },

        exportExcel: function () {
            var oView = this.getView();

            if (window.ExcelJS) {
                _doExport(oView);
                return;
            }

            var script = document.createElement("script");
            script.src = sap.ui.require.toUrl("zcusprodsalesrp/libs/exceljs.min.js");
            script.onload = function () { _doExport(oView); };
            script.onerror = function () {
                MessageBox.error("Khong load duoc ExcelJS library");
            };
            document.head.appendChild(script);
        },

        ExportPDF: function () {
            var oView = this.getView();

            if (window.jspdf && window.jspdf.jsPDF) {
                _doExportPDF(oView);
                return;
            }

            var sBasePath = sap.ui.require.toUrl("zcusprodsalesrp/libs/");

            var scriptJsPDF = document.createElement("script");
            scriptJsPDF.src = sBasePath + "jspdf.umd.min.js";
            scriptJsPDF.onload = function () {
                var scriptAutoTable = document.createElement("script");
                scriptAutoTable.src = sBasePath + "jspdf.plugin.autotable.min.js";
                scriptAutoTable.onload = function () {
                    _doExportPDF(oView);
                };
                scriptAutoTable.onerror = function () {
                    MessageBox.error("Khong load duoc autoTable library");
                };
                document.head.appendChild(scriptAutoTable);
            };
            scriptJsPDF.onerror = function () {
                MessageBox.error("Khong load duoc jsPDF library");
            };
            document.head.appendChild(scriptJsPDF);
        }
    };
});