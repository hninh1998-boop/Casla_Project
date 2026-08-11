sap.ui.define([
	'sap/ui/core/mvc/ControllerExtension',
	'sap/ui/core/Fragment',
	'sap/ui/model/json/JSONModel',
	'sap/ui/model/Filter',
	'sap/ui/model/FilterOperator',
	'sap/m/MessageToast'
], function (ControllerExtension, Fragment, JSONModel, Filter, FilterOperator, MessageToast) {
	'use strict';

	return ControllerExtension.extend('zhhdvov4.ext.controller.LayDuLieu', {
		// this section allows to extend lifecycle hooks or hooks provided by Fiori elements
		override: {
			/**
             * Called when a controller is instantiated and its View controls (if available) are already created.
             * Can be used to modify the View before it is displayed, to bind event handlers and do other one-time initialization.
             * @memberOf zhhdvov4.ext.controller.LayDuLieu
             */
			onInit: function () {
				// you can access the Fiori elements extensionAPI via this.base.getExtensionAPI
				var oModel = this.base.getExtensionAPI().getModel();
			}
		},

		/**
         * Generated event handler.
         *
         * @param oContext the context of the page on which the event was fired. `undefined` for list report page.
         * @param aSelectedContexts the selected contexts of the table rows.
         */
		idLayDuLieu: async function (oContext, aSelectedContexts) {
			if (!this._oLayDuLieuDialog) {
				this._oLayDuLieuDialog = await this.base.getExtensionAPI().loadFragment({
					id: 'idLayDuLieuDialog',
					name: 'zhhdvov4.ext.fragment.LayDuLieu',
					controller: this
				});
			}
			this._openLayDuLieuDialog();
		},

		_openLayDuLieuDialog: function () {
			var oModel = new JSONModel({
				CompanyCode: '',
				StartDate: null,
				EndDate: null
			});
			this._oLayDuLieuDialog.setModel(oModel, 'layDuLieuModel');
			this._oLayDuLieuDialog.open();
		},

		onLyButtonPress: async function () {
			var sCompanyCode = Fragment.byId('idLayDuLieuDialog', 'idCompanyCodeInput').getValue();
			var sStartDate = Fragment.byId('idLayDuLieuDialog', 'idStartDateDatePicker').getValue();
			var sEndDate = Fragment.byId('idLayDuLieuDialog', 'idEndDateDatePicker').getValue();

			if (!sCompanyCode || !sStartDate || !sEndDate) {
				MessageToast.show('Vui lòng nhập đủ Company code, Start date, End date.');
				return;
			}

			var oModel = this.base.getExtensionAPI().getModel();
			var oHeaderContext = oModel.bindList('/HHDVHead').getHeaderContext();
			var oOperation = oModel.bindContext(
				'com.sap.gateway.srvd.zui_hhdv.v0001.LayDuLieu(...)',
				oHeaderContext
			);

			oOperation.setParameter('CompanyCode', sCompanyCode);
			oOperation.setParameter('StartDate', sStartDate);
			oOperation.setParameter('EndDate', sEndDate);

			this._oLayDuLieuDialog.setBusy(true);

			try {
				await oOperation.invoke();
				MessageToast.show('Lấy dữ liệu thành công.');
				this._oLayDuLieuDialog.close();

				this.base.getExtensionAPI().refresh();
			} catch (oError) {
				MessageToast.show('Lấy dữ liệu thất bại: ' + (oError && oError.message ? oError.message : ''));
			} finally {
				this._oLayDuLieuDialog.setBusy(false);
			}
		},

		onNgButtonPress: function () {
			this._oLayDuLieuDialog.close();
		},

		/**
         * Generated event handler.
         *
         * @param oContext the context of the page on which the event was fired. `undefined` for list report page.
         * @param aSelectedContexts the selected contexts of the table rows.
         */
		idUdtInvoiceStatus: async function (oContext, aSelectedContexts) {
			if (!this._oUdtInvoiceStatusDialog) {
				this._oUdtInvoiceStatusDialog = await this.base.getExtensionAPI().loadFragment({
					id: 'idUdtInvoiceStatusDialog',
					name: 'zhhdvov4.ext.fragment.UdtInvoiceStatus',
					controller: this
				});
			}
			this._openUdtInvoiceStatusDialog();
		},

		_openUdtInvoiceStatusDialog: function () {
			var oModel = new JSONModel({
				StartDate: null,
				EndDate: null
			});
			this._oUdtInvoiceStatusDialog.setModel(oModel, 'udtInvoiceStatusModel');
			this._oUdtInvoiceStatusDialog.open();
		},

		onCapNhatButtonPress: async function () {
			var sStartDate = Fragment.byId('idUdtInvoiceStatusDialog', 'idUdtStartDateDatePicker').getValue();
			var sEndDate = Fragment.byId('idUdtInvoiceStatusDialog', 'idUdtEndDateDatePicker').getValue();

			if (!sStartDate || !sEndDate) {
				MessageToast.show('Vui lòng nhập đủ Start date, End date.');
				return;
			}

			var oModel = this.base.getExtensionAPI().getModel();
			var oHeaderContext = oModel.bindList('/HHDVHead').getHeaderContext();
			var oOperation = oModel.bindContext(
				'com.sap.gateway.srvd.zui_hhdv.v0001.UdtInvoiceStatus(...)',
				oHeaderContext
			);

			oOperation.setParameter('StartDate', sStartDate);
			oOperation.setParameter('EndDate', sEndDate);

			this._oUdtInvoiceStatusDialog.setBusy(true);

			try {
				await oOperation.invoke();
				MessageToast.show('Cập nhật trạng thái thành công.');
				this._oUdtInvoiceStatusDialog.close();

				this.base.getExtensionAPI().refresh();
			} catch (oError) {
				MessageToast.show('Cập nhật trạng thái thất bại: ' + (oError && oError.message ? oError.message : ''));
			} finally {
				this._oUdtInvoiceStatusDialog.setBusy(false);
			}
		},

		onUdtDongButtonPress: function () {
			this._oUdtInvoiceStatusDialog.close();
		},

		onCompanyCodeInputValueHelpRequest: async function () {
			if (!this._oCompanyCodeVHDialog) {
				this._oCompanyCodeVHDialog = await this.base.getExtensionAPI().loadFragment({
					id: 'idCompanyCodeVHDialog',
					name: 'zhhdvov4.ext.fragment.CompanyCodeValueHelp',
					controller: this
				});
			}
			this._oCompanyCodeVHDialog.open();
		},

		onSearchFieldLiveChange: function (oEvent) {
			var sQuery = oEvent.getParameter('newValue');
			var oTable = Fragment.byId('idCompanyCodeVHDialog', 'idCompanyCodeVHTable');
			var oBinding = oTable.getBinding('items');

			if (!sQuery) {
				oBinding.filter([]);
				return;
			}

			oBinding.filter(new Filter({
				filters: [
					new Filter('CompanyCode', FilterOperator.Contains, sQuery),
					new Filter('CompanyCodeName', FilterOperator.Contains, sQuery)
				],
				and: false
			}));
		},

		onColumnListItemPress: function (oEvent) {
			var oCtx = oEvent.getSource().getBindingContext();
			var sCompanyCode = oCtx.getProperty('CompanyCode');

			this._oLayDuLieuDialog.getModel('layDuLieuModel').setProperty('/CompanyCode', sCompanyCode);
			this._oCompanyCodeVHDialog.close();
		},

		onNgButtonVHPress: function () {
			this._oCompanyCodeVHDialog.close();
		}
	});
});
