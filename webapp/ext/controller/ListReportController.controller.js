sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension"
], function (ControllerExtension) {
    "use strict";

    const LIST_ROUTE = "DnttListList";

    return ControllerExtension.extend("zupdnttrp.ext.controller.ListReportController", {
        override: {
            /**
             * Danh sách (DnttList) và màn hình chi tiết (DnttHead) là 2 entity khác nhau nên Fiori
             * không tự tải lại danh sách sau khi Check / Post / Edit / Delete ở màn hình chi tiết
             * -> quay về danh sách thì refresh.
             */
            onInit: function () {
                const oRoute = this.base.getAppComponent().getRouter().getRoute(LIST_ROUTE);
                if (oRoute) {
                    oRoute.attachPatternMatched(() => {
                        if (this._bOpenedDetail) {
                            this._bOpenedDetail = false;
                            this.base.getExtensionAPI().refresh();
                        }
                    });
                }
            },

            routing: {
                /**
                 * Danh sách đọc từ custom entity DnttList (1 dòng / chứng từ),
                 * màn hình chi tiết dùng BO draft DnttHead (có item + Edit/Save/Cancel)
                 * -> chuyển context DnttList sang DnttHead (bản active).
                 */
                onBeforeNavigation: function (mNavigationParameters) {
                    const oContext = mNavigationParameters && mNavigationParameters.bindingContext;
                    if (!oContext || !oContext.getPath().startsWith("/DnttList")) {
                        return false;
                    }

                    const sDocNo = oContext.getProperty("DocumentSequenceNo").replace(/'/g, "''");
                    const oHeadContext = oContext.getModel()
                        .bindContext(`/DnttHead(DocumentSequenceNo='${sDocNo}',IsActiveEntity=true)`)
                        .getBoundContext();

                    this._bOpenedDetail = true; // quay về danh sách sẽ refresh
                    this.base.getExtensionAPI().routing.navigate(oHeadContext);
                    return true; // chặn navigation mặc định sang DnttList(...)
                }
            }
        }
    });
});
