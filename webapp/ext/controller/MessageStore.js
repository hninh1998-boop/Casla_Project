sap.ui.define([], function () {
    "use strict";

    // Cancel Item messages per row (key = context path). The backend does not persist them,
    // so the object page gets them from here. Lives until the list is refreshed (Go).
    const mMessages = new Map();

    return {
        set: function (sPath, oMessage) {
            mMessages.set(sPath, oMessage);
        },
        get: function (sPath) {
            return mMessages.get(sPath);
        },
        clear: function () {
            mMessages.clear();
        }
    };
});
