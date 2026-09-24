sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/ui/core/dnd/DragDropInfo"
], function (MessageToast, MessageBox, BusyDialog, DragDropInfo) {
    'use strict';

    // Entity set của bảng chính trên List Report (khớp manifest sap.ui.generic.app).
    var MAIN_ENTITY_SET = "zce_cont";

    var BATCH_SIZE = 1000;
    var CONCURRENCY = 4;

    // Chiều cao dòng Excel (pt): mặc định 1 dòng, và mỗi dòng chữ khi wrapText (font size 10).
    var DEFAULT_ROW_HEIGHT = 15;
    var LINE_HEIGHT = 13.5;

    var DEPT_NAME = "PHÒNG KD-XNK";

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
        { label: "Số Booking", field: "Booking", width: 12 },
        { label: "Thời gian cắt máng", field: "ThoiGianCatMang", width: 12 },
        { label: "Phương thức đóng hàng & phối thùng", field: "GhiChuGiaoHang", width: 42, wrap: true },
        { label: "Số SO", field: "SO", width: 12, numeric: true },
        { label: "Item", field: "SOItem", width: 8, numeric: true },
        { label: "SỐ KH", field: "SoKH", width: 14 },
        { label: "Mã hàng", field: "MaHang", width: 14 },
        { label: "TÊN TÚI", field: "TenHang", width: 14 },
        { label: "Số lượng trên lệnh xuất hàng", field: "SoLuongTrenLenhXuatHang", width: 16, quantity: true },
        { label: "Cont", field: "Cont", width: 10 },
        { label: "Địa điểm đóng hàng", field: "DiaDiemDongHangContName", width: 16 },
        { label: "Plant", field: "PlantName", width: 16 },
        { label: "Số lệnh xuất hàng (OD)", field: "SoLenhXuatHang", width: 14, numeric: true },
        { label: "OD item", field: "SoLenhXuatHangItem", width: 8, numeric: true },
        { label: "Số lượng chưa lên lệnh xuất hàng", field: "SoLuongChuaLenLenhXuatHang", width: 16, quantity: true },
        { label: "Kich thước túi", field: "KichThhuocTui", width: 12 },
        { label: "Loại màng", field: "LoaiMang", width: 12 },
        { label: "Loại manh", field: "LoaiManh", width: 12 },
        { label: "Trạng thái OD", field: "TrangThaiOD", width: 14 },
        { label: "Kế hoạch đóng cont", field: "KeHoachDongCont", width: 14 },
        { label: "Ghi chú khác", field: "GhiChuKhac", width: 20, wrap: true }
    ];

    // Các field dùng trong Excel (tiêu đề, hoặc cột trong COLUMNS) nhưng có thể
    // KHÔNG phải cột hiển thị trên SmartTable -> $select mà SmartTable tự sinh
    // (dùng trong getDownloadUrl, xem fetchAllData) sẽ không có field này, phải
    // tự ép thêm vào, tương tự cách ensureSortOrderSelected ép thêm SortOrder
    // cho binding của GridTable.
    var EXPORT_ONLY_SELECT_FIELDS = ["CompanyCodeName", "LoaiMang", "LoaiManh", "PlantName", "MaHang"];

    var FIRST_COL = 2;                                  // B
    var LAST_COL = FIRST_COL + COLUMNS.length - 1;       // S

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

        var oModel = oBinding.getModel();
        // getPath() có thể trả về path tương đối (vd khi bảng bind qua context của
        // SmartTable) -> phải resolve về path tuyệt đối thì model.read() mới đúng,
        // nếu không request sẽ sai URL và báo lỗi "HTTP request failed".
        var sPath = oModel.resolve(oBinding.getPath(), oBinding.getContext()) || oBinding.getPath();

        // Gộp cả application filters (từ SmartFilterBar) lẫn control filters (vd
        // search box trên toolbar) để export đúng những gì đang hiển thị.
        var aFilters = []
            .concat(oBinding.aApplicationFilters || [])
            .concat(oBinding.aFilters || []);

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
    // (getDownloadUrl -> đúng 100% với dữ liệu đang hiển thị trên bảng) rồi gửi
    // lại qua model.read(). Không tự dựng lại filter từ aApplicationFilters/aFilters
    // vì dễ lệch với filter thật của bảng (vd đã từng lấy nhầm object binding cũ,
    // hoặc control filter/application filter không được gộp đúng cách) -> export
    // sai dữ liệu so với những gì đang hiển thị trên màn hình (âm thầm, không báo lỗi).
    function fetchAllData(oRaw, oBusyDialog) {
        return new Promise(function (resolve, reject) {

            var sUrl = oRaw.binding.getDownloadUrl && oRaw.binding.getDownloadUrl("json");
            if (!sUrl) {
                reject(new Error("Không lấy được URL tải dữ liệu từ bảng (getDownloadUrl rỗng)"));
                return;
            }
            var oBaseParams = parseQueryOptions(sUrl);

            // SmartTable chỉ $select đúng những cột đang HIỂN THỊ trên bảng ->
            // các field chỉ dùng để in tiêu đề Excel (không phải cột trên bảng)
            // sẽ bị thiếu, phải ép thêm vào đây.
            if (oBaseParams.$select) {
                var aSelectFields = oBaseParams.$select.split(",");
                EXPORT_ONLY_SELECT_FIELDS.forEach(function (sField) {
                    if (aSelectFields.indexOf(sField) < 0) {
                        aSelectFields.push(sField);
                    }
                });
                oBaseParams.$select = aSelectFields.join(",");
            }

            // Nếu không parse được $filter (vd không có filter nào) thì fallback
            // dùng Filter object của binding.
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
                        sorters: bUseFilterObjects ? oRaw.sorters : undefined,
                        urlParameters: oUrlParams,
                        success: function (oData) {
                            res({ results: oData.results || [], count: oData.__count });
                        },
                        error: function (oErr) {
                            rej(oErr);
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

                function updateProgress(iLoaded) {
                    oBusyDialog.setText("Đang tải dữ liệu: " + Math.min(iLoaded, iTotal).toLocaleString("vi-VN")
                        + " / " + iTotal.toLocaleString("vi-VN") + " dòng");
                }
                updateProgress(aFirst.length);

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

                function runNext() {
                    if (bHasError) { return; }
                    if (iNextBatch >= iNumBatches) { return; }

                    var iBatchIdx = iNextBatch++;
                    readBatch(iBatchIdx * BATCH_SIZE, false).then(function (oData) {
                        if (bHasError) { return; }
                        aResults[iBatchIdx] = oData.results || [];
                        iCompleted++;
                        updateProgress(iCompleted * BATCH_SIZE);

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


    // OData V2 trả Edm.DateTime (vd field Ngay, kiểu abap.dats) dưới dạng object Date
    // JS -> so 2 giá trị bằng "===" luôn ra false dù cùng ngày (khác instance object).
    // Quy về giá trị nguyên thuỷ (timestamp) trước khi so sánh/lưu prevValue.
    function toComparable(v) {
        if (v instanceof Date) { return v.getTime(); }
        return v || "";
    }

    // Khoá nhóm để gộp ô: đã có SỐ CONT -> nhóm theo SỐ CONT; chưa có SỐ CONT nhưng
    // đã có OD -> nhóm theo OD; không có cả hai -> "" (dòng này không gộp với ai).
    function getMergeGroupKey(oItem) {
        if (oItem.SoCont) { return "C|" + oItem.SoCont; }
        if (oItem.SoLenhXuatHang) { return "O|" + oItem.SoLenhXuatHang; }
        return "";
    }

    // Ước lượng (thiên cao) chiều cao cần để hiển thị hết 1 ô wrapText trong cột rộng iColWidth.
    function estimateTextHeight(sText, iColWidth) {
        if (!sText) { return DEFAULT_ROW_HEIGHT; }
        var iCharsPerLine = Math.max(1, Math.floor(iColWidth * 1.2));
        var iLines = String(sText).split(/\r?\n/).reduce(function (iSum, sLine) {
            return iSum + Math.max(1, Math.ceil(sLine.length / iCharsPerLine));
        }, 0);
        return Math.max(DEFAULT_ROW_HEIGHT, iLines * LINE_HEIGHT + 3);
    }

    // Chiều cao 1 dòng nếu chỉ tính các ô wrapText KHÔNG bị gộp (sExcludeField là cột đã gộp).
    function ownRowHeight(oItem, sExcludeField) {
        return COLUMNS.reduce(function (iMax, oCol) {
            return (oCol.wrap && oCol.field !== sExcludeField)
                ? Math.max(iMax, estimateTextHeight(oItem[oCol.field], oCol.width))
                : iMax;
        }, DEFAULT_ROW_HEIGHT);
    }

    // Excel không tự giãn chiều cao dòng theo ô đã gộp -> với ô wrapText gộp nhiều dòng
    // (vd Phương thức đóng hàng & phối thùng) mà tổng chiều cao các dòng không đủ chứa
    // nội dung thì tăng chiều cao các dòng đó, tránh bị cắt chữ.
    function fitMergedRowHeights(ws, aBlocks, aData, iFirstDataRow) {
        aBlocks.forEach(function (oBlock) {
            var aOwn = [];
            var iOwnTotal = 0;
            for (var iRow = oBlock.startRow; iRow <= oBlock.endRow; iRow++) {
                var iOwn = ownRowHeight(aData[iRow - iFirstDataRow], oBlock.field);
                aOwn.push(iOwn);
                iOwnTotal += iOwn;
            }
            var iNeeded = estimateTextHeight(aData[oBlock.startRow - iFirstDataRow][oBlock.field], oBlock.width);
            if (iNeeded <= iOwnTotal) { return; }
            var iExtra = (iNeeded - iOwnTotal) / aOwn.length;
            aOwn.forEach(function (iRowHeight, k) {
                ws.getRow(oBlock.startRow + k).height = iRowHeight + iExtra;
            });
        });
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
            var sPlantName = (aData[0] && aData[0].DiaDiemDongHangContName) || "";

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

            // Gộp ô các dòng liên tiếp cùng "nhóm" (xem getMergeGroupKey): đã có SỐ CONT
            // thì nhóm theo SỐ CONT, chưa có SỐ CONT thì nhóm theo OD. Trong cùng nhóm,
            // cột nào có cùng giá trị (kể cả cùng để trống) thì gộp; khác nhóm thì luôn
            // tách riêng dù giá trị trùng nhau.
            // Riêng cột OD chỉ gộp khi chưa có SỐ CONT (đã có SỐ CONT thì không gộp OD).
            var MERGE_FIELDS = [
                "Ngay", "SoCont", "GioGoiContVeNM", "SoChi", "NgayTauChay", "Booking",
                "ThoiGianCatMang", "GhiChuGiaoHang", "Cont", "DiaDiemDongHangContName",
                "PlantName", "SoLenhXuatHang"
            ];
            var MERGE_WITHOUT_CONT_ONLY = ["SoLenhXuatHang"];
            var iFirstDataRow = iRow;
            var aWrapBlocks = [];
            var oMergeInfo = {};
            MERGE_FIELDS.forEach(function (sField) {
                var iColIdx = COLUMNS.findIndex(function (oCol) {
                    return oCol.field === sField;
                });
                oMergeInfo[sField] = {
                    field: sField,
                    col: FIRST_COL + iColIdx,
                    wrap: !!COLUMNS[iColIdx].wrap,
                    width: COLUMNS[iColIdx].width,
                    startRow: iRow,
                    prevValue: null
                };
            });

            // Chốt khối đang gộp của 1 cột: gộp ô từ startRow đến dòng liền trước iEndRow.
            function closeMergeBlock(oInfo, iEndRow) {
                if (iEndRow - oInfo.startRow <= 1) { return; }
                ws.mergeCells(oInfo.startRow, oInfo.col, iEndRow - 1, oInfo.col);
                if (oInfo.wrap) {
                    aWrapBlocks.push({
                        field: oInfo.field, width: oInfo.width,
                        startRow: oInfo.startRow, endRow: iEndRow - 1
                    });
                }
            }

            var sPrevGroupKey = "";
            for (r = 0; r < aData.length; r++) {
                item = aData[r];

                var sGroupKey = getMergeGroupKey(item);
                var bSameGroup = r > 0 && sGroupKey !== "" && sGroupKey === sPrevGroupKey;
                var bNoCont = sGroupKey.charAt(0) === "O";

                var oContinuation = {};
                MERGE_FIELDS.forEach(function (sField) {
                    var oInfo = oMergeInfo[sField];
                    var bIsContinuation = bSameGroup
                        && toComparable(item[sField]) === oInfo.prevValue
                        && (bNoCont || MERGE_WITHOUT_CONT_ONLY.indexOf(sField) < 0);
                    oContinuation[sField] = bIsContinuation;

                    if (!bIsContinuation) {
                        closeMergeBlock(oInfo, iRow);
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
                            vValue = Math.round(toNumber(vValue) * 1000) / 1000;
                            // Chỉ dùng format có phần thập phân khi giá trị thực sự có số lẻ,
                            // tránh 1 số ứng dụng hiển thị dư dấu chấm cuối với số nguyên (vd "500.")
                            cell.numFmt = (vValue % 1 !== 0) ? "#,##0.###" : "#,##0";
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
                    oMergeInfo[sField].prevValue = toComparable(item[sField]);
                });
                sPrevGroupKey = sGroupKey;
                iRow++;
            }

            MERGE_FIELDS.forEach(function (sField) {
                closeMergeBlock(oMergeInfo[sField], iRow);
            });
            fitMergedRowHeights(ws, aWrapBlocks, aData, iFirstDataRow);

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
