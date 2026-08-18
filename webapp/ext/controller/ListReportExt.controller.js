sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog"
], function (MessageToast, MessageBox, BusyDialog) {
    'use strict';

    var BATCH_SIZE = 1000;
    var CONCURRENCY = 4;

    var FIELD = {
        companyCode: "CompanyCode",
        assetClass: "LoaiTaiSan",
        assetClassText: "TenLoaiTaiSan",
        assetNumber: "MaTaiSan",
        assetName: "TenTaiSan",
        usageDate: "NgayDuaVaoSuDung",

        // Đầu kỳ
        openNG: "NguyenGiaDauKy",
        openHMLK: "HaoMonLuyKeDauKy",
        openGTCL: "GiaTriConLaiDauKy",

        // Tăng trong kỳ
        increaseNG: "TangNguyenGiaTrongKy",
        increaseHMLK: "TangHaoMonLuyKeTrongKy",
        increaseGTCL: "GiaTriConLaiTangTrongKy",

        // Giảm trong kỳ
        decreaseNG: "GiamNguyenGiaTrongKy",
        decreaseHMLK: "GiamHaoMonLuyKeTrongKy",
        decreaseGTCL: "NguyenGiaConLaiGiamTrongKy",

        // KH trong kỳ
        khTrongKy: "GiaTriKhauHaoTrongKy",

        // Cuối kỳ
        closeNG: "NguyenGiaCuoiKy",
        closeHMLK: "KhauHaoLuyKeCuoiKy",
        closeGTCL: "GiaTriConLaiCuoiKy",

        // Chưa có field -> để trống
        soThe: "",
        tlKH: ""
    };

    var REPORT_TITLE = "BÁO CÁO CHI TIẾT TÀI SẢN CỐ ĐỊNH";

    // ────────────────────────────────────────────────────────
    // Tìm SmartTable + binding (giữ nguyên pattern cũ)
    // ────────────────────────────────────────────────────────
    function _getBindingInfo(oView) {
        var aAll = oView.findAggregatedObjects(true);
        var oSmartTable = aAll.filter(function (o) {
            return o.getMetadata().getName() === "sap.ui.comp.smarttable.SmartTable";
        })[0];
        if (!oSmartTable) { return null; }

        var oTable = oSmartTable.getTable();
        var oBinding = oTable.getBinding("rows") || oTable.getBinding("items");
        if (!oBinding) { return null; }

        return {
            smartTable: oSmartTable,
            table: oTable,
            binding: oBinding,
            model: oBinding.getModel(),
            path: oBinding.getPath(),
            filters: oBinding.aApplicationFilters || [],
            sorters: oBinding.aSorters || [],
            total: oBinding.getLength()
        };
    }

    // ────────────────────────────────────────────────────────
    // Batch fetch ALL data qua $skip / $top, concurrency limit = 4
    // (giữ nguyên logic cũ)
    // ────────────────────────────────────────────────────────
    function _fetchAllBatched(oInfo, oBusyDialog) {
        return new Promise(function (resolve, reject) {
            var iTotal = oInfo.total;
            if (iTotal === 0) { resolve([]); return; }

            var iNumBatches = Math.ceil(iTotal / BATCH_SIZE);
            var aResults = new Array(iNumBatches);
            var iNextIdx = 0;
            var iCompleted = 0;
            var bHasError = false;

            function updateProgress() {
                var iLoaded = Math.min(iCompleted * BATCH_SIZE, iTotal);
                oBusyDialog.setText("Đang tải dữ liệu: " + iLoaded.toLocaleString("vi-VN")
                    + " / " + iTotal.toLocaleString("vi-VN") + " dòng");
            }

            function runBatch(iBatchIdx) {
                if (bHasError) { return; }

                oInfo.model.read(oInfo.path, {
                    filters: oInfo.filters,
                    sorters: oInfo.sorters,
                    urlParameters: {
                        "$skip": iBatchIdx * BATCH_SIZE,
                        "$top": BATCH_SIZE
                    },
                    success: function (oData) {
                        if (bHasError) { return; }
                        aResults[iBatchIdx] = oData.results || [];
                        iCompleted++;
                        updateProgress();

                        if (iNextIdx < iNumBatches) {
                            runBatch(iNextIdx++);
                        } else if (iCompleted === iNumBatches) {
                            var aAll = [].concat.apply([], aResults);
                            resolve(aAll);
                        }
                    },
                    error: function (oErr) {
                        bHasError = true;
                        reject(oErr);
                    }
                });
            }

            updateProgress();
            var iInitial = Math.min(CONCURRENCY, iNumBatches);
            for (var k = 0; k < iInitial; k++) {
                runBatch(iNextIdx++);
            }
        });
    }

    function _num(v) {
        return v ? parseFloat(v) : 0;
    }

    // ────────────────────────────────────────────────────────
    // Group flat data theo AssetClass (LoaiTaiSan), tính subtotal
    // (1 cấp nhóm - giữ nguyên như hiện tại)
    // ────────────────────────────────────────────────────────
    function _emptySum() {
        return {
            openNG: 0, openHMLK: 0, openGTCL: 0,
            increaseNG: 0, increaseHMLK: 0, increaseGTCL: 0,
            decreaseNG: 0, decreaseHMLK: 0, decreaseGTCL: 0,
            khTrongKy: 0,
            closeNG: 0, closeHMLK: 0, closeGTCL: 0
        };
    }

    function _groupData(aData) {
        var oGroups = {};
        var aOrder = [];

        aData.forEach(function (item) {
            var sKey = item[FIELD.assetClass] || "";
            if (!oGroups[sKey]) {
                oGroups[sKey] = {
                    code: sKey,
                    text: item[FIELD.assetClassText] || "",
                    items: [],
                    sum: _emptySum()
                };
                aOrder.push(sKey);
            }
            var oGroup = oGroups[sKey];
            oGroup.items.push(item);

            oGroup.sum.openNG += _num(item[FIELD.openNG]);
            oGroup.sum.openHMLK += _num(item[FIELD.openHMLK]);
            oGroup.sum.openGTCL += _num(item[FIELD.openGTCL]);

            oGroup.sum.increaseNG += _num(item[FIELD.increaseNG]);
            oGroup.sum.increaseHMLK += _num(item[FIELD.increaseHMLK]);
            oGroup.sum.increaseGTCL += _num(item[FIELD.increaseGTCL]);

            oGroup.sum.decreaseNG += _num(item[FIELD.decreaseNG]);
            oGroup.sum.decreaseHMLK += _num(item[FIELD.decreaseHMLK]);
            oGroup.sum.decreaseGTCL += _num(item[FIELD.decreaseGTCL]);

            oGroup.sum.khTrongKy += _num(item[FIELD.khTrongKy]);

            oGroup.sum.closeNG += _num(item[FIELD.closeNG]);
            oGroup.sum.closeHMLK += _num(item[FIELD.closeHMLK]);
            oGroup.sum.closeGTCL += _num(item[FIELD.closeGTCL]);
        });

        return aOrder.map(function (k) { return oGroups[k]; });
    }

    // ────────────────────────────────────────────────────────
    // Suy ra dòng "Tài khoản XX -" từ mã Nhóm tài sản (LoaiTaiSan)
    // (giữ nguyên logic cũ)
    // ────────────────────────────────────────────────────────
    function _getAccountLine(oGroups) {
        var oPrefixSet = {};

        oGroups.forEach(function (oGroup) {
            var sCode = oGroup.code || "";
            var oMatch = sCode.match(/(\d{2})/);
            if (oMatch) {
                oPrefixSet[oMatch[1]] = true;
            }
        });

        var aPrefixes = Object.keys(oPrefixSet);
        if (aPrefixes.length === 1) {
            return "Tài khoản " + aPrefixes[0] + " - ";
        }
        return "";
    }

    // ────────────────────────────────────────────────────────
    // Xác định "Từ ngày ... Đến ngày ..." - GIỮ NGUYÊN 100% logic cũ
    // ────────────────────────────────────────────────────────
    function _flattenFilters(aFilters, oMap) {
        oMap = oMap || {};
        if (!aFilters) { return oMap; }
        aFilters.forEach(function (oFilter) {
            var aNested = oFilter.aFilters;
            if (aNested) {
                _flattenFilters(aNested, oMap);
                return;
            }
            var sPath = oFilter.sPath || oFilter.getPath && oFilter.getPath();
            if (!sPath) { return; }
            if (!oMap[sPath]) { oMap[sPath] = []; }
            oMap[sPath].push({
                operator: oFilter.sOperator || (oFilter.getOperator && oFilter.getOperator()),
                value1: oFilter.oValue1 !== undefined ? oFilter.oValue1 : (oFilter.getValue1 && oFilter.getValue1()),
                value2: oFilter.oValue2 !== undefined ? oFilter.oValue2 : (oFilter.getValue2 && oFilter.getValue2())
            });
        });
        return oMap;
    }

    function _pad2(n) { return (n < 10 ? "0" : "") + n; }

    function _formatDMY(oDate) {
        if (!oDate) { return ""; }
        var d = (oDate instanceof Date) ? oDate : new Date(oDate);
        if (isNaN(d.getTime())) { return ""; }
        return _pad2(d.getDate()) + "/" + _pad2(d.getMonth() + 1) + "/" + d.getFullYear();
    }

    function _lastDateOfPeriod(iYear, iPeriod) {
        var iNextPeriod = iPeriod + 1;
        var iNextYear = iYear;
        if (iNextPeriod > 12) {
            iNextPeriod = 1;
            iNextYear = iYear + 1;
        }
        var oFirstDayNext = new Date(iNextYear, iNextPeriod - 1, 1);
        oFirstDayNext.setDate(oFirstDayNext.getDate() - 1);
        return oFirstDayNext;
    }

    function _getFromToDate(oInfo) {
        var oMap = _flattenFilters(oInfo.filters);

        var aPosting = oMap["PostingDate"] || [];
        var aPeriods = oMap["Periods"] || [];
        var aFiscalYear = oMap["FiscalYear"] || [];

        if (aPosting.length > 0) {
            var oP = aPosting[0];
            var oFrom = oP.value1 || oP.value2;
            var oTo = oP.value2 || oP.value1;
            return { from: _formatDMY(oFrom), to: _formatDMY(oTo) };
        }

        var sYearLow = "";
        var sYearHigh = "";
        if (aFiscalYear.length > 0) {
            sYearLow = aFiscalYear[0].value1 || aFiscalYear[0].value2 || "";
            sYearHigh = aFiscalYear[0].value2 || aFiscalYear[0].value1 || "";
        }
        var iYearLow = parseInt(sYearLow, 10) || new Date().getFullYear();
        var iYearHigh = parseInt(sYearHigh, 10) || iYearLow;

        var sPeriodLow = "001";
        var sPeriodHigh = "012";
        if (aPeriods.length > 0) {
            sPeriodLow = aPeriods[0].value1 || aPeriods[0].value2 || "001";
            sPeriodHigh = aPeriods[0].value2 || aPeriods[0].value1 || sPeriodLow;
        }
        var iPeriodLow = parseInt(sPeriodLow, 10);
        var iPeriodHigh = parseInt(sPeriodHigh, 10);

        var oFromDate = new Date(iYearLow, iPeriodLow - 1, 1);
        var oToDate = _lastDateOfPeriod(iYearHigh, iPeriodHigh);

        return { from: _formatDMY(oFromDate), to: _formatDMY(oToDate) };
    }

    // ────────────────────────────────────────────────────────
    // Lấy tên/địa chỉ công ty - GIỮ NGUYÊN 100% logic cũ
    // ────────────────────────────────────────────────────────
    function _getSmartFilterBar(oView) {
        var oById = oView.byId("listReportFilter");
        if (oById) { return oById; }

        return oView.findAggregatedObjects(true).filter(function (o) {
            return o.getMetadata().getName() === "sap.ui.comp.smartfilterbar.SmartFilterBar";
        })[0];
    }

    function _fetchCompanyInfo(oView, fnCallback) {
        var sCompanyName = "";
        var sCompanyCode = "";
        var oSFB = _getSmartFilterBar(oView);

        if (oSFB) {
            try {
                var oField = oSFB.getControlByKey(FIELD.companyCode);
                if (oField) {
                    var sControlName = oField.getMetadata().getName();

                    if (sControlName === "sap.m.MultiInput" && oField.getTokens) {
                        var aTokens = oField.getTokens();
                        if (aTokens.length > 0) {
                            var sText = aTokens[0].getText();
                            var oMatch = sText.match(/\((.+)\)/);
                            sCompanyName = oMatch ? oMatch[1] : sText;
                            sCompanyCode = aTokens[0].getKey ? aTokens[0].getKey() : "";
                        }
                    } else if (sControlName === "sap.m.Input" && oField.getValue) {
                        var sVal = oField.getValue() || "";
                        var oMatch2 = sVal.match(/^(.*?)\s*\((.+)\)\s*$/);
                        if (oMatch2) {
                            sCompanyName = oMatch2[1];
                            sCompanyCode = oMatch2[2];
                        } else {
                            sCompanyCode = sVal;
                        }
                    } else if (oField.getSelectedKey) {
                        sCompanyCode = oField.getSelectedKey() || "";
                        if (oField.getSelectedItem) {
                            var oItem = oField.getSelectedItem();
                            sCompanyName = oItem ? oItem.getText() : "";
                        }
                    }
                }
            } catch (e) { /* ignore, fallback bên dưới */ }

            if (!sCompanyCode) {
                sCompanyCode = oSFB.getFilterData()[FIELD.companyCode] || "";
            }
        }

        if (!sCompanyCode) {
            fnCallback({ name: sCompanyName, address: "" });
            return;
        }

        var oModel = oView.getModel();
        oModel.read("/ZI_COMPANYCODE_VH('" + sCompanyCode + "')", {
            success: function (oData) {
                fnCallback({
                    name: sCompanyName || oData.CompanyCodeName || "",
                    address: oData.CityName ? ("Địa chỉ : " + oData.CityName + ", Việt Nam") : ""
                });
            },
            error: function (oErr) {
                console.error("Lỗi gọi ZI_COMPANYCODE_VH:", oErr);
                fnCallback({ name: sCompanyName, address: "" });
            }
        });
    }

    // ────────────────────────────────────────────────────────
    // Build Excel theo đúng mẫu ảnh (cột B -> S)
    // ────────────────────────────────────────────────────────
    function _buildExcel(aData, sFromDate, sToDate, oCompanyInfo) {
        return new Promise(function (resolve, reject) {
            var workbook = new ExcelJS.Workbook();
            var ws = workbook.addWorksheet("Sheet1");

            var BORDER = {
                top: { style: "thin" }, left: { style: "thin" },
                bottom: { style: "thin" }, right: { style: "thin" }
            };
            var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };
            var HEADER_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF2F2F2" } };
            var NUM_FMT = "#,##0;(#,##0)";

            // Group trước để lấy dòng "Tài khoản"
            var oGroups = _groupData(aData);
            var sAccountLine = _getAccountLine(oGroups);

            // Row 1-2: Company info
            ws.mergeCells("B1:S1");
            ws.getCell("B1").value = oCompanyInfo.name || "";
            ws.getCell("B1").font = { name: "Times New Roman", size: 14 };
            ws.getCell("B1").alignment = { horizontal: "center" };

            ws.mergeCells("B2:S2");
            ws.getCell("B2").value = oCompanyInfo.address || "";
            ws.getCell("B2").font = { name: "Times New Roman", size: 10 };
            ws.getCell("B2").alignment = { horizontal: "center" };

            // Row 4: Title
            ws.mergeCells("B4:S4");
            ws.getCell("B4").value = REPORT_TITLE;
            ws.getCell("B4").font = { bold: true, size: 16, color: { argb: "FFFF0000" }, name: "Times New Roman" };
            ws.getCell("B4").alignment = { horizontal: "center" };

            // Row 5: period
            ws.mergeCells("B5:S5");
            ws.getCell("B5").value = "Từ ngày " + sFromDate + " Đến ngày " + sToDate;
            ws.getCell("B5").font = { name: "Times New Roman", size: 11 };
            ws.getCell("B5").alignment = { horizontal: "center" };

            // Row 6: Tài khoản
            ws.mergeCells("B6:S6");
            ws.getCell("B6").value = sAccountLine;
            ws.getCell("B6").font = { bold: true, size: 11, name: "Times New Roman" };
            ws.getCell("B6").alignment = { horizontal: "center" };

            // Row 8-9: header
            var rowGroup = 8;
            var rowCol = 9;

            ["B", "C", "D", "E", "F"].forEach(function (col) {
                ws.mergeCells(col + rowGroup + ":" + col + rowCol);
            });

            ws.mergeCells("G" + rowGroup + ":I" + rowGroup);
            ws.getCell("G" + rowGroup).value = "Số đầu kỳ";
            ws.mergeCells("J" + rowGroup + ":L" + rowGroup);
            ws.getCell("J" + rowGroup).value = "Tăng trong kỳ";
            ws.mergeCells("M" + rowGroup + ":O" + rowGroup);
            ws.getCell("M" + rowGroup).value = "Giảm trong kỳ";
            ws.mergeCells("P" + rowGroup + ":P" + rowCol);
            ws.getCell("P" + rowGroup).value = "KH Tkỳ";
            ws.mergeCells("Q" + rowGroup + ":S" + rowGroup);
            ws.getCell("Q" + rowGroup).value = "Số dư cuối kỳ";

            ["G" + rowGroup, "J" + rowGroup, "M" + rowGroup, "Q" + rowGroup].forEach(function (a) {
                ws.getCell(a).font = { bold: true, size: 9, name: "Times New Roman" };
                ws.getCell(a).alignment = CENTER;
                ws.getCell(a).border = BORDER;
                ws.getCell(a).fill = HEADER_FILL;
            });

            var headerSingle = {
                B: "Mã tài sản",
                C: "Số thẻ",
                D: "Tên tài sản ",
                E: "Ngày SD",
                F: "TL KH",
                P: "KH Tkỳ"
            };
            Object.keys(headerSingle).forEach(function (col) {
                var cell = ws.getCell(col + rowGroup);
                cell.value = headerSingle[col];
                cell.font = { bold: true, size: 9, name: "Times New Roman" };
                cell.alignment = CENTER;
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            });

            var headerRow2 = {
                G: "ĐK.N.Giá",
                H: "ĐK.HMLK",
                I: "ĐK.GTCL",
                J: "Tăng.NGgiá",
                K: "Tăng.HMLK",
                L: "Tăng.GTCL",
                M: "Giảm.Ngiá",
                N: "Giảm.HMLK",
                O: "Giảm.GTCL",
                Q: "CK.N.Giá",
                R: "CK.KHLK",
                S: "CK.GTCL"
            };
            Object.keys(headerRow2).forEach(function (col) {
                var cell = ws.getCell(col + rowCol);
                cell.value = headerRow2[col];
                cell.font = { bold: true, size: 9, name: "Times New Roman" };
                cell.alignment = CENTER;
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            });
            ["B", "C", "D", "E", "F", "P"].forEach(function (col) {
                var cell = ws.getCell(col + rowCol);
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            });

            // Data rows: group + item
            var iRow = rowCol + 1;

            var oGrandTotal = _emptySum();

            oGroups.forEach(function (oGroup) {
                var row = ws.getRow(iRow);
                row.getCell(2).value = oGroup.code;               // B
                row.getCell(3).value = "";                        // C - Số thẻ
                row.getCell(4).value = oGroup.text;                // D
                row.getCell(5).value = "";                        // E - Ngày SD
                row.getCell(6).value = "";                        // F - TL KH
                row.getCell(7).value = oGroup.sum.openNG;          // G
                row.getCell(8).value = oGroup.sum.openHMLK;        // H
                row.getCell(9).value = oGroup.sum.openGTCL;        // I
                row.getCell(10).value = oGroup.sum.increaseNG;     // J
                row.getCell(11).value = oGroup.sum.increaseHMLK;   // K
                row.getCell(12).value = oGroup.sum.increaseGTCL;   // L
                row.getCell(13).value = oGroup.sum.decreaseNG;     // M
                row.getCell(14).value = oGroup.sum.decreaseHMLK;   // N
                row.getCell(15).value = oGroup.sum.decreaseGTCL;   // O
                row.getCell(16).value = oGroup.sum.khTrongKy;      // P
                row.getCell(17).value = oGroup.sum.closeNG;        // Q
                row.getCell(18).value = oGroup.sum.closeHMLK;      // R
                row.getCell(19).value = oGroup.sum.closeGTCL;      // S

                for (var c = 2; c <= 19; c++) {
                    row.getCell(c).font = { bold: true, size: 10, name: "Times New Roman" };
                    row.getCell(c).border = BORDER;
                }
                iRow++;

                oGroup.items.forEach(function (item) {
                    var r = ws.getRow(iRow);
                    r.getCell(2).value = item[FIELD.assetNumber];
                    r.getCell(3).value = "";
                    r.getCell(4).value = "    " + (item[FIELD.assetName] || "");
                    r.getCell(5).value = item[FIELD.usageDate] ? new Date(item[FIELD.usageDate]) : "";
                    if (r.getCell(5).value) { r.getCell(5).numFmt = "mm-dd-yy"; }
                    r.getCell(6).value = "";
                    r.getCell(7).value = _num(item[FIELD.openNG]);
                    r.getCell(8).value = _num(item[FIELD.openHMLK]);
                    r.getCell(9).value = _num(item[FIELD.openGTCL]);
                    r.getCell(10).value = _num(item[FIELD.increaseNG]);
                    r.getCell(11).value = _num(item[FIELD.increaseHMLK]);
                    r.getCell(12).value = _num(item[FIELD.increaseGTCL]);
                    r.getCell(13).value = _num(item[FIELD.decreaseNG]);
                    r.getCell(14).value = _num(item[FIELD.decreaseHMLK]);
                    r.getCell(15).value = _num(item[FIELD.decreaseGTCL]);
                    r.getCell(16).value = _num(item[FIELD.khTrongKy]);
                    r.getCell(17).value = _num(item[FIELD.closeNG]);
                    r.getCell(18).value = _num(item[FIELD.closeHMLK]);
                    r.getCell(19).value = _num(item[FIELD.closeGTCL]);

                    for (var cc = 2; cc <= 19; cc++) {
                        r.getCell(cc).border = BORDER;
                        r.getCell(cc).font = { size: 9, name: "Times New Roman" };
                    }
                    iRow++;
                });

                Object.keys(oGrandTotal).forEach(function (k) {
                    oGrandTotal[k] += oGroup.sum[k];
                });
            });

            // Dòng Cộng
            var rowTotal = ws.getRow(iRow);
            rowTotal.getCell(2).value = "Cộng";
            rowTotal.getCell(2).font = { bold: true, color: { argb: "FFFF0000" }, name: "Times New Roman" };
            rowTotal.getCell(2).alignment = { horizontal: "center" };
            rowTotal.getCell(7).value = oGrandTotal.openNG;
            rowTotal.getCell(8).value = oGrandTotal.openHMLK;
            rowTotal.getCell(9).value = oGrandTotal.openGTCL;
            rowTotal.getCell(10).value = oGrandTotal.increaseNG;
            rowTotal.getCell(11).value = oGrandTotal.increaseHMLK;
            rowTotal.getCell(12).value = oGrandTotal.increaseGTCL;
            rowTotal.getCell(13).value = oGrandTotal.decreaseNG;
            rowTotal.getCell(14).value = oGrandTotal.decreaseHMLK;
            rowTotal.getCell(15).value = oGrandTotal.decreaseGTCL;
            rowTotal.getCell(16).value = oGrandTotal.khTrongKy;
            rowTotal.getCell(17).value = oGrandTotal.closeNG;
            rowTotal.getCell(18).value = oGrandTotal.closeHMLK;
            rowTotal.getCell(19).value = oGrandTotal.closeGTCL;
            for (var ct = 2; ct <= 19; ct++) {
                rowTotal.getCell(ct).font = { bold: true, name: "Times New Roman" };
                rowTotal.getCell(ct).border = BORDER;
            }
            var iRowAfterTotal = iRow;
            iRow += 2;

            // Dòng "Ngày ... Tháng ... Năm ..." - lấy đúng ngày hiện tại khi export
            var oToday = new Date();
            ws.mergeCells("Q" + iRow + ":S" + iRow);
            ws.getCell("Q" + iRow).value = "Ngày " + _pad2(oToday.getDate())
                + "   Tháng " + _pad2(oToday.getMonth() + 1)
                + "   Năm " + oToday.getFullYear();
            ws.getCell("Q" + iRow).font = { name: "Times New Roman", size: 9 };
            ws.getCell("Q" + iRow).alignment = { horizontal: "right", vertical: "center" };
            iRow += 1;

            // Dòng chữ ký - tách 3 cell riêng biệt (không gộp chung 1 string)
            ws.mergeCells("B" + iRow + ":G" + iRow);
            ws.getCell("B" + iRow).value = "Người lập biểu";
            ws.mergeCells("H" + iRow + ":M" + iRow);
            ws.getCell("H" + iRow).value = "Kế toán trưởng";
            ws.mergeCells("N" + iRow + ":S" + iRow);
            ws.getCell("N" + iRow).value = "Giám đốc";

            ["B" + iRow, "H" + iRow, "N" + iRow].forEach(function (a) {
                ws.getCell(a).font = { bold: true, name: "Times New Roman", size: 9 };
                ws.getCell(a).alignment = { horizontal: "center", vertical: "center" };
            });

            // Number format cho các cột tiền (G-S)
            for (var nr = rowGroup + 2; nr <= iRowAfterTotal; nr++) {
                for (var nc = 7; nc <= 19; nc++) {
                    ws.getRow(nr).getCell(nc).numFmt = NUM_FMT;
                }
            }

            // Column widths (B -> S)
            ws.columns = [
                { width: 2 },  // A (ẩn/không dùng)
                { width: 14 }, // B - Mã tài sản
                { width: 10 }, // C - Số thẻ
                { width: 45 }, // D - Tên tài sản
                { width: 10 }, // E - Ngày SD
                { width: 8 },  // F - TL KH
                { width: 14 }, // G
                { width: 14 }, // H
                { width: 14 }, // I
                { width: 14 }, // J
                { width: 14 }, // K
                { width: 14 }, // L
                { width: 14 }, // M
                { width: 14 }, // N
                { width: 14 }, // O
                { width: 12 }, // P
                { width: 14 }, // Q
                { width: 14 }, // R
                { width: 14 }  // S
            ];

            // Ẩn cột A, C, F
            ws.getColumn(1).hidden = true; // A
            ws.getColumn(3).hidden = true; // C
            ws.getColumn(6).hidden = true; // F

            workbook.xlsx.writeBuffer().then(function (buffer) {
                var blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                var url = URL.createObjectURL(blob);
                var link = document.createElement("a");
                link.href = url;
                link.download = "BaoCaoTangGiamTSCD_"
                    + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
                    + ".xlsx";
                link.click();
                URL.revokeObjectURL(url);
                resolve();
            }).catch(reject);
        });
    }

    function _loadExcelJS() {
        if (window.ExcelJS) { return Promise.resolve(); }
        return new Promise(function (resolve, reject) {
            var script = document.createElement("script");
            script.src = sap.ui.require.toUrl("zassettgrpov2/libs/exceljs.min.js"); // TODO confirm path
            script.onload = resolve;
            script.onerror = function () { reject(new Error("Không load được ExcelJS")); };
            document.head.appendChild(script);
        });
    }

    function _doExport(oView) {
        var oInfo = _getBindingInfo(oView);
        if (!oInfo) {
            MessageBox.warning("Vui lòng nhấn nút \"Go\" để tải dữ liệu trước khi Export.");
            return;
        }
        if (oInfo.total === 0) {
            MessageBox.warning("Không có dữ liệu để export. Vui lòng kiểm tra lại điều kiện lọc rồi nhấn \"Go\".");
            return;
        }

        var oFromTo = _getFromToDate(oInfo);
        var sFromDate = oFromTo.from;
        var sToDate = oFromTo.to;

        var oBusy = new BusyDialog({ title: "Đang xuất Excel", text: "Đang chuẩn bị..." });
        oBusy.open();

        _loadExcelJS()
            .then(function () {
                return new Promise(function (resolve, reject) {
                    _fetchCompanyInfo(oView, function (oCompanyInfo) {
                        _fetchAllBatched(oInfo, oBusy)
                            .then(function (aData) {
                                resolve({ data: aData, company: oCompanyInfo });
                            })
                            .catch(reject);
                    });
                });
            })
            .then(function (oResult) {
                oBusy.setText("Đang tạo file Excel (" + oResult.data.length.toLocaleString("vi-VN") + " dòng)...");
                return _buildExcel(oResult.data, sFromDate, sToDate, oResult.company);
            })
            .then(function () {
                oBusy.close();
                oBusy.destroy();
                MessageToast.show("Export thành công!");
            })
            .catch(function (oErr) {
                oBusy.close();
                oBusy.destroy();
                var sMsg = oErr && oErr.message ? oErr.message
                    : (oErr && oErr.responseText) ? oErr.responseText
                        : JSON.stringify(oErr);
                MessageBox.error("Lỗi export: " + sMsg);
            });
    }

    return {
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },
        exportExcel: function () {
            _doExport(this.getView());
        }
    };
});