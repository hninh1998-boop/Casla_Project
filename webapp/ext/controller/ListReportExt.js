sap.ui.define([
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/m/Dialog",
    "sap/m/Button",
    "sap/ui/unified/FileUploader",
    "sap/ui/core/BusyIndicator",
    "sap/base/Log"
], function (MessageToast, MessageBox, Dialog, Button, FileUploader, BusyIndicator, Log) {
    "use strict";

    const SERVICE_NAMESPACE = "com.sap.gateway.srvd.zui_up_dntt_rp.v0001";
    const ENTITY_SET = "/DnttList";
    const DEFAULT_FILE_NAME = "Template_Upload_DNTT.xlsx";
    const DEFAULT_MIME_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    // Báo cáo đề nghị thanh toán (app bên khác) - ZDENGHITT-DISPLAY
    const PRINT_TARGET = {
        semanticObject: "ZDENGHITT",
        action: "DISPLAY",
        // Tên field filter bên app báo cáo (metadata ZC_DNTT)
        companyCode: "CompanyCode",   // bắt buộc, chỉ 1 giá trị (SINGLE)
        fiscalYear: "FiscalYear",     // bắt buộc
        documentNumber: "JournalEntry",
        // Tham số in: filter bên mình (ZCE_UP_DNTT) -> filter cùng tên bên báo cáo (1 giá trị)
        printFilters: ["NguoiDeNghi", "PhongBan", "NguoiLap", "GiamDoc", "KeToan"]
    };

    function base64ToBlob(sBase64, sMimeType) {
        const sBinary = atob(sBase64.replace(/\s/g, ""));
        const aBytes = new Uint8Array(sBinary.length);
        for (let i = 0; i < sBinary.length; i++) {
            aBytes[i] = sBinary.charCodeAt(i);
        }
        return new Blob([aBytes], { type: sMimeType });
    }

    function saveBlob(oBlob, sFileName) {
        const sUrl = URL.createObjectURL(oBlob);
        const oLink = document.createElement("a");
        oLink.href = sUrl;
        oLink.download = sFileName;
        document.body.appendChild(oLink);
        oLink.click();
        document.body.removeChild(oLink);
        URL.revokeObjectURL(sUrl);
    }

    function readFileAsBase64(oFile) {
        return new Promise(function (resolve, reject) {
            const oReader = new FileReader();
            // result dạng "data:<mime>;base64,<content>" -> chỉ lấy phần content
            oReader.onload = () => resolve(String(oReader.result).split(",")[1] || "");
            oReader.onerror = () => reject(oReader.error);
            oReader.readAsDataURL(oFile);
        });
    }

    const POPUP_WIDTH = "45rem";

    /**
     * Nội dung popup có danh sách chi tiết: hiện luôn từng dòng (•) ngay trong popup,
     * tự xuống dòng - không dùng link "View Details".
     */
    function withLines(sText, aLines) {
        return aLines && aLines.length ? sText + "\n\n" + aLines.map((sLine) => `• ${sLine}`).join("\n") : sText;
    }

    /** Lấy toàn bộ message lỗi trả về từ RAP (message chính + details), bỏ trùng */
    function getErrorTexts(oError) {
        const oODataError = oError && oError.error;
        const aTexts = [];
        if (oODataError) {
            aTexts.push(oODataError.message);
            (oODataError.details || []).forEach((oDetail) => aTexts.push(oDetail.message));
        } else if (oError && oError.message) {
            aTexts.push(oError.message);
        }
        return [...new Set(aTexts.filter(Boolean))];
    }

    /** Popup lỗi upload: hiển thị đầy đủ từng lỗi, tự xuống dòng, popup rộng */
    function showUploadErrors(aTexts, oBundle) {
        MessageBox.error(withLines(oBundle.getText("msgUploadError"), aTexts), { contentWidth: POPUP_WIDTH });
    }

    /** @returns {Promise<boolean>} true nếu upload thành công (có lưu dữ liệu) */
    async function uploadFile(oExtensionAPI, oFile, oBundle) {
        const sBase64 = await readFileAsBase64(oFile);

        const oAction = oExtensionAPI.getModel().bindContext(`${ENTITY_SET}/${SERVICE_NAMESPACE}.uploadFile(...)`);
        oAction.setParameter("FileName", oFile.name);
        oAction.setParameter("MimeType", oFile.type || DEFAULT_MIME_TYPE);
        oAction.setParameter("FileContent", sBase64);
        await oAction.invoke();

        const oResult = oAction.getBoundContext().getObject() || {};

        // Lỗi chặn cả file (sai header, không có quyền, sai template...) -> không lưu gì
        const aErrors = String(oResult.Errors || "").split("\n").filter(Boolean);
        if (aErrors.length) {
            showUploadErrors(aErrors, oBundle);
            return false;
        }

        const aCounts = [oResult.DocumentCount || 0, oResult.ItemCount || 0, oResult.ErrorCount || 0];
        // Cảnh báo (nếu có) -> hiện luôn trong popup
        const aWarnings = String(oResult.Warnings || "").split("\n").filter(Boolean);
        const mOptions = aWarnings.length ? { contentWidth: POPUP_WIDTH } : {};

        let sText = oBundle.getText(oResult.ErrorCount ? "msgUploadWithErrors" : "msgUploadSuccess", aCounts);
        if (aWarnings.length) {
            sText += "\n\n" + oBundle.getText("msgUploadSkipped", [aWarnings.length]);
        }

        if (oResult.ErrorCount || aWarnings.length) {
            MessageBox.warning(withLines(sText, aWarnings), mOptions);
        } else {
            MessageBox.success(sText, mOptions);
        }
        oExtensionAPI.refresh();
        return true;
    }

    const STATUS_POSTED = "POSTED";
    const STATUS_DRAFT = "DRAFT";
    const STATUS_CHECKED = "CHECKED";
    const STATUS_ERROR = "ERROR";
    const ACTION_CHECK = "checkDocuments";
    const ACTION_POST = "postDocuments";

    /** Thông tin chứng từ cần cho Check / Post / Print (lấy từ context danh sách hoặc màn hình chi tiết) */
    function getDocInfos(aContexts) {
        return aContexts.map((oCtx) => ({
            docNo: String(oCtx.getProperty("DocumentSequenceNo")),
            companyCode: oCtx.getProperty("CompanyCode"),
            postingDate: oCtx.getProperty("PostingDate"),
            documentNumber: oCtx.getProperty("DocumentNumber")
        }));
    }

    /** Năm của Posting date: danh sách trả "2026-10-03", màn hình chi tiết trả "03/10/2026" */
    function getFiscalYear(vPostingDate) {
        const aMatch = /(\d{4})/.exec(String(vPostingDate || ""));
        return aMatch ? aMatch[1] : "";
    }

    /**
     * Mở báo cáo đề nghị thanh toán (ZDENGHITT-DISPLAY) với filter của các chứng từ:
     * Company Code + Fiscal Year (năm của Posting date) + Document Number (các chứng từ đã có số)
     * + tham số in trên filter bar (Người đề nghị, Phòng ban, ...).
     */
    async function printDocuments(oExtensionAPI, aDocs, oBundle) {
        const fnDistinct = (aValues) => [...new Set(aValues.filter(Boolean).map(String))];

        // Báo cáo chỉ cho filter 1 Company Code -> chọn nhiều Company code thì lấy Company code đầu tiên.
        // Fiscal Year / Document Number vẫn lấy của TẤT CẢ chứng từ được chọn (bất kể Company code)
        const aCompanyCodes = fnDistinct(aDocs.map((oDoc) => oDoc.companyCode));
        const aFiscalYears = fnDistinct(aDocs.map((oDoc) => getFiscalYear(oDoc.postingDate)));
        const aDistinctDocs = fnDistinct(aDocs.map((oDoc) => oDoc.documentNumber));

        if (!aCompanyCodes.length || !aFiscalYears.length) {
            MessageBox.warning(oBundle.getText("msgPrintMissing"));
            return;
        }

        // Tham số khởi động -> Fiori Elements bên báo cáo tự điền vào filter cùng tên (nhiều giá trị -> mảng)
        const mParams = {
            [PRINT_TARGET.companyCode]: aCompanyCodes[0],
            [PRINT_TARGET.fiscalYear]: aFiscalYears.length > 1 ? aFiscalYears : aFiscalYears[0]
        };
        // Không chứng từ nào có Document Number -> chỉ lọc Company Code + Fiscal Year
        if (aDistinctDocs.length) {
            mParams[PRINT_TARGET.documentNumber] = aDistinctDocs.length > 1 ? aDistinctDocs : aDistinctDocs[0];
        }

        // Tham số in nhập trên filter bar (chỉ có ở màn hình danh sách)
        Object.assign(mParams, await getPrintFilterValues(oExtensionAPI));

        sap.ui.require(["sap/ushell/Container"], async (Container) => {
            try {
                const oNavigation = await Container.getServiceAsync("Navigation");
                await oNavigation.navigate({
                    target: { semanticObject: PRINT_TARGET.semanticObject, action: PRINT_TARGET.action },
                    params: mParams
                });
            } catch (oError) {
                MessageBox.error(oBundle.getText("msgPrintNavError", [oError && oError.message || oError]));
            }
        }, () => MessageBox.error(oBundle.getText("msgPrintNavError", ["Launchpad (sap.ushell) không khả dụng"])));
    }

    function getStatus(oContext) {
        return String(oContext.getProperty("Status") || "").toUpperCase();
    }

    function isPosted(oContext) {
        return getStatus(oContext) === STATUS_POSTED;
    }

    /** Check được chứng từ Draft và Error (Error -> check lại sau khi sửa dữ liệu / master data) */
    function isCheckable(oContext) {
        const sStatus = getStatus(oContext);
        return sStatus === STATUS_DRAFT || sStatus === STATUS_ERROR;
    }

    function isChecked(oContext) {
        return getStatus(oContext) === STATUS_CHECKED;
    }

    /**
     * Gọi static action checkDocuments / postDocuments 1 lần cho tất cả chứng từ được chọn
     * (backend gọi API Journal Entry - tối đa 10 chứng từ / request SOAP).
     * Kết quả tổng hợp hiển thị trong 1 MessageBox.
     */
    async function processDocuments(oExtensionAPI, sAction, aDocs, oBundle, sSuccessKey, sResultKey) {
        const aDocNos = aDocs.map((oDoc) => oDoc.docNo);

        const oAction = oExtensionAPI.getModel().bindContext(`${ENTITY_SET}/${SERVICE_NAMESPACE}.${sAction}(...)`);
        oAction.setParameter("DocumentList", aDocNos.join(","));
        await oAction.invoke();

        const oResult = oAction.getBoundContext().getObject() || {};
        const aLines = String(oResult.Details || "").split("\n").filter(Boolean);

        oExtensionAPI.refresh();

        const fnShow = oResult.ErrorCount ? MessageBox.warning : MessageBox.success;
        const sText = oResult.ErrorCount
            ? oBundle.getText(sResultKey, [oResult.SuccessCount || 0, aDocNos.length])
            : oBundle.getText(sSuccessKey, [aDocNos.join(", ")]);
        // Kết quả từng chứng từ (lỗi / số chứng từ đã post) hiện luôn trong popup
        const mOptions = aLines.length ? { contentWidth: POPUP_WIDTH } : {};

        // Thêm nút thao tác tiếp theo ngay trên popup: Check xong -> Post, Post xong -> Print
        const fnAddNextAction = (sLabelKey, fnRun) => {
            const sNextAction = oBundle.getText(sLabelKey);
            mOptions.actions = [sNextAction, MessageBox.Action.OK];
            mOptions.emphasizedAction = MessageBox.Action.OK;
            mOptions.onClose = (sPressed) => {
                if (sPressed === sNextAction) {
                    fnRun();
                }
            };
        };

        if (sAction === ACTION_CHECK && oResult.SuccessCount) {
            // Dòng chi tiết "<Document SequenceNo>: ..." = chứng từ lỗi -> chỉ Post các chứng từ vừa Checked
            const aFailed = aLines.map((sLine) => sLine.split(":")[0].trim());
            const aCheckedDocs = aDocs.filter((oDoc) => !aFailed.includes(oDoc.docNo));
            if (aCheckedDocs.length) {
                fnAddNextAction("btnPost", () => runWithBusy(() => processDocuments(oExtensionAPI, ACTION_POST,
                    aCheckedDocs, oBundle, "msgPostSuccess", "msgPostResult")));
            }
        } else if (sAction === ACTION_POST && oResult.SuccessCount) {
            // Dòng chi tiết "<Document SequenceNo>: Posted - <Document number>" = chứng từ vừa post -> Print các chứng từ đó
            const aPostedDocs = [];
            aLines.forEach((sLine) => {
                const aMatch = /^(\S+): Posted - (\S+)$/.exec(sLine.trim());
                const oDoc = aMatch && aDocs.find((oItem) => oItem.docNo === aMatch[1]);
                if (oDoc) {
                    aPostedDocs.push(Object.assign({}, oDoc, { documentNumber: aMatch[2] }));
                }
            });
            if (aPostedDocs.length) {
                fnAddNextAction("btnPrint", () => printDocuments(oExtensionAPI, aPostedDocs, oBundle));
            }
        }

        fnShow(withLines(sText, aLines), mOptions);
    }

    async function deleteDocuments(oExtensionAPI, aContexts, oBundle) {
        const oModel = oExtensionAPI.getModel();
        const aResults = await Promise.allSettled(aContexts.map((oContext) =>
            oModel.bindContext(`${SERVICE_NAMESPACE}.deleteDocument(...)`, oContext).invoke()
        ));

        const aDeleted = [];
        const aErrors = [];
        aResults.forEach((oResult, i) => {
            const sDocNo = aContexts[i].getProperty("DocumentSequenceNo");
            if (oResult.status === "fulfilled") {
                aDeleted.push(sDocNo);
            } else {
                getErrorTexts(oResult.reason).forEach((sText) => aErrors.push(`${sDocNo}: ${sText}`));
            }
        });

        oExtensionAPI.refresh();

        if (aErrors.length) {
            MessageBox.error(
                withLines(oBundle.getText("msgDeletePartial", [aDeleted.length, aContexts.length]), aErrors),
                { contentWidth: POPUP_WIDTH }
            );
        } else {
            MessageToast.show(oBundle.getText("msgDeleteSuccess", [aDeleted.join(", ")]));
        }
    }

    /**
     * Đọc giá trị tham số in (PRINT_TARGET.printFilters) trên filter bar của List Report.
     * Dùng API công khai của filter bar (building block sap.fe.macros.FilterBar), ID cố định
     * fe::FilterBar::<EntitySet>::FilterBar - truy cập control nội bộ fe::FilterBar::<EntitySet> bị FE chặn.
     * Dự phòng: SelectionVariant của ExtensionAPI.
     */
    async function getPrintFilterValues(oExtensionAPI) {
        const fnFromSelectionVariant = (oSelectionVariant) => {
            const mValues = {};
            PRINT_TARGET.printFilters.forEach((sField) => {
                const aOptions = (oSelectionVariant && oSelectionVariant.getSelectOption(sField)) || [];
                if (aOptions.length && aOptions[0].Low) {
                    mValues[sField] = aOptions[0].Low;
                }
            });
            return mValues;
        };

        try {
            const oFilterBarAPI = oExtensionAPI.byId(`fe::FilterBar::${ENTITY_SET.substring(1)}::FilterBar`);
            if (oFilterBarAPI && oFilterBarAPI.getSelectionVariant) {
                return fnFromSelectionVariant(await oFilterBarAPI.getSelectionVariant());
            }
        } catch (oError) {
            Log.error("Print: không đọc được tham số in qua FilterBar API", oError);
        }

        try {
            if (oExtensionAPI.getSelectionVariant) {
                return fnFromSelectionVariant(await oExtensionAPI.getSelectionVariant());
            }
        } catch (oError) {
            Log.error("Print: không đọc được tham số in qua ExtensionAPI", oError);
        }

        Log.error("Print: không tìm thấy filter bar để đọc tham số in");
        return {};
    }

    async function runWithBusy(fnRun) {
        BusyIndicator.show(0);
        try {
            await fnRun();
        } catch (oError) {
            MessageBox.error(getErrorTexts(oError).join("\n"));
        } finally {
            BusyIndicator.hide();
        }
    }

    return {
        /**
         * Gọi static action downloadTemplate (BDEF ZCE_UP_DNTT) và tải file Excel về.
         * "this" là ExtensionAPI của List Report.
         */
        onDownloadTemplate: async function () {
            const oModel = this.getModel();
            const oBundle = this.getModel("i18n").getResourceBundle();

            BusyIndicator.show(0);
            try {
                const oAction = oModel.bindContext(`${ENTITY_SET}/${SERVICE_NAMESPACE}.downloadTemplate(...)`);
                await oAction.invoke();

                const oResult = oAction.getBoundContext().getObject();
                if (!oResult || !oResult.FileContent) {
                    MessageBox.error(oBundle.getText("msgDownloadTemplateEmpty"));
                    return;
                }

                saveBlob(
                    base64ToBlob(oResult.FileContent, oResult.MimeType || DEFAULT_MIME_TYPE),
                    oResult.FileName || DEFAULT_FILE_NAME
                );
                MessageToast.show(oBundle.getText("msgDownloadTemplateSuccess"));
            } catch (oError) {
                MessageBox.error(oBundle.getText("msgDownloadTemplateError", [oError.message]));
            } finally {
                BusyIndicator.hide();
            }
        },

        /**
         * Mở dialog chọn file Excel, gọi static action uploadFile.
         * "this" là ExtensionAPI của List Report.
         */
        onUploadFile: function () {
            const oExtensionAPI = this;
            const oBundle = this.getModel("i18n").getResourceBundle();
            let oSelectedFile = null;

            const oFileUploader = new FileUploader({
                width: "100%",
                fileType: ["xlsx"],
                mimeType: [DEFAULT_MIME_TYPE],
                placeholder: oBundle.getText("uploadPlaceholder"),
                change: (oEvent) => {
                    const aFiles = oEvent.getParameter("files");
                    oSelectedFile = aFiles && aFiles.length ? aFiles[0] : null;
                },
                typeMissmatch: () => MessageToast.show(oBundle.getText("msgUploadWrongType"))
            });

            const oDialog = new Dialog({
                title: oBundle.getText("uploadDialogTitle"),
                contentWidth: "30rem",
                content: [oFileUploader],
                beginButton: new Button({
                    text: oBundle.getText("btnUpload"),
                    type: "Emphasized",
                    press: async () => {
                        if (!oSelectedFile) {
                            MessageToast.show(oBundle.getText("msgUploadNoFile"));
                            return;
                        }
                        oDialog.setBusy(true);
                        try {
                            // File lỗi -> giữ dialog để user chọn lại file đã sửa
                            if (await uploadFile(oExtensionAPI, oSelectedFile, oBundle)) {
                                oDialog.close();
                            }
                        } catch (oError) {
                            showUploadErrors(getErrorTexts(oError), oBundle);
                        } finally {
                            oDialog.setBusy(false);
                        }
                    }
                }),
                endButton: new Button({
                    text: oBundle.getText("btnCancel"),
                    press: () => oDialog.close()
                }),
                afterClose: () => oDialog.destroy()
            });
            oDialog.addStyleClass("sapUiContentPadding");

            oExtensionAPI.addDependent(oDialog);
            oDialog.open();
        },

        /** Check chỉ bật khi có ít nhất 1 chứng từ Draft / Error */
        isCheckEnabled: function (oContext, aSelectedContexts) {
            return (aSelectedContexts || []).some(isCheckable);
        },

        /**
         * Check = test run API Journal Entry - Post (TestDataIndicator = true), không tạo chứng từ.
         * Không lỗi -> Checked, có lỗi -> Error + Message. Chỉ chứng từ Draft / Error được check.
         */
        onCheck: async function (oContext, aSelectedContexts) {
            const oBundle = this.getModel("i18n").getResourceBundle();
            const aContexts = (aSelectedContexts || []).filter(isCheckable);

            if (!aContexts.length) {
                MessageBox.warning(oBundle.getText("msgCheckNone"));
                return;
            }

            await runWithBusy(() => processDocuments(this, ACTION_CHECK, getDocInfos(aContexts), oBundle,
                "msgCheckSuccess", "msgCheckResult"));
        },

        /** Post chỉ bật khi có ít nhất 1 chứng từ Checked */
        isPostEnabled: function (oContext, aSelectedContexts) {
            return (aSelectedContexts || []).some(isChecked);
        },

        /**
         * Post = gọi API Journal Entry - Post thật (TestDataIndicator = false).
         * Thành công -> Posted + Document number, lỗi -> Error + Message. Chỉ chứng từ Checked được post.
         */
        onPost: function (oContext, aSelectedContexts) {
            const oExtensionAPI = this;
            const oBundle = this.getModel("i18n").getResourceBundle();
            const aContexts = (aSelectedContexts || []).filter(isChecked);
            const aSkipped = (aSelectedContexts || []).filter((oCtx) => !isChecked(oCtx))
                .map((oCtx) => oCtx.getProperty("DocumentSequenceNo"));

            if (!aContexts.length) {
                MessageBox.warning(oBundle.getText("msgPostNone"));
                return;
            }

            let sText = oBundle.getText("msgPostConfirm", [
                aContexts.map((oCtx) => oCtx.getProperty("DocumentSequenceNo")).join(", ")
            ]);
            if (aSkipped.length) {
                sText += "\n\n" + oBundle.getText("msgPostSkip", [aSkipped.join(", ")]);
            }

            MessageBox.confirm(sText, {
                emphasizedAction: MessageBox.Action.OK,
                onClose: (sAction) => {
                    if (sAction === MessageBox.Action.OK) {
                        runWithBusy(() => processDocuments(oExtensionAPI, ACTION_POST, getDocInfos(aContexts), oBundle,
                            "msgPostSuccess", "msgPostResult"));
                    }
                }
            });
        },


        /** Delete chỉ bật khi có ít nhất 1 chứng từ chưa Posted (Draft / Checked / Error) */
        isDeleteEnabled: function (oContext, aSelectedContexts) {
            return (aSelectedContexts || []).some((oCtx) => !isPosted(oCtx));
        },

        /**
         * Xóa các chứng từ được chọn (header + item) qua action deleteDocument.
         * Chứng từ Posted bị bỏ qua (backend cũng chặn).
         */
        onDelete: function (oContext, aSelectedContexts) {
            const oExtensionAPI = this;
            const oBundle = this.getModel("i18n").getResourceBundle();
            const aContexts = (aSelectedContexts || []).filter((oCtx) => !isPosted(oCtx));
            const aSkipped = (aSelectedContexts || []).filter(isPosted)
                .map((oCtx) => oCtx.getProperty("DocumentSequenceNo"));

            if (!aContexts.length) {
                MessageBox.warning(oBundle.getText("msgDeleteNone"));
                return;
            }

            let sText = oBundle.getText("msgDeleteConfirm", [
                aContexts.map((oCtx) => oCtx.getProperty("DocumentSequenceNo")).join(", ")
            ]);
            if (aSkipped.length) {
                sText += "\n\n" + oBundle.getText("msgDeleteSkipPosted", [aSkipped.join(", ")]);
            }

            MessageBox.confirm(sText, {
                emphasizedAction: MessageBox.Action.OK,
                onClose: async (sAction) => {
                    if (sAction !== MessageBox.Action.OK) {
                        return;
                    }
                    BusyIndicator.show(0);
                    try {
                        await deleteDocuments(oExtensionAPI, aContexts, oBundle);
                    } finally {
                        BusyIndicator.hide();
                    }
                }
            });
        },

        /**
         * Mở báo cáo đề nghị thanh toán (ZDENGHITT-DISPLAY) với filter của các chứng từ được chọn:
         * Company Code + Fiscal Year (năm của Posting date) + Document Number.
         * Chứng từ chưa có Document Number được bỏ qua khi lọc Document Number;
         * không chứng từ nào có Document Number -> chỉ filter Company Code + Fiscal Year.
         */
        onPrint: function (oContext, aSelectedContexts) {
            return printDocuments(this, getDocInfos(aSelectedContexts || []),
                this.getModel("i18n").getResourceBundle());
        }
    };
});
