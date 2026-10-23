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

	return ControllerExtension.extend("zthungov4.ext.controller.ListReportExt", {

		_NS: "com.sap.gateway.srvd.zui_thung_mau.v0001.",

		override: {
			onInit: function () {
				// giữ nguyên hook mặc định
			},
			editFlow: {
				onAfterActionExecution: function (oEvent) {
					if (!oEvent) { return; }

					if (oEvent.indexOf("downloadTemplate") !== -1) {
						this.downloadTemplate();
					} else if (["chuyenViTri", "doThung", "daXuat"].some((sAction) => oEvent.indexOf(sAction) !== -1)) {
						// Các action này chạy theo cả số thùng/pallet nên phải load lại list để thấy các dòng khác cùng thùng
						this._refreshListReport();
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
					script.src = sap.ui.require.toUrl("zthungov4/libs/exceljs.min.js");
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

		// ===== Template upload thùng mẫu ==========================================
		// Thứ tự cột phải khớp ty_file_upload ở backend (dòng 1 header, dòng 2 hướng dẫn, dữ liệu từ dòng 3)
		downloadTemplate: function () {
			const columns = [
				{ header: "Type", key: "Type", width: 16 },
				{ header: "Số KHSX", key: "SoKhsx", width: 20 },
				{ header: "Số thùng/Pallet", key: "SoThung", width: 24 },
				{ header: "Material (Mã hàng)", key: "Material", width: 22 },
				{ header: "Batch", key: "Batch", width: 16 },
				{ header: "Số lượng (Viên)", key: "Quantity", width: 18 },
				{ header: "Vị trí (Storage Location)", key: "StorageLocation", width: 24 },
				{ header: "Khách hàng", key: "Customer", width: 14 },
				{ header: "Ngày nhập kho", key: "NgayNhapKho", width: 18 },
				{ header: "Tem", key: "Tem", width: 18 },
				{ header: "Khối lượng (kg)", key: "KhoiLuong", width: 18 }
			];

			const hintRow = {
				Type: "I = Thêm mới\nM = Chỉnh sửa",
				SoKhsx: "SO/SO Item\nVD: 10001234/10",
				SoThung: "PAYYXXXX\n2 ký tự đầu: loại thùng\nYY: năm đóng thùng\nXXXX: số thứ tự\nVD: PA260001",
				Material: "Mã hàng",
				Batch: "Batch\nTối đa 10 ký tự",
				Quantity: "Số lượng (viên)\nVD: 100",
				StorageLocation: "Storage Location\nVD: 3002",
				Customer: "Khách hàng\n2 ký tự, VD: CA",
				NgayNhapKho: "DD/MM/YYYY\nVD: 08/10/2026",
				Tem: "CÓ TEM / KHÔNG TEM",
				KhoiLuong: "Khối lượng thùng mẫu (kg)\nVD: 8, 2000"
			};

			return this._downloadExcel(columns, hintRow, "Template_Upload thung mau.xlsx");
		},

		// ===== Upload =============================================================
		uploadExcelDialog: async function () {
			this._sActiveEntitySet = "ManageFile";
			this._sActiveAction = "uploadExcel";
			await this._openUploadDialog();
		},

		// ===== Shared upload dialog logic =========================================
		async _openUploadDialog() {
			if (!this._dlg) {
				this._dlg = await this._api().loadFragment({
					id: "idFileUploadDialog",
					name: "zthungov4.ext.fragment.filedialog",
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