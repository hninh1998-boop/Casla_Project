sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/ui/core/Fragment",
    "sap/ui/model/json/JSONModel"
], function (MessageToast, MessageBox, BusyDialog, Fragment, JSONModel) {
    "use strict";

    var BATCH_SIZE = 1000;
    var CONCURRENCY = 4;

    // Cột hiển thị trên Excel, theo đúng thứ tự trên mẫu "BẢNG KÊ HĐ HH, DV BÁN RA
    // 01-1/GTGT - TT28". Field lấy theo custom entity HHDVRP (zce_hhdv_rp).
    var COLUMNS = [
        { label: "Ký hiệu mẫu hóa đơn", field: "KyHieuMauHoaDon", width: 14 },
        { label: "Ký hiệu HĐ", field: "KyHieuHD", width: 12 },
        { label: "Số HĐ", field: "SoHD", width: 14 },
        { label: "Ngày", field: "Ngay", width: 12, date: true },
        { label: "Tên Đ.v - K.hàng", field: "TenDVKHang", width: 30, wrap: true },
        { label: "Mã số thuế", field: "MaSoThue", width: 16 },
        { label: "Tên hàng", field: "TenHang", width: 26, wrap: true },
        { label: "Doanh số", field: "DoanhSo", width: 16, numeric: true },
        { label: "Thuế suất", field: "ThueSuat", width: 10, numeric: true, numFmt: "0.00" },
        { label: "Thuế GTGT", field: "ThueGTGT", width: 16, numeric: true },
        { label: "Tổng cộng", field: "TongCong", width: 16, numeric: true },
        { label: "Chứng từ", field: "ChungTu", width: 12 },
        { label: "Số Tờ khai", field: "SoToKhai", width: 14 },
        { label: "TK", field: "TK", width: 10 },
        { label: "TK DU", field: "TKDU", width: 10 },
        { label: "Tỷ giá", field: "TyGia", width: 10, numeric: true, round: true, numFmt: "#,##0" },
        { label: "Ngoại tệ", field: "NgoaiTe", width: 14, numeric: true, decimals: true },
        { label: "User hạch toán", field: "UserHachToan", width: 16 },
        { label: "Ghi chú", field: "GhiChu", width: 24, wrap: true }
    ];

    var FIRST_COL = 1;                                   // A
    var LAST_COL = FIRST_COL + COLUMNS.length - 1;        // S

    var REPORT_TITLE = "BẢNG KÊ HĐ HH, DV BÁN RA 01-1/GTGT - TT28";

    return {

        /**
         * Standard controller hook - fire khi view khởi tạo
         */
        onInit: function () {
            console.log(">>> ListReportExt: onInit FIRED");
        },

        /**
         * Gán icon cho nút Export Excel (được khai báo qua manifest.json - actions)
         */
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },

        /**
         * Fiori Elements hook - fire khi SmartFilterBar init xong
         * Đăng ký listener để set default Kỳ báo cáo = tháng trước (N-1)
         */
        onInitSmartFilterBarExtension: function (oEvent) {
            console.log(">>> ListReportExt: onInitSmartFilterBarExtension FIRED");

            this._bInitKyBaoCao = false;
            this._oSmartFilterBar = oEvent.getSource();

            // Set default ngay first call
            this._handleFilterChange();

            // Attach listener cho các lần sau
            this._oSmartFilterBar.attachFilterChange(this._handleFilterChange, this);
            this._oSmartFilterBar.attachAfterVariantLoad(this._onAfterVariantLoad, this);
        },

        /**
         * Set default KyBaoCao = tháng N-1 (Last Month) ở first load
         * Chỉ set 1 lần khi field chưa có giá trị
         */
        _handleFilterChange: function () {
            if (this._bInitKyBaoCao === true) {
                return;
            }
            this._bInitKyBaoCao = true;

            var oJSONData = this._oSmartFilterBar.getFilterData(true);
            console.log(">>> ListReportExt: Current KyBaoCao =", JSON.stringify(oJSONData.KyBaoCao));

            // Chỉ set default nếu KyBaoCao chưa có giá trị
            if (this._isKyBaoCaoEmpty(oJSONData.KyBaoCao)) {
                oJSONData.KyBaoCao = this._buildLastMonthRange();
                this._oSmartFilterBar.setFilterData(oJSONData);
                console.log(">>> ListReportExt: Set default KyBaoCao = Last Month range");
            } else {
                console.log(">>> ListReportExt: KyBaoCao already has value, skip default");
            }
        },

        /**
         * Khi user load Standard variant của SAP mà variant đó rỗng
         * -> auto fill tháng N-1
         */
        _onAfterVariantLoad: function () {
            console.log(">>> ListReportExt: _onAfterVariantLoad FIRED");

            if (!this._oSmartFilterBar) {
                return;
            }

            var oJSONData = this._oSmartFilterBar.getFilterData(true);
            var oSmartVariantManagement = this._oSmartFilterBar.getSmartVariant();

            if (!oSmartVariantManagement) {
                return;
            }

            var oCurrentVariant = oSmartVariantManagement.getVariantByKey(
                oSmartVariantManagement.getPresentVariantId()
            );

            var bShouldFill = this._isKyBaoCaoEmpty(oJSONData.KyBaoCao)
                && oCurrentVariant
                && oCurrentVariant.getAuthor() === "SAP";

            if (bShouldFill) {
                oJSONData.KyBaoCao = this._buildLastMonthRange();
                this._oSmartFilterBar.setFilterData(oJSONData);
                console.log(">>> ListReportExt: Variant load - Set KyBaoCao = Last Month range");
            }
        },

        /**
         * KyBaoCao là DynamicDateRange (useDateRange=true) nên giá trị thực sự
         * nằm ở conditionTypeInfo.data, không phải ranges/items.
         * Coi là rỗng khi chưa có conditionTypeInfo hoặc operation mặc định "DATE"
         * mà chưa chọn ngày nào (value1 rỗng).
         */
        _isKyBaoCaoEmpty: function (oKyBaoCao) {
            if (!oKyBaoCao || !oKyBaoCao.conditionTypeInfo || !oKyBaoCao.conditionTypeInfo.data) {
                return true;
            }
            var oData = oKyBaoCao.conditionTypeInfo.data;
            return !oData.operation || (oData.operation === "DATE" && !oData.value1);
        },

        /**
         * Build filter data cho KyBaoCao = khoảng tháng N-1 (từ ngày đầu đến
         * ngày cuối tháng trước), set qua conditionTypeInfo với operation
         * "DATERANGE" (between) đúng cấu trúc mà DynamicDateRange control dùng.
         */
        _buildLastMonthRange: function () {
            var oToday = new Date();

            // Chỉ lấy đến cấp ngày (giờ/phút/giây mặc định 00:00:00 theo local time),
            // không quy đổi UTC - luôn ra đúng ngày đầu và ngày cuối tháng trước.
            var oFirstDayLastMonth = new Date(oToday.getFullYear(), oToday.getMonth() - 1, 1);

            var oLastDayLastMonth = new Date(oToday.getFullYear(), oToday.getMonth(), 0);

            return {
                conditionTypeInfo: {
                    name: "sap.ui.comp.config.condition.DateRangeType",
                    data: {
                        operation: "DATERANGE",
                        value1: oFirstDayLastMonth,
                        value2: oLastDayLastMonth,
                        key: "KyBaoCao",
                        calendarType: "Gregorian"
                    }
                },
                ranges: [],
                items: []
            };
        },

        /**
         * Export Excel - gọi từ nút "Xuất Excel" trên toolbar của List Report
         * (khai báo trong manifest.json - sap.ui.generic.app > actions)
         */
        exportExcel: function () {
            mainExport(this.getView());
        },

        /**
         * Cập nhật trạng thái hóa đơn - gọi từ nút "Cập nhật trạng thái hóa đơn"
         * trên toolbar của List Report (khai báo trong manifest.json - sap.ui.generic.app > Actions)
         */
        onUdtInvoiceStatusButtonPress: async function () {
            var oView = this.getView();

            if (!this._oUdtInvoiceStatusDialog) {
                this._oUdtInvoiceStatusDialog = await Fragment.load({
                    id: oView.getId(),
                    name: "zhhdvrpov2.ext.fragment.UdtInvoiceStatus",
                    controller: this
                });
                oView.addDependent(this._oUdtInvoiceStatusDialog);
            }
            this._openUdtInvoiceStatusDialog();
        },

        _openUdtInvoiceStatusDialog: function () {
            // Mặc định Start date/End date = đầu năm - cuối năm hiện tại.
            // DatePicker bind trực tiếp property "value" (valueFormat yyyy-MM-dd)
            // nên set chuỗi, không phải Date object.
            var iYear = new Date().getFullYear();
            var oModel = new JSONModel({
                StartDate: iYear + "-01-01",
                EndDate: iYear + "-12-31"
            });
            this._oUdtInvoiceStatusDialog.setModel(oModel, "udtInvoiceStatusModel");
            this._oUdtInvoiceStatusDialog.open();
        },

        onCapNhatButtonPress: function () {
            var oView = this.getView();
            var sViewId = oView.getId();

            // StartDate/EndDate trên backend là abap.dats (Edm.DateTime) nên phải
            // truyền JS Date object (getDateValue) chứ không phải chuỗi yyyy-MM-dd,
            // để ODataModel v2 tự format đúng thành datetime'...' literal.
            var oStartDate = Fragment.byId(sViewId, "idUdtStartDateDatePicker").getDateValue();
            var oEndDate = Fragment.byId(sViewId, "idUdtEndDateDatePicker").getDateValue();

            if (!oStartDate || !oEndDate) {
                MessageToast.show("Vui lòng nhập đủ Start date, End date.");
                return;
            }

            var oModel = oView.getModel();
            var that = this;

            this._oUdtInvoiceStatusDialog.setBusy(true);

            oModel.callFunction("/UdtInvoiceStatus", {
                method: "POST",
                urlParameters: {
                    StartDate: oStartDate,
                    EndDate: oEndDate
                },
                success: function () {
                    that._oUdtInvoiceStatusDialog.setBusy(false);
                    MessageToast.show("Cập nhật trạng thái thành công.");
                    that._oUdtInvoiceStatusDialog.close();
                    refreshSmartTable(oView);
                },
                error: function (oError) {
                    that._oUdtInvoiceStatusDialog.setBusy(false);
                    var sMsg = (oError && oError.responseText) || (oError && oError.message) || "";
                    MessageBox.error("Cập nhật trạng thái thất bại: " + sMsg);
                }
            });
        },

        onUdtDongButtonPress: function () {
            this._oUdtInvoiceStatusDialog.close();
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

        var sCompanyCode = getCompanyCodeFromFilters(oRaw.filters);
        var oPeriod = getDateRangeFromFilters(oRaw.filters);

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
                if (!sCompanyCode && aData.length) {
                    sCompanyCode = aData[0].CompanyCode;
                }
                return fetchCompanyInfo(oRaw.model, sCompanyCode).then(function (oCompany) {
                    oBusy.setText("Đang tạo file Excel (" + aData.length.toLocaleString("vi-VN") + " dòng)...");
                    return buildExcel(aData, oCompany, sCompanyCode, oPeriod);
                });
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
    // Rebind lại SmartTable trên view (dùng sau khi cập nhật trạng thái hóa đơn)
    function refreshSmartTable(oView) {
        var oAll = oView.findAggregatedObjects(true);

        for (var i = 0; i < oAll.length; i++) {
            if (oAll[i].getMetadata().getName() === "sap.ui.comp.smarttable.SmartTable") {
                oAll[i].rebindTable();
                return;
            }
        }
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
            oScript.src = sap.ui.require.toUrl("zhhdvrpov2/libs/exceljs.min.js");
            oScript.onload = resolve;
            oScript.onerror = function () {
                reject(new Error("Không load được ExcelJS"));
            };
            document.head.appendChild(oScript);
        });
    }


    //////////////////////////////////////////////////////////////////////////
    // Lấy tên công ty + địa chỉ theo ZI_COMPANYCODE_VH (CompanyCodeName, CityName)
    function fetchCompanyInfo(oModel, sCompanyCode) {
        return new Promise(function (resolve) {
            if (!sCompanyCode) { resolve(null); return; }

            var sKey = "/" + oModel.createKey("ZI_COMPANYCODE_VH", { CompanyCode: sCompanyCode });
            oModel.read(sKey, {
                success: function (oData) { resolve(oData); },
                error: function () { resolve(null); }
            });
        });
    }


    //////////////////////////////////////////////////////////////////////////
    // Helpers - đọc filter hiện tại của SmartFilterBar (CompanyCode, KyBaoCao)
    function collectFilterConditions(aFilters, sPath, aOut) {
        aOut = aOut || [];
        (aFilters || []).forEach(function (oFilter) {
            if (!oFilter) { return; }

            var aNested = oFilter.aFilters || (oFilter.getFilters && oFilter.getFilters());
            if (aNested && aNested.length) {
                collectFilterConditions(aNested, sPath, aOut);
                return;
            }

            var sFilterPath = oFilter.sPath || (oFilter.getPath && oFilter.getPath());
            if (sFilterPath !== sPath) { return; }

            aOut.push({
                operator: oFilter.sOperator || (oFilter.getOperator && oFilter.getOperator()),
                value1: oFilter.oValue1 !== undefined ? oFilter.oValue1 : (oFilter.getValue1 && oFilter.getValue1()),
                value2: oFilter.oValue2 !== undefined ? oFilter.oValue2 : (oFilter.getValue2 && oFilter.getValue2())
            });
        });
        return aOut;
    }

    function getCompanyCodeFromFilters(aFilters) {
        var aConds = collectFilterConditions(aFilters, "CompanyCode");
        for (var i = 0; i < aConds.length; i++) {
            if (aConds[i].operator === "EQ" && aConds[i].value1) {
                return aConds[i].value1;
            }
        }
        return null;
    }

    function getDateRangeFromFilters(aFilters) {
        var aConds = collectFilterConditions(aFilters, "KyBaoCao");
        var oFrom = null;
        var oTo = null;

        aConds.forEach(function (c) {
            if (c.operator === "BT") {
                oFrom = c.value1;
                oTo = c.value2;
            } else if (c.operator === "GE" || c.operator === "GT") {
                oFrom = c.value1;
            } else if (c.operator === "LE" || c.operator === "LT") {
                oTo = c.value1;
            }
        });

        return (oFrom && oTo) ? { from: oFrom, to: oTo } : null;
    }


    //////////////////////////////////////////////////////////////////////////
    // Helpers - format
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

    // Format Edm.DateTime (JS Date, giờ UTC 00:00) sang dd/mm/yyyy, dùng UTC để
    // tránh lùi 1 ngày do lệch múi giờ GMT+0700.
    function formatDateVN(oDate) {
        if (!oDate) { return ""; }
        return pad2(oDate.getUTCDate()) + "/" + pad2(oDate.getUTCMonth() + 1) + "/" + oDate.getUTCFullYear();
    }


    //////////////////////////////////////////////////////////////////////////
    // Build file Excel theo mẫu "BẢNG KÊ HĐ HH, DV BÁN RA 01-1/GTGT - TT28",
    // rồi tải về máy. Header ở dòng 7, dữ liệu bắt đầu từ dòng 8.
    function buildExcel(aData, oCompany, sCompanyCode, oPeriod) {
        return new Promise(function (resolve, reject) {
            var workbook = new ExcelJS.Workbook();
            var ws = workbook.addWorksheet("BangKe HHDV");

            var BORDER = {
                top: { style: "thin" }, left: { style: "thin" },
                bottom: { style: "thin" }, right: { style: "thin" }
            };
            var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };
            var HEADER_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF2F2F2" } };
            var FONT = "Times New Roman";

            var sFirst = colLetter(FIRST_COL);
            var sLast = colLetter(LAST_COL);

            //1. Dòng 1: Tên công ty
            ws.mergeCells(sFirst + "1:" + sLast + "1");
            var oCompanyCell = ws.getCell(sFirst + "1");
            oCompanyCell.value = (oCompany && oCompany.CompanyCodeName) || sCompanyCode || "";
            oCompanyCell.font = { bold: true, size: 13, name: FONT };
            oCompanyCell.alignment = { horizontal: "left", vertical: "middle" };

            //2. Dòng 2: Địa chỉ công ty
            ws.mergeCells(sFirst + "2:" + sLast + "2");
            var oAddrCell = ws.getCell(sFirst + "2");
            oAddrCell.value = (oCompany && oCompany.CityName) || "";
            oAddrCell.font = { size: 10, name: FONT };
            oAddrCell.alignment = { horizontal: "left", vertical: "middle" };

            //3. Dòng 4: Tiêu đề báo cáo
            ws.mergeCells(sFirst + "4:" + sLast + "4");
            var oTitleCell = ws.getCell(sFirst + "4");
            oTitleCell.value = REPORT_TITLE;
            oTitleCell.font = { bold: true, size: 14, color: { argb: "FFFF0000" }, name: FONT };
            oTitleCell.alignment = { horizontal: "center", vertical: "middle" };

            //4. Dòng 5: Kỳ báo cáo
            ws.mergeCells(sFirst + "5:" + sLast + "5");
            var oPeriodCell = ws.getCell(sFirst + "5");
            oPeriodCell.value = oPeriod
                ? "Từ ngày " + formatDateVN(oPeriod.from) + " Đến ngày " + formatDateVN(oPeriod.to)
                : "";
            oPeriodCell.font = { size: 11, name: FONT };
            oPeriodCell.alignment = { horizontal: "center", vertical: "middle" };

            //5. Dòng 7: Header
            var iHeaderRow = 7;
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

            //6. Dữ liệu - bắt đầu từ dòng 8
            var iRow = iHeaderRow + 1;
            var r, item, c, oColDef, vValue;

            for (r = 0; r < aData.length; r++) {
                item = aData[r];

                for (i = 0; i < COLUMNS.length; i++) {
                    c = FIRST_COL + i;
                    oColDef = COLUMNS[i];
                    cell = ws.getCell(iRow, c);
                    vValue = item[oColDef.field];

                    if (oColDef.date) {
                        vValue = formatDateVN(vValue);
                    } else if (oColDef.numeric) {
                        vValue = toNumber(vValue);
                        if (oColDef.round) {
                            vValue = Math.round(vValue);
                        }
                        cell.numFmt = oColDef.numFmt || (oColDef.decimals ? "#,##0.00" : "#,##0");
                    } else {
                        vValue = vValue || "";
                    }

                    cell.value = vValue;
                    cell.font = { size: 10, name: FONT };
                    cell.border = BORDER;
                    cell.alignment = {
                        horizontal: oColDef.numeric ? "right" : "left",
                        vertical: "middle",
                        wrapText: !!oColDef.wrap
                    };
                }

                iRow++;
            }

            //7. Độ rộng cột
            var aColumns = [];
            for (i = 0; i < COLUMNS.length; i++) {
                aColumns.push({ width: COLUMNS[i].width });
            }
            ws.columns = aColumns;

            //8. Xuất file và tải về
            workbook.xlsx.writeBuffer().then(function (buffer) {
                var blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                var url = URL.createObjectURL(blob);
                var link = document.createElement("a");
                link.href = url;

                var sPeriodPart = oPeriod
                    ? formatDateVN(oPeriod.from).replace(/\//g, "") + "-" + formatDateVN(oPeriod.to).replace(/\//g, "")
                    : new Date().toLocaleDateString("vi-VN").replace(/\//g, "-");

                link.download = "BangKe_HHDV_01-1_GTGT_" + (sCompanyCode || "") + "_" + sPeriodPart + ".xlsx";
                link.click();
                URL.revokeObjectURL(url);
                resolve();
            }).catch(reject);
        });
    }

});
