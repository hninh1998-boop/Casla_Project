sap.ui.define([
  "sap/ui/core/mvc/ControllerExtension"
], function (ControllerExtension) {
  "use strict";

  return ControllerExtension.extend("zmultitabchk.ext.controller.ListReportExt", {
    override: {
      onInit: function () {
        var oView = this.base.getView();

        var oSegmentedButton = oView.byId(
          "template::SegmentedButton"
        );

        if (oSegmentedButton) {
          oSegmentedButton.attachSelect(this.onTabSelect.bind(this));
        } else {
          jQuery.sap.log.warning("SegmentedButton not found - check ID");
        }
      }
    },

    onTabSelect: function (oEvent) {
      var oView = this.base.getView();
      var sKey = oEvent.getParameter("key"); // "HeaderVariant" / "ItemVariant"

      var oSmartTable = oView.byId("listReport");

      var sEntitySet = (sKey === "ItemVariant")
        ? "zi_m_crud_poc_chk"
        : "zi_m_crt_batch_chk";

      if (oSmartTable && oSmartTable.getEntitySet() !== sEntitySet) {
        oSmartTable.setEntitySet(sEntitySet);
        oSmartTable.rebindTable();
      }
    }
  });
});