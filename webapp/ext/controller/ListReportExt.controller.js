sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog"
], function (MessageToast, MessageBox, BusyDialog) {
    'use strict';

    var BATCH_SIZE  = 1000;   // 261k / 10k ≈ 27 batches
    var CONCURRENCY = 4;       // 4 request song song

    // ────────────────────────────────────────────────────────
    // Tìm SmartTable + binding
    // ────────────────────────────────────────────────────────
    function _getBindingInfo(oView) {
        var aAll = oView.findAggregatedObjects(true);
        var oSmartTable = aAll.filter(function (o) {
            return o.getMetadata().getName() === "sap.ui.comp.smarttable.SmartTable";
        })[0];
        if (!oSmartTable) { return null; }

        var oTable   = oSmartTable.getTable();
        var oBinding = oTable.getBinding("rows") || oTable.getBinding("items");
        if (!oBinding) { return null; }

        return {
            smartTable: oSmartTable,
            table:      oTable,
            binding:    oBinding,
            model:      oBinding.getModel(),
            path:       oBinding.getPath(),
            filters:    oBinding.aApplicationFilters || [],
            sorters:    oBinding.aSorters || [],
            total:      oBinding.getLength()
        };
    }

    // ────────────────────────────────────────────────────────
    // Batch fetch ALL data qua $skip / $top, có concurrency limit
    // ────────────────────────────────────────────────────────
    function _fetchAllBatched(oInfo, oBusyDialog) {
        return new Promise(function (resolve, reject) {
            var iTotal = oInfo.total;
            if (iTotal === 0) { resolve([]); return; }

            var iNumBatches = Math.ceil(iTotal / BATCH_SIZE);
            var aResults    = new Array(iNumBatches);
            var iNextIdx    = 0;
            var iCompleted  = 0;
            var bHasError   = false;

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
                        "$top":  BATCH_SIZE
                    },
                    success: function (oData) {
                        if (bHasError) { return; }
                        aResults[iBatchIdx] = oData.results || [];
                        iCompleted++;
                        updateProgress();

                        if (iNextIdx < iNumBatches) {
                            runBatch(iNextIdx++);
                        } else if (iCompleted === iNumBatches) {
                            // Flatten
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

    // ────────────────────────────────────────────────────────
    // Build Excel (giữ nguyên format cũ của bạn)
    // ────────────────────────────────────────────────────────
    function _buildExcel(aData) {
        return new Promise(function (resolve, reject) {
            var workbook = new ExcelJS.Workbook();
            var ws = workbook.addWorksheet("Sheet1");

            var BORDER = {
                top:    { style: "thin" },
                left:   { style: "thin" },
                bottom: { style: "thin" },
                right:  { style: "thin" }
            };
            var HEADER_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF2F2F2" } };
            var GROUP1_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFA3CDF4" } };
            var GROUP2_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFE2EFDA" } };
            var GROUP3_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFE2FA" } };
            var GROUP4_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF9CB9C" } };
            var BOLD_CENTER = { bold: true };
            var CENTER      = { horizontal: "center", vertical: "middle", wrapText: true };

            // Row 1: tiêu đề
            ws.mergeCells("A1:AG1");
            var c1 = ws.getCell("A1");
            c1.value     = "BÁO CÁO QUẢN LÝ ĐƠN HÀNG BÁN";
            c1.font      = { bold: true, size: 14 };
            c1.alignment = { horizontal: "center", vertical: "middle" };
            ws.getRow(1).height = 33;

            // Row 2: group headers
            var i;
            for (i = 1; i <= 15; i++) { ws.getCell(2, i).fill = GROUP1_FILL; ws.getCell(2, i).border = BORDER; }
            ws.mergeCells("A2:O2");
            ws.getCell("A2").value = "Thông tin đơn hàng";
            ws.getCell("A2").font  = BOLD_CENTER;
            ws.getCell("A2").alignment = CENTER;

            for (i = 16; i <= 22; i++) { ws.getCell(2, i).fill = GROUP2_FILL; ws.getCell(2, i).border = BORDER; }
            ws.mergeCells("P2:V2");
            ws.getCell("P2").value = "Phiếu yêu cầu xuất kho";
            ws.getCell("P2").font  = BOLD_CENTER;
            ws.getCell("P2").alignment = CENTER;

            for (i = 23; i <= 26; i++) { ws.getCell(2, i).fill = GROUP3_FILL; ws.getCell(2, i).border = BORDER; }
            ws.mergeCells("W2:Z2");
            ws.getCell("W2").value = "Chứng từ xuất kho";
            ws.getCell("W2").font  = BOLD_CENTER;
            ws.getCell("W2").alignment = CENTER;

            for (i = 27; i <= 33; i++) { ws.getCell(2, i).fill = GROUP4_FILL; ws.getCell(2, i).border = BORDER; }
            ws.mergeCells("AA2:AG2");
            ws.getCell("AA2").value = "Thông tin xuất hoá đơn";
            ws.getCell("AA2").font  = BOLD_CENTER;
            ws.getCell("AA2").alignment = CENTER;

            ws.getRow(2).height = 33;

            // Row 3: column headers
            var headers = [
                "Sales Organization", "Distribution Channel", "Division",
                "Sold-to-party", "Ship-to-party", "Bill-to-party", "Payer",
                "Payer Name", "Payer Address", "Document Date", "Customer reference",
                "Sales Order", "Sales Order Item", "Overall Status", "Rejection Reason",
                "Planned Goods Movement Date", "Outbound Delivery", "Outbound Delivery Item",
                "Material", "Material Short Text", "Material Long Text", "Quantity",
                "Goods Receipt Date", "Material Document", "Plant", "Storage Location",
                "Billing Date", "Billing Document", "Journal Entry", "Reference",
                "Commercial Invoice", "Số tờ khai xuất khẩu", "Số hợp đồng ủy thác XK"
            ];

            var headerRow = ws.addRow(headers);
            headerRow.height = 33;
            headerRow.eachCell(function (cell) {
                cell.font      = { bold: true };
                cell.border    = BORDER;
                cell.alignment = CENTER;
                cell.fill      = HEADER_FILL;
            });

            // Data rows — dùng vòng for thường (nhanh hơn forEach với data lớn)
            for (var idx = 0; idx < aData.length; idx++) {
                var item = aData[idx];
                var row  = ws.addRow([
                    item.salesOrganization,
                    item.distributionChannel,
                    item.division,
                    item.soldToParty ? (item.soldToParty + "(" + (item.searchTerm1 || "") + ")") : "",
                    item.shipToParty ? (item.shipToParty + "(" + (item.shipToPartyName || "") + ")") : "",
                    item.billToParty ? (item.billToParty + "(" + (item.billToPartyName || "") + ")") : "",
                    item.payer,
                    item.payerName,
                    item.payerAddress,
                    item.documentDate,
                    item.customerReference,
                    item.salesOrder,
                    item.salesOrderItem,
                    item.sDProcessStatus ? (item.sDProcessStatus + "(" + (item.sDProcessStatusDesc || "") + ")") : "",
                    item.salesDocumentRjcnReason ? (item.salesDocumentRjcnReason + "(" + (item.salesDocumentRjcnReasonName || "") + ")") : "",
                    item.plannedGoodsMovementDate,
                    item.outboundDelivery,
                    item.outboundDeliveryItem,
                    item.material,
                    item.productName,
                    item.materialLongText,
                    item.quantity ? parseFloat(item.quantity) : "",
                    item.goodsReceiptDate,
                    item.materialDocument,
                    item.plant,
                    item.storageLocation,
                    item.billingDate,
                    item.billingDocument,
                    item.journalEntry,
                    item.reference,
                    item.commercialInvoice,
                    item.soToKhaiXK,
                    item.soHopDongUyThacXK
                ]);
                for (var c = 1; c <= 33; c++) {
                    row.getCell(c).border = BORDER;
                }
                row.getCell(22).numFmt = "#,##0";
            }

            // Column widths
            ws.columns = [
                { width: 14 }, { width: 14 }, { width: 14 }, { width: 34 },
                { width: 34 }, { width: 34 }, { width: 16 }, { width: 34 },
                { width: 34 }, { width: 14 }, { width: 20 }, { width: 14 },
                { width: 16 }, { width: 26 }, { width: 26 }, { width: 18 },
                { width: 20 }, { width: 14 }, { width: 20 }, { width: 34 },
                { width: 44 }, { width: 14 }, { width: 20 }, { width: 20 },
                { width: 14 }, { width: 14 }, { width: 14 }, { width: 18 },
                { width: 16 }, { width: 18 }, { width: 26 }, { width: 26 },
                { width: 26 }
            ];

            // Apply Times New Roman cho toàn worksheet
            ws.eachRow({ includeEmpty: false }, function (row) {
                row.eachCell({ includeEmpty: false }, function (cell) {
                    cell.font = Object.assign({}, cell.font, { name: "Times New Roman" });
                });
            });

            // Write & download
            workbook.xlsx.writeBuffer().then(function (buffer) {
                var blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                var url  = URL.createObjectURL(blob);
                var link = document.createElement("a");
                link.href     = url;
                link.download = "BaoCaoQuanLyDonHangBan_"
                              + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
                              + ".xlsx";
                link.click();
                URL.revokeObjectURL(url);
                resolve();
            }).catch(reject);
        });
    }

    // ────────────────────────────────────────────────────────
    // Load ExcelJS lib (lazy)
    // ────────────────────────────────────────────────────────
    function _loadExcelJS() {
        if (window.ExcelJS) { return Promise.resolve(); }
        return new Promise(function (resolve, reject) {
            var script = document.createElement("script");
            script.src = sap.ui.require.toUrl("zrpsalesmgt/libs/exceljs.min.js");
            script.onload  = resolve;
            script.onerror = function () { reject(new Error("Không load được ExcelJS")); };
            document.head.appendChild(script);
        });
    }

    // ────────────────────────────────────────────────────────
    // Main flow
    // ────────────────────────────────────────────────────────
    function _doExport(oView) {
        var oInfo = _getBindingInfo(oView);
        if (!oInfo) {
            MessageBox.error("Không tìm thấy SmartTable hoặc binding");
            return;
        }
        if (oInfo.total === 0) {
            MessageBox.error("Không có dữ liệu để export");
            return;
        }

        var oBusy = new BusyDialog({
            title: "Đang xuất Excel",
            text:  "Đang chuẩn bị..."
        });
        oBusy.open();

        _loadExcelJS()
            .then(function () {
                return _fetchAllBatched(oInfo, oBusy);
            })
            .then(function (aData) {
                oBusy.setText("Đang tạo file Excel (" + aData.length.toLocaleString("vi-VN") + " dòng)...");
                return _buildExcel(aData);
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

    // ────────────────────────────────────────────────────────
    // Controller extension exports
    // ────────────────────────────────────────────────────────
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