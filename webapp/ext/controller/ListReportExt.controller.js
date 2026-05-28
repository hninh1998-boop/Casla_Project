sap.ui.define([
	"sap/m/MessageToast",
	"sap/m/MessageBox",
	"sap/m/BusyDialog",
	"sap/m/PDFViewer",
	"sap/m/Dialog",
	"sap/m/Toolbar",
	"sap/m/ToolbarSpacer",
	"sap/m/Select",
	"sap/m/VBox",
	"sap/m/Button",
	"sap/m/Text",
	"sap/ui/core/Item",
	"sap/ui/core/HTML"
], function (
	MessageToast, MessageBox, BusyDialog,
	PDFViewer, Dialog, Toolbar, ToolbarSpacer, Select, VBox,
	Button, Text, Item, HTML
) {
	"use strict";

	return {

		/* ================================================================
		 *  HELPERS
		 * ================================================================ */

		_b64ToSources: function (b64, mime) {
			var s = (b64 || "").replace(/_/g, "/").replace(/-/g, "+");
			var pad = s.length % 4;
			if (pad) { s += "=".repeat(4 - pad); }
			var bin = atob(s);
			var u8 = new Uint8Array(bin.length);
			for (var i = 0; i < bin.length; i++) { u8[i] = bin.charCodeAt(i); }
			var type = mime || "application/pdf";
			var blob = new Blob([u8], { type: type });
			return {
				blob: blob,
				url: URL.createObjectURL(blob),
				data: "data:" + type + ";base64," + s
			};
		},

		_buildPdfIframeHtml: function (src) {
			var fit = "#page=1&zoom=page-fit";
			return "<iframe style='border:0;width:100%;height:100%;' " +
				"referrerpolicy='no-referrer' loading='eager' " +
				"src='" + src + fit + "'></iframe>";
		},

		_waitPdfLoaded: function (viewer, timeoutMs) {
			return new Promise(function (resolve, reject) {
				var tm;
				var done = function () {
					viewer.detachLoaded(onLoaded);
					viewer.detachError(onError);
					if (tm) { clearTimeout(tm); }
				};
				var onLoaded = function () { done(); resolve(); };
				var onError = function () { done(); reject(new Error("viewer error")); };
				viewer.attachLoaded(onLoaded);
				viewer.attachError(onError);
				tm = setTimeout(function () { done(); reject(new Error("viewer timeout")); }, timeoutMs || 900);
			});
		},

		/* ================================================================
		 *  LẤY SELECTED ROWS
		 *  Smart Template V2 + GridTable + MultiSelectionPlugin
		 *
		 *  Khi manifest có "selectAll": true, framework tự inject
		 *  MultiSelectionPlugin vào GridTable.
		 *  → Không được gọi table.getSelectedIndices() (sẽ throw error)
		 *  → Phải dùng plugin.getSelectedContexts() thay thế
		 * ================================================================ */

		_getSelectedRows: function () {
			var oView = this.getView();
			var oSmartTable = null;

			// Tìm SmartTable trong view
			var aCtrls = oView.findAggregatedObjects(true, function (c) {
				return c.isA && c.isA("sap.ui.comp.smarttable.SmartTable");
			});
			if (aCtrls.length) { oSmartTable = aCtrls[0]; }

			if (!oSmartTable) {
				MessageToast.show("Không tìm thấy bảng dữ liệu.");
				return [];
			}

			var oTable = oSmartTable.getTable ? oSmartTable.getTable() : oSmartTable;
			var aResult = [];

			// GridTable
			if (oTable.isA && oTable.isA("sap.ui.table.Table")) {
				// Check xem có Selection Plugin không
				var aPlugins = oTable.getPlugins ? oTable.getPlugins() : [];
				var oSelPlugin = null;
				for (var p = 0; p < aPlugins.length; p++) {
					if (aPlugins[p].getSelectedContexts) {
						oSelPlugin = aPlugins[p];
						break;
					}
				}

				if (oSelPlugin) {
					// CÓ plugin → dùng plugin.getSelectedContexts()
					var aCtxP = oSelPlugin.getSelectedContexts();
					for (var k = 0; k < aCtxP.length; k++) {
						if (aCtxP[k]) { aResult.push(aCtxP[k].getObject()); }
					}
				} else {
					// KHÔNG có plugin → dùng table.getSelectedIndices()
					var aIdx = oTable.getSelectedIndices();
					for (var i = 0; i < aIdx.length; i++) {
						var oCtx = oTable.getContextByIndex(aIdx[i]);
						if (oCtx) { aResult.push(oCtx.getObject()); }
					}
				}
			}
			// ResponsiveTable (sap.m.Table)
			else if (oTable.getSelectedContexts) {
				var aCtx2 = oTable.getSelectedContexts();
				for (var j = 0; j < aCtx2.length; j++) {
					aResult.push(aCtx2[j].getObject());
				}
			}

			return aResult;
		},

		/* ================================================================
		 *  MAIN ACTION — FunctionImport OData V2
		 *
		 *  $metadata FunctionImport:
		 *    Name="btnPrintPDF", HttpMethod="POST"
		 *    Parameters: companyCode, masterFixedAsset, fixedAsset (Edm.String)
		 *    ReturnType: ComplexType ZC_BTN_TTS
		 *      → fileContent (base64), fileName, fileExtension, mimeType
		 * ================================================================ */

		btnPrintPDF: function () {
			var that = this;

			// 1. Lấy dòng đã chọn
			var aRows = this._getSelectedRows();
			if (!aRows.length) {
				MessageToast.show("Vui lòng chọn ít nhất 1 dòng.");
				return;
			}

			// 2. Thu thập tham số
			var aCompany = [];
			var aMain = [];
			var aSub = [];
			aRows.forEach(function (o) {
				if (o.companyCode) { aCompany.push(o.companyCode); }
				if (o.masterFixedAsset) { aMain.push(o.masterFixedAsset); }
				if (o.fixedAsset !== undefined && o.fixedAsset !== null) { aSub.push(String(o.fixedAsset)); }
			});

			// 3. Busy dialog
			var oBusy = new BusyDialog({ text: "Generating PDF..." });
			oBusy.open();

			// 4. Gọi FunctionImport
			var oModel = this.getView().getModel();
			oModel.callFunction("/btnPrintPDF", {
				method: "POST",
				urlParameters: {
					companyCode: aCompany.join(","),
					masterFixedAsset: aMain.join(","),
					fixedAsset: aSub.join(",")
				},
				success: function (oData) {
					oBusy.close();

					// ComplexType return: kết quả nằm trong oData.btnPrintPDF hoặc oData
					var result = oData.btnPrintPDF || oData;

					if (!result || !result.fileContent) {
						MessageBox.error("Không có nội dung file trả về.");
						return;
					}

					var conv = that._b64ToSources(
						result.fileContent,
						result.mimeType || "application/pdf"
					);

					that._openPdfPreview([{
						name: result.fileName || "The_tai_san",
						ext: result.fileExtension || "pdf",
						mimeType: result.mimeType || "application/pdf",
						blob: conv.blob,
						url: conv.url,
						data: conv.data
					}]);
				},
				error: function (oError) {
					oBusy.close();
					console.error("[btnPrintPDF]", oError);
					var sMsg = "Print PDF failed.";
					try {
						var parsed = JSON.parse(oError.responseText);
						sMsg = parsed.error.message.value || sMsg;
					} catch (e) { /* ignore */ }
					MessageBox.error(sMsg);
				}
			});
		},

		/* ================================================================
		 *  PDF PREVIEW DIALOG
		 * ================================================================ */

		_presentFile: function (file) {
			var that = this;
			var src = (file.data || file.url) + "#page=1&zoom=page-fit";

			this._pdfViewer.setVisible(false);
			var busy = new BusyDialog({ text: "Loading PDF..." });
			busy.open();

			this._usingHtml = false;
			this._stack.removeAllItems();
			this._stack.addItem(this._pdfViewer);
			this._pdfViewer.setTitle(file.name + (file.ext ? "." + file.ext : ""));
			this._pdfViewer.setSource(src);

			this._waitPdfLoaded(this._pdfViewer, 900)
				.then(function () {
					that._pdfViewer.setVisible(true);
					busy.close();
				})
				.catch(function () {
					if (!that._html) { that._html = new HTML(); }
					that._html.setContent(that._buildPdfIframeHtml(src));
					that._stack.removeAllItems();
					that._stack.addItem(that._html);
					that._usingHtml = true;
					busy.close();
				});
		},

		_openPdfPreview: function (files) {
			var that = this;

			if (!this._pdfDialog) {
				this._pdfViewer = new PDFViewer({ width: "100%", height: "100%" });

				this._pdfSelect = new Select({
					width: "350px",
					change: function (oEvent) {
						var idx = Number(oEvent.getParameter("selectedItem").getKey());
						var f = that._pdfFiles[idx];
						if (f) { that._presentFile(f); }
					}
				});

				var btnDownload = new Button({
					text: "Download",
					icon: "sap-icon://download",
					press: function () {
						var idx = Number(that._pdfSelect.getSelectedKey());
						var f = that._pdfFiles[idx];
						if (f) {
							sap.ui.core.util.File.save(
								f.blob, f.name, f.ext || "pdf",
								f.mimeType || "application/pdf", "utf-8"
							);
						}
					}
				});

				var btnClose = new Button({
					text: "Close",
					type: "Transparent",
					press: function () { that._pdfDialog.close(); }
				});

				var header = new Toolbar({
					content: [
						new Text({ text: "Preview PDFs" }),
						new ToolbarSpacer(),
						new Text({ text: "Chọn file:" }),
						this._pdfSelect,
						new ToolbarSpacer(),
						btnDownload,
						btnClose
					]
				});

				this._stack = new VBox({
					width: "100%",
					height: "100%",
					renderType: "Bare",
					fitContainer: true
				}).addStyleClass("pdfFill");
				this._stack.addItem(this._pdfViewer);

				this._pdfDialog = new Dialog({
					contentWidth: "98vw",
					contentHeight: "96vh",
					stretch: true,
					resizable: true,
					draggable: true,
					horizontalScrolling: false,
					verticalScrolling: false,
					customHeader: header,
					content: [this._stack],
					afterOpen: function () {
						that._stack.setWidth("100%");
						that._stack.setHeight("100%");
						that._pdfViewer.setWidth("100%");
						that._pdfViewer.setHeight("100%");
					},
					afterClose: function () {
						that._cleanupPdfPreview();
					}
				}).addStyleClass("pdfDialogFull");
			}

			this._usingHtml = false;
			this._pdfFiles = files;

			this._pdfSelect.destroyItems();
			files.forEach(function (f, i) {
				that._pdfSelect.addItem(new Item({
					key: String(i),
					text: f.name + (f.ext ? "." + f.ext : "")
				}));
			});

			this._pdfSelect.setSelectedKey("0");
			this._presentFile(files[0]);
			this._pdfDialog.open();
		},

		_cleanupPdfPreview: function () {
			if (this._pdfFiles && this._pdfFiles.length) {
				this._pdfFiles.forEach(function (f) {
					try {
						if (f.url) { URL.revokeObjectURL(f.url); }
					} catch (e) { /* ignore */ }
				});
			}
			this._pdfFiles = [];
		}
	};
});