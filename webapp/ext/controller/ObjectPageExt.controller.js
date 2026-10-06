sap.ui.define(
    ["sap/ui/core/mvc/ControllerExtension", "sap/base/Log", "zmcanmatdoc/ext/controller/MessageStore"],
    function (ControllerExtension, Log, MessageStore) {
        "use strict";

        return ControllerExtension.extend("zmcanmatdoc.ext.controller.ObjectPageExt", {
            override: {
                routing: {
                    /**
                     * The object page reads the item again from the backend, where Message is empty.
                     * Put back the message of the last Cancel Item run (client side only, no PATCH).
                     */
                    onAfterBinding: async function (oBindingContext) {
                        const oMessage = oBindingContext && MessageStore.get(oBindingContext.getPath());
                        if (!oMessage) {
                            return;
                        }
                        try {
                            await oBindingContext.requestProperty(["Message", "MessageCriticality"]);
                            await oBindingContext.setProperty("Message", oMessage.message, null);
                            await oBindingContext.setProperty("MessageCriticality", oMessage.criticality, null);
                        } catch (oError) {
                            Log.warning("Cancel Item message could not be shown", oError, "zmcanmatdoc");
                        }
                    }
                }
            }
        });
    }
);
