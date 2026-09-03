sap.ui.define([
	"sap/ui/core/mvc/ControllerExtension",
	"sap/m/MessageToast",
	"sap/ui/core/Messaging",
	"sap/ui/core/message/Message",
	"sap/ui/core/message/MessageType",
	"sap/ui/core/Fragment"
], function (
	ControllerExtension,
	MessageToast,
	Messaging,
	Message,
	MessageType,
	Fragment
) {
	"use strict";

	return ControllerExtension.extend("zmasspoov42.ext.controller.ListReportExt", {

		_NS: "com.sap.gateway.srvd.zui_m_mass_po.v0001.",

		override: {
			onInit: function () {
				// giữ nguyên hook mặc định
			},
			editFlow: {
				onAfterActionExecution: function (oEvent) {
					if (!oEvent) { return; }

					if (oEvent.indexOf("downloadTemplateSubComp") !== -1) {
						this.downloadTemplateSubComp();
					} else if (oEvent.indexOf("downloadTemplateItem") !== -1) {
						this.downloadTemplateItem();
					}
				}
			}
		},

		// ===== Shortcuts ==========================================================
		_api() { return this.base.getExtensionAPI(); },
		_model() { return this._api().getModel(); },

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
			row.height = 90;
		},

		async _downloadExcel(columns, hintRowData, fileName) {
			await this._ensureExcelJS();

			const workbook = new ExcelJS.Workbook();
			const sheet = workbook.addWorksheet("Sheet1");

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
				{ header: "BillOfMaterialItemNumber", key: "BillOfMaterialItemNumber", width: 16 },
				{ header: "Material", key: "Material", width: 22 },
				{ header: "QuantityInEntryUnit", key: "QuantityInEntryUnit", width: 18 },
				{ header: "EntryUnit", key: "EntryUnit", width: 12 },
				{ header: "Plant", key: "Plant", width: 12 },
				{ header: "StorageLocation", key: "StorageLocation", width: 18 }
			];

			const hintRow = {
				Type: "I = POST\nM=PATCH\nD= delete",
				PurchaseOrder: "Điền PO ( 34000..)",
				PurchaseOrderItem: "Điền PO item ( 10.20.,..)",
				ScheduleLine: "Mặc định điền 1",
				BillOfMaterialItemNumber: "Điền stt item trong component ( 10,20,30..)\nĐiền trong Trường hợp chỉnh sửa item hoặc xóa item",
				Material: "Điền material",
				QuantityInEntryUnit: "Số lượng",
				EntryUnit: "Đơn vị",
				Plant: "Plant xuất hàng\n6711,6712…",
				StorageLocation: "Kho xuất\n1000,2000…"
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
				{ header: "NetPriceAmount", key: "NetPriceAmount", width: 20 },
				{ header: "DocumentCurrency", key: "DocumentCurrency", width: 22 },
				{ header: "PurchasingItemIsFreeOfCharge", key: "IsFreeOfCharge", width: 26 },
				{ header: "Plant", key: "Plant", width: 12 },
				{ header: "StorageLocation", key: "StorageLocation", width: 18 },
				{ header: "G/L Account", key: "GlAccount", width: 16 },
				{ header: "OrderID", key: "OrderId", width: 14 },
				{ header: "OrderInternalID", key: "OrderInternalId", width: 16 },
				{ header: "FunctionalArea", key: "FunctionalArea", width: 18 }
			];

			const hintRow = {
				Type: "I = POST\nM=PATCH\nD= delete",
				PurchaseOrder: "Điền PO ( 34000..)",
				PurchaseOrderItem: "Điền PO item ( 10.20.,..)",
				AccountAssignmentCategory: "Điền AccountAssignmentCategory\nđối với gia công may điền F \nGia công của KHSX để trống\nđối với item refer từ PR không cần điền",
				PurchaseOrderItemCategory: "Điền L nếu có component\ncòn lại để trống",
				PurchaseRequisition: "số PR refer",
				PurchaseRequisitionItem: "số PR item refer",
				Material: "Mã hàng\nđối với item refer từ PR không cần điền",
				PurchaseOrderItemText: "diễn giải item PO \nđối với item refer từ PR không cần điền",
				MaterialGroup: "nhóm mã hàng điền trong TH không có material \nvới group của gia công điền 210018\nđối với item refer từ PR không cần điền",
				OrderQuantity: "số lượng PO\nđối với item refer từ PR không cần điền",
				PurchaseOrderQuantityUnit: "Đơn vị",
				NetPriceAmount: "đơn giá\nđối với item refer từ PR không cần điền",
				DocumentCurrency: "Loại tiền tệ",
				IsFreeOfCharge: "Tích X với các dòng xuất NVL đi gia công",
				Plant: "Plant\nđối với item refer từ PR không cần điền",
				StorageLocation: "điền kho\nđối với item refer từ PR không cần điền",
				GlAccount: "đối với gia công may điền 1543002000\nđối với item refer từ PR không cần điền",
				OrderId: "điền lệnh sản xuất\nđối với item refer từ PR không cần điền",
				OrderInternalId: "điền công đoạn sản xuất, không có để trống\nđối với item refer từ PR không cần điền",
				FunctionalArea: "với gia công chọn YB20\nđối với item refer từ PR không cần điền"
			};

			return this._downloadExcel(
				columns,
				hintRow,
				"Template_Mass Change PO Item.xlsx"
			);
		},

		// ===== Upload: Tab 1 (SubComp) =============================================
		uploadExcelDialogSubComp: async function () {
			this._sActiveEntitySet = "ManageFilePOSubComp";
			this._sActiveAction = "uploadExcelSubComp";
			await this._openUploadDialog();
		},

		// ===== Upload: Tab 2 (Item) ================================================
		uploadExcelDialogItem: async function () {
			this._sActiveEntitySet = "ManageFilePOItem";
			this._sActiveAction = "uploadExcelItem";
			await this._openUploadDialog();
		},

		// ===== Shared upload dialog logic =========================================
		async _openUploadDialog() {
			if (!this._dlg) {
				this._dlg = await this._api().loadFragment({
					id: "idFileUploadDialog",
					name: "zmasspoov42.ext.fragment.filedialog",
					controller: this
				});
			}
			this._dlg.open();
		},

		onFileChange: async function (oEvent) {
			const f = (oEvent.getParameter("files") || [])[0];
			if (!f) return;

			this._file = {
				type: f.type || "",
				name: f.name || "",
				ext: (f.name || "").split(".").pop() || ""
			};

			await this._secured(() =>
				this._readAsDataUrl(f).then((url) => {
					const m = String(url).match(/,(.*)$/);
					this._file.content = m && m[1] ? m[1] : "";
				})
			);
		},

		onUploadPress: async function () {
			if (!this._file?.content) {
				MessageToast.show("Vui lòng chọn tệp.");
				return;
			}

			await this._secured(async () => {
				await this._invokeCollectionAction(this._sActiveEntitySet, this._sActiveAction, {
					mimeType: this._file.type,
					fileName: this._file.name,
					fileContent: this._file.content,
					fileExtension: this._file.ext
				});

				await this._refreshListReport();
				MessageToast.show("Tải lên thành công.");
				this._resetDialog();
			});
		},

		onCancelUpload: function () {
			this._resetDialog();
		},

		// ===== OData V4 — Bound to Collection Action ==============================
		_invokeCollectionAction: async function (sEntitySet, sActionName, params) {
			const path = `/${sEntitySet}/${this._NS}${sActionName}(...)`;
			const op = this._model().bindContext(path);

			if (params) {
				Object.entries(params).forEach(([k, v]) => {
					if (v !== undefined && v !== null && v !== "") {
						op.setParameter(k, v);
					}
				});
			}

			try {
				await op.invoke();
			} catch (e) {
				this._pushODataErrors(e);
				this._openFEMessages();
				throw e;
			}

			const ctx = op.getBoundContext?.();
			return ctx?.getObject?.() || {};
		},

		_secured: function (fn) {
			return this._api().getEditFlow().securedExecution(fn, { busy: { set: true } });
		},

		_refreshListReport: async function () {
			const api = this._api();
			if (typeof api.refresh === "function") {
				await api.refresh();
				return;
			}
			if (this._model()?.refresh) {
				await this._model().refresh();
			}
		},

		_resetDialog: function () {
			try {
				const fu = Fragment.byId("idFileUploadDialog", "idFileUpload");
				fu?.clear?.();
			} catch (e) { /* no-op */ }
			this._file = null;
			if (this._dlg) {
				this._dlg.close?.();
				this._dlg.destroy?.();
				this._dlg = null;
			}
		},

		_openFEMessages: function () {
			const h = this._api().getEditFlow?.().getMessageHandler?.();
			h?.showMessages?.();
		},

		_pushODataErrors: function (err) {
			const root = err?.error || err?.cause?.error || {};
			const bag = [];
			const rootMsg = root?.message || err?.message;

			if (typeof rootMsg === "string" && rootMsg.trim()) {
				bag.push(new Message({
					message: rootMsg,
					type: MessageType.Error,
					persistent: true,
					code: root?.code
				}));
			}

			if (Array.isArray(root?.details)) {
				root.details.forEach((d) => {
					if (d?.message) {
						bag.push(new Message({
							message: d.message,
							type: MessageType.Error,
							persistent: true,
							code: d.code,
							target: d.target || ""
						}));
					}
				});
			}

			if (bag.length) {
				if (Messaging?.addMessages) {
					Messaging.addMessages(bag);
				} else {
					sap.ui.getCore().getMessageManager?.()?.addMessages?.(bag);
				}
			}
		},

		_readAsDataUrl: function (file) {
			return new Promise((resolve, reject) => {
				try {
					const r = new FileReader();
					r.onload = (e) => resolve(e?.target?.result || "");
					r.onerror = reject;
					r.readAsDataURL(file);
				} catch (e) { reject(e); }
			});
		}

	});
});