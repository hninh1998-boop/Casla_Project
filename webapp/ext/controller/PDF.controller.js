sap.ui.define([
    './PdfViewerBase'
], function (createPdfViewerController) {
    'use strict';

    return createPdfViewerController('mfgordoperwc.ext.controller.PDF', {
        actionName: 'com.sap.gateway.srvd.zsd_mfgord_oper_wc.v0001.btnPrintPDF',
        fileNamePrefix: 'MFGORD_',
        getDedupeKey: function (oObject) {
            return oObject.ManufacturingOrder;
        }
    });
});
