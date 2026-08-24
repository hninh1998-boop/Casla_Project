sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/m/MenuButton",
    "sap/m/Menu",
    "sap/m/MenuItem",
    "sap/ui/core/Fragment",
    "sap/ui/model/json/JSONModel"
], function (MessageToast, MessageBox, BusyDialog, MenuButton, Menu, MenuItem, Fragment, JSONModel) {
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
        { label: "Doanh số", field: "DoanhSoSauLamTron", width: 16, numeric: true },
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

    // "Bảng kê tổng hợp" - group các line item có cùng giá trị ở toàn bộ các field
    // dưới đây thành 1 dòng. Field không nằm trong danh sách này (Tên hàng, Doanh
    // số, Thuế GTGT, Tổng cộng) sẽ được gộp: Tên hàng nối chuỗi "; ", còn lại cộng dồn.
    var SUMMARY_GROUP_FIELDS = [
        "KyHieuMauHoaDon", "KyHieuHD", "SoHD", "Ngay", "TenDVKHang", "MaSoThue",
        "ThueSuat", "ChungTu", "SoToKhai", "TK", "TKDU", "TyGia",
        "UserHachToan", "GhiChu"
    ];
    var SUMMARY_SUM_FIELDS = ["DoanhSoSauLamTron", "ThueGTGT", "TongCong", "NgoaiTe"];

    return {

        /**
         * Standard controller hook - fire khi view khởi tạo
         */
        onInit: function () {
            console.log(">>> ListReportExt: onInit FIRED");
        },

        /**
         * Thay nút "Xuất Excel" (khai báo qua manifest.json - actions, mặc định là
         * sap.m.Button đơn) bằng sap.m.MenuButton có 2 lựa chọn: "Bảng kê chi tiết"
         * / "Bảng kê tổng hợp". Chỉ thay 1 lần, các lần onAfterRendering sau (re-render
         * toolbar) sẽ bỏ qua vì control đã là MenuButton.
         */
        onAfterRendering: function () {
            this._setupExportExcelMenuButton();
        },

        _setupExportExcelMenuButton: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (!oButton || oButton.getMetadata().getName() === "sap.m.MenuButton") {
                return;
            }

            var oParent = oButton.getParent();
            var sAggregation = oButton.sParentAggregationName;
            var iIndex = oParent.indexOfAggregation(sAggregation, oButton);
            var sButtonId = oButton.getId();
            var that = this;

            oButton.destroy();

            var oMenuButton = new MenuButton(sButtonId, {
                text: "{i18n>exportExcelButtonText}",
                icon: "sap-icon://excel-attachment",
                menu: new Menu({
                    items: [
                        new MenuItem({
                            text: "{i18n>exportExcelDetailMenuText}",
                            press: function () { that.exportExcel(); }
                        }),
                        new MenuItem({
                            text: "{i18n>exportExcelSummaryMenuText}",
                            press: function () { that.exportExcelSummary(); }
                        })
                    ]
                })
            });

            oParent.insertAggregation(sAggregation, oMenuButton, iIndex);
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
         * Export Excel - "Bảng kê chi tiết", gọi từ menu item của MenuButton
         * "Xuất Excel" trên toolbar của List Report.
         */
        exportExcel: function () {
            mainExport(this.getView(), false);
        },

        /**
         * Export Excel - "Bảng kê tổng hợp", gọi từ menu item của MenuButton
         * "Xuất Excel" trên toolbar của List Report. Group các line item theo
         * cùng 1 hóa đơn (xem SUMMARY_GROUP_FIELDS) trước khi build file.
         */
        exportExcelSummary: function () {
            mainExport(this.getView(), true);
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
    // bSummary = true -> "Bảng kê tổng hợp" (group line item theo SUMMARY_GROUP_FIELDS)
    // bSummary = false -> "Bảng kê chi tiết" (giữ nguyên từng line item)
    function mainExport(oView, bSummary) {
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
                if (bSummary) {
                    aData = groupDataForSummary(aData);
                }
                return fetchCompanyInfo(oRaw.model, sCompanyCode).then(function (oCompany) {
                    oBusy.setText("Đang tạo file Excel (" + aData.length.toLocaleString("vi-VN") + " dòng)...");
                    return buildExcel(aData, oCompany, sCompanyCode, oPeriod, bSummary);
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
    // "Bảng kê tổng hợp" - group các line item cùng hóa đơn (giống nhau ở toàn bộ
    // SUMMARY_GROUP_FIELDS) thành 1 dòng: Tên hàng nối chuỗi "; ", các field tiền
    // trong SUMMARY_SUM_FIELDS cộng dồn.
    function groupDataForSummary(aData) {
        var aGroups = [];
        var oIndexByKey = {};

        aData.forEach(function (item) {
            var sKey = buildSummaryGroupKey(item);
            var iIdx = oIndexByKey[sKey];

            if (iIdx === undefined) {
                oIndexByKey[sKey] = aGroups.length;

                var oGroup = {};
                SUMMARY_GROUP_FIELDS.forEach(function (f) { oGroup[f] = item[f]; });
                SUMMARY_SUM_FIELDS.forEach(function (f) { oGroup[f] = toNumber(item[f]); });
                oGroup._aTenHang = [item.TenHang || ""];

                aGroups.push(oGroup);
            } else {
                var oExisting = aGroups[iIdx];
                SUMMARY_SUM_FIELDS.forEach(function (f) { oExisting[f] += toNumber(item[f]); });
                oExisting._aTenHang.push(item.TenHang || "");
            }
        });

        aGroups.forEach(function (oGroup) {
            oGroup.TenHang = oGroup._aTenHang.join("; ");
            delete oGroup._aTenHang;
        });

        return aGroups;
    }

    function buildSummaryGroupKey(item) {
        return SUMMARY_GROUP_FIELDS.map(function (f) {
            return normalizeGroupKeyValue(item[f]);
        }).join("||");
    }

    function normalizeGroupKeyValue(v) {
        if (v === null || v === undefined) { return ""; }
        if (v instanceof Date) { return v.getTime(); }
        return String(v);
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
    function buildExcel(aData, oCompany, sCompanyCode, oPeriod, bSummary) {
        return new Promise(function (resolve, reject) {
            var workbook = new ExcelJS.Workbook();
            var ws = workbook.addWorksheet(bSummary ? "BangKe HHDV Tong hop" : "BangKe HHDV Chi tiet");

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

            //7. Dòng "Cộng" - tổng tiền theo cột Doanh số / Thuế GTGT / Tổng cộng,
            // dùng công thức SUM tham chiếu vùng dữ liệu (không hard-code số) để
            // luôn khớp khi số dòng dữ liệu thay đổi.
            var iFirstDataRow = iHeaderRow + 1;
            var iLastDataRow = iRow - 1;
            var iTotalRow = iRow;
            var bHasData = iLastDataRow >= iFirstDataRow;

            var sDoanhSoCol = colLetter(FIRST_COL + 7);   // H
            var sThueGTGTCol = colLetter(FIRST_COL + 9);  // J
            var sTongCongCol = colLetter(FIRST_COL + 10); // K

            ws.mergeCells(colLetter(FIRST_COL + 2) + iTotalRow + ":" + colLetter(FIRST_COL + 6) + iTotalRow); // C:G
            var oTotalLabelCell = ws.getCell(colLetter(FIRST_COL + 2) + iTotalRow);
            oTotalLabelCell.value = "Cộng";
            oTotalLabelCell.font = { bold: true, size: 11, name: FONT };
            oTotalLabelCell.alignment = { horizontal: "center", vertical: "middle" };

            [sDoanhSoCol, sThueGTGTCol, sTongCongCol].forEach(function (sCol) {
                var oTotalCell = ws.getCell(sCol + iTotalRow);
                oTotalCell.value = bHasData
                    ? { formula: "SUM(" + sCol + iFirstDataRow + ":" + sCol + iLastDataRow + ")" }
                    : 0;
                oTotalCell.numFmt = "#,##0";
                oTotalCell.font = { bold: true, size: 10, name: FONT };
                oTotalCell.alignment = { horizontal: "right", vertical: "middle" };
            });

            for (i = 0; i < COLUMNS.length; i++) {
                ws.getCell(iTotalRow, FIRST_COL + i).border = BORDER;
            }
            ws.getRow(iTotalRow).height = 22;

            //8. Khối ký tên - cách dòng "Cộng" 2 dòng trống. Dòng "Ngày .. tháng ..
            // năm .." nằm riêng 1 dòng phía trên, còn "Tổng giám đốc", "Kế toán
            // trưởng", "Người lập biểu" nằm cùng 1 dòng phía dưới.
            var iDateRow = iTotalRow + 3;
            var iSignRow = iDateRow + 1;

            ws.mergeCells(colLetter(FIRST_COL + 16) + iDateRow + ":" + sLast + iDateRow); // Q:S
            var oDateCell = ws.getCell(colLetter(FIRST_COL + 16) + iDateRow);
            oDateCell.value = "Ngày ….. tháng ….. năm …..";
            oDateCell.font = { italic: true, size: 10, name: FONT };
            oDateCell.alignment = { horizontal: "center", vertical: "middle" };

            ws.mergeCells(colLetter(FIRST_COL + 2) + iSignRow + ":" + colLetter(FIRST_COL + 4) + iSignRow); // C:E
            var oCeoCell = ws.getCell(colLetter(FIRST_COL + 2) + iSignRow);
            oCeoCell.value = "Tổng giám đốc";
            oCeoCell.font = { bold: true, size: 11, name: FONT };
            oCeoCell.alignment = { horizontal: "center", vertical: "middle" };

            ws.mergeCells(colLetter(FIRST_COL + 6) + iSignRow + ":" + colLetter(FIRST_COL + 10) + iSignRow); // G:K
            var oChiefAccCell = ws.getCell(colLetter(FIRST_COL + 6) + iSignRow);
            oChiefAccCell.value = "Kế toán trưởng";
            oChiefAccCell.font = { bold: true, size: 11, name: FONT };
            oChiefAccCell.alignment = { horizontal: "center", vertical: "middle" };

            ws.mergeCells(colLetter(FIRST_COL + 16) + iSignRow + ":" + sLast + iSignRow); // Q:S
            var oPreparerCell = ws.getCell(colLetter(FIRST_COL + 16) + iSignRow);
            oPreparerCell.value = "Người lập biểu";
            oPreparerCell.font = { bold: true, size: 11, name: FONT };
            oPreparerCell.alignment = { horizontal: "center", vertical: "middle" };

            //9. Độ rộng cột
            var aColumns = [];
            for (i = 0; i < COLUMNS.length; i++) {
                aColumns.push({ width: COLUMNS[i].width });
            }
            ws.columns = aColumns;

            //10. Xuất file và tải về
            workbook.xlsx.writeBuffer().then(function (buffer) {
                var blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                var url = URL.createObjectURL(blob);
                var link = document.createElement("a");
                link.href = url;

                link.download = (bSummary ? "TH_Bảng kê_hhdv.xlsx" : "CT_Bảng kê_hhdv.xlsx");
                link.click();
                URL.revokeObjectURL(url);
                resolve();
            }).catch(reject);
        });
    }

});
