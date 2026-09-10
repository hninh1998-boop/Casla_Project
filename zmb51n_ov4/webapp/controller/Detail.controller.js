sap.ui.define(
    ["sap/ui/core/mvc/Controller", "sap/m/Label", "sap/m/Text", "sap/m/MessageToast", "zmb51nov4/model/metadataHelper"],
    function (Controller, Label, Text, MessageToast, metadataHelper) {
        "use strict";

        var ENTITY_PATH = "/zce_zmb51n";

        return Controller.extend("zmb51nov4.controller.Detail", {
            onInit: function () {
                this.getOwnerComponent()
                    .getRouter()
                    .getRoute("detail")
                    .attachPatternMatched(this._onRouteMatched, this);

                var oModel = this.getOwnerComponent().getModel(),
                    oMetaModel = oModel.getMetaModel(),
                    oForm = this.byId("detailForm");

                metadataHelper
                    .requestFieldList(oMetaModel, ENTITY_PATH, "com.sap.vocabularies.UI.v1.LineItem")
                    .then(function (aFields) {
                        aFields.forEach(function (oField) {
                            oForm.addContent(new Label({ text: oField.label }));
                            oForm.addContent(new Text({ text: "{" + oField.name + "}" }));
                        });
                    })
                    .catch(function (oError) {
                        /* eslint-disable-next-line no-console */
                        console.error("Failed to load field metadata for " + ENTITY_PATH, oError);
                    });
            },

            // A plain bindElement({path}) does its own GET-by-key, which 500s on this backend
            // ("Multiple instances returned for entity ZCE_ZMB51N using given key" - the exposed
            // key (MaterialDocumentYear/MaterialDocument/MaterialDocumentItem/Nhom) isn't
            // actually unique). getKeepAliveContext instead reuses the SAME context the list row
            // already fetched (kept alive in onRowPress via $$getKeepAliveContext) - no second
            // request at all for the common case of navigating from a row that's on screen.
            //
            // It still falls back to a fresh read if no matching context exists (a deep link /
            // page reload straight into the Detail route, bypassing the list) - that read hits
            // the same backend bug, but requestObject().catch() now surfaces the failure instead
            // of leaving the form's Text controls silently empty next to their (static) Labels.
            _onRouteMatched: function (oEvent) {
                var sKey = decodeURIComponent(oEvent.getParameter("arguments").key),
                    oContext = this.getOwnerComponent().getModel().getKeepAliveContext("/" + sKey, false);

                this.getView().setBindingContext(oContext);
                oContext.requestObject().catch(
                    function (oError) {
                        /* eslint-disable-next-line no-console */
                        console.error("Failed to load material document details for /" + sKey, oError);
                        this._showLoadError();
                    }.bind(this)
                );
            },

            _showLoadError: function () {
                var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();
                if (oBundle && typeof oBundle.then === "function") {
                    oBundle.then(function (oResolvedBundle) {
                        MessageToast.show(oResolvedBundle.getText("detail.loadError"));
                    });
                } else {
                    MessageToast.show(oBundle.getText("detail.loadError"));
                }
            },

            onNavBack: function () {
                this.getOwnerComponent().getRouter().navTo("list");
            }
        });
    }
);
