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

	return ControllerExtension.extend("zcrtbatchov4.ext.controller.ExcelUploadExt", {
// ==== DOWNLOAD TEMPLATE - gọi static action downloadFile dưới BE ====
        onTempDownload: async function () {
            const oModel = this.getView().getModel();   // sửa theo cấu trúc controller của bạn

            // Static action bound to Collection ManageFile
            const NS = "com.sap.gateway.srvd.zui_crt_batch.v0001.";
            const path = `/ManageFile/${NS}downloadFile(...)`;

            const oOp = oModel.bindContext(path);

            try {
                await oOp.invoke();   // ← breakpoint BE trong handler downloadFile sẽ ăn ở đây

                const result = oOp.getBoundContext().getObject();
                if (!result || !result.fileContent) {
                    MessageToast.show("Không nhận được nội dung template.");
                    return;
                }

                // BE trả base64url → đổi về base64 chuẩn
                const fixedB64 = String(result.fileContent).replace(/_/g, "/").replace(/-/g, "+");
                const bin = Uint8Array.from(atob(fixedB64), (c) => c.charCodeAt(0));
                const blob = new Blob([bin], {
                    type: result.mimeType || "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                });

                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = (result.fileName || "template") +
                             (result.fileExtension ? ("." + result.fileExtension) : ".xlsx");
                document.body.appendChild(a);
                a.click();
                a.remove();
                URL.revokeObjectURL(url);

                MessageToast.show("Template downloaded.");
            } catch (e) {
                MessageToast.show("Tải template thất bại.");
            }
        },		


		// ===== Constants ==========================================================
		// Action uploadExcel bound to Collection(ManageFileType)
		// → path: /ManageFile/<NS>uploadExcel(...)
		_NS: "com.sap.gateway.srvd.zui_crt_batch.v0001.",
		_ENTITY_SET: "ManageFile",
		_DIALOG_ID: "idFileUploadDialog",
		_FRAGMENT: "zcrtbatchov4.ext.fragment.filedialog",

		// ===== Lifecycle ==========================================================
		override: {
			onInit: function () {
				if (this.base && this.base.onInit) {
					this.base.onInit();
				}
			},
			editFlow: {
				onAfterActionExecution: function (oEvent) {
					// oEvent là string dạng: "com.sap.gateway.srvd.zui_crt_batch.v0001.downloadTemplate(...)"
					if (oEvent && oEvent.split(".")[6] === "downloadTemplate") {
						this.onTempDownload();
					}
				}
			}
		},

		// ===== Shortcuts ==========================================================
		_api() { return this.base.getExtensionAPI(); },
		_model() { return this._api().getModel(); },
		_i18n() { return this._api().getModel("i18n"); },
		_t(key, def) {
			const b = this._i18n()?.getResourceBundle?.();
			try { return b?.getText?.(key) ?? def ?? key; } catch (e) { return def ?? key; }
		},

		// ===== Open Upload Dialog =================================================
		async uploadexceldialog() {
			if (!this._dlg) {
				this._dlg = await this._api().loadFragment({
					id: this._DIALOG_ID,
					name: this._FRAGMENT,
					controller: this
				});
			}
			this._dlg.open();
		},

		// ===== File Change ========================================================
		async onFileChange(oEvent) {
			const f = (oEvent.getParameter("files") || [])[0];
			if (!f) return;

			this._file = {
				type: f.type || "",
				name: f.name || "",
				ext: (f.name || "").split(".").pop() || ""
			};

			// fileContent là Edm.Binary → truyền base64 string
			await this._secured(() =>
				this._readAsDataUrl(f).then((url) => {
					const m = String(url).match(/,(.*)$/);
					this._file.content = m && m[1] ? m[1] : "";
				})
			);
		},

		// ===== Upload =============================================================
		async onUploadPress() {
			if (!this._file?.content) {
				MessageToast.show(this._t("uploadFileErrMeg", "Vui lòng chọn tệp."));
				return;
			}

			await this._secured(async () => {
				await this._invokeCollectionAction("uploadExcel", {
					mimeType: this._file.type,
					fileName: this._file.name,
					fileContent: this._file.content,  // base64 cho Edm.Binary
					fileExtension: this._file.ext
				});

				await this._refreshListReport();
				MessageToast.show(this._t("uploadFileSuccMsg", "Tải lên thành công."));
				this._resetDialog();
			});
		},

		// ===== Cancel =============================================================
		onCancelUpload() {
			this._resetDialog();
		},

		// ===== OData V4 — Bound to Collection Action =============================
		// Path: /<EntitySet>/<Namespace><ActionName>(...)
		async _invokeCollectionAction(actionName, params) {
			const path = `/${this._ENTITY_SET}/${this._NS}${actionName}(...)`;
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

		// ===== Helpers ============================================================
		_secured(fn) {
			return this._api().getEditFlow().securedExecution(fn, { busy: { set: true } });
		},

		async _refreshListReport() {
			const api = this._api();
			if (typeof api.refresh === "function") {
				await api.refresh();
				return;
			}
			if (this._model()?.refresh) {
				await this._model().refresh();
			}
		},

		_resetDialog() {
			try {
				const fu = Fragment.byId(this._DIALOG_ID, "idFileUpload");
				fu?.clear?.();
			} catch (e) { /* no-op */ }
			this._file = null;
			if (this._dlg) {
				this._dlg.close?.();
				this._dlg.destroy?.();
				this._dlg = null;
			}
		},

		_openFEMessages() {
			const h = this._api().getEditFlow?.().getMessageHandler?.();
			h?.showMessages?.();
		},

		_pushODataErrors(err) {
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

		_readAsDataUrl(file) {
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