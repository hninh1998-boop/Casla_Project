sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/ui/core/Fragment"
], function (MessageToast, MessageBox, BusyDialog, Fragment) {
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
        location: "DiaDiemSuDung",
        plant: "NhaMay",

        openBookValue: "NguyenGiaDauKy",
        increaseValue: "TangNguyenGia",
        decreaseValue: "GiamNguyenGia",
        closeBookValue: "NguyenGiaCuoiKy",

        openAccumDep: "KhauHaoDauKy",
        increaseAccumDep: "TangKhauHao",
        decreaseAccumDep: "GiamKhauHao",
        closeAccumDep: "KhauHaoCuoiKy",

        closeNetValue: "GiaTriConLaiCuoiKy",

        cardInfo: "",
        totalCriteria: "SoKyKhauHao"
    };

    var REPORT_TITLE = "BÁO CÁO TỔNG HỢP TÀI SẢN CỐ ĐỊNH";
    var REPORT_TITLE_TSCD2 = "BÁO CÁO TÀI SẢN CỐ ĐỊNH THEO NHÓM HÌNH CÂY";

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
    // ────────────────────────────────────────────────────────
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
                    sum: {
                        openBookValue: 0, increaseValue: 0, decreaseValue: 0, closeBookValue: 0,
                        openAccumDep: 0, increaseAccumDep: 0, decreaseAccumDep: 0, closeAccumDep: 0,
                        closeNetValue: 0
                    }
                };
                aOrder.push(sKey);
            }
            var oGroup = oGroups[sKey];
            oGroup.items.push(item);

            oGroup.sum.openBookValue += _num(item[FIELD.openBookValue]);
            oGroup.sum.increaseValue += _num(item[FIELD.increaseValue]);
            oGroup.sum.decreaseValue += _num(item[FIELD.decreaseValue]);
            oGroup.sum.closeBookValue += _num(item[FIELD.closeBookValue]);
            oGroup.sum.openAccumDep += _num(item[FIELD.openAccumDep]);
            oGroup.sum.increaseAccumDep += _num(item[FIELD.increaseAccumDep]);
            oGroup.sum.decreaseAccumDep += _num(item[FIELD.decreaseAccumDep]);
            oGroup.sum.closeAccumDep += _num(item[FIELD.closeAccumDep]);
            oGroup.sum.closeNetValue += _num(item[FIELD.closeNetValue]);
        });

        return aOrder.map(function (k) { return oGroups[k]; });
    }

    function _groupDataTSCD2(aData) {
        var oGroups = {};
        var aOrder = [];

        aData.forEach(function (item) {
            var sKey = item[FIELD.assetClass] || "";
            if (!oGroups[sKey]) {
                oGroups[sKey] = {
                    code: sKey,
                    text: item[FIELD.assetClassText] || "",
                    items: [],
                    sum: {
                        closeBookValue: 0,
                        khTrongKy: 0,
                        khLuyKe: 0,
                        conLai: 0
                    }
                };
                aOrder.push(sKey);
            }
            var oGroup = oGroups[sKey];
            oGroup.items.push(item);

            var fKhTrongKy = _num(item[FIELD.increaseAccumDep]) - _num(item[FIELD.decreaseAccumDep]);

            oGroup.sum.closeBookValue += _num(item[FIELD.closeBookValue]);
            oGroup.sum.khTrongKy += fKhTrongKy;
            oGroup.sum.khLuyKe += _num(item[FIELD.closeAccumDep]);
            oGroup.sum.conLai += _num(item[FIELD.closeNetValue]);
        });

        return aOrder.map(function (k) { return oGroups[k]; });
    }

    // ────────────────────────────────────────────────────────
    // Suy ra dòng "Tài khoản XX -" từ mã Nhóm tài sản (LoaiTaiSan)
    // của các nhóm đã group. Lấy 2 chữ số đầu tiên xuất hiện trong
    // mã (VD "Z2111001" -> "21"). Nếu TẤT CẢ nhóm cùng chung 2 số
    // đầu -> hiển thị "Tài khoản XX -". Nếu có từ 2 prefix khác
    // nhau trở lên (VD Z21..., Z24...) -> để trống.
    // ────────────────────────────────────────────────────────
    function _getAccountLine(oGroups) {
        var oPrefixSet = {};

        oGroups.forEach(function (oGroup) {
            var sCode = oGroup.code || "";
            var oMatch = sCode.match(/(\d{2})/); // 2 chữ số liên tiếp đầu tiên
            if (oMatch) {
                oPrefixSet[oMatch[1]] = true;
            }
        });

        var aPrefixes = Object.keys(oPrefixSet);
        if (aPrefixes.length === 1) {
            return "Tài khoản " + aPrefixes[0] + " -";
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
    // Build Excel theo đúng mẫu ảnh (cấu trúc cột A -> M)
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

            // Group trước để lấy được dòng "Tài khoản" từ danh sách nhóm
            var oGroups = _groupData(aData);
            var sAccountLine = _getAccountLine(oGroups);

            // Row 1-2: Company info
            ws.mergeCells("A1:M1");
            ws.getCell("A1").value = oCompanyInfo.name || "";
            ws.getCell("A1").font = { bold: true, size: 12 };
            ws.getCell("A1").alignment = { horizontal: "center" };

            ws.mergeCells("A2:M2");
            ws.getCell("A2").value = oCompanyInfo.address || "";
            ws.getCell("A2").alignment = { horizontal: "center" };

            // Row 4: Title
            ws.mergeCells("A4:M4");
            ws.getCell("A4").value = REPORT_TITLE;
            ws.getCell("A4").font = { bold: true, size: 14, color: { argb: "FFFF0000" } };
            ws.getCell("A4").alignment = { horizontal: "center" };

            // Row 5: period
            ws.mergeCells("A5:M5");
            ws.getCell("A5").value = "Từ ngày " + sFromDate + " Đến ngày " + sToDate;
            ws.getCell("A5").alignment = { horizontal: "center" };

            // Row 6: Tài khoản - suy ra động, nếu rỗng thì để trống dòng (vẫn merge)
            ws.mergeCells("A6:M6");
            ws.getCell("A6").value = sAccountLine;
            ws.getCell("A6").font = { bold: true };
            ws.getCell("A6").alignment = { horizontal: "center" };

            // Row 8-9: header
            var rowGroup = 8;
            var rowCol = 9;

            ["A", "B", "K", "L", "M"].forEach(function (col) {
                ws.mergeCells(col + rowGroup + ":" + col + rowCol);
            });

            ws.mergeCells("C" + rowGroup + ":F" + rowGroup);
            ws.getCell("C" + rowGroup).value = "Nguyên giá";
            ws.mergeCells("G" + rowGroup + ":J" + rowGroup);
            ws.getCell("G" + rowGroup).value = "GT khấu hao";

            ["C" + rowGroup, "G" + rowGroup].forEach(function (a) {
                ws.getCell(a).font = { bold: true };
                ws.getCell(a).alignment = CENTER;
                ws.getCell(a).border = BORDER;
                ws.getCell(a).fill = HEADER_FILL;
            });

            var headerSingle = {
                A: "Mã TSCĐ",
                B: "Tên TSCĐ",
                K: "Giá trị còn lại",
                L: "Thẻ TSCĐ",
                M: "Tổng tiêu thức"
            };
            Object.keys(headerSingle).forEach(function (col) {
                var cell = ws.getCell(col + rowGroup);
                cell.value = headerSingle[col];
                cell.font = { bold: true };
                cell.alignment = CENTER;
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            });

            var headerRow2 = {
                C: "Nguyên giá đầu kỳ",
                D: "Tăng Nguyên giá",
                E: "Giảm Nguyên giá",
                F: "Nguyên giá cuối kỳ",
                G: "Khấu hao đầu kỳ",
                H: "Tăng Khấu hao",
                I: "Giảm Khấu hao",
                J: "Khấu hao cuối kỳ"
            };
            Object.keys(headerRow2).forEach(function (col) {
                var cell = ws.getCell(col + rowCol);
                cell.value = headerRow2[col];
                cell.font = { bold: true };
                cell.alignment = CENTER;
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            });
            ["A", "B", "K", "L", "M"].forEach(function (col) {
                var cell = ws.getCell(col + rowCol);
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            });

            // Data rows: group + item (dùng lại oGroups đã tính ở trên)
            var iRow = rowCol + 1;

            var oGrandTotal = {
                openBookValue: 0, increaseValue: 0, decreaseValue: 0, closeBookValue: 0,
                openAccumDep: 0, increaseAccumDep: 0, decreaseAccumDep: 0, closeAccumDep: 0,
                closeNetValue: 0
            };

            oGroups.forEach(function (oGroup) {
                var row = ws.getRow(iRow);
                row.getCell(1).value = oGroup.code;
                row.getCell(2).value = oGroup.text;
                row.getCell(3).value = oGroup.sum.openBookValue;
                row.getCell(4).value = oGroup.sum.increaseValue;
                row.getCell(5).value = oGroup.sum.decreaseValue;
                row.getCell(6).value = oGroup.sum.closeBookValue;
                row.getCell(7).value = oGroup.sum.openAccumDep;
                row.getCell(8).value = oGroup.sum.increaseAccumDep;
                row.getCell(9).value = oGroup.sum.decreaseAccumDep;
                row.getCell(10).value = oGroup.sum.closeAccumDep;
                row.getCell(11).value = oGroup.sum.closeNetValue;
                row.getCell(12).value = "";
                row.getCell(13).value = "";

                for (var c = 1; c <= 13; c++) {
                    row.getCell(c).font = { bold: true };
                    row.getCell(c).border = BORDER;
                }
                iRow++;

                oGroup.items.forEach(function (item) {
                    var r = ws.getRow(iRow);
                    r.getCell(1).value = item[FIELD.assetNumber];
                    r.getCell(2).value = "    " + (item[FIELD.assetName] || "");
                    r.getCell(3).value = _num(item[FIELD.openBookValue]);
                    r.getCell(4).value = _num(item[FIELD.increaseValue]);
                    r.getCell(5).value = _num(item[FIELD.decreaseValue]);
                    r.getCell(6).value = _num(item[FIELD.closeBookValue]);
                    r.getCell(7).value = _num(item[FIELD.openAccumDep]);
                    r.getCell(8).value = _num(item[FIELD.increaseAccumDep]);
                    r.getCell(9).value = _num(item[FIELD.decreaseAccumDep]);
                    r.getCell(10).value = _num(item[FIELD.closeAccumDep]);
                    r.getCell(11).value = _num(item[FIELD.closeNetValue]);
                    r.getCell(12).value = item[FIELD.cardInfo] || "";
                    r.getCell(13).value = item[FIELD.totalCriteria] ? parseInt(item[FIELD.totalCriteria], 10) : "";

                    for (var cc = 1; cc <= 11; cc++) {
                        r.getCell(cc).border = BORDER;
                    }
                    r.getCell(12).border = BORDER;
                    r.getCell(13).border = BORDER;
                    r.getCell(13).alignment = { horizontal: "center" };
                    iRow++;
                });

                Object.keys(oGrandTotal).forEach(function (k) {
                    oGrandTotal[k] += oGroup.sum[k];
                });
            });

            // Dòng Cộng
            var rowTotal = ws.getRow(iRow);
            rowTotal.getCell(1).value = "Cộng";
            rowTotal.getCell(1).font = { bold: true, color: { argb: "FFFF0000" } };
            rowTotal.getCell(3).value = oGrandTotal.openBookValue;
            rowTotal.getCell(4).value = oGrandTotal.increaseValue;
            rowTotal.getCell(5).value = oGrandTotal.decreaseValue;
            rowTotal.getCell(6).value = oGrandTotal.closeBookValue;
            rowTotal.getCell(7).value = oGrandTotal.openAccumDep;
            rowTotal.getCell(8).value = oGrandTotal.increaseAccumDep;
            rowTotal.getCell(9).value = oGrandTotal.decreaseAccumDep;
            rowTotal.getCell(10).value = oGrandTotal.closeAccumDep;
            rowTotal.getCell(11).value = oGrandTotal.closeNetValue;
            for (var ct = 1; ct <= 13; ct++) {
                rowTotal.getCell(ct).font = { bold: true };
                rowTotal.getCell(ct).border = BORDER;
            }
            var iRowAfterTotal = iRow;
            iRow += 2;

            // Signature block
            var oToday = new Date();
            ws.getCell("B" + iRow).value = "Ngày " + _pad2(oToday.getDate())
                + " Tháng " + _pad2(oToday.getMonth() + 1)
                + " Năm " + oToday.getFullYear();
            iRow += 2;
            ws.getCell("B" + iRow).value = "Người lập biểu";
            ws.getCell("F" + iRow).value = "Kế toán trưởng";
            ws.getCell("K" + iRow).value = "Giám đốc";
            ["B", "F", "K"].forEach(function (col) {
                ws.getCell(col + iRow).font = { bold: true };
                ws.getCell(col + iRow).alignment = { horizontal: "center" };
            });

            // Number format cho các cột tiền (C-K)
            for (var nr = rowCol + 1; nr <= iRowAfterTotal; nr++) {
                for (var nc = 3; nc <= 11; nc++) {
                    ws.getRow(nr).getCell(nc).numFmt = "#,##0";
                }
            }

            // Column widths (A -> M)
            ws.columns = [
                { width: 18 }, { width: 50 },
                { width: 16 }, { width: 16 }, { width: 16 }, { width: 16 },
                { width: 16 }, { width: 16 }, { width: 16 }, { width: 16 },
                { width: 16 }, { width: 14 }, { width: 14 }
            ];

            ws.eachRow({ includeEmpty: false }, function (row) {
                row.eachCell({ includeEmpty: false }, function (cell) {
                    cell.font = Object.assign({}, cell.font, { name: "Times New Roman" });
                });
            });

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

    function _buildExcelTSCD2(aData, sFromDate, sToDate, oCompanyInfo) {
        return new Promise(function (resolve, reject) {
            var workbook = new ExcelJS.Workbook();
            var ws = workbook.addWorksheet("Sheet1");

            var BORDER = {
                top: { style: "thin" }, left: { style: "thin" },
                bottom: { style: "thin" }, right: { style: "thin" }
            };
            var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };
            var HEADER_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF2F2F2" } };

            var oGroups = _groupDataTSCD2(aData);
            var sAccountLine = _getAccountLine(oGroups); // dùng lại nguyên logic cũ

            // Row 1-2: Company info — GIỮ NGUYÊN logic cũ
            ws.mergeCells("A1:K1");
            ws.getCell("A1").value = oCompanyInfo.name || "";
            ws.getCell("A1").font = { bold: true, size: 12 };
            ws.getCell("A1").alignment = { horizontal: "center" };

            ws.mergeCells("A2:K2");
            ws.getCell("A2").value = oCompanyInfo.address || "";
            ws.getCell("A2").alignment = { horizontal: "center" };

            // Row 4: Title
            ws.mergeCells("A4:K4");
            ws.getCell("A4").value = REPORT_TITLE_TSCD2;
            ws.getCell("A4").font = { bold: true, size: 14, color: { argb: "FFFF0000" } };
            ws.getCell("A4").alignment = { horizontal: "center" };

            // Row 5: period — GIỮ NGUYÊN logic cũ
            ws.mergeCells("A5:K5");
            ws.getCell("A5").value = "Từ ngày " + sFromDate + " Đến ngày " + sToDate;
            ws.getCell("A5").alignment = { horizontal: "center" };

            // Row 6: Tài khoản — GIỮ NGUYÊN logic cũ
            ws.mergeCells("A6:K6");
            ws.getCell("A6").value = sAccountLine;
            ws.getCell("A6").font = { bold: true };
            ws.getCell("A6").alignment = { horizontal: "center" };

            // Row 8: header (1 dòng duy nhất)
            var rowHeader = 8;
            var headerMap = {
                A: "Mã TSCĐ",
                B: "Số thẻ",
                C: "Bộ phận",
                D: "Tên TSCĐ",
                E: "Nhà máy",
                F: "Ngày SD",
                G: "Nguyên giá",
                H: "Tổng tiêu thức",
                I: "KH trong kỳ",
                J: "KH lũy kế",
                K: "GT còn lại"
            };
            Object.keys(headerMap).forEach(function (col) {
                var cell = ws.getCell(col + rowHeader);
                cell.value = headerMap[col];
                cell.font = { bold: true };
                cell.alignment = CENTER;
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            });

            var iRow = rowHeader + 1;

            var oGrandTotal = { closeBookValue: 0, khTrongKy: 0, khLuyKe: 0, conLai: 0 };

            oGroups.forEach(function (oGroup) {
                var row = ws.getRow(iRow);
                row.getCell(1).value = oGroup.code;               // Mã TSCĐ (group)
                row.getCell(4).value = oGroup.text;                // Tên TSCĐ (group)
                row.getCell(7).value = oGroup.sum.closeBookValue;  // Nguyên giá (cuối kỳ)
                row.getCell(8).value = "";                          // Tổng tiêu thức - để trống ở group
                row.getCell(9).value = oGroup.sum.khTrongKy;       // KH trong kỳ
                row.getCell(10).value = oGroup.sum.khLuyKe;        // KH lũy kế
                row.getCell(11).value = oGroup.sum.conLai;         // GT còn lại

                for (var c = 1; c <= 11; c++) {
                    row.getCell(c).font = { bold: true };
                    row.getCell(c).border = BORDER;
                }
                iRow++;

                oGroup.items.forEach(function (item) {
                    var r = ws.getRow(iRow);
                    r.getCell(1).value = item[FIELD.assetNumber];
                    r.getCell(2).value = item[FIELD.assetNumber];                // Số thẻ = MaTaiSan
                    r.getCell(3).value = item[FIELD.location] || "";            // Bộ phận = DiaDiemSuDung
                    r.getCell(4).value = "    " + (item[FIELD.assetName] || ""); // Tên TSCĐ (indented)
                    r.getCell(5).value = item[FIELD.plant] || "";                // Nhà máy
                    r.getCell(6).value = _formatDMY(item[FIELD.usageDate]);      // Ngày SD
                    r.getCell(7).value = _num(item[FIELD.closeBookValue]);       // Nguyên giá (cuối kỳ)
                    r.getCell(8).value = item[FIELD.totalCriteria]
                        ? parseInt(item[FIELD.totalCriteria], 10) : "";           // Tổng tiêu thức
                    r.getCell(9).value = _num(item[FIELD.increaseAccumDep])
                        - _num(item[FIELD.decreaseAccumDep]);                    // KH trong kỳ
                    r.getCell(10).value = _num(item[FIELD.closeAccumDep]);       // KH lũy kế
                    r.getCell(11).value = _num(item[FIELD.closeNetValue]);       // GT còn lại

                    for (var cc = 1; cc <= 11; cc++) {
                        r.getCell(cc).border = BORDER;
                    }
                    r.getCell(6).alignment = { horizontal: "center" };
                    r.getCell(8).alignment = { horizontal: "center" };
                    iRow++;
                });

                oGrandTotal.closeBookValue += oGroup.sum.closeBookValue;
                oGrandTotal.khTrongKy += oGroup.sum.khTrongKy;
                oGrandTotal.khLuyKe += oGroup.sum.khLuyKe;
                oGrandTotal.conLai += oGroup.sum.conLai;
            });

            // Dòng Cộng
            var rowTotal = ws.getRow(iRow);
            rowTotal.getCell(1).value = "Cộng";
            rowTotal.getCell(1).font = { bold: true, color: { argb: "FFFF0000" } };
            rowTotal.getCell(7).value = oGrandTotal.closeBookValue;
            rowTotal.getCell(9).value = oGrandTotal.khTrongKy;
            rowTotal.getCell(10).value = oGrandTotal.khLuyKe;
            rowTotal.getCell(11).value = oGrandTotal.conLai;
            for (var ct = 1; ct <= 11; ct++) {
                rowTotal.getCell(ct).font = { bold: true };
                rowTotal.getCell(ct).border = BORDER;
            }
            var iRowAfterTotal = iRow;
            iRow += 2;

            // Signature block — GIỮ NGUYÊN logic cũ, chỉ đổi cột (B/F/K -> B/F/J vì bảng hẹp hơn)
            var oToday = new Date();
            ws.getCell("B" + iRow).value = "Ngày " + _pad2(oToday.getDate())
                + " Tháng " + _pad2(oToday.getMonth() + 1)
                + " Năm " + oToday.getFullYear();
            iRow += 2;
            ws.getCell("B" + iRow).value = "Người lập biểu";
            ws.getCell("F" + iRow).value = "Kế toán trưởng";
            ws.getCell("J" + iRow).value = "Giám đốc";
            ["B", "F", "J"].forEach(function (col) {
                ws.getCell(col + iRow).font = { bold: true };
                ws.getCell(col + iRow).alignment = { horizontal: "center" };
            });

            // Number format cho cột tiền (G, I, J, K)
            for (var nr = rowHeader + 1; nr <= iRowAfterTotal; nr++) {
                [7, 9, 10, 11].forEach(function (nc) {
                    ws.getRow(nr).getCell(nc).numFmt = "#,##0";
                });
            }

            // Column widths (A -> K)
            ws.columns = [
                { width: 14 }, { width: 12 }, { width: 14 }, { width: 45 },
                { width: 10 }, { width: 12 }, { width: 16 }, { width: 14 },
                { width: 16 }, { width: 16 }, { width: 16 }
            ];

            ws.eachRow({ includeEmpty: false }, function (row) {
                row.eachCell({ includeEmpty: false }, function (cell) {
                    cell.font = Object.assign({}, cell.font, { name: "Times New Roman" });
                });
            });

            workbook.xlsx.writeBuffer().then(function (buffer) {
                var blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                var url = URL.createObjectURL(blob);
                var link = document.createElement("a");
                link.href = url;
                link.download = "BaoCaoTSCD_TheoNhom_"
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
            script.src = sap.ui.require.toUrl("zassetrpov2/libs/exceljs.min.js"); // TODO confirm path
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

    function _doExportGeneric(oView, fnBuild) {
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
                return fnBuild(oResult.data, sFromDate, sToDate, oResult.company);
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

    function _replaceExportButtonWithMenu(oView, oController) {
        var oButton = oView.byId("exportExcelButton");
        if (!oButton || oButton._bReplacedByMenu) {
            return;
        }

        var oToolbar = oButton.getParent();
        if (!oToolbar || !oToolbar.getContent) {
            return;
        }

        var iIndex = oToolbar.indexOfContent(oButton);

        Fragment.load({
            id: oView.getId(),
            name: "zassetrpov2.ext.fragment.ExportMenuButton",
            controller: oController
        }).then(function (oMenuButton) {
            oButton._bReplacedByMenu = true;
            oButton.setVisible(false); // ẩn thay vì destroy để tránh lỗi id-binding của template
            oToolbar.insertContent(oMenuButton, iIndex);
        });
    }

    return {
        onInit: function () {
            this.getView().addEventDelegate({
                onAfterRendering: function () {
                    _replaceExportButtonWithMenu(this.getView(), this);
                }.bind(this)
            });
        },

        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },
        // THAY hàm exportExcel cũ:
        exportExcel: function (oEvent) {
            var oSource = oEvent.getSource();
            var sFormType = (oSource.data && oSource.data("formType")) || "TSCD1";

            if (sFormType === "TSCD2") {
                _doExportGeneric(this.getView(), _buildExcelTSCD2);
                return;
            }

            // TSCĐ 1 — giữ nguyên logic export hiện tại, KHÔNG đổi gì
            _doExportGeneric(this.getView(), _buildExcel);
        }
    };
});