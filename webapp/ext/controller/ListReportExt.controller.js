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

	return ControllerExtension.extend("zmassprov4.ext.controller.ListReportExt", {

		_NS: "com.sap.gateway.srvd.zui_m_mass_pr.v0001.",

		override: {
			onInit: function () {
				// giữ nguyên hook mặc định
			},
			editFlow: {
				onAfterActionExecution: function (oEvent) {
					if (!oEvent) { return; }

					if (oEvent.indexOf("downloadTemplatePR1") !== -1) {
						this.downloadTemplatePR1();
					} else if (oEvent.indexOf("downloadTemplatePR2") !== -1) {
						this.downloadTemplatePR2();
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
					script.src = sap.ui.require.toUrl("zmassprov4/libs/exceljs.min.js");
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

		// Hint row style KHÔNG phân nhóm (dùng cho các template không cần phân biệt Header/Item API)
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

		// Hint row style CÓ phân nhóm màu: Header API (cam đậm) vs Item API (vàng nhạt)
		_styleHintRowGrouped(row, columns, headerFieldKeys) {
			row.eachCell((cell, colNumber) => {
				const sKey = columns[colNumber - 1]?.key;
				const bIsHeaderField = headerFieldKeys.includes(sKey);

				cell.fill = {
					type: "pattern",
					pattern: "solid",
					fgColor: { argb: bIsHeaderField ? "FFF4B183" : "FFFFF2CC" }
				};
				cell.font = {
					name: "Calibri",
					size: 10,
					italic: true,
					bold: bIsHeaderField,
					color: { argb: "FF7F6000" }
				};
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

		async _downloadExcel(columns, hintRowData, fileName, headerFieldKeys) {
			await this._ensureExcelJS();

			const workbook = new ExcelJS.Workbook();
			const sheet = workbook.addWorksheet("Sheet1");

			sheet.columns = columns;
			sheet.addRow(hintRowData);

			this._styleHeaderRow(sheet.getRow(1));

			if (Array.isArray(headerFieldKeys) && headerFieldKeys.length) {
				this._styleHintRowGrouped(sheet.getRow(2), columns, headerFieldKeys);
			} else {
				this._styleHintRow(sheet.getRow(2));
			}

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

		// ===== Tab 1: Purchase Requisition (PR1) ==================================
		downloadTemplatePR1: function () {
			const columns = [
				{ header: "Type", key: "Type", width: 14 },
				{ header: "PurchaseRequisition", key: "PurchaseRequisition", width: 26 },
				{ header: "PurchaseRequisitionType", key: "PurchaseRequisitionType", width: 26 },
				{ header: "PurReqnDescription", key: "PurReqnDescription", width: 22 },
				{ header: "PurReqnHeaderNote", key: "PurReqnHeaderNote", width: 24 },
				{ header: "PurchaseRequisitionItem", key: "PurchaseRequisitionItem", width: 26 },
				{ header: "Material", key: "Material", width: 22 },
				{ header: "RequestedQuantity", key: "RequestedQuantity", width: 22 },
				{ header: "BaseUnit", key: "BaseUnit", width: 20 },
				{ header: "Plant", key: "Plant", width: 20 },
				{ header: "StorageLocation", key: "StorageLocation", width: 20 },
				{ header: "PurchaseRequisitionPrice", key: "PurchaseRequisitionPrice", width: 26 },
				{ header: "PurReqnPriceQuantity", key: "PurReqnPriceQuantity", width: 24 },
				{ header: "PurReqnItemCurrency", key: "PurReqnItemCurrency", width: 24 },
				{ header: "PurchasingGroup", key: "PurchasingGroup", width: 20 },
				{ header: "DeliveryDate", key: "DeliveryDate", width: 24 }
			];

			const hintRow = {
				Type: "I = Tạo mới\nM = Thay đổi",
				PurchaseRequisition: "Nếu tạo mới thì điền ký tự bất kỳ để hệ thống tự sinh PR\nNếu có nhiều item thì điền các dòng giống nhau",
				PurchaseRequisitionType: "Điền PR type\nNếu có nhiều Item thì điền các dòng giống nhau",
				PurReqnDescription: "Diễn giải PR\nNếu có nhiều Item thì điền các dòng giống nhau",
				PurReqnHeaderNote: "Note text PR\nNếu có nhiều Item thì điền các dòng giống nhau",
				PurchaseRequisitionItem: "Điền các PR item\nChỉ áp dụng cho Type I",
				Material: "Điền material\nChỉ áp dụng cho Type I",
				RequestedQuantity: "Số lượng\nChỉ áp dụng cho Type I",
				BaseUnit: "Đơn vị\nChỉ áp dụng cho Type I",
				Plant: "Plant xuất hàng\n6711,6712…\nChỉ áp dụng cho Type I",
				StorageLocation: "Kho xuất\n1000,2000…\nChỉ áp dụng cho Type I",
				PurchaseRequisitionPrice: "Đơn giá\nChỉ áp dụng cho Type I",
				PurReqnPriceQuantity: "Per ( /10; /100..)\nChỉ áp dụng cho Type I",
				PurReqnItemCurrency: "Loại tiền tệ ( VND, usd..)\nChỉ áp dụng cho Type I",
				PurchasingGroup: "Nhóm mua hàng\nChỉ áp dụng cho Type I",
				DeliveryDate: "Ngày giao hàng\nĐiền dạng dd.mm.yyyy\nChỉ áp dụng cho Type I"
			};

			// Field thuộc Header API (PR Header) — tô cam đậm để phân biệt với Item API
			const headerFieldKeys = [
				"Type",
				"PurchaseRequisition",
				"PurchaseRequisitionType",
				"PurReqnDescription",
				"PurReqnHeaderNote"
			];

			return this._downloadExcel(
				columns,
				hintRow,
				"Template_Mass Change PR.xlsx",
				headerFieldKeys
			);
		},

		// ===== Tab 2: Purchase Requisition Item (PR Item) =========================
		downloadTemplatePR2: function () {
			const columns = [
				{ header: "Type", key: "Type", width: 14 },
				{ header: "PurchaseRequisition", key: "PurchaseRequisition", width: 20 },
				{ header: "PurchaseRequisitionItem", key: "PurchaseRequisitionItem", width: 22 },
				{ header: "Material", key: "Material", width: 22 },
				{ header: "RequestedQuantity", key: "RequestedQuantity", width: 20 },
				{ header: "BaseUnit", key: "BaseUnit", width: 18 },
				{ header: "Plant", key: "Plant", width: 20 },
				{ header: "StorageLocation", key: "StorageLocation", width: 20 },
				{ header: "PurchaseRequisitionPrice", key: "PurchaseRequisitionPrice", width: 24 },
				{ header: "PurReqnPriceQuantity", key: "PurReqnPriceQuantity", width: 22 },
				{ header: "PurReqnItemCurrency", key: "PurReqnItemCurrency", width: 22 },
				{ header: "PurchasingGroup", key: "PurchasingGroup", width: 20 },
				{ header: "DeliveryDate", key: "DeliveryDate", width: 22 },
				{ header: "RequirementTracking", key: "RequirementTracking", width: 20 }
			];

			const hintRow = {
				Type: "I = POST\nM = PATCH\nD = delete",
				PurchaseRequisition: "Điền số PR",
				PurchaseRequisitionItem: "Điền số PR Item\nBắt buộc điền với type M, D",
				Material: "Điền material",
				RequestedQuantity: "Số lượng",
				BaseUnit: "Đơn vị",
				Plant: "Plant xuất hàng\n6711,6712…",
				StorageLocation: "Kho xuất\n1000,2000…",
				PurchaseRequisitionPrice: "Đơn giá",
				PurReqnPriceQuantity: "Per (/10;/100..)",
				PurReqnItemCurrency: "Loại tiền tệ ( VND, usd..)",
				PurchasingGroup: "Nhóm mua hàng",
				DeliveryDate: "Ngày giao hàng\nĐiền dạng dd.mm.yyyy",
				RequirementTracking: "Tracking Number"
			};

			// Field thuộc Header API
			const headerFieldKeys = [
				"Type",
				"PurchaseRequisition"
			];

			return this._downloadExcel(
				columns,
				hintRow,
				"Template_Mass Change PR Item.xlsx",
				headerFieldKeys
			);
		},

		// ===== Upload: Tab 1 (PR1) =============================================
		uploadExcelDialogPR1: async function () {
			this._sActiveEntitySet = "ManageFilePR1";
			this._sActiveAction = "uploadExcelPR1";
			await this._openUploadDialog();
		},

		// ===== Upload: Tab 2 (PR2) ================================================
		uploadExcelDialogPR2: async function () {
			this._sActiveEntitySet = "ManageFilePR2";
			this._sActiveAction = "uploadExcelPR2";
			await this._openUploadDialog();
		},

		// ===== Shared upload dialog logic =========================================
		async _openUploadDialog() {
			if (!this._dlg) {
				this._dlg = await this._api().loadFragment({
					id: "idFileUploadDialog",
					name: "zmassprov4.ext.fragment.filedialog",
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