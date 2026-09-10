sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog"
], function (MessageToast, MessageBox, BusyDialog) {
    "use strict";

    // Entity set của bảng chính trên List Report (khớp manifest routing).
    var MAIN_ENTITY_SET = "zce_mapim";

    var BATCH_SIZE = 1000;
    var CONCURRENCY = 4;

    // Cột xuất Excel, đúng thứ tự + tên hiển thị trên SmartTable (zce_mapim).
    var COLUMNS = [
        { label: "Company Code", field: "CompanyCode", width: 12 },
        { label: "Invoicing party", field: "InvoicingParty", width: 14 },
        { label: "Invoicing party name", field: "InvoicingPartyName", width: 28 },
        { label: "INV Posting Date", field: "InvoicePostingDate", width: 14, date: true },
        { label: "E-Invoice", field: "InvoiceNo", width: 16 },
        { label: "Invoice Doc", field: "Inv", width: 14, numeric: true },
        { label: "Invoice Doc Item", field: "InvItem", width: 12, numeric: true },
        { label: "GR Posting Date", field: "GRPostingDate", width: 14, date: true },
        { label: "GR Doc", field: "MatDoc", width: 14, numeric: true },
        { label: "GR Doc Item", field: "MatDocItem", width: 12, numeric: true },
        { label: "GR Qty", field: "GRQty", width: 12, quantity: true },
        { label: "INV Qty", field: "InvoiceQty", width: 12, quantity: true },
        { label: "Allocated Qty", field: "AllocatedQty", width: 12, quantity: true },
        { label: "GR Open Qty", field: "GROpenQty", width: 12, quantity: true },
        { label: "INV Open Qty", field: "InvOpenQty", width: 12, quantity: true },
        { label: "Item Text", field: "ItemText", width: 24 },
        { label: "Header Text", field: "HeaderText", width: 24 },
        { label: "Material Code", field: "MaterialCode", width: 16 },
        { label: "Material Description", field: "MaterialDescription", width: 28 },
        { label: "Order Price Unit", field: "OrderPriceUnit", width: 12 },
        { label: "GR Category", field: "GRCategory", width: 12 },
        { label: "INV Category", field: "IVCategory", width: 12 },
        { label: "GR Amount ComCode", field: "GRAmountComCode", width: 16, amount: true },
        { label: "GR Amount TransCode", field: "GRAmountTransCode", width: 16, amount: true },
        { label: "TransCur", field: "TransCur", width: 10 },
        { label: "INV Journal Entry", field: "JE", width: 14, numeric: true },
        { label: "INV Amount ComCode", field: "InvoiceAmountComCode", width: 16, amount: true },
        { label: "INV Amount Trans", field: "InvoiceAmountTrans", width: 16, amount: true },
        { label: "INV Net price TransCur", field: "INVNetPriceTransCur", width: 16, amount: true },
        { label: "Currency", field: "Currency", width: 10 },
        { label: "GR Fully Invoiced", field: "GRFullyInvoiced", width: 14 },
        { label: "IV Fully Invoiced", field: "IVFullyInvoiced", width: 14 },
        { label: "PO fully invoiced", field: "POFullyInvoiced", width: 14 },
        { label: "Storage Location", field: "StorageLocation", width: 14 },
        { label: "Plant", field: "Plant", width: 10 },
        { label: "PO No", field: "PONo", width: 14, numeric: true },
        { label: "PO Item", field: "POItem", width: 10, numeric: true },
        { label: "PO Net Price", field: "PONetprice", width: 14, amount: true },
        { label: "PO Currency", field: "POCurrency", width: 12 },
        { label: "PO Supplier", field: "POSupplier", width: 14 },
        { label: "PO Supplier Name", field: "POSupplierName", width: 28 },
        { label: "Ghi chú", field: "GhiChu", width: 24 },
        { label: "GR-based INV", field: "GRBasedInv", width: 14 },
        { label: "Delivery Doc", field: "DeliveryDoc", width: 14, numeric: true },
        { label: "Delivery Item", field: "DeliveryItem", width: 12, numeric: true },
        { label: "PO Type", field: "POType", width: 10 },
        { label: "GR Fiscal year", field: "GRFiscalYear", width: 12 },
        { label: "Invoice Fiscal year", field: "InvFiscalYear", width: 14 },
        { label: "Allocated GR Amount ComCode", field: "AllocatedGRAmountComCode", width: 20, amount: true },
        { label: "Allocated GR Amount TransCode", field: "AllocatedGRAmountTransCode", width: 20, amount: true },
        { label: "Allocated Invoice Amount ComCode", field: "AllocatedInvoiceAmountComCode", width: 22, amount: true },
        { label: "Allocated Invoice Amount Trans", field: "AllocatedInvoiceAmountTrans", width: 22, amount: true }
    ];

    var FIRST_COL = 1;                                   // A
    var LAST_COL = FIRST_COL + COLUMNS.length - 1;        // AV

    return {

        /**
         * Standard controller hook - fire khi view khởi tạo
         */
        onInit: function () {
            console.log(">>> ZMAPIM ListReportExt: onInit FIRED");
        },

        /**
         * Fiori Elements hook - fire khi SmartFilterBar init xong
         * Đăng ký listener để set default năm hiện tại
         */
        onInitSmartFilterBarExtension: function (oEvent) {
            console.log(">>> ZMAPIM ListReportExt: onInitSmartFilterBarExtension FIRED");

            this._bInitYear = false;
            this._oSmartFilterBar = oEvent.getSource();

            // Set default ngay first call
            this._handleFilterChange();

            // Attach listener cho các lần sau
            this._oSmartFilterBar.attachFilterChange(this._handleFilterChange, this);
            this._oSmartFilterBar.attachAfterVariantLoad(this._onAfterVariantLoad, this);
        },

        /**
         * Set default FiscalYear = năm hiện tại ở first load
         * Chỉ set 1 lần khi field chưa có giá trị
         */
        _handleFilterChange: function () {
            if (this._bInitYear === true) {
                return;
            }
            this._bInitYear = true;

            var oJSONData = this._oSmartFilterBar.getFilterData(true);
            console.log(">>> ZMAPIM: Current FiscalYear =", JSON.stringify(oJSONData.FiscalYear));

            // Chỉ set default nếu FiscalYear chưa có giá trị
            var bIsEmpty = !oJSONData.FiscalYear
                || (oJSONData.FiscalYear.ranges
                    && oJSONData.FiscalYear.ranges.length === 0
                    && oJSONData.FiscalYear.items
                    && oJSONData.FiscalYear.items.length === 0);

            if (bIsEmpty) {
                var sCurrentYear = "" + new Date().getFullYear();

                oJSONData.FiscalYear = {
                    items: [],
                    ranges: [{
                        exclude: false,
                        keyField: "FiscalYear",
                        operation: "EQ",
                        value1: sCurrentYear,
                        value2: null
                    }],
                    value: null
                };
                this._oSmartFilterBar.setFilterData(oJSONData);
                console.log(">>> ZMAPIM: Set default FiscalYear =", sCurrentYear);
            } else {
                console.log(">>> ZMAPIM: FiscalYear already has value, skip default");
            }
        },

        /**
         * Khi user load Standard variant của SAP mà variant đó rỗng
         * -> auto fill năm hiện tại
         */
        _onAfterVariantLoad: function () {
            console.log(">>> ZMAPIM: _onAfterVariantLoad FIRED");

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

            var bShouldFill = oJSONData.FiscalYear
                && oJSONData.FiscalYear.ranges
                && oJSONData.FiscalYear.ranges.length === 0
                && oJSONData.FiscalYear.items
                && oJSONData.FiscalYear.items.length === 0
                && oCurrentVariant
                && oCurrentVariant.getAuthor() === "SAP";

            if (bShouldFill) {
                var sCurrentYear = "" + new Date().getFullYear();

                oJSONData.FiscalYear = {
                    items: [],
                    ranges: [{
                        exclude: false,
                        keyField: "FiscalYear",
                        operation: "EQ",
                        value1: sCurrentYear,
                        value2: null
                    }],
                    value: null
                };
                this._oSmartFilterBar.setFilterData(oJSONData);
                console.log(">>> ZMAPIM: Variant load - Set FiscalYear =", sCurrentYear);
            }
        },

        /**
         * Fire mỗi lần view render lại - set icon cho nút Export Excel
         * (nút được đăng ký qua manifest.json controlConfiguration nên
         * không gán icon trực tiếp được, phải set bằng code)
         */
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },

        /**
         * Handler nút "Xuất Excel" trên toolbar SmartTable
         */
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

        // Chỉ nhận đúng SmartTable bind vào entity set chính. Bỏ qua các
        // SmartTable của value help (vd _I_PurchaseOrderType khi mở F4 PO Type),
        // adapt filters, personalization... Nhận diện qua entitySet HOẶC path
        // của binding (FE nhiều khi không set property entitySet).
        var oSmartTable, oTable, oBinding, i;
        for (i = 0; i < oAll.length; i++) {
            if (oAll[i].getMetadata().getName() !== "sap.ui.comp.smarttable.SmartTable") {
                continue;
            }
            var oST = oAll[i];
            var sES = (oST.getEntitySet && oST.getEntitySet()) || "";
            var sTblPath = (oST.getTableBindingPath && oST.getTableBindingPath()) || "";
            var oInner = oST.getTable && oST.getTable();
            var oBnd = oInner && (oInner.getBinding("rows") || oInner.getBinding("items"));
            var sBndPath = oBnd ? (oBnd.getPath() || "") : "";

            console.log(">>> ZMAPIM export: found SmartTable id =", oST.getId(),
                "| entitySet =", sES || "(none)",
                "| tableBindingPath =", sTblPath || "(none)",
                "| bindingPath =", sBndPath || "(none)",
                "| bound =", !!oBnd);

            var bMatch = sES === MAIN_ENTITY_SET
                || sTblPath === MAIN_ENTITY_SET || sTblPath === "/" + MAIN_ENTITY_SET
                || sBndPath === MAIN_ENTITY_SET || sBndPath === "/" + MAIN_ENTITY_SET;

            if (bMatch) {
                oSmartTable = oST;
                oTable = oInner;
                oBinding = oBnd;
                if (oBnd) { break; }   // ưu tiên cái đã có binding
            }
        }
        if (!oSmartTable) {
            console.error(">>> ZMAPIM export: không tìm thấy SmartTable của entity set", MAIN_ENTITY_SET);
            return null;
        }
        if (!oTable) { oTable = oSmartTable.getTable(); }
        if (!oBinding && oTable) {
            oBinding = oTable.getBinding("rows") || oTable.getBinding("items");
        }
        if (!oBinding) {
            console.error(">>> ZMAPIM export: SmartTable chưa có binding dữ liệu (bấm Go trước).");
            return null;
        }

        var oModel = oBinding.getModel();

        // Đã khớp đúng bảng chính -> path chắc chắn là entity set chính.
        var sPath = "/" + MAIN_ENTITY_SET;

        // Gộp cả application filters (từ SmartFilterBar) lẫn control filters.
        var aFilters = []
            .concat(oBinding.aApplicationFilters || [])
            .concat(oBinding.aFilters || []);

        console.log(">>> ZMAPIM export: path =", sPath,
            "| filters =", aFilters.length,
            "| binding length =", oBinding.getLength(),
            "| isLengthFinal =", oBinding.isLengthFinal && oBinding.isLengthFinal());

        return {
            smartTable: oSmartTable,
            table: oTable,
            binding: oBinding,
            model: oModel,
            path: sPath,
            filters: aFilters,
            sorters: oBinding.aSorters || [],
            totalLength: oBinding.getLength()
        };
    }


    //////////////////////////////////////////////////////////////////////////
    // Tách các query option ($select/$filter/$orderby/$expand) ra khỏi URL.
    function parseQueryOptions(sUrl) {
        var oOut = {};
        var iQ = sUrl.indexOf("?");
        if (iQ < 0) { return oOut; }
        sUrl.slice(iQ + 1).split("&").forEach(function (sPair) {
            var iEq = sPair.indexOf("=");
            if (iEq < 0) { return; }
            var sKey = decodeURIComponent(sPair.slice(0, iEq));
            if (["$select", "$filter", "$orderby", "$expand"].indexOf(sKey) >= 0) {
                oOut[sKey] = decodeURIComponent(sPair.slice(iEq + 1));
            }
        });
        return oOut;
    }

    //////////////////////////////////////////////////////////////////////////
    // Tải toàn bộ dữ liệu qua $skip/$top theo batch, chạy song song CONCURRENCY batch.
    //
    // Lấy nguyên bộ $select/$filter/$orderby mà binding SmartTable tự sinh ra
    // (getDownloadUrl -> đã đúng cho service analytical, trả dòng chi tiết) rồi
    // gửi lại qua model.read(). ODataModel v2 gói request trong $batch POST nên
    // $filter dài (multi-select PO Type...) nằm trong body -> KHÔNG bị lỗi URL quá dài.
    function fetchAllData(oRaw, oBusyDialog) {
        return new Promise(function (resolve, reject) {

            var sUrl = oRaw.binding.getDownloadUrl && oRaw.binding.getDownloadUrl("json");
            if (!sUrl) {
                reject(new Error("Không lấy được URL tải dữ liệu từ bảng (getDownloadUrl rỗng)"));
                return;
            }
            var oBaseParams = parseQueryOptions(sUrl);
            console.log(">>> ZMAPIM export: downloadUrl =", sUrl);
            console.log(">>> ZMAPIM export: $select =", oBaseParams.$select || "(không có)",
                "| $filter =", oBaseParams.$filter || "(không có)");

            // Nếu không parse được $filter thì fallback dùng Filter object của binding.
            var bUseFilterObjects = !oBaseParams.$filter && oRaw.filters.length > 0;

            function readBatch(iSkip, bCount) {
                return new Promise(function (res, rej) {
                    var oUrlParams = { "$skip": iSkip, "$top": BATCH_SIZE };
                    Object.keys(oBaseParams).forEach(function (k) {
                        if (!(bUseFilterObjects && k === "$filter")) {
                            oUrlParams[k] = oBaseParams[k];
                        }
                    });
                    if (bCount) { oUrlParams["$inlinecount"] = "allpages"; }

                    oRaw.model.read(oRaw.path, {
                        filters: bUseFilterObjects ? oRaw.filters : undefined,
                        urlParameters: oUrlParams,
                        success: function (oData) {
                            res({ results: oData.results || [], count: oData.__count });
                        },
                        error: function (oErr) {
                            var sText = (oErr && (oErr.responseText || oErr.message)) || "unknown error";
                            rej(new Error(String(sText).replace(/\s+/g, " ").slice(0, 400)));
                        }
                    });
                });
            }

            // Batch đầu tiên kèm $inlinecount để lấy tổng số dòng thật từ server,
            // không phụ thuộc oBinding.getLength() (có thể sai / chưa load đủ).
            readBatch(0, true).then(function (oFirst) {
                var aFirst = oFirst.results || [];
                var iTotal = parseInt(oFirst.count, 10);
                if (isNaN(iTotal)) { iTotal = aFirst.length; }

                console.log(">>> ZMAPIM export: server __count =", oFirst.count,
                    "| batch đầu =", aFirst.length, "dòng",
                    "| keys dòng đầu =", aFirst[0] ? Object.keys(aFirst[0]).join(",") : "(rỗng)");

                if (aFirst[0] && aFirst[0].CompanyCode === undefined) {
                    console.warn(">>> ZMAPIM export: dữ liệu trả về KHÔNG có field 'CompanyCode' "
                        + "-> URL tải dữ liệu đang sai entity.");
                }

                if (iTotal <= aFirst.length) {
                    resolve(aFirst);
                    return;
                }

                var iNumBatches = Math.ceil(iTotal / BATCH_SIZE);
                var aResults = new Array(iNumBatches);
                aResults[0] = aFirst;

                var iNextBatch = 1;
                var iCompleted = 1;
                var bHasError = false;

                function updateProgress() {
                    var iLoaded = Math.min(iCompleted * BATCH_SIZE, iTotal);
                    oBusyDialog.setText("Đang tải dữ liệu: " + iLoaded.toLocaleString("vi-VN")
                        + " / " + iTotal.toLocaleString("vi-VN") + " dòng");
                }

                function runNext() {
                    if (bHasError) { return; }
                    if (iNextBatch >= iNumBatches) { return; }

                    var iBatchIdx = iNextBatch++;
                    readBatch(iBatchIdx * BATCH_SIZE, false).then(function (oData) {
                        if (bHasError) { return; }
                        aResults[iBatchIdx] = oData.results || [];
                        iCompleted++;
                        updateProgress();

                        if (iCompleted === iNumBatches) {
                            resolve([].concat.apply([], aResults));
                        } else {
                            runNext();
                        }
                    }).catch(function (oErr) {
                        bHasError = true;
                        reject(oErr);
                    });
                }

                updateProgress();
                var iInitial = Math.min(CONCURRENCY, iNumBatches - 1);
                for (var k = 0; k < iInitial; k++) {
                    runNext();
                }
            }).catch(reject);
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
            oScript.src = sap.ui.require.toUrl("zmapim/libs/exceljs.min.js");
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

    function toNumber(v) {
        return v ? parseFloat(v) : 0;
    }

    // Bỏ số 0 dẫn đầu của các field số chứng từ (Inv, MatDoc, PONo, JE...)
    function stripLeadingZeros(v) {
        if (v === undefined || v === null || v === "") { return ""; }
        var s = String(v);
        return /^\d+$/.test(s) ? String(parseInt(s, 10)) : s;
    }

    // OData V2 Edm.DateTime -> ODataModel đã tự parse thành JS Date; phòng khi
    // vẫn còn ở dạng chuỗi "/Date(ms)/" (vd dữ liệu lấy qua $batch thô).
    function toDate(v) {
        if (!v) { return null; }
        if (v instanceof Date) { return v; }
        if (typeof v === "string") {
            var oMatch = /\/Date\((-?\d+)\)\//.exec(v);
            if (oMatch) { return new Date(parseInt(oMatch[1], 10)); }
        }
        return null;
    }


    //////////////////////////////////////////////////////////////////////////
    // Build file Excel với các cột theo đúng thứ tự trên SmartTable, rồi tải về máy
    function buildExcel(aData) {
        return new Promise(function (resolve, reject) {
            var workbook = new ExcelJS.Workbook();
            var ws = workbook.addWorksheet("SAPUI5 Export");

            var iHeaderRow = 1;
            var i, col, cell;

            //1. Header
            for (i = 0; i < COLUMNS.length; i++) {
                col = FIRST_COL + i;
                cell = ws.getCell(iHeaderRow, col);
                cell.value = COLUMNS[i].label;
                cell.font = { bold: true };
            }

            //2. Dữ liệu
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
                        var oDate = toDate(vValue);
                        cell.value = oDate;
                        if (oDate) { cell.numFmt = "dd/mm/yyyy"; }
                    } else if (oColDef.quantity) {
                        var fQty = toNumber(vValue);
                        cell.value = fQty;
                        // "#" là placeholder tùy chọn, nếu số nguyên thì phần thập phân rỗng
                        // nhưng dấu chấm literal vẫn bị in ra -> chỉ dùng numFmt có thập phân
                        // khi giá trị thực sự có phần lẻ.
                        cell.numFmt = Number.isInteger(fQty) ? "#,##0" : "#,##0.###";
                    } else if (oColDef.amount) {
                        cell.value = toNumber(vValue);
                        cell.numFmt = "#,##0.00";
                    } else if (oColDef.numeric) {
                        cell.value = stripLeadingZeros(vValue);
                    } else {
                        cell.value = vValue || "";
                    }
                }

                iRow++;
            }

            //3. Độ rộng cột + autofilter + freeze header
            var aColumns = [];
            for (i = 0; i < COLUMNS.length; i++) {
                aColumns.push({ width: COLUMNS[i].width });
            }
            ws.columns = aColumns;

            var sFirst = colLetter(FIRST_COL);
            var sLast = colLetter(LAST_COL);
            ws.autoFilter = sFirst + iHeaderRow + ":" + sLast + iHeaderRow;
            ws.views = [{ state: "frozen", ySplit: iHeaderRow }];

            //4. Xuất file và tải về
            workbook.xlsx.writeBuffer().then(function (buffer) {
                var blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                var url = URL.createObjectURL(blob);
                var link = document.createElement("a");
                link.href = url;
                link.download = "MappingHoaDonChungTuKho_"
                    + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
                    + ".xlsx";
                link.click();
                URL.revokeObjectURL(url);
                resolve();
            }).catch(reject);
        });
    }

});