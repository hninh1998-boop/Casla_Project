sap.ui.define([
    "sap/m/BusyDialog",
    "sap/m/MessageBox",
    "sap/m/MessageToast",
    "exceljs"
], function(BusyDialog, MessageBox, MessageToast, ExcelJS) {
    "use strict";

    var PAGE_SIZE = 5000;

    var COLUMN_WIDTHS = [
        12.33203125, 6.109375, 77.5546875, 8.6640625, 6.109375,
        14.88671875, 13.88671875, 14.88671875, 14.88671875, 12.6640625,
        14.88671875, 13.88671875, 9.44140625, 11.6640625, 13.88671875,
        14.88671875, 14.88671875, 14.88671875
    ];
    var FR_COLS = ["F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R"];
    var GREY_BORDER_SIDE = { style: "thin", color: { indexed: 23 } };
    var THIN_GREY_BORDER = {
        top: GREY_BORDER_SIDE,
        left: GREY_BORDER_SIDE,
        bottom: GREY_BORDER_SIDE,
        right: GREY_BORDER_SIDE
    };
    var DATE_NUM_FMT = "mm-dd-yy";
    var PERCENT_NUM_FMT = "### ### ### ##0.00 ;[Red](### ### ##0.00) ; ";
    var MONEY_NUM_FMT = "### ### ### ### ;[Red](### ### ### ###)";

    // Sample dataset reproduced from Template.xlsx, sheet "1" (demo content until real OData is wired up).
    var DEMO = {
        company: "Công ty Cổ phần CASLA",
        address: "Địa chỉ : Khu CN Châu Sơn, P. Châu Sơn, TP. Phủ Lý, Tỉnh Hà Nam, Việt Nam",
        title: "Báo cáo chi tiết tài sản cố định",
        period: "Từ ngày 01/01/2024 Đến ngày 31/05/2025",
        accountLine: "Tài khoản 21 - ",
        totalLabel: "Cộng",
        dateLine: " Ngày   Tháng    Năm  2025                          ",
        signatureLine: "Người lập biểu                                                                  Kế toán trưởng                                                                  Giám đốc",
        footerLine: "                    ",
        headerTop: ["Mã", "Số thẻ", "Tên TSCĐ", "Ngày SD", "TL KH", "Số đầu kỳ", "Tăng trong kỳ", "Giảm trong kỳ", "KH Tkỳ", "Số dư cuối kỳ"],
        headerSub: ["ĐK.N.Giá", "ĐK.HMLK", "ĐK.GTCL", "Tăng.NGgiá", "Tăng.HMLK", "Tăng.GTCL", "Giảm.Ngiá", "Giảm.HMLK", "Giảm.GTCL", "CK.N.Giá", "CK.KHLK", "CK.GTCL"],
        rows: [
            {
                row: 11, type: "level", code: "A", card: "", name: "   Tài sản hữu hình",
                vals: [182752724744, 47319931810, 135432792934, 152372093442, 21951284, 152350142158, 1538347832, 0, 0, 23968181904, 333586470354, 94832943710, 238753526644]
            },
            {
                row: 12, type: "level", code: "ANC", card: "", name: "         Nhà cửa vật kiến trúc",
                vals: ["xxx", "xxx", "xxx", "xxx", "xxx", "xxx", "xxx", 0, 0, "xxx", "xxx", "xxx", "xxx"]
            },
            {
                row: 13, type: "formula", code: "ANCCL1", card: "", name: "                  Nhà cửa vật kiến trúc- NM Casla 1",
                sumFrom: 14, sumTo: 16, formulaCols: [0, 1, 2, 3, 4, 5, 9, 10, 11, 12],
                vals: [29681968396, 11146696167, 18535272229, 0, 0, 0, 0, 0, 0, 3710246040, 29681968396, 18567188247, 11114780149]
            },
            {
                row: 14, type: "detail", code: "ANCCL10001", card: "1.1.001", date: "2020-03-30",
                name: "                              Nhà xưởng sản xuất số 1 (6600 M2) (in lưới, dán túi, tráng, cắt dập, chia cuộn, chia viền)",
                vals: [11103440790, 4169759877, 6933680913, 0, 0, 0, 0, 0, 0, 1387930095, 11103440790, 6945620067, 4157820723]
            },
            {
                row: 15, type: "detail", code: "ANCCL10002", card: "1.1.002", date: "2020-03-30",
                name: "                              Nhà xưởng sản xuất số 2 (7216M2) (dệt quai, cắt quai, kho BTP)",
                vals: [13618904063, 5114411006, 8504493057, 0, 0, 0, 0, 0, 0, 1702363005, 13618904063, 8519137016, 5099767047]
            },
            {
                row: 16, type: "detail", code: "ANCCL10003", card: "1.1.003", date: "2020-03-30",
                name: "                              Nhà xưởng sản xuất số 3 (1617M2) (sợi quai)",
                vals: [4959623543, 1862525284, 3097098259, 0, 0, 0, 0, 0, 0, 619952940, 4959623543, 3102431164, 1857192379]
            },
            {
                row: 17, type: "formula", code: "ANCCL2", card: "", name: "                  Nhà cửa vật kiến trúc- NM Casla 2",
                sumFrom: 18, sumTo: 20, formulaCols: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                vals: [44875668853, 6520929869, 38354738984, 0, 0, 0, 0, 0, 0, 5609458605, 44875668853, 17739847079, 27135821774]
            },
            {
                row: 18, type: "detail", code: "ANCCL20001", card: "1.4.001", date: "2022-06-01",
                name: "                              Nhà xưởng số 01",
                vals: [11518313999, 1665885122, 9852428877, 0, 0, 0, 0, 0, 0, 1439789250, 11518313999, 4545463622, 6972850377]
            },
            {
                row: 19, type: "detail", code: "ANCCL20002", card: "1.4.002", date: "2022-06-01",
                name: "                              Nhà xưởng số 02",
                vals: [16832287553, 2439401485, 14392886068, 0, 0, 0, 0, 0, 0, 2104035945, 16832287553, 6647473375, 10184814178]
            },
            {
                row: 20, type: "detail", code: "ANCCL20003", card: "1.4.003", date: "2022-06-01",
                name: "                              Nhà xưởng số 03",
                vals: [16525067301, 2415643262, 14109424039, 0, 0, 0, 0, 0, 0, 2065633410, 16525067301, 6546910082, 9978157219]
            },
            {
                row: 21, type: "formula", code: "BMMCL", card: "", name: "               Máy móc thiết bị chính- NM Casla 1",
                sumFrom: 22, sumTo: 27, formulaCols: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                vals: [6304989637, 3276927782, 3028061855, 319000000, 41452235, 277547765, 34545455, 0, 0, 1026398885, 6589444182, 5303037812, 1286406370]
            },
            {
                row: 22, type: "detail", code: "BMMCL00001", card: "2.1.001", date: "2020-03-30",
                name: "                              Máy dệt kim BK 6/50 số 31",
                vals: [85106909, 45658331, 39448578, 0, 0, 0, 0, 0, 0, 15197655, 85106909, 76053641, 9053268]
            },
            {
                row: 23, type: "detail", code: "BMMCL00002", card: "2.1.002", date: "2020-03-30",
                name: "                              Dây chuyền máy kéo sợi Polypropylene số 1 (TK102914708152)",
                vals: [6185337273, 3207871751, 2977465522, 0, 0, 0, 0, 0, 0, 966458955, 6185337273, 5140789661, 1044547612]
            },
            {
                row: 24, type: "detail", code: "BMMCL00113", card: "2.1.113", date: "2020-04-29",
                name: "                              Máy may lập trình khổ nhỏ Jack JK-T1906 GH",
                vals: [34545455, 23397700, 11147755, 0, 0, 0, 34545455, 0, 0, 3290040, 0, 3290040, -3290040]
            },
            {
                row: 25, type: "detail", code: "BMMCL00261", card: "2.1.261", date: "2024-06-03",
                name: "                              Máy dập cúc, HĐ 00000010",
                vals: [0, 0, 0, 134000000, 18487036, 115512964, 0, 0, 0, 18487036, 134000000, 36974072, 97025928]
            },
            {
                row: 26, type: "detail", code: "BMMCL00262", card: "2.1.262", date: "2024-06-11",
                name: "                              Máy chặt thủy lực; HĐ 48",
                vals: [0, 0, 0, 125000000, 16782406, 108217594, 0, 0, 0, 16782406, 125000000, 33564812, 91435188]
            },
            {
                row: 27, type: "detail", code: "BMMCL00263", card: "2.1.263", date: "2024-08-19", height: 12,
                name: "                              Máy thu hồi biên phế tái sử dụng; HĐ 155",
                vals: [0, 0, 0, 60000000, 6182793, 53817207, 0, 0, 0, 6182793, 60000000, 12365586, 47634414]
            }
        ]
    };

    function applyBoldRowStyle(oCell) {
        oCell.font = { name: "Times New Roman", size: 10, bold: true };
        oCell.border = THIN_GREY_BORDER;
    }

    function applyDetailRowStyle(oCell) {
        oCell.font = { name: "Times New Roman", size: 9 };
        oCell.border = THIN_GREY_BORDER;
    }

    function writeContentRow(oWorksheet, oRowDef) {
        var oRow = oWorksheet.getRow(oRowDef.row);
        var bBold = oRowDef.type !== "detail";
        var fnStyle = bBold ? applyBoldRowStyle : applyDetailRowStyle;
        var oCellA = oRow.getCell(1);
        var oCellB = oRow.getCell(2);
        var oCellC = oRow.getCell(3);
        var oCellD = oRow.getCell(4);
        var oCellE = oRow.getCell(5);

        fnStyle(oCellA);
        fnStyle(oCellB);
        fnStyle(oCellC);
        oCellA.value = oRowDef.code;
        oCellB.value = oRowDef.card || "";
        oCellC.value = oRowDef.name;

        fnStyle(oCellD);
        oCellD.numFmt = DATE_NUM_FMT;
        oCellD.value = oRowDef.type === "detail" ? new Date(oRowDef.date) : "  -   -";

        fnStyle(oCellE);
        oCellE.numFmt = PERCENT_NUM_FMT;
        oCellE.value = 0;

        FR_COLS.forEach(function(sLetter, iIndex) {
            var oCell = oRow.getCell(iIndex + 6);

            fnStyle(oCell);
            oCell.numFmt = MONEY_NUM_FMT;

            if (oRowDef.type === "formula" && oRowDef.formulaCols.indexOf(iIndex) !== -1) {
                oCell.value = {
                    formula: "+SUM(" + sLetter + oRowDef.sumFrom + ":" + sLetter + oRowDef.sumTo + ")",
                    result: oRowDef.vals[iIndex]
                };
            } else {
                oCell.value = oRowDef.vals[iIndex];
            }
        });

        if (oRowDef.height) {
            oRow.height = oRowDef.height;
        }
    }

    function writeBlankGridRow(oWorksheet, iRowNumber) {
        var oRow = oWorksheet.getRow(iRowNumber);

        for (var iCol = 1; iCol <= 18; iCol += 1) {
            var oCell = oRow.getCell(iCol);

            applyDetailRowStyle(oCell);
            if (iCol === 4) {
                oCell.numFmt = DATE_NUM_FMT;
            } else if (iCol === 5) {
                oCell.numFmt = PERCENT_NUM_FMT;
            } else if (iCol >= 6) {
                oCell.numFmt = MONEY_NUM_FMT;
            }
        }
    }

    function writeMergedText(oWorksheet, iRowNumber, sText, oOptions) {
        var oCell = oWorksheet.getRow(iRowNumber).getCell(1);

        oWorksheet.mergeCells(iRowNumber, 1, iRowNumber, 18);
        oCell.value = sText;
        oCell.font = {
            name: "Times New Roman",
            size: oOptions.size || 9,
            bold: !!oOptions.bold,
            color: oOptions.color ? { argb: "FF" + oOptions.color } : undefined
        };
        oCell.alignment = {
            horizontal: oOptions.horizontal || "center",
            vertical: oOptions.vertical || undefined,
            wrapText: !!oOptions.wrapText
        };

        if (oOptions.bottomBorder) {
            oCell.border = { bottom: { style: "thin", color: { indexed: 64 } } };
        }

        if (oOptions.height) {
            oWorksheet.getRow(iRowNumber).height = oOptions.height;
        }
    }

    function writeTableHeader(oWorksheet) {
        var oHeaderAlignment = { horizontal: "center", vertical: "middle", wrapText: true };

        function styleHeaderCell(oCell, bBold) {
            oCell.font = { name: "Times New Roman", size: 9, bold: !!bBold };
            oCell.alignment = oHeaderAlignment;
            oCell.border = THIN_GREY_BORDER;
        }

        var oRow8 = oWorksheet.getRow(8);
        var oRow9 = oWorksheet.getRow(9);

        ["A8:A9", "B8:B9", "C8:C9", "D8:D9", "E8:E9", "F8:H8", "I8:K8", "L8:N8", "O8:O9", "P8:R8"].forEach(function(sRange) {
            oWorksheet.mergeCells(sRange);
        });

        styleHeaderCell(oRow8.getCell(1), false);
        oRow8.getCell(1).value = DEMO.headerTop[0];

        styleHeaderCell(oRow8.getCell(2), false);
        oRow8.getCell(2).value = DEMO.headerTop[1];
        oRow8.getCell(2).fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFFF00" } };

        styleHeaderCell(oRow8.getCell(3), false);
        oRow8.getCell(3).value = DEMO.headerTop[2];

        styleHeaderCell(oRow8.getCell(4), false);
        oRow8.getCell(4).value = DEMO.headerTop[3];
        oRow8.getCell(4).numFmt = DATE_NUM_FMT;

        styleHeaderCell(oRow8.getCell(5), false);
        oRow8.getCell(5).value = DEMO.headerTop[4];
        oRow8.getCell(5).numFmt = PERCENT_NUM_FMT;

        [6, 9, 12].forEach(function(iCol, iIndex) {
            styleHeaderCell(oRow8.getCell(iCol), true);
            oRow8.getCell(iCol).value = DEMO.headerTop[5 + iIndex];
        });

        styleHeaderCell(oRow8.getCell(15), false);
        oRow8.getCell(15).value = DEMO.headerTop[8];
        oRow8.getCell(15).numFmt = MONEY_NUM_FMT;

        styleHeaderCell(oRow8.getCell(16), true);
        oRow8.getCell(16).value = DEMO.headerTop[9];

        [6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18].forEach(function(iCol, iIndex) {
            styleHeaderCell(oRow9.getCell(iCol), true);
            oRow9.getCell(iCol).value = DEMO.headerSub[iIndex];
            oRow9.getCell(iCol).numFmt = MONEY_NUM_FMT;
        });

        oRow9.height = 22.8;
    }

    function saveAsFile(vBuffer, sFileName) {
        var oBlob = new Blob([vBuffer], {
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        });
        var sUrl = URL.createObjectURL(oBlob);
        var oLink = document.createElement("a");

        oLink.href = sUrl;
        oLink.download = sFileName;
        document.body.appendChild(oLink);
        oLink.click();
        document.body.removeChild(oLink);
        URL.revokeObjectURL(sUrl);
    }

    return {
        ExportExcel: function() {
            var oBusyDialog = new BusyDialog({
                text: "Dang xuat Excel..."
            });

            oBusyDialog.open();

            Promise.resolve().then(function() {
                return this._buildDemoWorkbook();
            }.bind(this)).then(function(vBuffer) {
                saveAsFile(vBuffer, "Bao_cao_tang_giam_tai_san.xlsx");
                MessageToast.show("Da xuat Excel.");
            }).catch(function(oError) {
                MessageBox.error((oError && oError.message) || "Khong the xuat Excel.");
            }).finally(function() {
                oBusyDialog.close();
            });
        },

        _buildDemoWorkbook: function() {
            var oWorkbook = new ExcelJS.Workbook();
            var oWorksheet = oWorkbook.addWorksheet("1", {
                views: [
                    {
                        showGridLines: false,
                        state: "frozen",
                        ySplit: 9
                    }
                ],
                pageSetup: {
                    paperSize: 9,
                    orientation: "landscape",
                    fitToPage: false,
                    printTitlesRow: "8:9",
                    margins: {
                        left: 0.010416666666666666,
                        right: 0.006944444444444444,
                        top: 0.010416666666666666,
                        bottom: 0.006944444444444444,
                        header: 0,
                        footer: 0
                    }
                },
                properties: {
                    defaultRowHeight: 13.2
                }
            });

            oWorksheet.columns = COLUMN_WIDTHS.map(function(fWidth) {
                return { width: fWidth };
            });

            writeMergedText(oWorksheet, 1, DEMO.company, { size: 9 });
            writeMergedText(oWorksheet, 2, DEMO.address, { size: 9, bottomBorder: true });
            writeMergedText(oWorksheet, 4, DEMO.title, { size: 12, bold: true, color: "FF0000", height: 15.6 });
            writeMergedText(oWorksheet, 5, DEMO.period, { size: 9 });
            writeMergedText(oWorksheet, 6, DEMO.accountLine, { size: 9, bold: true });

            writeTableHeader(oWorksheet);
            writeBlankGridRow(oWorksheet, 10);

            DEMO.rows.forEach(function(oRowDef) {
                writeContentRow(oWorksheet, oRowDef);
            });

            writeBlankGridRow(oWorksheet, 28);

            var oTotalCell = oWorksheet.getRow(29).getCell(1);
            oTotalCell.value = DEMO.totalLabel;
            oTotalCell.font = { name: "Times New Roman", size: 9, bold: true, color: { argb: "FFFF0000" } };
            oTotalCell.alignment = { horizontal: "center" };
            for (var iCol = 1; iCol <= 18; iCol += 1) {
                oWorksheet.getRow(29).getCell(iCol).border = THIN_GREY_BORDER;
            }

            writeMergedText(oWorksheet, 31, DEMO.dateLine, { size: 9, horizontal: "right", vertical: "middle" });
            writeMergedText(oWorksheet, 32, DEMO.signatureLine, { size: 9, bold: true, horizontal: "center", vertical: "middle", wrapText: true });
            writeMergedText(oWorksheet, 37, DEMO.footerLine, { size: 9, bold: true, horizontal: "center", vertical: "middle", wrapText: true });

            return oWorkbook.xlsx.writeBuffer();
        },

        _readAllRecords: function() {
            var oModel = this.getView().getModel();
            var oBinding = this._getTableBinding();
            var sPath = this._getReadPath(oBinding);
            var aFilters = this._getCurrentFilters(oBinding);
            var aSorters = this._getCurrentSorters(oBinding);
            var aRecords = [];

            if (!sPath) {
                return Promise.reject(new Error("Khong xac dinh duoc binding path de doc du lieu."));
            }

            return this._readPage(oModel, sPath, aFilters, aSorters, 0, aRecords);
        },

        _readPage: function(oModel, sPath, aFilters, aSorters, iSkip, aRecords) {
            return new Promise(function(resolve, reject) {
                oModel.read(sPath, {
                    filters: aFilters,
                    sorters: aSorters,
                    urlParameters: {
                        "$skip": iSkip,
                        "$top": PAGE_SIZE
                    },
                    success: function(oData) {
                        var aPageRecords = (oData && oData.results) || [];

                        aRecords.push.apply(aRecords, aPageRecords);

                        if (aPageRecords.length === PAGE_SIZE) {
                            resolve(this._readPage(oModel, sPath, aFilters, aSorters, iSkip + PAGE_SIZE, aRecords));
                        } else {
                            resolve(aRecords);
                        }
                    }.bind(this),
                    error: reject
                });
            }.bind(this));
        },

        _getReadPath: function(oBinding) {
            if (oBinding && oBinding.getPath) {
                return oBinding.getPath();
            }

            var oSmartTable = this._getSmartTable();
            var sEntitySet = oSmartTable && oSmartTable.getEntitySet && oSmartTable.getEntitySet();

            return sEntitySet ? "/" + sEntitySet : "";
        },

        _getSmartFilterBar: function() {
            if (this.extensionAPI && this.extensionAPI.getSmartFilterBar) {
                return this.extensionAPI.getSmartFilterBar();
            }

            return this.byId && this.byId("listReportFilter");
        },

        _getSmartTable: function() {
            if (this.extensionAPI && this.extensionAPI.getSmartTable) {
                return this.extensionAPI.getSmartTable();
            }

            return this.byId && this.byId("listReport");
        },

        _getCurrentFilters: function(oBinding) {
            var oSmartFilterBar = this._getSmartFilterBar();

            if (oSmartFilterBar && oSmartFilterBar.getFilters) {
                return oSmartFilterBar.getFilters();
            }

            return oBinding && oBinding.aFilters ? oBinding.aFilters : [];
        },

        _getCurrentSorters: function(oBinding) {
            return oBinding && oBinding.aSorters ? oBinding.aSorters : [];
        },

        _getTableBinding: function() {
            var oSmartTable = this._getSmartTable();
            var oTable = oSmartTable && oSmartTable.getTable && oSmartTable.getTable();

            if (!oTable || !oTable.getBinding) {
                return null;
            }

            return oTable.getBinding("items") || oTable.getBinding("rows");
        },

        _getFilterData: function() {
            var oSmartFilterBar = this._getSmartFilterBar();
            return oSmartFilterBar && oSmartFilterBar.getFilterData ? oSmartFilterBar.getFilterData() : {};
        }
    };
});
