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
            // try {
            //     var oField = oSFB.getControlByKey("Company");
            //     if (oField && oField.getTokens) {
            //         var aTokens = oField.getTokens();
            //         if (aTokens.length > 0) {
            //             var sText = aTokens[0].getText();
            //             var match = sText.match(/\((.+)\)/);
            //             sCompanyName = match ? match[1] : sText;
            //             sCC = aTokens[0].getKey ? aTokens[0].getKey() : "";
            //         }
            //     }
            // } catch (e) { }

            try {
                var oField = oSFB.getControlByKey("Company");
                if (oField) {
                    if (oField.getTokens) {
                        var aTokens = oField.getTokens();
                        if (aTokens.length > 0) {
                            sCC = aTokens[0].getKey();
                        }
                    } else if (oField.getValue) {
                        var sVal = oField.getValue();
                        // Parse "CÔNG TY CP CASLA (6710)" → "6710"
                        var match = sVal.match(/\(([^)]+)\)/);
                        if (match) {
                            sCC = match[1];
                        } else {
                            sCC = sVal.trim();
                        }
                    }
                }
            } catch (e) { }

            if (!sCC) {
                sCC = oSFB.getFilterData().CompanyCode || "";
            } else {

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
        var worksheet = workbook.addWorksheet("Monitor PO Delivery Cost");

        var GREEN = { argb: "FF00B050" };
        var BORDER = {
            top: { style: "thin" },
            left: { style: "thin" },
            bottom: { style: "thin" },
            right: { style: "thin" }
        };
        var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };
        var HEADER_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFD9E1F2" } };

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
        worksheet.mergeCells("A4:Y4");
        var titleCell = worksheet.getCell("A4");
        titleCell.value = "MONITOR PURCHASE ORDER DELIVERY COST";
        titleCell.font = { bold: true, size: 14, color: { argb: "FFFF0000" } };
        titleCell.alignment = { horizontal: "center" };

        // Row 5: Trống
        worksheet.addRow([]);

        // Row 6: Header
        var aHeaders = [
            "PO", "PO Item", "Condition Type", "Condition Type Name",
            "Supplier Delivery Cost", "Name supplier", "Material", "Material name",
            "PO Quantity", "Delivered Quantity", "Invoiced Quantity", "To be invoiced Quantity",
            "PO Estimated Value", "Delivered Value", "Invoiced Value", "Value To be invoiced",
            "Exchange rate PO", "Delivery Cost Currency",
            "Fully Invoiced", "Unit of Measure",
            "PO Supplier", "PO Supplier name", "Plant", "Company", "PO Currency"
        ];

        var oHeaderRow = worksheet.getRow(6);
        oHeaderRow.height = 35;
        aHeaders.forEach(function (h, i) {
            var oCell = oHeaderRow.getCell(i + 1);
            oCell.value = h;
            oCell.fill = HEADER_FILL;
            oCell.font = { bold: true };
            oCell.border = BORDER;
            oCell.alignment = CENTER;
        });

        // // Row 7: Số thứ tự columns
        // var aNumbers = [
        //     "(1)", "(2)", "(3)", "(4)", "(5)", "(6)", "(7)", "(8)",
        //     "(9)", "(10)", "(11)", "(12)", "(13)", "(14)", "(15)",
        //     "(17)", "(18)", "(19)", "(20)", "(21)",
        //     "(22)", "(23)", "(24)", "(25)", "(26)"
        // ];
        // var oNumRow = worksheet.getRow(7);
        // aNumbers.forEach(function (n, i) {
        //     var oCell = oNumRow.getCell(i + 1);
        //     oCell.value = n;
        //     oCell.font = { color: { argb: "FFFF0000" } };
        //     oCell.border = BORDER;
        //     oCell.alignment = CENTER;
        // });

        // Data rows
        aData.forEach(function (item) {
            var oRow = worksheet.addRow([
                item.PO || "",
                item.POItem || "",
                item.ConditionType || "",
                item.ConditionTypeName || "",
                item.SupplierDeliveryCost || "",
                item.NameSupplier || "",
                item.Material || "",
                item.MaterialName || "",
                parseFloat(item.POQuantity || 0),
                parseFloat(item.DeliveredQuantity || 0),
                parseFloat(item.InvoicedQuantity || 0),
                parseFloat(item.QuantityToBeInvoiced || 0),
                parseFloat(item.POEstimatedValue || 0),
                parseFloat(item.DeliveriedValue || 0),
                parseFloat(item.InvoicedValue || 0),
                // item.ValueToBeInvoiced !== "" && item.ValueToBeInvoiced !== null && item.ValueToBeInvoiced !== undefined
                //     ? parseFloat(item.ValueToBeInvoiced.replace(/\./g, "").replace(",", "."))
                //     : "",
                item.ValueToBeInvoiced !== "" && item.ValueToBeInvoiced !== null && item.ValueToBeInvoiced !== undefined
                    ? parseFloat(item.ValueToBeInvoiced.replace(/\s*VND\s*/g, "").replace(/\./g, "").replace(",", "."))
                    : "",
                parseFloat(item.POExchangeRate || 0),
                item.DeliveryCostCurrency || "",
                item.FullyInvoicedText || "",
                item.UnitOfMeasure || "",
                item.POSupplier || "",
                item.POSupplierName || "",
                item.Plant || "",
                item.Company || "",
                item.POCurrency || ""
            ]);

            oRow.eachCell(function (cell) { cell.border = BORDER; });

            oRow.getCell(9).numFmt = "#,##0.000";
            oRow.getCell(10).numFmt = "#,##0.000";
            oRow.getCell(11).numFmt = "#,##0.000";
            oRow.getCell(12).numFmt = "#,##0.000";
            oRow.getCell(13).numFmt = "#,##0.00";
            oRow.getCell(14).numFmt = "#,##0.00";
            oRow.getCell(15).numFmt = "#,##0.00";
            // oRow.getCell(16).numFmt = "#,##0.00";
            if (item.ValueToBeInvoiced !== "" && item.ValueToBeInvoiced !== null && item.ValueToBeInvoiced !== undefined) {
                oRow.getCell(16).numFmt = "#,##0.00";
            }
            oRow.getCell(17).numFmt = "#,##0.00000";
        });

        // Column widths
        worksheet.columns = [
            { width: 14 }, //A - PO
            { width: 10 }, //B - PO Item
            { width: 12 }, //C - Condition Type
            { width: 22 }, //D - Condition Type Name
            { width: 20 }, //E - Supplier Delivery Cost
            { width: 40 }, //F - Name Supplier
            { width: 16 }, //G - Material
            { width: 30 }, //H - Material Name
            { width: 14 }, //I - PO Quantity
            { width: 14 }, //J - Delivered Quantity
            { width: 14 }, //K - Invoiced Quantity
            { width: 14 }, //L - Quantity To Be Invoiced
            { width: 16 }, //M - PO Estimated Value
            { width: 16 }, //N - Deliveried Value
            { width: 16 }, //O - Invoiced Value
            { width: 16 }, //P - Value to be invoiced
            { width: 16 }, //Q - Exchange Rate PO
            { width: 14 }, //R - Delivery Cost Currency
            { width: 14 }, //S - Fully Invoiced
            { width: 14 }, //T - Unit Of Measure
            { width: 14 }, //U - PO Supplier
            { width: 30 }, //V - PO Supplier Name
            { width: 10 }, //W - Plant
            { width: 10 }, //X - Company
            { width: 14 }  //Y - PO Currency
        ];

        // Download
        workbook.xlsx.writeBuffer().then(function (buffer) {
            var blob = new Blob([buffer], {
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            });
            var url = URL.createObjectURL(blob);
            var link = document.createElement("a");
            link.href = url;
            link.download = "MonitorPODeliveryCost_"
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
            }, 1500);

            // Tính % + ẩn lại button mỗi lần data load
            oSmartTable.attachDataReceived(function () {
                _calcPercentage(oTable);

                // Căn phải cột ValueToBeInvoiced
                var aCols = oTable.getColumns();
                aCols.forEach(function (oCol) {
                    var oTemplate = oCol.getTemplate();
                    if (oTemplate && oTemplate.getBindingPath &&
                        oTemplate.getBindingPath("text") === "ValueToBeInvoiced") {
                        // oTemplate.setTextAlign("End");
                        oCol.setHAlign("End");
                    }
                });
            });
        },
        exportExcel: function () {
            var oView = this.getView();

            if (window.ExcelJS) {
                _doExport(oView);
                return;
            }

            var script = document.createElement("script");
            script.src = sap.ui.require.toUrl("zrppodelicostov2/libs/exceljs.min.js");
            script.onload = function () { _doExport(oView); };
            script.onerror = function () {
                MessageBox.error("Không load được ExcelJS library");
            };
            document.head.appendChild(script);
        }
    };
});