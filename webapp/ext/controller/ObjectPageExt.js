sap.ui.define([
    "zupdnttrp/ext/controller/ListReportExt"
], function (ListReportExt) {
    "use strict";

    /** Context của chứng từ đang mở ở Object Page ("this" = ExtensionAPI của Object Page) */
    function getDocumentContext(oExtensionAPI, oContext) {
        return oContext || (oExtensionAPI.getBindingContext && oExtensionAPI.getBindingContext());
    }

    return {
        /**
         * Check / Post ở màn hình chi tiết: dùng lại đúng logic của màn hình danh sách
         * (static action checkDocuments / postDocuments với 1 chứng từ), xong thì refresh trang.
         */
        onCheck: function (oContext) {
            const oDocContext = getDocumentContext(this, oContext);
            return ListReportExt.onCheck.call(this, oDocContext, oDocContext ? [oDocContext] : []);
        },

        onPost: function (oContext) {
            const oDocContext = getDocumentContext(this, oContext);
            return ListReportExt.onPost.call(this, oDocContext, oDocContext ? [oDocContext] : []);
        }
    };
});
