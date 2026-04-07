sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator"
], function(MessageToast, MessageBox, Filter, FilterOperator) {
    'use strict';

    function _doExport(oView, oModel) {
        var oSmartFilterBar = oView.byId("listReportFilter");
        var aFilters        = [];
        var lv_month        = "";
        var lv_year         = "";

        if (oSmartFilterBar) {
            var oFilterData = oSmartFilterBar.getFilterData();

            if (oFilterData.CompanyCode)
                aFilters.push(new Filter("CompanyCode", FilterOperator.EQ, oFilterData.CompanyCode));
            if (oFilterData.FiscalYear)
                aFilters.push(new Filter("FiscalYear", FilterOperator.EQ, oFilterData.FiscalYear));
            if (oFilterData.FiscalPeriod)
                aFilters.push(new Filter("FiscalPeriod", FilterOperator.EQ, oFilterData.FiscalPeriod));
            if (oFilterData.Plant)
                aFilters.push(new Filter("Plant", FilterOperator.EQ, oFilterData.Plant));
            if (oFilterData.Product)
                aFilters.push(new Filter("Product", FilterOperator.EQ, oFilterData.Product));
            if (oFilterData.SalesDistrict)
                aFilters.push(new Filter("SalesDistrict", FilterOperator.EQ, oFilterData.SalesDistrict));

            // Auto filter currency
            aFilters.push(new Filter("TransactionCurrency", FilterOperator.EQ, "USD"));
            aFilters.push(new Filter("CompanyCodeCurrency",  FilterOperator.EQ, "VND"));

            lv_month = oFilterData.FiscalPeriod || "";
            lv_year  = oFilterData.FiscalYear   || "";
        }

        oModel.read("/zi_sales_report_chk2", {
            filters: aFilters,
            urlParameters: { "$top": "9999" },
            success: function(oData) {
                _buildExcel(oData.results, lv_month, lv_year);
            },
            error: function(oErr) {
                MessageBox.error("Lỗi khi lấy dữ liệu: " + oErr.message);
            }
        });
    }

    function _buildExcel(aData, lv_month, lv_year) {
        var workbook  = new ExcelJS.Workbook();
        var worksheet = workbook.addWorksheet("Báo cáo bán hàng");

        var YELLOW = { argb: "FFFFFF00" };
        var BORDER = {
            top:    { style: "thin" },
            left:   { style: "thin" },
            bottom: { style: "thin" },
            right:  { style: "thin" }
        };

        // ── Row 1: Tiêu đề ──────────────────────────
        worksheet.mergeCells("B1:K1");
        var titleCell       = worksheet.getCell("B1");
        titleCell.value     = "BÁO CÁO BÁN HÀNG";
        titleCell.font      = { bold: true, size: 13 };
        titleCell.alignment = { horizontal: "center", vertical: "middle" };
        worksheet.getRow(1).height = 20;

        // ── Row 2: Tháng/Năm ────────────────────────
        worksheet.mergeCells("B2:K2");
        var subCell       = worksheet.getCell("B2");
        subCell.value     = "Tháng " + (lv_month || "...") + " năm " + (lv_year || "...");
        subCell.alignment = { horizontal: "center" };

        // ── Row 3: Trống ────────────────────────────
        worksheet.addRow([]);

        // ── Row 4: Header ───────────────────────────
        var headers = [
            "STT", "Tên nhà máy", "Mã hàng", "Tên hàng",
            "ĐVT", "Loại hàng", "Số lượng",
            "Doanh thu USD", "Doanh thu VND",
            "Giá vốn VND", "Thị trường xuất khẩu"
        ];

        var headerRow    = worksheet.addRow(headers);
        headerRow.height = 30;
        headerRow.eachCell(function(cell) {
            cell.fill      = { type: "pattern", pattern: "solid", fgColor: YELLOW };
            cell.font      = { bold: true };
            cell.border    = BORDER;
            cell.alignment = { horizontal: "center", vertical: "middle", wrapText: true };
        });

        // ── Data rows ────────────────────────────────
        var totalQty    = 0;
        var totalRevUSD = 0;
        var totalRevVND = 0;
        var totalCOGS   = 0;

        aData.forEach(function(item, idx) {
            var qty    = parseFloat(item.Quantity   || 0);
            var revUSD = parseFloat(item.RevenueUSD || 0);
            var revVND = parseFloat(item.RevenueVND || 0);
            var cogs   = parseFloat(item.COGSVND    || 0);

            var row = worksheet.addRow([
                idx + 1,
                item.Plant,
                item.Product,
                item.ProductName,
                item.BaseUnit,
                item.ProductType,
                qty,
                revUSD,
                revVND,
                cogs,
                item.SalesDistrict
            ]);

            row.getCell(7).numFmt  = "#,##0.000";
            row.getCell(8).numFmt  = "#,##0";
            row.getCell(9).numFmt  = "#,##0";
            row.getCell(10).numFmt = "#,##0";
            row.eachCell(function(cell) { cell.border = BORDER; });

            totalQty    += qty;
            totalRevUSD += revUSD;
            totalRevVND += revVND;
            totalCOGS   += cogs;
        });

        // ── Total row ────────────────────────────────
        var totalRow = worksheet.addRow([
            "", "", "", "", "", "",
            totalQty, totalRevUSD, totalRevVND, totalCOGS, ""
        ]);
        totalRow.eachCell(function(cell) {
            cell.fill   = { type: "pattern", pattern: "solid", fgColor: YELLOW };
            cell.font   = { bold: true };
            cell.border = BORDER;
        });
        totalRow.getCell(7).numFmt  = "#,##0.000";
        totalRow.getCell(8).numFmt  = "#,##0";
        totalRow.getCell(9).numFmt  = "#,##0";
        totalRow.getCell(10).numFmt = "#,##0";

        // ── Column widths ────────────────────────────
        worksheet.columns = [
            { width: 6  },
            { width: 15 },
            { width: 20 },
            { width: 30 },
            { width: 8  },
            { width: 12 },
            { width: 16 },
            { width: 16 },
            { width: 16 },
            { width: 16 },
            { width: 22 }
        ];

        // ── Download ─────────────────────────────────
        workbook.xlsx.writeBuffer().then(function(buffer) {
            var blob = new Blob([buffer], {
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            });
            var url  = URL.createObjectURL(blob);
            var link = document.createElement("a");
            link.href     = url;
            link.download = "BaoCaoBanHang_"
                + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
                + ".xlsx";
            link.click();
            URL.revokeObjectURL(url);
            MessageToast.show("Export thành công!");
        });
    }

    return {
        exportExcel: function(oEvent) {
            var oView  = this.getView();
            var oModel = oView.getModel();

            if (window.ExcelJS) {
                _doExport(oView, oModel);
                return;
            }

            var script     = document.createElement("script");
            script.src     = "https://cdnjs.cloudflare.com/ajax/libs/exceljs/4.3.0/exceljs.min.js";
            script.onload  = function() { _doExport(oView, oModel); };
            script.onerror = function() {
                MessageBox.error("Không load được ExcelJS library");
            };
            document.head.appendChild(script);
        }
    };
});