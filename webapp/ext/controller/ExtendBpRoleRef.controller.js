sap.ui.define([
<<<<<<< HEAD
    'sap/ui/core/mvc/ControllerExtension',
    'sap/ui/core/Fragment',
    'sap/m/MessageToast',
    'sap/m/MessageBox'
], function (ControllerExtension, Fragment, MessageToast, MessageBox) {
    'use strict';

    var NS = 'com.sap.gateway.srvd.zui_bp_ext_role_ref.v0001.extendBpRoleRef(...)';

    return ControllerExtension.extend('zextendbproleref.ext.controller.ExtendBpRoleRef', {

        override: {
            onInit: function () {
                this._oDialog      = null;
=======
    "sap/ui/core/mvc/ControllerExtension",
    "sap/ui/core/Fragment",
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (ControllerExtension, Fragment, MessageToast, MessageBox) {
    "use strict";

    var ACTION_NS = "com.sap.gateway.srvd.zui_bp_ext_role_ref.v0001.extendBpRoleRef(...)";

    return ControllerExtension.extend("zextendbproleref.ext.controller.ExtendBpRoleRef", {

        override: {
            onInit: function () {
                this._oDialog = null;
>>>>>>> bf875ca (Tool Extend BP with Reference)
                this._aSelectedCtx = [];
            }
        },

<<<<<<< HEAD
        // ── Button press từ manifest ───────────────────────────────────
        extendBpRoleRef: function () {
            var oView = this.base.getView();
            var that  = this;

            // Lấy selected rows ngay lúc mở dialog
            this._aSelectedCtx = this.base.getExtensionAPI().getSelectedContexts();

            if (!this._aSelectedCtx || this._aSelectedCtx.length === 0) {
                MessageBox.error('Vui lòng chọn ít nhất 1 dòng.');
                return;
            }

            if (!this._oDialog) {
                Fragment.load({
                    id:         oView.getId(),
                    name:       'zextendbproleref.ext.fragment.ExtendRoleDialog',
=======
        extendBpRoleRef: function () {
            var oView = this.base.getView();
            var that = this;

            this._aSelectedCtx = this.base.getExtensionAPI().getSelectedContexts();

            if (!this._oDialog) {
                Fragment.load({
                    id: oView.getId(),
                    name: "zextendbproleref.ext.fragment.extendRoleDialog",
>>>>>>> bf875ca (Tool Extend BP with Reference)
                    controller: this
                }).then(function (oDialog) {
                    that._oDialog = oDialog;
                    oView.addDependent(oDialog);
                    that._resetDialog();
                    oDialog.open();
                }).catch(function (oError) {
<<<<<<< HEAD
                    MessageBox.error('Fragment load failed: ' + oError.message);
=======
                    MessageBox.error("Fragment load failed: " + oError.message);
>>>>>>> bf875ca (Tool Extend BP with Reference)
                });
            } else {
                this._resetDialog();
                this._oDialog.open();
            }
        },

<<<<<<< HEAD
        // ── Reset dialog ──────────────────────────────────────────────
        _resetDialog: function () {
            var sId = this.base.getView().getId();
            Fragment.byId(sId, 'inputRefBP').setValue('');
            Fragment.byId(sId, 'inputRefCC').setValue('');
            Fragment.byId(sId, 'cbFLCU01').setSelected(true);
            Fragment.byId(sId, 'cbFLCU00').setSelected(true);
            Fragment.byId(sId, 'cbFLVN01').setSelected(false);
            Fragment.byId(sId, 'cbFLVN00').setSelected(false);
        },

        // ── Đóng dialog ───────────────────────────────────────────────
        onCloseDialog: function () {
            this._oDialog.close();
        },

        // ── Gọi instance action cho từng selected row ──────────────────
        onExtendRole: function () {
            var sId     = this.base.getView().getId();
            var sRefBP  = Fragment.byId(sId, 'inputRefBP').getValue();
            var sRefCC  = Fragment.byId(sId, 'inputRefCC').getValue();
            var bFLCU01 = Fragment.byId(sId, 'cbFLCU01').getSelected();
            var bFLCU00 = Fragment.byId(sId, 'cbFLCU00').getSelected();
            var bFLVN01 = Fragment.byId(sId, 'cbFLVN01').getSelected();
            var bFLVN00 = Fragment.byId(sId, 'cbFLVN00').getSelected();

            // ── Validate ───────────────────────────────────────────────
            if (!sRefBP) {
                MessageBox.error('Vui lòng nhập Reference Business Partner.');
                return;
            }
            if (!sRefCC) {
                MessageBox.error('Vui lòng nhập Reference Company Code.');
                return;
            }
            if (!bFLCU01 && !bFLCU00 && !bFLVN01 && !bFLVN00) {
                MessageBox.error('Vui lòng chọn ít nhất 1 role.');
                return;
            }

            var oModel   = this.base.getView().getModel();
            var that     = this;
            var aPromises = [];

            // ── Loop từng selected row ─────────────────────────────────
            this._aSelectedCtx.forEach(function (oCtx) {
                var sTargetBP = oCtx.getProperty('BusinessPartner');
                var sTargetCC = oCtx.getProperty('OrgCode');

                var oContext = oModel.bindContext( NS, oCtx );

                oContext.setParameter('TargetBusinessPartner',    sTargetBP);
                oContext.setParameter('TargetCompanyCode',        sTargetCC);
                oContext.setParameter('ReferenceBusinessPartner', sRefBP);
                oContext.setParameter('ReferenceCompanyCode',     sRefCC);
                oContext.setParameter('ExtendFLCU01',             bFLCU01);
                oContext.setParameter('ExtendFLCU00',             bFLCU00);
                oContext.setParameter('ExtendFLVN01',             bFLVN01);
                oContext.setParameter('ExtendFLVN00',             bFLVN00);

                aPromises.push( oContext.execute() );
            });

            Promise.all(aPromises).then(function () {
                MessageToast.show(
                    'Extend role thành công ' + that._aSelectedCtx.length + ' dòng!'
                );
                that.base.getExtensionAPI().refresh();
                that._oDialog.close();
            }).catch(function (oError) {
                MessageBox.error('Extend role thất bại: ' + oError.message);
=======
        _resetDialog: function () {
            var sId = this.base.getView().getId();
            var aBPs = [];

            this._aSelectedCtx.forEach(function (oCtx) {
                var sBP = oCtx.getProperty("TargetBusinessPartner");
                if (sBP) { aBPs.push(sBP); }
            });

            Fragment.byId(sId, "inputTargetBPs").setValue(aBPs.join(","));
            Fragment.byId(sId, "inputRefBP").setValue("");
            Fragment.byId(sId, "inputRefCC").setValue("");
            Fragment.byId(sId, "cbFLCU01").setSelected(false);
            Fragment.byId(sId, "cbFLCU00").setSelected(false);
            Fragment.byId(sId, "cbFLVN01").setSelected(false);
            Fragment.byId(sId, "cbFLVN00").setSelected(false);
        },

        onCloseDialog: function () {
            if (this._oDialog) { this._oDialog.close(); }
        },

        onExtendRole: function () {
            var sId = this.base.getView().getId();
            var sTargetBPs = Fragment.byId(sId, "inputTargetBPs").getValue().trim();
            var sRefBP = Fragment.byId(sId, "inputRefBP").getValue().trim();
            var sRefCC = Fragment.byId(sId, "inputRefCC").getValue().trim();
            var bFLCU01 = Fragment.byId(sId, "cbFLCU01").getSelected();
            var bFLCU00 = Fragment.byId(sId, "cbFLCU00").getSelected();
            var bFLVN01 = Fragment.byId(sId, "cbFLVN01").getSelected();
            var bFLVN00 = Fragment.byId(sId, "cbFLVN00").getSelected();
            var bAll = Fragment.byId(sId, "cbAll").getSelected();

            if (!sTargetBPs) {
                MessageBox.error("Vui lòng nhập ít nhất 1 Target BP.");
                return;
            }
            if (!sRefBP) {
                MessageBox.error("Vui lòng nhập Reference BP.");
                return;
            }
            if (!bFLCU01 && !bFLCU00 && !bFLVN01 && !bFLVN00 && !bAll) {
                MessageBox.error("Vui lòng chọn ít nhất 1 check box");
                return;
            }

            // ── Bound action trên collection header context ─────────────
            var oModel = this.base.getView().getModel();
            var oListBinding = oModel.bindList("/ExtendBpRoleRef");
            var oHeaderCtx = oListBinding.getHeaderContext();
            var oContext = oModel.bindContext(ACTION_NS, oHeaderCtx);

            //Tên parameter khớp đúng với metadata
            oContext.setParameter("TargetBusinessPartner", sTargetBPs);  //singular
            oContext.setParameter("ReferenceBusinessPartner", sRefBP);
            oContext.setParameter("ReferenceCompanyCode", sRefCC);
            oContext.setParameter("ExtendFLCU01", bFLCU01);
            oContext.setParameter("ExtendFLCU00", bFLCU00);
            oContext.setParameter("ExtendFLVN01", bFLVN01);
            oContext.setParameter("ExtendFLVN00", bFLVN00);
            oContext.setParameter("ExtendAll", bAll);

            var that = this;
            var iCount = sTargetBPs.split(",").filter(Boolean).length;

            oContext.execute().then(function () {
                // MessageToast.show("Extend role thành công cho " + iCount + " BP!");
                MessageToast.show("Done!");
                that.base.getExtensionAPI().refresh();
                that._oDialog.close();
            }).catch(function (oError) {
                MessageBox.error("Extend role thất bại: " + oError.message);
>>>>>>> bf875ca (Tool Extend BP with Reference)
            });
        }

    });
});