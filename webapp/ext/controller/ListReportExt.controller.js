sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (MessageToast, MessageBox) {
    'use strict';

    function _getTableData(oView) {
        var aAllControls = oView.findAggregatedObjects(true);
        var oSmartTable = aAllControls.filter(function (o) {
            return o.getMetadata().getName() === "sap.ui.comp.smarttable.SmartTable";
        })[0];

        console.log("SmartTable found:", oSmartTable ? oSmartTable.getId() : "NOT FOUND");

        if (!oSmartTable) return [];

        var oTable = oSmartTable.getTable();
        console.log("Table:", oTable ? oTable.getId() : "NOT FOUND");

        var oBinding = oTable.getBinding("rows");
        console.log("Binding length:", oBinding ? oBinding.getLength() : "NO BINDING");

        if (!oBinding) return [];

        var iLength = oBinding.getLength();
        var aContexts = oBinding.getContexts(0, iLength);
        console.log("Contexts:", aContexts.length);
        console.log("Sample:", aContexts[0] ? JSON.stringify(aContexts[0].getObject()) : "empty");

        return aContexts.map(function (oCtx) { return oCtx.getObject(); });
    }

    function _buildExcel(aData, lv_from, lv_to) {
        var workbook = new ExcelJS.Workbook();
        var ws = workbook.addWorksheet("Sheet1");

        var BORDER = {
            top: { style: "thin" },
            left: { style: "thin" },
            bottom: { style: "thin" },
            right: { style: "thin" }
        };
        var HEADER_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "" } };
        var GROUP1_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFA3CDF4" } }; //Thông tin đơn hàng
        var GROUP2_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFE2EFDA" } }; //Phiếu yêu cầu xuất kho
        var GROUP3_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFE2FA" } }; //Chứng từ xuất kho
        var GROUP4_FILL = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF9CB9C" } }; //Thông tin xuất hoá đơn
        var BOLD_CENTER = { bold: true };
        var CENTER = { horizontal: "center", vertical: "middle", wrapText: true };

        // ── Row 1: Tiêu đề
        ws.mergeCells("A1:V1");
        var c1 = ws.getCell("A1");
        c1.value = "BÁO CÁO QUẢN LÝ ĐƠN HÀNG BÁN";
        c1.font = { bold: true, size: 14 };
        c1.alignment = { horizontal: "center", vertical: "middle" };
        ws.getRow(1).height = 33;

        // ── Row 2: Group headers
        // Thông tin đơn hàng: A-O (cột 1-15)
        for (var i = 1; i <= 15; i++) {
            ws.getCell(2, i).fill = GROUP1_FILL;
            ws.getCell(2, i).border = BORDER;
        }
        ws.mergeCells("A2:O2");
        ws.getCell("A2").value = "Thông tin đơn hàng";
        ws.getCell("A2").font = BOLD_CENTER;
        ws.getCell("A2").alignment = CENTER;

        // Phiếu yêu cầu xuất kho: P-V (cột 16-22)
        for (var i = 16; i <= 22; i++) {
            ws.getCell(2, i).fill = GROUP2_FILL;
            ws.getCell(2, i).border = BORDER;
        }
        ws.mergeCells("P2:V2");
        ws.getCell("P2").value = "Phiếu yêu cầu xuất kho";
        ws.getCell("P2").font = BOLD_CENTER;
        ws.getCell("P2").alignment = CENTER;

        // Chứng từ xuất kho: W-Z (cột 23-26)
        for (var i = 23; i <= 26; i++) {
            ws.getCell(2, i).fill = GROUP3_FILL;
            ws.getCell(2, i).border = BORDER;
        }
        ws.mergeCells("W2:Z2");
        ws.getCell("W2").value = "Chứng từ xuất kho";
        ws.getCell("W2").font = BOLD_CENTER;
        ws.getCell("W2").alignment = CENTER;

        // Thông tin xuất hoá đơn: AA-AG (cột 27-33)
        for (var i = 27; i <= 33; i++) {
            ws.getCell(2, i).fill = GROUP4_FILL;
            ws.getCell(2, i).border = BORDER;
        }
        ws.mergeCells("AA2:AG2");
        ws.getCell("AA2").value = "Thông tin xuất hoá đơn";
        ws.getCell("AA2").font = BOLD_CENTER;
        ws.getCell("AA2").alignment = CENTER;

        ws.getRow(2).height = 33;

        // ── Row 3: Column headers
        var headers = [
            //Thông tin đơn hàng
            "Sales Organization",       // A
            "Distribution Channel",     // B  
            "Division",                 // C  
            "Sold-to-party",            // D
            "Ship-to-party",            // E
            "Bill-to-party",            // F
            "Payer",                    // G
            "Payer Name",               // H
            "Payer Address",            // I
            "Document Date",            // J
            "Customer reference",       // K
            "Sales Order",              // L
            "Sales Order Item",         // M
            "Overall Status",           // N
            "Rejection Reason",         // O

            //Phiếu yêu cầu xuất kho
            "Planned Goods Movement Date",  // P
            "Outbound Delivery",            // Q
            "Outbound Delivery Item",       // R
            "Material",                     // S
            "Material Short Text",          // T
            "Material Long Text",           // U
            "Quantity",                     // V

            //Chứng từ xuất kho
            "Goods Receipt Date",    // W
            "Material Document",     // X
            "Plant",                 // Y
            "Storage Location",      // Z

            //Thông tin xuất hoá đơn
            "Billing Date",             // AA
            "Billing Document",         // AB
            "Journal Entry",            // AC
            "Reference",                // AD
            "Commercial Invoice",       // AE
            "Số tờ khai xuất khẩu",     // AF
            "Số hợp đồng ủy thác XK"    // AG
        ];

        var headerRow = ws.addRow(headers);
        headerRow.height = 33;
        headerRow.eachCell(function (cell) {
            cell.font = { bold: true };
            cell.border = BORDER;
            cell.alignment = CENTER;
            cell.fill = HEADER_FILL;
        });

        // ── Data rows
        aData.forEach(function (item) {
            var row = ws.addRow([
                //Thông tin đơn hàng
                item.salesOrganization,
                item.distributionChannel,
                item.division,
                item.soldToParty ? `${item.soldToParty}(${item.searchTerm1 || ""})`.trim() : "",        // Gộp SoldToParty và tên người mua
                item.shipToParty ? `${item.shipToParty}(${item.shipToPartyName || ""})`.trim() : "",    // Gộp ShipToParty và tên người nhận
                item.billToParty ? `${item.billToParty}(${item.billToPartyName || ""})`.trim() : "",    // Gộp BillToParty và tên người thanh toán
                item.payer,
                item.payerName,
                item.payerAddress,
                item.documentDate,
                item.customerReference,
                item.salesOrder,
                item.salesOrderItem,
                item.sDProcessStatus ? `${item.sDProcessStatus}(${item.sDProcessStatusDesc || ""})`.trim() : "",                    // Overall Status
                item.salesDocumentRjcnReason ? `${item.salesDocumentRjcnReason}(${item.salesDocumentRjcnReasonName || ""})`.trim() : "",    // Rejection Reason

                //Phiếu yêu cầu xuất kho
                item.plannedGoodsMovementDate,
                item.outboundDelivery,
                item.outboundDeliveryItem,
                item.material,
                item.productName,           // Material Short Text
                item.materialLongText,      // Material Long Text
                item.quantity ? parseFloat(item.quantity) : "",

                //Chứng từ xuất kho
                item.goodsReceiptDate,
                item.materialDocument,
                item.plant,
                item.storageLocation,

                //Thông tin xuất hoá đơn
                item.billingDate,
                item.billingDocument,
                item.journalEntry,
                item.reference,
                item.commercialInvoice,
                item.soToKhaiXK,            // Số tờ khai xuất khẩu
                item.soHopDongUyThacXK      // Số hợp đồng ủy thác XK
            ]);
            for (var c = 1; c <= 33; c++) {
                row.getCell(c).border = BORDER;
            }
            row.getCell(22).numFmt = "#,##0";
        });

        // ── Column widths
        ws.columns = [
            //Thông tin đơn hàng
            { width: 14 },  // A - Sales Organization
            { width: 14 },  // B - Distribution Channel
            { width: 14 },  // C - Division
            { width: 34 },  // D - Sold To Party
            { width: 34 },  // E - Ship To Party
            { width: 34 },  // F - Bill To Party
            { width: 16 },  // G - Payer
            { width: 34 },  // H - Payer Name
            { width: 34 },  // I - Payer Address
            { width: 14 },  // J - Document Date
            { width: 20 },  // K - Customer reference
            { width: 14 },  // L - Sales Order
            { width: 16 },  // M - Sales Order Item
            { width: 26 },  // N - Overall Status
            { width: 26 },  // O - Rejection Reason

            //Phiếu yêu cầu xuất kho
            { width: 18 },  // P - Planned Goods Movement Date
            { width: 20 },  // Q - Outbound Delivery
            { width: 14 },  // R - Outbound Delivery Item
            { width: 20 },  // S - Material
            { width: 34 },  // T - Material Short Text
            { width: 44 },  // U - Material Long Text
            { width: 14 },  // V - Quantity

            //Chứng từ xuất kho
            { width: 20 },  // Y - Goods Receipt Date
            { width: 20 },  // Z - Material Document
            { width: 14 },  // W - Plant
            { width: 14 },  // X - Storage Location

            //Thông tin xuất hoá đơn
            { width: 14 },  // AB - Billing Date
            { width: 18 },  // AA - Billing Document
            { width: 16 },  // AC - Journal Entry
            { width: 18 },  // AD - Reference
            { width: 26 },  // AE - Commercial Invoice
            { width: 26 },  // AF - Số tờ khai xuất khẩu
            { width: 26 },  // AG - Số hợp đồng ủy thác XK
        ];

        // ── Apply Times New Roman cho toàn bộ worksheet (giữ nguyên bold/size đã set)
        ws.eachRow({ includeEmpty: false }, function (row) {
            row.eachCell({ includeEmpty: false }, function (cell) {
                cell.font = Object.assign({}, cell.font, { name: "Times New Roman" });
            });
        });

        // ── Download
        workbook.xlsx.writeBuffer().then(function (buffer) {
            var blob = new Blob([buffer], {
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            });
            var url = URL.createObjectURL(blob);
            var link = document.createElement("a");
            link.href = url;
            link.download = "BaoCaoChiTietLuongChungTu_"
                + new Date().toLocaleDateString("vi-VN").replace(/\//g, "-")
                + ".xlsx";
            link.click();
            URL.revokeObjectURL(url);
            MessageToast.show("Export thành công!");
        });
    }

    function _doExport(oView) {
        var aData = _getTableData(oView);
        if (!aData.length) {
            MessageBox.error("Không có dữ liệu để export");
            return;
        }

        var lv_month = "";
        var lv_year = "";
        var oSmartFilterBar = oView.byId("listReportFilter");
        if (oSmartFilterBar) {
            var oFilterData = oSmartFilterBar.getFilterData();
            lv_month = oFilterData.FiscalPeriod || "";
            lv_year = oFilterData.FiscalYear || "";
        }

        _buildExcel(aData, lv_month, lv_year);
    }

    return {
        onAfterRendering: function () {
            var oButton = this.getView().byId("exportExcelButton");
            if (oButton) {
                oButton.setIcon("sap-icon://excel-attachment");
            }
        },

        exportExcel: function () {
            var oView = this.getView();

            if (window.ExcelJS) {
                _doExport(oView);
                return;
            }

            var script = document.createElement("script");
            script.src = sap.ui.require.toUrl("zrpsalesmgt/libs/exceljs.min.js");
            script.onload = function () { _doExport(oView); };
            script.onerror = function () {
                MessageBox.error("Không load được ExcelJS library");
            };
            document.head.appendChild(script);
        }
    };
});