sap.ui.define([
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
                this._aSelectedCtx = [];
            }
        },

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
                    controller: this
                }).then(function (oDialog) {
                    that._oDialog = oDialog;
                    oView.addDependent(oDialog);
                    that._resetDialog();
                    oDialog.open();
                }).catch(function (oError) {
                    MessageBox.error('Fragment load failed: ' + oError.message);
                });
            } else {
                this._resetDialog();
                this._oDialog.open();
            }
        },

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
            });
        }

    });
});