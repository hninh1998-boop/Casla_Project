sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog"
], function (MessageToast, MessageBox, BusyDialog) {
    'use strict';

    var BATCH_SIZE = 1000;
    var CONCURRENCY = 4;

    var DEPT_NAME = "PHÒNG KD-XNK";

    // Cột hiển thị trên Excel, theo đúng thứ tự trên mẫu "Tem KH đóng cont".
    // 4 cột đầu (Thứ/Ngày, Giờ gọi cont về NM, SỐ CONT, SỐ CHỈ) chưa có nguồn dữ liệu
    // từ RAP nên tạm thời gán cứng (value: null). Từ cột thứ 5 trở đi lấy theo field
    // tương ứng trên custom entity zce_cont.
    var COLUMNS = [
        { label: "Thứ/ Ngày", field: "Ngay", width: 10 },
        { label: "Giờ gọi cont về NM", field: "GioGoiContVeNM", width: 12 },
        { label: "SỐ CONT", field: "SoCont", width: 12 },
        { label: "SỐ CHÌ", field: "SoChi", width: 10 },
        { label: "Ngày tàu chạy", field: "NgayTauChay", width: 12 },
        { label: "Phương thức đóng hàng & phối thùng", field: "GhiChuGiaoHang", width: 42, wrap: true },
        { label: "Đóng dấu thùng", field: "DongDauThung", width: 12 },
        { label: "Số SO", field: "SO", width: 12, numeric: true },
        { label: "Item", field: "SOItem", width: 8, numeric: true },
        { label: "SỐ KH", field: "SoKH", width: 14 },
        { label: "TÊN TÚI", field: "TenHang", width: 14 },
        { label: "Kich thước túi", field: "KichThhuocTui", width: 12 },
        { label: "Người phụ trách cont", field: "NguoiPhuTrachCont", width: 12 },
        { label: "Thời gian cắt máng", field: "ThoiGianCatMang", width: 12 },
        { label: "Địa điểm đóng hàng", field: "PlantName", width: 16 },
        { label: "Cont", field: "Cont", width: 10 },
        { label: "Số lệnh xuất hàng (OD)", field: "SoLenhXuatHang", width: 14, numeric: true },
        { label: "OD item", field: "SoLenhXuatHangItem", width: 8, numeric: true },
        { label: "Số lượng trên lệnh xuất hàng", field: "SoLuongTrenLenhXuatHang", width: 16, quantity: true },
        { label: "Số lượng chưa lên lệnh xuất hàng", field: "SoLuongChuaLenLenhXuatHang", width: 16, quantity: true },
        { label: "Trạng thái OD", field: "TrangThaiOD", width: 14 },
        { label: "Kế hoạch đóng cont", field: "KeHoachDongCont", width: 14 },
        { label: "Ghi chú khác", field: "GhiChuKhac", width: 20, wrap: true }
    ];

    var FIRST_COL = 2;                                  // B
    var LAST_COL = FIRST_COL + COLUMNS.length - 1;       // S

    return {
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },
        exportExcel: function () {
            mainExport(this.getView());
        }
    };


    //////////////////////////////////////////////////////////////////////////
    // Main Logic Export Excel
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

        var oBusy = new BusyDialog({
            title: "Đang xuất Excel",
            text: "Đang chuẩn bị..."
        });
        oBusy.open();

        loadExcelJS()
            .then(function () {
                return fetchAllData(oRaw, oBusy);
            })
            .then(function (aData) {
                oBusy.setText("Đang tạo file Excel (" + aData.length.toLocaleString("vi-VN") + " dòng)...");
                return buildExcel(aData);
            })
            .then(function () {
                oBusy.close();
                oBusy.destroy();
                MessageToast.show("Export thành công!");
            })
            .catch(function (oErr) {
                oBusy.close();
                oBusy.destroy();

                var sMsg = "Có lỗi xảy ra";
                if (oErr && oErr.message) {
                    sMsg = oErr.message;
                } else if (oErr && oErr.responseText) {
                    sMsg = oErr.responseText;
                }
                MessageBox.error("Lỗi export: " + sMsg);
            });
    }


    //////////////////////////////////////////////////////////////////////////
    // Lấy dữ liệu Raw từ SmartTable đang hiển thị trên view
    function getRaw(oView) {
        var oAll = oView.findAggregatedObjects(true);

        var oSmartTable;
        for (var i = 0; i < oAll.length; i++) {
            if (oAll[i].getMetadata().getName() === "sap.ui.comp.smarttable.SmartTable") {
                oSmartTable = oAll[i];
                break;
            }
        }
        if (!oSmartTable) { return null; }

        var oTable = oSmartTable.getTable();
        if (!oTable) { return null; }

        var oBinding = oTable.getBinding("rows") || oTable.getBinding("items");
        if (!oBinding) { return null; }

        var oModel = oBinding.getModel();
        // getPath() có thể trả về path tương đối (vd khi bảng bind qua context của
        // SmartTable) -> phải resolve về path tuyệt đối thì model.read() mới đúng,
        // nếu không request sẽ sai URL và báo lỗi "HTTP request failed".
        var sPath = oModel.resolve(oBinding.getPath(), oBinding.getContext()) || oBinding.getPath();

        return {
            smartTable: oSmartTable,
            table: oTable,
            binding: oBinding,
            model: oModel,
            path: sPath,
            filters: oBinding.aApplicationFilters || [],
            sorters: oBinding.aSorters || [],
            totalLength: oBinding.getLength()
        };
    }


    //////////////////////////////////////////////////////////////////////////
    // Tải toàn bộ dữ liệu qua $skip/$top theo batch, chạy song song CONCURRENCY batch
    // để tối ưu tốc độ khi dữ liệu nhiều.
    function fetchAllData(oRaw, oBusyDialog) {
        return new Promise(function (resolve, reject) {
            var iTotal = oRaw.totalLength;
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

                oRaw.model.read(oRaw.path, {
                    filters: oRaw.filters,
                    sorters: oRaw.sorters,
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


    //////////////////////////////////////////////////////////////////////////
    // Load thư viện ExcelJS (chỉ load 1 lần)
    function loadExcelJS() {
        if (window.ExcelJS) {
            return Promise.resolve();
        }

        return new Promise(function (resolve, reject) {
            var oScript = document.createElement("script");
            oScript.src = sap.ui.require.toUrl("zcontov2/libs/exceljs.min.js");
            oScript.onload = resolve;
            oScript.onerror = function () {
                reject(new Error("Không load được ExcelJS"));
            };
            document.head.appendChild(oScript);
        });
    }


    //////////////////////////////////////////////////////////////////////////
    // Helpers
    function colLetter(iIndex) {
        var s = "";
        while (iIndex > 0) {
            var iRem = (iIndex - 1) % 26;
            s = String.fromCharCode(65 + iRem) + s;
            iIndex = Math.floor((iIndex - 1) / 26);
        }
        return s;
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function toNumber(v) {
        return v ? parseFloat(v) : 0;
    }

    // Bỏ số 0 dẫn đầu của các field kiểu SO/Item/DO (vbelv, posnv, vbeln...)
    function stripLeadingZeros(v) {
        if (v === undefined || v === null || v === "") { return ""; }
        var s = String(v);
        return /^\d+$/.test(s) ? String(parseInt(s, 10)) : s;
    }

    // Tuần hiện tại (Thứ 2 -> Thứ 7) theo ngày export
    function getCurrentWeekInfo() {
        var oToday = new Date();
        var iDay = oToday.getDay() || 7; // Chủ nhật -> 7
        var oMonday = new Date(oToday);
        oMonday.setDate(oToday.getDate() - (iDay - 1));
        var oSaturday = new Date(oMonday);
        oSaturday.setDate(oMonday.getDate() + 5);

        var oJan1 = new Date(oMonday.getFullYear(), 0, 1);
        var iWeekNo = Math.ceil((((oMonday - oJan1) / 86400000) + oJan1.getDay() + 1) / 7);

        return {
            week: iWeekNo,
            from: pad2(oMonday.getDate()) + "." + pad2(oMonday.getMonth() + 1),
            to: pad2(oSaturday.getDate()) + "." + pad2(oSaturday.getMonth() + 1)
        };
    }


    //////////////////////////////////////////////////////////////////////////
    // Build file Excel theo mẫu "Tem KH đóng cont", rồi tải về máy
    function buildExcel(aData) {
        return new Promise(function (resolve, reject) {
            var workbook = new ExcelJS.Workbook();
            var ws = workbook.addWorksheet("Sheet1");

            var BORDER = {
                top: { style: "thin" }, left: { style: "thin" },
                bottom: { style: "thin" }, right: { style: "thin" }
            };
            var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };
            var HEADER_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF2F2F2" } };
            var FONT = "Times New Roman";

            var sFirst = colLetter(FIRST_COL);
            var sLast = colLetter(LAST_COL);
            var oWeek = getCurrentWeekInfo();
            var sCompanyName = (aData[0] && aData[0].CompanyCodeName) || "";
            var sPlantName = (aData[0] && aData[0].PlantName) || "";

            //1. Dòng 1-3, cột B-C: Phòng ban
            ws.mergeCells(sFirst + "1:" + colLetter(FIRST_COL + 1) + "3");
            var oDept = ws.getCell(sFirst + "1");
            oDept.value = DEPT_NAME;
            oDept.font = { bold: true, size: 12, name: FONT };
            oDept.alignment = CENTER;
            oDept.border = BORDER;

            //2. Dòng 1: Tên công ty
            ws.mergeCells(colLetter(FIRST_COL + 2) + "1:" + sLast + "1");
            var oCompany = ws.getCell(colLetter(FIRST_COL + 2) + "1");
            oCompany.value = sCompanyName;
            oCompany.font = { bold: true, size: 14, color: { argb: "FFFF0000" }, name: FONT };
            oCompany.alignment = { horizontal: "center", vertical: "middle" };

            //3. Dòng 2: Tên nhà máy
            ws.mergeCells(colLetter(FIRST_COL + 2) + "2:" + sLast + "2");
            var oPlant = ws.getCell(colLetter(FIRST_COL + 2) + "2");
            oPlant.value = sPlantName;
            oPlant.font = { bold: true, size: 14, color: { argb: "FFFF0000" }, name: FONT };
            oPlant.alignment = { horizontal: "center", vertical: "middle" };

            //4. Dòng 3: Tuần báo cáo
            ws.mergeCells(colLetter(FIRST_COL + 2) + "3:" + sLast + "3");
            var oWeekCell = ws.getCell(colLetter(FIRST_COL + 2) + "3");
            oWeekCell.value = "Tuần " + oWeek.week + " (từ ngày " + oWeek.from + "-" + oWeek.to + ")";
            oWeekCell.font = { bold: true, size: 13, name: FONT };
            oWeekCell.alignment = { horizontal: "center", vertical: "middle" };
            oWeekCell.border = { bottom: { style: "thin" } };

            //5. Dòng 4: Header
            var iHeaderRow = 4;
            var i, col, cell;
            for (i = 0; i < COLUMNS.length; i++) {
                col = FIRST_COL + i;
                cell = ws.getCell(iHeaderRow, col);
                cell.value = COLUMNS[i].label;
                cell.font = { bold: true, size: 10, name: FONT };
                cell.alignment = CENTER;
                cell.border = BORDER;
                cell.fill = HEADER_FILL;
            }
            ws.getRow(iHeaderRow).height = 30;

            //6. Dữ liệu
            var iRow = iHeaderRow + 1;
            var r, item, c, oColDef, vValue;

            // Gộp ô cột SỐ CONT và cột Cont khi các dòng liên tiếp có cùng giá trị
            var MERGE_FIELDS = ["SoCont", "Cont"];
            var oMergeInfo = {};
            MERGE_FIELDS.forEach(function (sField) {
                oMergeInfo[sField] = {
                    col: FIRST_COL + COLUMNS.findIndex(function (oCol) {
                        return oCol.field === sField;
                    }),
                    startRow: iRow,
                    prevValue: null
                };
            });

            for (r = 0; r < aData.length; r++) {
                item = aData[r];

                var oContinuation = {};
                MERGE_FIELDS.forEach(function (sField) {
                    var oInfo = oMergeInfo[sField];
                    var sValue = item[sField] || "";
                    var bIsContinuation = r > 0 && sValue && sValue === oInfo.prevValue;
                    oContinuation[sField] = bIsContinuation;

                    if (!bIsContinuation) {
                        if (iRow - oInfo.startRow > 1) {
                            ws.mergeCells(oInfo.startRow, oInfo.col, iRow - 1, oInfo.col);
                        }
                        oInfo.startRow = iRow;
                    }
                });

                for (i = 0; i < COLUMNS.length; i++) {
                    c = FIRST_COL + i;
                    oColDef = COLUMNS[i];
                    cell = ws.getCell(iRow, c);

                    if (!oColDef.field) {
                        // 4 cột đầu: chưa có nguồn dữ liệu -> tạm để trống
                        vValue = "";
                    } else if (oContinuation[oColDef.field]) {
                        // Dòng thuộc cùng 1 giá trị với dòng trên -> để trống, sẽ được gộp ô
                        vValue = "";
                    } else {
                        vValue = item[oColDef.field];
                        if (oColDef.numeric) {
                            vValue = stripLeadingZeros(vValue);
                        } else if (oColDef.quantity) {
                            vValue = toNumber(vValue);
                            cell.numFmt = "#,##0.###";
                        } else {
                            vValue = vValue || "";
                        }
                    }

                    cell.value = vValue;
                    cell.font = { size: 10, name: FONT };
                    cell.border = BORDER;
                    cell.alignment = {
                        horizontal: oColDef.quantity || oColDef.numeric ? "center" : "left",
                        vertical: "middle",
                        wrapText: !!oColDef.wrap
                    };
                }

                MERGE_FIELDS.forEach(function (sField) {
                    oMergeInfo[sField].prevValue = item[sField] || "";
                });
                iRow++;
            }

            MERGE_FIELDS.forEach(function (sField) {
                var oInfo = oMergeInfo[sField];
                if (iRow - oInfo.startRow > 1) {
                    ws.mergeCells(oInfo.startRow, oInfo.col, iRow - 1, oInfo.col);
                }
            });

            //7. Độ rộng cột
            var aColumns = [{ width: 3 }]; // A (ẩn)
            for (i = 0; i < COLUMNS.length; i++) {
                aColumns.push({ width: COLUMNS[i].width });
            }
            ws.columns = aColumns;
            ws.getColumn(1).hidden = true;

            //8. Xuất file và tải về
            workbook.xlsx.writeBuffer().then(function (buffer) {
                var blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                var url = URL.createObjectURL(blob);
                var link = document.createElement("a");
                link.href = url;
                link.download = "TemKHDongCont_Tuan" + oWeek.week + "_"
                    + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
                    + ".xlsx";
                link.click();
                URL.revokeObjectURL(url);
                resolve();
            }).catch(reject);
        });
    }

});
