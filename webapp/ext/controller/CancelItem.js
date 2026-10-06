sap.ui.define(
    ["sap/m/MessageBox", "sap/base/Log", "sap/base/security/encodeXML", "zmcanmatdoc/ext/controller/MessageStore"],
    function (MessageBox, Log, encodeXML, MessageStore) {
        "use strict";

        const CANCEL_ACTION = "com.sap.gateway.srvd.zui_m_can_matdoc.v0001.cancelItem";
        const CANCEL_HEADER_ACTION = "com.sap.gateway.srvd.zui_m_can_matdoc.v0001.cancelHeader";

        // List bindings that already clear the message store on refresh (Go)
        const oWatchedBindings = new WeakSet();

        /** Remembers the messages returned by the action so that the object page can show them too. */
        function storeMessages(aContexts) {
            aContexts.forEach((oContext) => {
                MessageStore.set(oContext.getPath(), {
                    message: oContext.getProperty("Message"),
                    criticality: oContext.getProperty("MessageCriticality")
                });
            });

            const oBinding = aContexts[0].getBinding();
            if (oBinding && !oWatchedBindings.has(oBinding)) {
                oWatchedBindings.add(oBinding);
                oBinding.attachEvent("refresh", MessageStore.clear);
            }
        }

        return {
            /**
             * Cancel Item: skips lines that are already canceled or are reversal lines.
             * Mixed selection -> ask for confirmation, nothing left to cancel -> error.
             * `this` is the Fiori elements ExtensionAPI.
             */
            onCancelItem: async function (oContext, aSelectedContexts) {
                const oBundle = await this.getModel("i18n").getResourceBundle();

                // requestProperty also works when the two columns are hidden in the table
                const aItems = await Promise.all(
                    aSelectedContexts.map(async (oSelected) => {
                        const [sDocument, sItem, sYear, bCanceled, bReversal] = await oSelected.requestProperty([
                            "MaterialDocument",
                            "MaterialDocumentItem",
                            "MaterialDocumentYear",
                            "ItemHasBeenCanceled",
                            "HasReversalMovementType"
                        ]);
                        return { context: oSelected, document: sDocument, item: sItem, year: sYear, canceled: bCanceled, reversal: bReversal };
                    })
                );

                const aSkipped = aItems.filter((oItem) => oItem.canceled || oItem.reversal);
                const aValid = aItems.filter((oItem) => !oItem.canceled && !oItem.reversal);
                const aContexts = aValid.map((oItem) => oItem.context);

                // The standard BO cannot cancel items of different material documents in one save
                // ("Canceling of different material documents not possible") -> one request per document.
                const mDocuments = new Map();
                aValid.forEach((oItem) => {
                    const sDocument = oItem.year + "/" + oItem.document;
                    mDocuments.set(sDocument, (mDocuments.get(sDocument) || []).concat(oItem.context));
                });

                const invoke = async () => {
                    for (const aDocumentContexts of mDocuments.values()) {
                        try {
                            await this.editFlow.invokeAction(CANCEL_ACTION, {
                                contexts: aDocumentContexts,
                                // one change set = one save, so items of the same document share one cancel document
                                invocationGrouping: "ChangeSet",
                                label: oBundle.getText("cancelItem")
                            });
                        } catch (oError) {
                            // Fiori elements already shows the error; go on with the next document
                            Log.error("Cancel Item failed", oError, "zmcanmatdoc");
                        }
                    }
                    storeMessages(aContexts);
                };

                if (aSkipped.length === 0) {
                    return invoke();
                }

                const sDetails =
                    "<ul>" +
                    aSkipped
                        .map((oItem) => {
                            const sKey = oItem.canceled ? "cancelItemDetailCanceled" : "cancelItemDetailReversal";
                            return "<li>" + encodeXML(oBundle.getText(sKey, [oItem.document, oItem.item, oItem.year])) + "</li>";
                        })
                        .join("") +
                    "</ul>";

                if (aContexts.length === 0) {
                    MessageBox.error(oBundle.getText("cancelItemAllSkipped"), { details: sDetails });
                    return undefined;
                }

                MessageBox.warning(oBundle.getText("cancelItemConfirm", [aSkipped.length, aItems.length, aContexts.length]), {
                    details: sDetails,
                    actions: [MessageBox.Action.YES, MessageBox.Action.NO],
                    emphasizedAction: MessageBox.Action.YES,
                    onClose: (sAction) => {
                        if (sAction === MessageBox.Action.YES) {
                            invoke();
                        }
                    }
                });
                return undefined;
            },

            /**
             * Cancel cả chứng từ: cancels every open line of the documents of the selected lines (header level).
             * Always asks for confirmation because more lines than the selected ones are canceled.
             * `this` is the Fiori elements ExtensionAPI.
             */
            onCancelHeader: async function (oContext, aSelectedContexts) {
                const oBundle = await this.getModel("i18n").getResourceBundle();

                const mDocuments = new Map();
                await Promise.all(
                    aSelectedContexts.map(async (oSelected) => {
                        const [sDocument, sYear] = await oSelected.requestProperty(["MaterialDocument", "MaterialDocumentYear"]);
                        mDocuments.set(sYear + "/" + sDocument, { document: sDocument, year: sYear, contexts: [] });
                    })
                );

                // Send every loaded line of these documents, so that each of them gets its message and new status.
                // The backend calls the cancel API only once per document.
                aSelectedContexts[0]
                    .getBinding()
                    .getAllCurrentContexts()
                    .forEach((oRow) => {
                        const oDocument = mDocuments.get(oRow.getProperty("MaterialDocumentYear") + "/" + oRow.getProperty("MaterialDocument"));
                        if (oDocument) {
                            oDocument.contexts.push(oRow);
                        }
                    });
                const aDocuments = Array.from(mDocuments.values());

                const invoke = async () => {
                    for (const oDocument of aDocuments) {
                        try {
                            await this.editFlow.invokeAction(CANCEL_HEADER_ACTION, {
                                contexts: oDocument.contexts,
                                invocationGrouping: "ChangeSet",
                                label: oBundle.getText("cancelHeader")
                            });
                        } catch (oError) {
                            // Fiori elements already shows the error; go on with the next document
                            Log.error("Cancel header failed", oError, "zmcanmatdoc");
                        }
                    }
                    storeMessages(aDocuments.flatMap((oDocument) => oDocument.contexts));
                };

                const sDetails =
                    "<ul>" +
                    aDocuments
                        .map((oDocument) => "<li>" + encodeXML(oBundle.getText("cancelHeaderDetail", [oDocument.document, oDocument.year])) + "</li>")
                        .join("") +
                    "</ul>";

                MessageBox.warning(oBundle.getText("cancelHeaderConfirm", [aDocuments.length]), {
                    details: sDetails,
                    actions: [MessageBox.Action.YES, MessageBox.Action.NO],
                    emphasizedAction: MessageBox.Action.YES,
                    onClose: (sAction) => {
                        if (sAction === MessageBox.Action.YES) {
                            invoke();
                        }
                    }
                });
                return undefined;
            }
        };
    }
);
