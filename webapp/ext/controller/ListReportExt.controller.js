sap.ui.define([
	"sap/ui/core/mvc/ControllerExtension",
	"sap/m/MessageToast"
], function (
	ControllerExtension,
	MessageToast
) {
	"use strict";

	return ControllerExtension.extend("zmasspoov42.ext.controller.ListReportExt", {

		override: {
			onInit: function () {
				// giữ nguyên hook mặc định
			},
			editFlow: {
				onAfterActionExecution: function (oEvent) {
					// oEvent là string dạng: ".../ManageFilePOSubComp(...)/<namespace>.downloadTemplate(...)"
					// hoặc ".../ManageFilePOItem(...)/<namespace>.downloadTemplate(...)"
					if (!oEvent) { return; }

					if (oEvent.indexOf("downloadTemplateSubComp") !== -1) {
						this.downloadTemplateSubComp();
					} else if (oEvent.indexOf("downloadTemplateItem") !== -1) {
						this.downloadTemplateItem();
					}
				}
			}
		},

		// ===== Shared helper: load ExcelJS 1 lần =================================
		async _ensureExcelJS() {
			if (!window.ExcelJS) {
				await new Promise((resolve, reject) => {
					const script = document.createElement("script");
					script.src = sap.ui.require.toUrl("zmasspoov42/libs/exceljs.min.js");
					script.onload = resolve;
					script.onerror = reject;
					document.head.appendChild(script);
				});
			}
		},

		_styleHeaderRow(row) {
			row.eachCell((cell) => {
				cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF4472C4" } };
				cell.font = { name: "Calibri", size: 11, bold: true, color: { argb: "FFFFFFFF" } };
				cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
				cell.border = {
					top: { style: "thin", color: { argb: "FF000000" } },
					left: { style: "thin", color: { argb: "FF000000" } },
					bottom: { style: "thin", color: { argb: "FF000000" } },
					right: { style: "thin", color: { argb: "FF000000" } }
				};
			});
			row.height = 24;
		},

		_styleHintRow(row) {
			row.eachCell((cell) => {
				cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFF2CC" } };
				cell.font = { name: "Calibri", size: 10, italic: true, color: { argb: "FF7F6000" } };
				cell.alignment = { vertical: "middle", horizontal: "left", wrapText: true };
				cell.border = {
					top: { style: "thin", color: { argb: "FFBFBFBF" } },
					left: { style: "thin", color: { argb: "FFBFBFBF" } },
					bottom: { style: "thin", color: { argb: "FFBFBFBF" } },
					right: { style: "thin", color: { argb: "FFBFBFBF" } }
				};
			});
			row.height = 65;
		},

		async _downloadExcel(columns, hintRowData, fileName) {
			await this._ensureExcelJS();

			const workbook = new ExcelJS.Workbook();
			const sheet = workbook.addWorksheet("Template");

			sheet.columns = columns;
			sheet.addRow(hintRowData);

			this._styleHeaderRow(sheet.getRow(1));
			this._styleHintRow(sheet.getRow(2));

			sheet.views = [{ state: "frozen", ySplit: 2 }];
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
				a.download = fileName;
				document.body.appendChild(a);
				a.click();
				document.body.removeChild(a);
				URL.revokeObjectURL(url);

				MessageToast.show("Template downloaded successfully.");
			} catch (e) {
				MessageToast.show("Download failed: " + e);
			}
		},

		// ===== Tab 1: Purchase Order Subcontracting Component ====================
		downloadTemplateSubComp: function () {
			const columns = [
				{ header: "Type", key: "Type", width: 14 },
				{ header: "PurchaseOrder", key: "PurchaseOrder", width: 16 },
				{ header: "PurchaseOrderItem", key: "PurchaseOrderItem", width: 16 },
				{ header: "ScheduleLine", key: "ScheduleLine", width: 14 },
				{ header: "ReservationItem", key: "ReservationItem", width: 16 },
				{ header: "Material", key: "Material", width: 22 },
				{ header: "QuantityInEntryUnit", key: "QuantityInEntryUnit", width: 18 },
				{ header: "EntryUnit", key: "EntryUnit", width: 12 },
				{ header: "Plant", key: "Plant", width: 12 },
				{ header: "StorageLocation", key: "StorageLocation", width: 18 }
			];

			const hintRow = {
				Type: "I/D/M\nI: Insert\nM: Modify\nD: Delete",
				PurchaseOrder: "Điền PO (34000..)",
				PurchaseOrderItem: "Điền PO item (10,20,..)",
				ScheduleLine: "Mặc định điền 1",
				ReservationItem: "Điền stt item trong component",
				Material: "Điền material",
				QuantityInEntryUnit: "Số lượng",
				EntryUnit: "Đơn vị",
				Plant: "Plant xuất hàng",
				StorageLocation: "Kho xuất"
			};

			return this._downloadExcel(
				columns,
				hintRow,
				"Template_Mass Change PO Subcontracting Component.xlsx"
			);
		},

		// ===== Tab 2: Purchase Order Item =========================================
		downloadTemplateItem: function () {
			const columns = [
				{ header: "Type", key: "Type", width: 14 },
				{ header: "PurchaseOrder", key: "PurchaseOrder", width: 16 },
				{ header: "PurchaseOrderItem", key: "PurchaseOrderItem", width: 16 },
				{ header: "AccountAssignmentCategory", key: "AccountAssignmentCategory", width: 22 },
				{ header: "PurchaseOrderItemCategory", key: "PurchaseOrderItemCategory", width: 20 },
				{ header: "PurchaseRequisition", key: "PurchaseRequisition", width: 18 },
				{ header: "PurchaseRequisitionItem", key: "PurchaseRequisitionItem", width: 20 },
				{ header: "Material", key: "Material", width: 22 },
				{ header: "PurchaseOrderItemText", key: "PurchaseOrderItemText", width: 24 },
				{ header: "MaterialGroup", key: "MaterialGroup", width: 16 },
				{ header: "OrderQuantity", key: "OrderQuantity", width: 16 },
				{ header: "PurchaseOrderQuantityUnit", key: "PurchaseOrderQuantityUnit", width: 22 },
				{ header: "Plant", key: "Plant", width: 12 },
				{ header: "StorageLocation", key: "StorageLocation", width: 18 },
				{ header: "GlAccount", key: "GlAccount", width: 16 },
				{ header: "OrderId", key: "OrderId", width: 14 },
				{ header: "OrderInternalId", key: "OrderInternalId", width: 16 },
				{ header: "FunctionalArea", key: "FunctionalArea", width: 18 }
			];

			const hintRow = {
				Type: "I/D/M\nI: Insert\nM: Modify\nD: Delete",
				PurchaseOrder: "Điền PO (34000..)",
				PurchaseOrderItem: "Điền PO item (10,20,..)",
				AccountAssignmentCategory: "Điền Account Assignment Category",
				PurchaseOrderItemCategory: "Điền Item Category",
				PurchaseRequisition: "Điền PR nếu có",
				PurchaseRequisitionItem: "Điền PR item nếu có",
				Material: "Điền material",
				PurchaseOrderItemText: "Mô tả ngắn",
				MaterialGroup: "Nhóm vật tư",
				OrderQuantity: "Số lượng đặt hàng",
				PurchaseOrderQuantityUnit: "Đơn vị",
				Plant: "Plant",
				StorageLocation: "Kho",
				GlAccount: "Tài khoản G/L",
				OrderId: "Số Order (nếu account assignment liên quan)",
				OrderInternalId: "Routing number nội bộ",
				FunctionalArea: "Functional Area"
			};

			return this._downloadExcel(
				columns,
				hintRow,
				"Template_Mass Change PO Item.xlsx"
			);
		}

	});
});