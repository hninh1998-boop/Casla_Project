sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/ui/core/BusyIndicator",
    "sap/ui/core/Element"
], function (MessageToast, MessageBox, BusyIndicator, Element) {
    "use strict";

    var ENTITY_SET_PATH = "/ZCE_NGC_STOCK_CUSTOM";
    var REPORT_TITLE = "Báo cáo NXT NVL tại nhà gia công";
    var FONT_FAMILY = "Times New Roman";
    var FONT_SIZE = 11;
    var HEADER_FILL_PRIMARY = "FF4472C4";
    var HEADER_FILL_SECONDARY = "FFD9E1F2";
    var THIN_BORDER = {
        top: { style: "thin", color: { argb: "FF000000" } },
        left: { style: "thin", color: { argb: "FF000000" } },
        bottom: { style: "thin", color: { argb: "FF000000" } },
        right: { style: "thin", color: { argb: "FF000000" } }
    };

    // Column order/labels follow the printed report layout (STT/PO/item/... /Trạng thái PO),
    // a reduced subset of the CDS annotation of ZCE_NGC_STOCK_CUSTOM (amount/plant/supplier
    // fields and a few WIP quantities are not part of this layout).
    // "STT" is rendered as a plain row sequence number, not the technical STTKey.
    var EXPORT_COLUMNS = [
        { key: "STTKey", label: "STT", type: "seq", width: 6 },
        { key: "PurchaseOrder", label: "PO", type: "text", width: 12 },
        { key: "PurchaseOrderItem", label: "Item", type: "text", width: 8 },
        { key: "Material", label: "Mã hàng", type: "text", width: 36, nameKey: "MaterialName" },
        { key: "ProductGroup", label: "Nhóm hàng", type: "text", width: 24, nameKey: "ProductGroupName" },
        { key: "BaseUnit", label: "ĐVT", type: "text", width: 8 },
        { key: "ValuationType", label: "Valuation Type", type: "text", width: 14 },
        { key: "CustomsCode", label: "Mã hải quan", type: "text", width: 14 },
        { key: "OpeningStockQty", label: "SL tồn đầu", type: "qty", width: 14 },
        { key: "IncreaseQty", label: "SL tăng", type: "qty", width: 14 },
        { key: "ReturnQty", label: "SL NVL trả về", type: "qty", width: 14 },
        { key: "POComponentQty", label: "SL theo Component PO", type: "qty", width: 16, group: "SL Tiêu Hao" },
        { key: "BOMQty", label: "SL BOM", type: "qty", width: 12, group: "SL Tiêu Hao" },
        { key: "LossQty", label: "SL hao hụt", type: "qty", width: 12, group: "SL Tiêu Hao" },
        { key: "ConsumptionQty", label: "SL Tiêu Hao", type: "qty", width: 12, group: "SL Tiêu Hao" },
        { key: "ClosingStockQty", label: "SL tồn cuối", type: "qty", width: 14 },
        { key: "BOMRatio", label: "SL BOM", type: "ratio", width: 10, numFmt: "0.000" },
        { key: "Plant", label: "Plant", type: "text", width: 24, nameKey: "PlantName" },
        { key: "FinishedGoodMaterial", label: "Mã TP GC", type: "text", width: 36, group: "Số lượng TP GC", nameKey: "FinishedGoodMaterialName" },
        { key: "FinishedGoodMaterialUnit", label: "ĐVT Thành Phẩm", type: "text", width: 10, group: "Số lượng TP GC" },
        { key: "FGReceivedBeforeQty", label: "Số lượng TP nhập các kì trước", type: "qty", width: 16, group: "Số lượng TP GC" },
        { key: "WipOpenQty", label: "Số lượng dở dang đầu kì", type: "qty", width: 16, group: "Số lượng TP GC" },
        { key: "FGRestockQty", label: "Số lượng TP nhập theo PO", type: "qty", width: 16, group: "Số lượng TP GC" },
        { key: "FGReturnQty", label: "Số lượng trả hàng", type: "qty", width: 14, group: "Số lượng TP GC" },
        { key: "RemainingPOQty", label: "Còn lại", type: "qty", width: 12, group: "Số lượng TP GC" },
        { key: "POStatus", label: "Trạng thái PO", type: "text", width: 16, group: "Số lượng TP GC" }
    ];

    // Locate the mdc Table actually bound to our entity set, so we reuse its live,
    // already-filtered row binding instead of reconstructing filters ourselves.
    function findTable() {
        var oTable;
        Element.registry.forEach(function (oElement) {
            if (oTable) {
                return;
            }
            if (oElement.isA && oElement.isA("sap.ui.mdc.Table")) {
                var oRowBinding = oElement.getRowBinding && oElement.getRowBinding();
                if (oRowBinding && oRowBinding.getPath && oRowBinding.getPath() === ENTITY_SET_PATH) {
                    oTable = oElement;
                }
            }
        });
        return oTable;
    }

    function pad2(iValue) {
        return iValue < 10 ? "0" + iValue : String(iValue);
    }

    function formatDate(oDate) {
        return pad2(oDate.getDate()) + "/" + pad2(oDate.getMonth() + 1) + "/" + oDate.getFullYear();
    }

    // zper is expected in "YYYYMM" format, e.g. "202605" -> "01/05/2026-31/05/2026"
    function formatPeriodRange(sZper) {
        if (!sZper || sZper.length !== 6 || !/^\d{6}$/.test(sZper)) {
            return sZper || "";
        }
        var iYear = parseInt(sZper.substring(0, 4), 10);
        var iMonth = parseInt(sZper.substring(4, 6), 10);
        if (iMonth < 1 || iMonth > 12) {
            return sZper;
        }
        var oFirstDay = new Date(iYear, iMonth - 1, 1);
        var oLastDay = new Date(iYear, iMonth, 0);
        return formatDate(oFirstDay) + "-" + formatDate(oLastDay);
    }

    // Text-element fields (Material/MaterialName, Supplier/SupplierName, ...) are rendered
    // as "Name (Code)", e.g. "TBA-10529-TX25020320TK1-G (100000024)".
    function formatNameCodeLabel(sCode, sName) {
        if (sName && sCode) {
            return sName + " (" + sCode + ")";
        }
        return sName || sCode || "";
    }

    function ensureExcelJs() {
        if (window.ExcelJS) {
            return Promise.resolve();
        }
        return new Promise(function (resolve, reject) {
            var oScript = document.createElement("script");
            oScript.src = sap.ui.require.toUrl("baocaonxtnvlnhagiacong/libs/exceljs.min.js");
            oScript.onload = resolve;
            oScript.onerror = function () {
                reject(new Error("Không tải được thư viện exceljs.min.js tại " + oScript.src));
            };
            document.head.appendChild(oScript);
        });
    }

    function styleGroupHeaderCell(oCell) {
        oCell.font = { name: FONT_FAMILY, size: FONT_SIZE, bold: true, color: { argb: "FFFFFFFF" } };
        oCell.alignment = { horizontal: "center", vertical: "middle", wrapText: true };
        oCell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: HEADER_FILL_PRIMARY } };
        oCell.border = THIN_BORDER;
    }

    function styleSubHeaderCell(oCell) {
        oCell.font = { name: FONT_FAMILY, size: FONT_SIZE, bold: true };
        oCell.alignment = { horizontal: "center", vertical: "middle", wrapText: true };
        oCell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: HEADER_FILL_SECONDARY } };
        oCell.border = THIN_BORDER;
    }

    function buildHeaderRows(oSheet, iRow1) {
        var iRow2 = iRow1 + 1;
        var iCol = 1;
        var i = 0;
        while (i < EXPORT_COLUMNS.length) {
            var oCurrent = EXPORT_COLUMNS[i];
            if (oCurrent.group) {
                var j = i;
                while (j < EXPORT_COLUMNS.length && EXPORT_COLUMNS[j].group === oCurrent.group) {
                    j++;
                }
                var iGroupStart = iCol;
                var iGroupEnd = iCol + (j - i) - 1;
                oSheet.mergeCells(iRow1, iGroupStart, iRow1, iGroupEnd);
                var oGroupCell = oSheet.getCell(iRow1, iGroupStart);
                oGroupCell.value = oCurrent.group;
                styleGroupHeaderCell(oGroupCell);
                for (var k = i; k < j; k++) {
                    var oSubCell = oSheet.getCell(iRow2, iCol);
                    oSubCell.value = EXPORT_COLUMNS[k].label;
                    styleSubHeaderCell(oSubCell);
                    iCol++;
                }
                i = j;
            } else {
                oSheet.mergeCells(iRow1, iCol, iRow2, iCol);
                var oCell = oSheet.getCell(iRow1, iCol);
                oCell.value = oCurrent.label;
                styleGroupHeaderCell(oCell);
                iCol++;
                i++;
            }
        }
        return iRow2;
    }

    function writeDataRows(oSheet, aRowData, iStartRow) {
        aRowData.forEach(function (oRowData, iIndex) {
            var iRow = iStartRow + iIndex;
            EXPORT_COLUMNS.forEach(function (oColumn, iColIndex) {
                var oCell = oSheet.getCell(iRow, iColIndex + 1);
                oCell.border = THIN_BORDER;
                oCell.font = { name: FONT_FAMILY, size: FONT_SIZE };
                if (oColumn.type === "seq") {
                    oCell.value = iIndex + 1;
                    oCell.alignment = { horizontal: "center" };
                } else if (oColumn.type === "qty" || oColumn.type === "ratio") {
                    var vValue = oRowData[oColumn.key];
                    oCell.value = vValue !== undefined && vValue !== null ? Number(vValue) : null;
                    if (oColumn.type === "ratio") {
                        oCell.numFmt = oColumn.numFmt || "0.000";
                    }
                    oCell.alignment = { horizontal: "right" };
                } else if (oColumn.nameKey) {
                    oCell.value = formatNameCodeLabel(oRowData[oColumn.key], oRowData[oColumn.nameKey]);
                    oCell.alignment = { horizontal: "left" };
                } else {
                    oCell.value = oRowData[oColumn.key] !== undefined ? oRowData[oColumn.key] : "";
                    oCell.alignment = { horizontal: "left" };
                }
            });
        });
    }

    // Groups rows by the given unit field and sums the given zone's "qty" columns per group,
    // in the order units first appear. Ratio columns (e.g. BOM) are never summed. The report
    // has two unit domains that must not be mixed together: NVL columns (up to and including
    // "Plant") use BaseUnit, TP GC columns (after "Plant") use FinishedGoodMaterialUnit.
    function buildUnitSumGroups(aRowData, sUnitKey, aZoneColumnKeys) {
        var oGroupByUnit = {};
        var aUnitOrder = [];
        aRowData.forEach(function (oRowData) {
            var sUnit = oRowData[sUnitKey] || "";
            if (!sUnit) {
                // Rows with no unit don't get a total row at all.
                return;
            }
            if (!oGroupByUnit[sUnit]) {
                oGroupByUnit[sUnit] = { unit: sUnit, sums: {} };
                aUnitOrder.push(sUnit);
            }
            var oSums = oGroupByUnit[sUnit].sums;
            aZoneColumnKeys.forEach(function (sColumnKey) {
                var vValue = oRowData[sColumnKey];
                var nValue = vValue !== undefined && vValue !== null ? Number(vValue) : 0;
                oSums[sColumnKey] = (oSums[sColumnKey] || 0) + (isNaN(nValue) ? 0 : nValue);
            });
        });
        return aUnitOrder.map(function (sUnit) { return oGroupByUnit[sUnit]; });
    }

    // Writes one total row per group. The label is merged from column 1 up to this zone's
    // first qty column; cells outside the zone still get the row's border/fill but no value,
    // so the two zones' totals read as visually separate blocks divided by "Plant".
    function writeSummaryBlock(oSheet, aGroups, iStartRow, sLabelPrefix, aZoneColumnKeys) {
        var oZoneColumnKeySet = {};
        aZoneColumnKeys.forEach(function (sKey) { oZoneColumnKeySet[sKey] = true; });

        var iFirstZoneQtyIndex = 0;
        EXPORT_COLUMNS.some(function (oColumn, iIndex) {
            if (oColumn.type === "qty" && oZoneColumnKeySet[oColumn.key]) {
                iFirstZoneQtyIndex = iIndex;
                return true;
            }
            return false;
        });

        aGroups.forEach(function (oGroup, iGroupIndex) {
            var iRow = iStartRow + iGroupIndex;
            if (iFirstZoneQtyIndex > 0) {
                oSheet.mergeCells(iRow, 1, iRow, iFirstZoneQtyIndex);
            }
            var oLabelCell = oSheet.getCell(iRow, 1);
            oLabelCell.value = sLabelPrefix + " (ĐVT: " + (oGroup.unit || "?") + ")";
            oLabelCell.alignment = { horizontal: "left", vertical: "middle" };

            EXPORT_COLUMNS.forEach(function (oColumn, iColIndex) {
                var oCell = oSheet.getCell(iRow, iColIndex + 1);
                oCell.border = THIN_BORDER;
                oCell.font = { name: FONT_FAMILY, size: FONT_SIZE, bold: true };
                oCell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: HEADER_FILL_SECONDARY } };
                if (oColumn.type === "qty" && oZoneColumnKeySet[oColumn.key]) {
                    oCell.value = oGroup.sums[oColumn.key] || 0;
                    oCell.alignment = { horizontal: "right" };
                }
            });
        });
    }

    async function buildAndDownloadWorkbook(aRowData, sPeriodLabel, sSupplierLabel) {
        var iColCount = EXPORT_COLUMNS.length;
        var oWorkbook = new ExcelJS.Workbook();
        var oSheet = oWorkbook.addWorksheet("Báo cáo");
        EXPORT_COLUMNS.forEach(function (oColumn, iIndex) {
            oSheet.getColumn(iIndex + 1).width = oColumn.width;
        });

        oSheet.mergeCells(1, 1, 1, iColCount);
        var oTitleCell = oSheet.getCell(1, 1);
        oTitleCell.value = REPORT_TITLE;
        oTitleCell.font = { name: FONT_FAMILY, bold: true, size: 16 };
        oTitleCell.alignment = { horizontal: "center", vertical: "middle" };
        oSheet.getRow(1).height = 24;

        oSheet.mergeCells(2, 1, 2, iColCount);
        var oSubtitleCell = oSheet.getCell(2, 1);
        oSubtitleCell.value = sPeriodLabel;
        oSubtitleCell.font = { name: FONT_FAMILY, bold: true, size: 12, color: { argb: "FFFF0000" } };
        oSubtitleCell.alignment = { horizontal: "center", vertical: "middle" };

        oSheet.mergeCells(3, 1, 3, iColCount);
        var oSupplierCell = oSheet.getCell(3, 1);
        oSupplierCell.value = sSupplierLabel;
        oSupplierCell.font = { name: FONT_FAMILY, bold: true, size: 12 };
        oSupplierCell.alignment = { horizontal: "center", vertical: "middle" };

        // 3 blank rows between the title block (rows 1-3) and the table header.
        var iHeaderStartRow = 3 + 3 + 1;
        var iLastHeaderRow = buildHeaderRows(oSheet, iHeaderStartRow);
        var iDataStartRow = iLastHeaderRow + 1;
        writeDataRows(oSheet, aRowData, iDataStartRow);

        // "Plant" is the divider between the NVL columns (BaseUnit) and the TP GC columns
        // (FinishedGoodMaterialUnit) — each domain gets its own, separately grouped totals.
        var iPlantIndex = -1;
        EXPORT_COLUMNS.some(function (oColumn, iIndex) {
            if (oColumn.key === "Plant") {
                iPlantIndex = iIndex;
                return true;
            }
            return false;
        });
        var aNvlColumnKeys = EXPORT_COLUMNS.slice(0, iPlantIndex + 1)
            .filter(function (oColumn) { return oColumn.type === "qty"; })
            .map(function (oColumn) { return oColumn.key; });
        var aTpgcColumnKeys = EXPORT_COLUMNS.slice(iPlantIndex + 1)
            .filter(function (oColumn) { return oColumn.type === "qty"; })
            .map(function (oColumn) { return oColumn.key; });

        var aNvlGroups = buildUnitSumGroups(aRowData, "BaseUnit", aNvlColumnKeys);
        var iNvlSummaryStartRow = iDataStartRow + aRowData.length;
        writeSummaryBlock(oSheet, aNvlGroups, iNvlSummaryStartRow, "Tổng cộng NVL", aNvlColumnKeys);

        var aTpgcGroups = buildUnitSumGroups(aRowData, "FinishedGoodMaterialUnit", aTpgcColumnKeys);
        var iTpgcSummaryStartRow = iNvlSummaryStartRow + aNvlGroups.length;
        writeSummaryBlock(oSheet, aTpgcGroups, iTpgcSummaryStartRow, "Tổng cộng TP GC", aTpgcColumnKeys);

        oSheet.views = [{ state: "frozen", ySplit: iLastHeaderRow }];

        var aBuffer = await oWorkbook.xlsx.writeBuffer();
        var oBlob = new Blob([aBuffer], {
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        });
        var sUrl = URL.createObjectURL(oBlob);
        var oLink = document.createElement("a");
        oLink.href = sUrl;
        oLink.download = "BaoCao_NXT_NVL_NhaGiaCong.xlsx";
        document.body.appendChild(oLink);
        oLink.click();
        document.body.removeChild(oLink);
        URL.revokeObjectURL(sUrl);
    }

    return {
        /**
         * Generated event handler.
         *
         * @param oContext the context of the page on which the event was fired. `undefined` for list report page.
         * @param aSelectedContexts the selected contexts of the table rows.
         */
        ExportExcel: async function (oContext, aSelectedContexts) {
            var oTable = findTable();
            var oBinding = oTable && oTable.getRowBinding();
            if (!oBinding) {
                MessageBox.warning("Vui lòng nhập đầy đủ điều kiện lọc bắt buộc (Kỳ kế toán, Nhà GC) và nhấn Tiến hành trước khi xuất Excel.");
                return;
            }

            BusyIndicator.show(0);
            try {
                var iCount;
                try {
                    iCount = await oBinding.getHeaderContext().requestProperty("$count");
                } catch (oRequestError) {
                    MessageBox.error("Không thể tải dữ liệu. Vui lòng kiểm tra lại điều kiện lọc (dữ liệu có thể chưa được load lên) và thử lại.");
                    return;
                }

                if (!iCount) {
                    MessageBox.information("Không có dữ liệu để xuất Excel.");
                    return;
                }

                // Reuse the table's own binding: it already has the correct filters/sorters
                // applied by the framework. requestContexts bypasses the GridTable's
                // rendering window, so this fetches every row, not just the visible ones.
                var aContexts = await oBinding.requestContexts(0, iCount);
                var aRowData = aContexts.map(function (oRowContext) { return oRowContext.getObject(); })
                    // Rows with a non-empty OpenStatusPO (PO đầu kì đã có trạng thái) are excluded from the export.
                    .filter(function (oRowData) { return !oRowData.OpenStatusPO; });

                if (!aRowData.length) {
                    MessageBox.information("Không có dữ liệu để xuất Excel.");
                    return;
                }

                await ensureExcelJs();
                var oFirstRow = aRowData[0] || {};
                await buildAndDownloadWorkbook(
                    aRowData,
                    formatPeriodRange(oFirstRow.zper),
                    formatNameCodeLabel(oFirstRow.Supplier, oFirstRow.SupplierName)
                );

                MessageToast.show("Xuất Excel thành công.");
            } catch (oError) {
                MessageBox.error("Xuất Excel thất bại: " + (oError && oError.message ? oError.message : oError));
            } finally {
                BusyIndicator.hide();
            }
        }
    };
});
