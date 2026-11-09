sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/ui/core/Fragment",
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/BusyDialog",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator"
], function (
    ControllerExtension,
    Fragment,
    MessageToast,
    MessageBox,
    BusyDialog,
    Filter,
    FilterOperator
) {
    "use strict";

    const MAX_FILES = 50;
    const MAX_SIZE = 10 * 1024 * 1024; // 10MB - khớp lcl_const=>max_file_size ở BE
    const DUP_CHECK_CHUNK = 20;        // số File Name mỗi lần hỏi BE

    return ControllerExtension.extend("zuplattsoov4.ext.controller.UploadAttachmentExt", {

        // ===== Constants =====================================================
        // Static action uploadFile bound to collection UploadAttachment
        // -> /UploadAttachment/<NS>uploadFile(...)
        _NS: "com.sap.gateway.srvd.zui_upl_att_so.v0001.",
        _ENTITY_SET: "UploadAttachment",
        _DIALOG_ID: "idUploadAttDialog",
        _FRAGMENT: "zuplattsoov4.ext.fragment.UploadDialog",

        // ===== Shortcuts =====================================================
        _api() { return this.base.getExtensionAPI(); },
        _model() { return this._api().getModel(); },
        _t(key, args) {
            const bundle = this._api().getModel("i18n")?.getResourceBundle?.();
            try { return bundle?.getText?.(key, args) ?? key; } catch (e) { return key; }
        },
        _byId(id) { return Fragment.byId(this._DIALOG_ID, id); },

        // ===== Open dialog ===================================================
        async openUploadDialog() {
            if (!this._dialog) {
                this._dialog = await this._api().loadFragment({
                    id: this._DIALOG_ID,
                    name: this._FRAGMENT,
                    controller: this
                });
            }
            this._files = [];
            this._byId("idFileUploader")?.clear?.();
            this._updateSelectedText();
            this._dialog.open();
        },

        onFilesChange(oEvent) {
            this._files = Array.from(oEvent.getParameter("files") || []);
            this._updateSelectedText();
        },

        onCancelUpload() {
            this._dialog?.close();
        },

        _updateSelectedText() {
            this._byId("idSelectedText")?.setText(this._t("dlgSelected", [(this._files || []).length]));
        },

        // ===== Upload ========================================================
        async onUploadPress() {
            const files = this._files || [];
            if (!files.length) {
                MessageToast.show(this._t("msgNoFile"));
                return;
            }
            if (files.length > MAX_FILES) {
                MessageBox.error(this._t("msgTooMany", [MAX_FILES, files.length]));
                return;
            }

            // 1. Lọc ngay tại FE: quá 10MB, chọn trùng tên trong cùng lần upload
            const skipped = [];
            const seen = new Set();
            let candidates = [];
            files.forEach((f) => {
                if (f.size > MAX_SIZE) {
                    skipped.push({ name: f.name, reason: this._t("reasonTooBig") });
                } else if (seen.has(f.name)) {
                    skipped.push({ name: f.name, reason: this._t("reasonDupSelection") });
                } else {
                    seen.add(f.name);
                    candidates.push(f);
                }
            });

            // 2. Hỏi BE các File Name đã tồn tại (File Name là key, phân biệt hoa thường)
            let existing;
            this._dialog.setBusy(true);
            try {
                existing = await this._findExistingNames(candidates.map((f) => f.name));
            } catch (e) {
                MessageBox.error(this._t("msgCheckDupFailed") + "\n" + this._errText(e));
                return;
            } finally {
                this._dialog.setBusy(false);
            }

            candidates = candidates.filter((f) => {
                if (existing.has(f.name)) {
                    skipped.push({ name: f.name, reason: this._t("reasonDupExisting") });
                    return false;
                }
                return true;
            });

            // 3. Có file bị loại -> cảnh báo số lượng, user OK thì upload phần còn lại
            if (skipped.length) {
                const detail = this._formatList(skipped);
                if (!candidates.length) {
                    MessageBox.error(this._t("msgAllSkipped", [files.length]) + "\n\n" + detail);
                    return;
                }
                const ok = await this._confirm(
                    this._t("msgSkippedConfirm", [skipped.length, files.length, candidates.length]) + "\n\n" + detail
                );
                if (!ok) {
                    return;
                }
            }

            this._dialog.close();
            await this._uploadAll(candidates);
        },

        // Upload tuần tự từng file -> mỗi file 1 lần gọi static action uploadFile
        async _uploadAll(files) {
            const busy = new BusyDialog({
                title: this._t("busyTitle"),
                text: this._t("busyText", [0, files.length])
            });
            busy.open();

            const failed = [];
            let success = 0;
            try {
                for (let i = 0; i < files.length; i++) {
                    const f = files[i];
                    busy.setText(this._t("busyText", [i + 1, files.length]) + "\n" + f.name);
                    try {
                        const content = await this._readAsBase64(f);
                        await this._invokeUpload({
                            fileName: f.name,
                            mimeType: f.type,
                            fileContent: content // base64 cho Edm.Binary
                        });
                        success++;
                    } catch (e) {
                        failed.push({ name: f.name, reason: this._errText(e) });
                    }
                }
            } finally {
                busy.close();
                busy.destroy();
            }

            await this._refreshListReport();

            if (!failed.length) {
                MessageBox.success(this._t("msgUploadOk", [success]));
            } else {
                MessageBox.warning(this._t("msgUploadPartial", [success, failed.length]) + "\n\n" +
                    this._formatList(failed));
            }
        },

        // ===== OData V4 helpers ==============================================
        async _findExistingNames(names) {
            const result = new Set();
            for (let i = 0; i < names.length; i += DUP_CHECK_CHUNK) {
                const chunk = names.slice(i, i + DUP_CHECK_CHUNK);
                const filter = new Filter({
                    filters: chunk.map((n) => new Filter("FileName", FilterOperator.EQ, n)),
                    and: false
                });
                const binding = this._model().bindList("/" + this._ENTITY_SET, undefined, undefined, filter,
                    { $select: "FileName" });
                try {
                    const contexts = await binding.requestContexts(0, chunk.length + 1);
                    contexts.forEach((ctx) => result.add(ctx.getProperty("FileName")));
                } finally {
                    binding.destroy();
                }
            }
            return result;
        },

        async _invokeUpload(params) {
            const op = this._model().bindContext(`/${this._ENTITY_SET}/${this._NS}uploadFile(...)`);
            Object.entries(params).forEach(([k, v]) => {
                if (v !== undefined && v !== null && v !== "") {
                    op.setParameter(k, v);
                }
            });
            try {
                await op.invoke();
            } finally {
                op.destroy();
            }
        },

        async _refreshListReport() {
            const api = this._api();
            if (typeof api.refresh === "function") {
                await api.refresh();
            } else if (this._model()?.refresh) {
                this._model().refresh();
            }
        },

        // ===== Misc helpers ==================================================
        _confirm(text) {
            const sContinue = this._t("btnContinueUpload");
            const sCancel = this._t("dlgCancel");
            return new Promise((resolve) => {
                MessageBox.warning(text, {
                    title: this._t("titleSkipped"),
                    actions: [sContinue, sCancel],
                    emphasizedAction: sContinue,
                    onClose: (action) => resolve(action === sContinue)
                });
            });
        },

        _formatList(items) {
            return items.map((it) => `• ${it.name}: ${it.reason}`).join("\n");
        },

        _errText(err) {
            const root = err?.error || err?.cause?.error || {};
            const details = Array.isArray(root.details) ? root.details.map((d) => d?.message).filter(Boolean) : [];
            return [root.message || err?.message || String(err), ...details].join(" | ");
        },

        _readAsBase64(file) {
            return new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = (e) => {
                    const match = String(e?.target?.result || "").match(/,(.*)$/);
                    resolve(match && match[1] ? match[1] : "");
                };
                reader.onerror = reject;
                reader.readAsDataURL(file);
            });
        }
    });
});
