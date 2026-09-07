sap.ui.define([
    "sap/m/MessageToast"
], function(MessageToast) {
    'use strict';

    return {
        /**
         * Generated event handler.
         *
         * @param oContext the context of the page on which the event was fired. `undefined` for list report page.
         * @param aSelectedContexts the selected contexts of the table rows.
         */
        DownloadTempate: async function(oContext, aSelectedContexts) {
            if (!window.ExcelJS) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement("script");
                    script.src = sap.ui.require.toUrl("zudbank/libs/exceljs.min.js");
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet("Template");

            // ===== Cấu trúc cột (5 cột) =====
            sheet.columns = [
                { key: "BankCountry", width: 16 },        // 1 Bank Country
                { key: "BankKey", width: 18 },            // 2 Bank Key
                { key: "BankName", width: 32 },           // 3 Bank Name
                { key: "BankBranch", width: 24 },         // 4 Bank Branch
                { key: "IsMarkedForDeletion", width: 22 } // 5 Is Marked For Deletion
            ];

            // ===== Row 1: Header =====
            const row1 = sheet.getRow(1);
            row1.getCell(1).value = "Bank Country";
            row1.getCell(2).value = "Bank Key";
            row1.getCell(3).value = "Bank Name";
            row1.getCell(4).value = "Bank Branch";
            row1.getCell(5).value = "Is Marked For Deletion";

            // ===== Style: header row (xanh) =====
            row1.eachCell({ includeEmpty: true }, (cell) => {
                cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF70AD47" } };
                cell.font = { name: "Calibri", size: 11, bold: true, color: { argb: "FFFFFFFF" } };
                cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
                cell.border = {
                    top: { style: "thin", color: { argb: "FF000000" } },
                    left: { style: "thin", color: { argb: "FF000000" } },
                    bottom: { style: "thin", color: { argb: "FF000000" } },
                    right: { style: "thin", color: { argb: "FF000000" } }
                };
            });
            row1.height = 22;

            sheet.views = [{ state: "frozen", ySplit: 1 }];
            sheet.autoFilter = {
                from: { row: 1, column: 1 },
                to: { row: 1, column: sheet.columns.length }
            };

            try {
                const buffer = await workbook.xlsx.writeBuffer();
                const blob = new Blob([buffer], {
                    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "Template_Bank.xlsx";
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);

                MessageToast.show("Template downloaded successfully.");
            } catch (e) {
                MessageToast.show("Download failed: " + e);
            }
        }
    };
});
