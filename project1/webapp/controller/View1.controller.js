sap.ui.define([
    "sap/ui/core/mvc/Controller"
], (Controller) => {
    "use strict";

    return Controller.extend("project1.controller.View1", {
        onInit() {
        },

        onBeforeExport(oEvent) {
            const mExcelSettings = oEvent.getParameter("exportSettings");

            if (mExcelSettings.url) {
                return;
            }

            mExcelSettings.worker = false;
        }
    });
});
