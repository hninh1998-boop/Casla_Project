sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/ui/core/dnd/DragDropInfo"
], function (MessageToast, MessageBox, BusyDialog, DragDropInfo) {
    'use strict';

    // Entity set của bảng chính trên List Report (khớp manifest sap.ui.generic.app).
    var MAIN_ENTITY_SET = "zce_cont";

    // Static action sinh file excel ở backend (zce_cont.bdef → ExportExcel)
    var EXPORT_ACTION = "ExportExcel";

    // Operator của sap.ui.model.Filter → sign / option của select-option
    var FILTER_OPERATORS = {
        EQ: { sign: "I", option: "EQ" },
        NE: { sign: "E", option: "EQ" },
        BT: { sign: "I", option: "BT" },
        NB: { sign: "E", option: "BT" },
        LT: { sign: "I", option: "LT" },
        LE: { sign: "I", option: "LE" },
        GT: { sign: "I", option: "GT" },
        GE: { sign: "I", option: "GE" },
        Contains: { sign: "I", option: "CP", prefix: "*", suffix: "*" },
        NotContains: { sign: "E", option: "CP", prefix: "*", suffix: "*" },
        StartsWith: { sign: "I", option: "CP", suffix: "*" },
        NotStartsWith: { sign: "E", option: "CP", suffix: "*" },
        EndsWith: { sign: "I", option: "CP", prefix: "*" },
        NotEndsWith: { sign: "E", option: "CP", prefix: "*" }
    };

    // Kéo-thả sắp xếp thứ tự dòng: yêu cầu backend (RAP custom entity zce_cont)
    // có field số SortOrder editable (persist ở Z table, cùng cơ chế update đang
    // dùng cho Cont/GhiChuKhac...) và mặc định $orderby=SortOrder asc.
    // Cách tính "gap-based": mỗi dòng cách nhau SORT_ORDER_GAP đơn vị, khi thả vào
    // giữa 2 dòng thì lấy trung bình cộng SortOrder của 2 dòng liền kề. Khi hết
    // khoảng trống (2 dòng liền kề có SortOrder sát nhau) thì đánh số lại các dòng
    // đang hiển thị trên màn hình theo bội số của SORT_ORDER_GAP.
    var SORT_ORDER_FIELD = "SortOrder";
    var SORT_ORDER_GAP = 1000;
    // Số dòng tối đa mở rộng ra mỗi phía khi tìm 2 mốc SortOrder thật (khác biệt
    // đủ xa) để bao quanh phạm vi cần đánh số lại (xem renumberBetweenAndRetry).
    var RENUMBER_MAX_EXPAND = 80;

    return {
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
            attachRowReorder(this.getView());
        },
        exportExcel: function () {
            mainExport(this.getView());
        }
    };


    //////////////////////////////////////////////////////////////////////////
    // Kéo-thả sắp xếp thứ tự dòng (GridTable)
    //
    // Không thể gắn dragDropConfig ngay trong onAfterRendering của view vì lúc đó
    // SmartTable thường CHƯA dựng xong GridTable bên trong (còn phải chờ load
    // metadata OData) -> getTable() trả về undefined, và onAfterRendering của
    // trang List Report chỉ chạy 1 lần nên sẽ không có cơ hội thử lại.
    // Thay vào đó lắng nghe sự kiện "initialise" (SmartTable đã dựng xong lần đầu)
    // và "beforeRebindTable" (SmartTable dựng lại inner table khi đổi variant/sort...)
    // để luôn gắn lại được vào đúng instance GridTable hiện hành.
    function attachRowReorder(oView) {
        var oAll = oView.findAggregatedObjects(true);
        var oSmartTable;
        for (var i = 0; i < oAll.length; i++) {
            if (oAll[i].getMetadata().getName() === "sap.ui.comp.smarttable.SmartTable") {
                oSmartTable = oAll[i];
                break;
            }
        }
        if (!oSmartTable || oSmartTable.data("reorderHooked")) { return; }
        oSmartTable.data("reorderHooked", true);

        enableRowReorder(oSmartTable);                          // phòng khi đã init xong từ trước
        oSmartTable.attachInitialise(function () {
            enableRowReorder(oSmartTable);
        });
        oSmartTable.attachEvent("beforeRebindTable", function (oEvt) {
            var oOldTable = oSmartTable.getTable();
            if (oOldTable) { oOldTable.data("reorderEnabled", null); }
            ensureSortOrderSelected(oEvt);
        });
    }

    // SmartTable mặc định chỉ $select đúng những cột đang HIỂN THỊ trên bảng.
    // SortOrder không phải cột hiển thị (chỉ dùng ngầm để tính thứ tự kéo-thả)
    // nên sẽ KHÔNG được select về client -> getProperty("SortOrder") luôn trả
    // undefined, khiến mọi lần kéo đều tính sai (luôn ra giá trị mặc định).
    // Ép thêm SortOrder vào $select ở đây, bất kể có phải cột hiển thị hay không.
    function ensureSortOrderSelected(oEvt) {
        var oParams = oEvt.getParameter("bindingParams");
        if (!oParams) { return; }
        oParams.parameters = oParams.parameters || {};
        var sSelect = oParams.parameters.select;
        // Không có $select tường minh -> framework đã lấy đủ field mặc định,
        // không cần (và không nên) tự ép select chỉ riêng SortOrder vào đây.
        if (!sSelect) { return; }
        var aFields = sSelect.split(",");
        if (aFields.indexOf(SORT_ORDER_FIELD) < 0) {
            aFields.push(SORT_ORDER_FIELD);
            oParams.parameters.select = aFields.join(",");
        }
    }

    function enableRowReorder(oSmartTable) {
        var oTable = oSmartTable.getTable();
        if (!oTable) {
            return;
        }
        if (oTable.data("reorderEnabled")) { return; }
        oTable.data("reorderEnabled", true);

        oTable.addDragDropConfig(new DragDropInfo({
            sourceAggregation: "rows",
            targetAggregation: "rows",
            dropPosition: "Between",
            drop: function (oEvent) {
                onRowDrop(oEvent, oTable);
            }
        }));
    }

    function onRowDrop(oEvent, oTable) {
        var oDraggedRow = oEvent.getParameter("draggedControl");
        var oDroppedRow = oEvent.getParameter("droppedControl");
        var sPosition = oEvent.getParameter("dropPosition"); // "Before" | "After"

        var oDragCtx = oDraggedRow.getBindingContext();
        var oDropCtx = oDroppedRow.getBindingContext();
        if (!oDragCtx || !oDropCtx || oDragCtx.getPath() === oDropCtx.getPath()) { return; }

        var oBinding = oTable.getBinding("rows");
        var iDropIdx = oDroppedRow.getIndex();
        var iPrevIdx = sPosition === "Before" ? iDropIdx - 1 : iDropIdx;
        var iNextIdx = sPosition === "Before" ? iDropIdx : iDropIdx + 1;

        var oPrevCtx = iPrevIdx >= 0 ? oBinding.getContexts(iPrevIdx, 1)[0] : null;
        var oNextCtx = oBinding.getContexts(iNextIdx, 1)[0] || null;

        if ((oPrevCtx && oPrevCtx.getPath() === oDragCtx.getPath())
            || (oNextCtx && oNextCtx.getPath() === oDragCtx.getPath())) {
            return; // Thả lại đúng vị trí cũ -> không đổi
        }

        // Dòng liền kề chưa kịp load dữ liệu (thường do vừa scroll) -> yêu cầu thử lại
        // thay vì tính SortOrder sai lệch.
        if ((iPrevIdx >= 0 && !oPrevCtx) || (iNextIdx < oBinding.getLength() && !oNextCtx)) {
            MessageToast.show("Vui lòng thử kéo thả lại");
            return;
        }

        var iPrevOrder = oPrevCtx ? toSortOrderNumber(oPrevCtx.getProperty(SORT_ORDER_FIELD)) : null;
        var iNextOrder = oNextCtx ? toSortOrderNumber(oNextCtx.getProperty(SORT_ORDER_FIELD)) : null;
        var iNewOrder = computeNewSortOrder(iPrevOrder, iNextOrder);

        if (iNewOrder === null) {
            renumberBetweenAndRetry(oTable, oDragCtx, oDropCtx, iPrevIdx, iNextIdx, sPosition);
            return;
        }

        persistSortOrder(oDragCtx, iNewOrder, oTable);
    }

    // OData V2 trả Edm.Decimal (SortOrder khai báo abap.dec) dưới dạng STRING
    // (vd "1000.000"), không phải number -> phải parse trước khi tính toán, nếu
    // không "+" sẽ bị hiểu là nối chuỗi thay vì cộng số.
    function toSortOrderNumber(v) {
        if (v === null || v === undefined || v === "") { return null; }
        var n = parseFloat(v);
        return isNaN(n) ? null : n;
    }

    // Tính SortOrder mới nằm giữa 2 dòng liền kề. Trả về null nếu không còn khoảng
    // trống (2 giá trị liền kề quá sát nhau) -> cần đánh số lại.
    function computeNewSortOrder(iPrev, iNext) {
        if (iPrev === null && iNext === null) { return SORT_ORDER_GAP; }
        if (iPrev === null) { return iNext - SORT_ORDER_GAP; }
        if (iNext === null) { return iPrev + SORT_ORDER_GAP; }
        var iMid = (iPrev + iNext) / 2;
        return (iMid > iPrev && iMid < iNext) ? iMid : null;
    }

    // SortOrder là Edm.Decimal (abap.dec) -> OData V2 yêu cầu gửi dạng STRING
    // trong JSON payload (vd "1500.000"), gửi number thô sẽ bị backend báo lỗi
    // parse (CX_S3ML_PARSE_ERROR: Failed to read property 'SortOrder').
    function formatSortOrder(n) {
        return n.toFixed(3);
    }

    // In lỗi OData gốc ra console để debug (message chung trên UI không đủ chi tiết
    // để biết lỗi thật từ backend là gì).
    function logODataError(sContext, oError) {
        var sDetail = oError && oError.responseText;
        if (sDetail) {
            try {
                var oParsed = JSON.parse(sDetail);
                sDetail = (oParsed.error && oParsed.error.message && oParsed.error.message.value) || sDetail;
            } catch (e) { /* responseText không phải JSON -> giữ nguyên raw text */ }
        }
        // eslint-disable-next-line no-console
        console.error("[RowReorder] " + sContext + ":", sDetail || oError);
    }

    function persistSortOrder(oContext, iNewOrder, oTable) {
        var oModel = oContext.getModel();
        var mPayload = {};
        mPayload[SORT_ORDER_FIELD] = formatSortOrder(iNewOrder);

        oModel.update(oContext.getPath(), mPayload, {
            merge: true,
            success: function () {
                oTable.getBinding("rows").refresh();
            },
            error: function (oError) {
                logODataError("persistSortOrder", oError);
                MessageBox.error("Không lưu được thứ tự mới. Vui lòng thử lại.");
            }
        });
    }

    // Hết khoảng trống giữa 2 dòng liền kề (thường do trùng SortOrder) -> KHÔNG
    // được gán bừa số nhỏ theo cửa sổ đang hiển thị (dễ trùng với dòng khác ở xa,
    // ngoài màn hình -> gây collision toàn cục). Thay vào đó mở rộng ra 2 phía để
    // tìm 2 mốc SortOrder THẬT, cách nhau đủ xa (không giới hạn ở các dòng đang
    // hiển thị) rồi chia đều lại SortOrder cho các dòng nằm giữa 2 mốc đó -> giá
    // trị mới luôn nằm chắc chắn trong khoảng [dLow, dHigh], không thể đụng bất kỳ
    // dòng nào ngoài phạm vi này dù renumber ở filter/thời điểm nào.
    function renumberBetweenAndRetry(oTable, oDragCtx, oDropCtx, iPrevIdx, iNextIdx, sPosition) {
        var oBinding = oTable.getBinding("rows");
        var iTotal = oBinding.getLength();

        function orderAt(iIdx) {
            if (iIdx < 0 || iIdx >= iTotal) { return null; }
            var oCtx = oBinding.getContexts(iIdx, 1)[0];
            return oCtx ? toSortOrderNumber(oCtx.getProperty(SORT_ORDER_FIELD)) : null;
        }

        var iLowIdx = iPrevIdx;
        var iHighIdx = iNextIdx;
        var dLow = orderAt(iLowIdx);
        var dHigh = orderAt(iHighIdx);
        var iGuard = 0;

        while (iGuard < RENUMBER_MAX_EXPAND && dLow !== null && dHigh !== null
            && (dHigh - dLow) < SORT_ORDER_GAP) {
            if (iLowIdx > 0) { iLowIdx--; dLow = orderAt(iLowIdx); }
            if (iHighIdx < iTotal - 1) { iHighIdx++; dHigh = orderAt(iHighIdx); }
            iGuard++;
        }
        if (dLow === null && dHigh === null) { dLow = 0; dHigh = SORT_ORDER_GAP; }
        else if (dLow === null) { dLow = dHigh - SORT_ORDER_GAP; }
        else if (dHigh === null) { dHigh = dLow + SORT_ORDER_GAP; }
        if (dHigh <= dLow) { dHigh = dLow + SORT_ORDER_GAP; } // an toàn, tránh chia khoảng âm/0

        // Các dòng cần renumber: nằm giữa 2 mốc biên (không gồm chính 2 mốc), giữ
        // nguyên thứ tự hiện tại, chèn dòng vừa kéo vào đúng vị trí thả.
        var aOrdered = [];
        for (var i = iLowIdx + 1; i <= iHighIdx - 1; i++) {
            var oCtx = oBinding.getContexts(i, 1)[0];
            if (oCtx && oCtx.getPath() !== oDragCtx.getPath()) { aOrdered.push(oCtx); }
        }
        var iInsertAt = aOrdered.findIndex(function (oFindCtx) {
            return oFindCtx.getPath() === oDropCtx.getPath();
        });
        if (iInsertAt < 0) { iInsertAt = aOrdered.length; }
        if (sPosition === "After") { iInsertAt++; }
        aOrdered.splice(iInsertAt, 0, oDragCtx);

        var iCount = aOrdered.length;
        var oModel = oDragCtx.getModel();
        var iPending = iCount;
        var bHasError = false;

        function checkDone() {
            iPending--;
            if (iPending > 0) { return; }
            oTable.getBinding("rows").refresh();
            if (bHasError) {
                MessageBox.error("Có lỗi khi đánh số lại thứ tự, vui lòng kiểm tra lại.");
            } else {
                MessageToast.show("Đã sắp xếp lại thứ tự");
            }
        }

        aOrdered.forEach(function (oRowCtx, iIdx) {
            var dNewOrder = dLow + (iIdx + 1) * (dHigh - dLow) / (iCount + 1);
            var mPayload = {};
            mPayload[SORT_ORDER_FIELD] = formatSortOrder(dNewOrder);

            oModel.update(oRowCtx.getPath(), mPayload, {
                merge: true,
                // Mỗi dòng 1 changeset riêng trong cùng $batch -> 1 dòng lỗi không
                // kéo theo rollback các dòng khác đang lưu cùng lúc.
                groupId: "reorder_" + iIdx,
                success: checkDone,
                error: function (oError) {
                    logODataError("renumberBetweenAndRetry", oError);
                    bHasError = true;
                    checkDone();
                }
            });
        });
    }

    //////////////////////////////////////////////////////////////////////////
    // Main Logic Export Excel
    //
    // File xlsx sinh hoàn toàn ở backend (static action ExportExcel → zcl_ce_cont_xlsx),
    // FE chỉ gửi filter + sort đang áp trên bảng rồi nhận file về. Không còn dựng file
    // bằng ExcelJS trên trình duyệt.
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

        var oParam;
        try {
            oParam = buildExportParam(oRaw);
        } catch (oError) {
            MessageBox.error("Không đọc được filter trên màn hình.");
            return;
        }

        var oBusy = new BusyDialog({
            title: "Đang xuất Excel",
            text: "Đang tạo file Excel..."
        });
        oBusy.open();

        function closeBusy() {
            oBusy.close();
            oBusy.destroy();
        }

        oRaw.model.callFunction("/" + EXPORT_ACTION, {
            method: "POST",
            urlParameters: { JsonString: JSON.stringify(oParam) },
            success: function (oData) {
                closeBusy();
                var oFile = getExportFile(oData);
                if (!oFile || !oFile.FileContent) {
                    MessageBox.warning("Không có dữ liệu để Export");
                    return;
                }
                downloadFile(oFile);
                MessageToast.show("Export thành công!");
            },
            error: function (oError) {
                closeBusy();
                MessageBox.error("Lỗi export: " + getErrorMessage(oError));
            }
        });
    }


    //////////////////////////////////////////////////////////////////////////
    // Lấy dữ liệu Raw từ SmartTable đang hiển thị trên view
    //
    // CHÚ Ý: view List Report còn chứa các value-help dialog (F4) của các field
    // filter dùng annotation ValueList (vd "Địa điểm đóng hàng" -> I_PlantStdVH,
    // "Số SO" -> I_SalesOrderStdVH, "Số lệnh xuất hàng (DO)" -> I_OutboundDelivery).
    // Các dialog này được dựng bằng SmartFilterBar + SmartTable riêng và gắn làm
    // dependent của control filter -> vẫn nằm trong view tree. Sau khi user đã mở
    // 1 trong các F4 đó, findAggregatedObjects(true) có thể trả về SmartTable của
    // value help TRƯỚC SmartTable dữ liệu chính, khiến export đọc nhầm entity
    // -> lỗi hoặc dữ liệu sai. Phải lọc đúng SmartTable bind vào MAIN_ENTITY_SET.
    function getRaw(oView) {
        var oAll = oView.findAggregatedObjects(true);

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
        if (!oSmartTable) { return null; }
        if (!oTable) { oTable = oSmartTable.getTable(); }
        if (!oBinding && oTable) {
            oBinding = oTable.getBinding("rows") || oTable.getBinding("items");
        }
        if (!oBinding) { return null; }

        // Gộp cả application filters (từ SmartFilterBar) lẫn control filters (vd
        // filter trên header cột) để export đúng những gì đang hiển thị.
        var aFilters = []
            .concat(oBinding.aApplicationFilters || [])
            .concat(oBinding.aFilters || []);

        return {
            model: oBinding.getModel(),
            filters: aFilters,
            sorters: oBinding.aSorters || [],
            totalLength: oBinding.getLength()
        };
    }


    //////////////////////////////////////////////////////////////////////////
    // Filter + sort của bảng → tham số JsonString của action ExportExcel
    // (ty_export_param trong zbp_ce_cont):
    // { filters: [{ name: "DIADIEMDONGHANG", range: [{ sign, option, low, high }] }],
    //   sort:    [{ name: "SO", descending: false }] }
    function buildExportParam(oRaw) {
        var oRanges = {};
        var aNames = [];
        oRaw.filters.forEach(function (oFilter) {
            collectFilter(oFilter, oRanges, aNames);
        });

        return {
            filters: aNames.map(function (sName) {
                return { name: sName, range: oRanges[sName] };
            }),
            sort: oRaw.sorters.map(function (oSorter) {
                return {
                    name: (oSorter.sPath || "").toUpperCase(),
                    descending: !!oSorter.bDescending
                };
            }).filter(function (oSort) {
                return !!oSort.name;
            })
        };
    }

    // Filter của bảng là cây lồng nhau (AND giữa các field, OR giữa các giá trị) → gom về
    // từng field, giống cách backend nhận filter khi query màn hình (get_as_ranges)
    function collectFilter(oFilter, oRanges, aNames) {
        if (!oFilter) { return; }
        var aSubFilters = oFilter.aFilters || (oFilter.getFilters && oFilter.getFilters());
        if (aSubFilters && aSubFilters.length) {
            aSubFilters.forEach(function (oSubFilter) {
                collectFilter(oSubFilter, oRanges, aNames);
            });
            return;
        }
        if (!oFilter.sPath) { return; }

        var oRange = toRange(oFilter);
        if (!oRange) { return; }

        var sName = oFilter.sPath.toUpperCase();
        if (!oRanges[sName]) {
            oRanges[sName] = [];
            aNames.push(sName);
        }
        oRanges[sName].push(oRange);
    }

    function toRange(oFilter) {
        var oOperator = FILTER_OPERATORS[oFilter.sOperator];
        if (!oOperator) { return null; }

        var sLow = toFilterValue(oFilter.oValue1);
        // Chỉ EQ / NE được phép để trống (điều kiện "<trống>" trên filter bar)
        if (!sLow && oOperator.option !== "EQ") { return null; }

        return {
            sign: oOperator.sign,
            option: oOperator.option,
            low: (oOperator.prefix || "") + sLow + (oOperator.suffix || ""),
            high: oOperator.option === "BT" ? toFilterValue(oFilter.oValue2) : ""
        };
    }

    // Ngày → YYYYMMDD. OData V2 có thể trả ngày dạng 00:00 UTC hoặc 00:00 giờ local
    // → cộng 12 tiếng rồi lấy theo UTC thì luôn ra đúng ngày user đã chọn.
    function toFilterValue(vValue) {
        if (vValue === null || vValue === undefined) { return ""; }
        if (vValue instanceof Date) {
            var oDate = new Date(vValue.getTime() + 12 * 3600 * 1000);
            return String(oDate.getUTCFullYear())
                + String(oDate.getUTCMonth() + 1).padStart(2, "0")
                + String(oDate.getUTCDate()).padStart(2, "0");
        }
        return String(vValue);
    }


    //////////////////////////////////////////////////////////////////////////
    // Kết quả action (complex type) → { MimeType, FileName, FileContent, FileExtension }
    function getExportFile(oData) {
        if (!oData) { return null; }
        if (oData[EXPORT_ACTION]) { return oData[EXPORT_ACTION]; }
        if (oData.results && oData.results.length) { return oData.results[0]; }
        return oData;
    }

    function decodeBase64(sBase64) {
        var sValue = (sBase64 || "").replace(/_/g, "/").replace(/-/g, "+");
        var iPad = sValue.length % 4;
        if (iPad) {
            sValue += "=".repeat(4 - iPad);
        }
        var sBinary = atob(sValue);
        var aBytes = new Uint8Array(sBinary.length);
        for (var i = 0; i < sBinary.length; i++) {
            aBytes[i] = sBinary.charCodeAt(i);
        }
        return aBytes;
    }

    function downloadFile(oFile) {
        var sMimeType = oFile.MimeType || "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        var oBlob = new Blob([decodeBase64(oFile.FileContent)], { type: sMimeType });
        var sUrl = URL.createObjectURL(oBlob);
        var oLink = document.createElement("a");
        oLink.href = sUrl;
        oLink.download = (oFile.FileName || "TemKHDongCont") + "." + (oFile.FileExtension || "xlsx");
        document.body.appendChild(oLink);
        oLink.click();
        document.body.removeChild(oLink);
        setTimeout(function () { URL.revokeObjectURL(sUrl); }, 1000);
    }

    // Lỗi trả về từ backend (failed / reported của action) → message hiển thị cho user
    function getErrorMessage(oError) {
        var sText = oError && oError.responseText;
        if (sText) {
            try {
                var oParsed = JSON.parse(sText);
                var oErr = oParsed.error || {};
                var aDetails = (oErr.innererror && oErr.innererror.errordetails) || [];
                if (aDetails.length && aDetails[0].message) {
                    return aDetails[0].message;
                }
                if (oErr.message && oErr.message.value) {
                    return oErr.message.value;
                }
            } catch (e) { /* responseText không phải JSON */ }
        }
        return (oError && oError.message) || "Có lỗi xảy ra";
    }

});
