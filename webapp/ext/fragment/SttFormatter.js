sap.ui.define([], function () {
    "use strict";

    return {
        /**
         * Gán STT (1..n) cho ô của cột STT theo vị trí dòng trong list binding.
         * GridTable gán lại context cho từng dòng mỗi khi cuộn trang / lọc / sắp xếp / xoá dòng
         * -> event modelContextChange chạy lại -> STT luôn đúng thứ tự đang hiển thị.
         * @param {sap.ui.base.Event} oEvent modelContextChange của control Text
         */
        onContextChange: function (oEvent) {
            const oText = oEvent.getSource();
            const iIndex = oText.getBindingContext()?.getIndex?.();
            oText.setText(typeof iIndex === "number" && iIndex >= 0 ? String(iIndex + 1) : "");
        }
    };
});
