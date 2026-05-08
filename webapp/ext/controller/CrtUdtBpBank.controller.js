sap.ui.define([
	"sap/ui/core/mvc/ControllerExtension",
	"sap/ui/model/json/JSONModel",
	"sap/ui/core/Fragment",
	"sap/m/MessageToast",
	"sap/m/MessageBox",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator"
], function (ControllerExtension, JSONModel, Fragment, MessageToast, MessageBox, Filter, FilterOperator) {
	"use strict";

	var NS_CREATE = "com.sap.gateway.srvd.zui_bp_bank_account.v0001.createBpBank(...)";
	var NS_UPDATE = "com.sap.gateway.srvd.zui_bp_bank_account.v0001.updateBpBank(...)";

	return ControllerExtension.extend("zudtbpbank.ext.controller.CrtUdtBpBank", {

		override: {
			onInit: function () {
				this._oCreateDialog = null;
				this._oUpdateDialog = null;
				this._oUpdateContext = null;
				this._oCreateModel = null;
				this._oUpdateModel = null;
				this.base.getView().setModel(new JSONModel({ items: [] }), "maBPModel");
			}
		},
		// ── Helper: fetch BankName + Branch theo BankKey ─────────
		// _fetchBankInfo: function (sBankKey, oModel) {
		// 	if (!sBankKey) {
		// 		oModel.setProperty("/BankName", "");
		// 		oModel.setProperty("/BankBranch", "");
		// 		oModel.setProperty("/BankCountry", "");
		// 		return;
		// 	}

		// 	// BankCountry luôn có trong response dù không $select
		// 	var sUrl = "/sap/opu/odata4/sap/api_bank/srvd_a2x/sap/api_bank/0001/Bank"
		// 		+ "?$filter=BankInternalID eq '" + sBankKey + "'"
		// 		+ "&$select=BankInternalID,BankName,Branch"
		// 		+ "&$top=1";

		// 	fetch(sUrl, { headers: { "Accept": "application/json" } })
		// 		.then(function (oRes) { return oRes.json(); })
		// 		.then(function (oData) {
		// 			var aResults = oData.value || [];
		// 			if (aResults.length > 0) {
		// 				oModel.setProperty("/BankName", aResults[0].BankName || "");
		// 				oModel.setProperty("/BankBranch", aResults[0].Branch || "");
		// 				oModel.setProperty("/BankCountry", aResults[0].BankCountry || ""); // ← tự có trong response
		// 			} else {
		// 				oModel.setProperty("/BankName", "");
		// 				oModel.setProperty("/BankBranch", "");
		// 				oModel.setProperty("/BankCountry", "");
		// 			}
		// 		})
		// 		.catch(function () {
		// 			oModel.setProperty("/BankName", "");
		// 			oModel.setProperty("/BankBranch", "");
		// 			oModel.setProperty("/BankCountry", "");
		// 		});
		// },

		// ── CREATE ───────────────────────────────────────────────
		onCreateBankPress: function () {
			var oView = this.base.getView();
			var that = this;

			var oCreateData = {
				MaBP: "",
				BankKey: "",
				CR: "",   // ← để trống, user sẽ nhập BankKey rồi backend tự resolve
				BankName: "",
				BankBranch: "",
				BankAccount: "",
				ExtID: "",
				AccountHolderName: "",
				AccountName: ""
			};

			var oCreateModel = new JSONModel(oCreateData);
			oView.setModel(oCreateModel, "createModel");
			this._oCreateModel = oCreateModel;

			if (!this._oCreateDialog) {
				Fragment.load({
					id: oView.getId(),
					name: "zudtbpbank.ext.fragment.CreateBankDialog",
					controller: this
				}).then(function (oDialog) {
					that._oCreateDialog = oDialog;
					oView.addDependent(oDialog);
					oDialog.open();
				}).catch(function (oError) {
					MessageBox.error("Fragment load failed: " + oError.message);
				});
			} else {
				this._oCreateDialog.open();
			}
		},

		onCreateBankConfirm: function () {
			var oView = this.base.getView();
			var oModel = oView.getModel();
			var oData = this._oCreateModel.getData();
			var that = this;

			var oListBinding = oModel.bindList("/UdtBpBank");
			var oHeaderCtx = oListBinding.getHeaderContext();
			var oContext = oModel.bindContext(NS_CREATE, oHeaderCtx);

			oContext.setParameter("MaBP", oData.MaBP);
			oContext.setParameter("BankKey", oData.BankKey);
			oContext.setParameter("BankName", oData.BankName);
			oContext.setParameter("BankBranch", oData.BankBranch);   // ← thêm
			oContext.setParameter("BankAccount", oData.BankAccount);
			oContext.setParameter("ExtID", oData.ExtID);
			oContext.setParameter("AccountHolderName", oData.AccountHolderName);
			oContext.setParameter("AccountName", oData.AccountName);

			oContext.execute().then(function () {
				MessageToast.show("Tạo bank account thành công!");
				that.base.getExtensionAPI().refresh();
				that._oCreateDialog.close();
			}).catch(function (oError) {
				MessageBox.error("Lỗi tạo bank account:\n" + oError.message);
			});
		},

		onCreateBankCancel: function () {
			if (this._oCreateDialog) { this._oCreateDialog.close(); }
		},

		// ── UPDATE ───────────────────────────────────────────────
		onUpdateBankPress: function () {
			var oView = this.base.getView();
			var that = this;
			var aContexts = this.base.getExtensionAPI().getSelectedContexts();

			if (!aContexts || aContexts.length === 0) {
				MessageBox.error("Vui lòng chọn 1 dòng để update.");
				return;
			}

			this._oUpdateContext = aContexts[0];
			var oRowData = this._oUpdateContext.getObject();

			var oUpdateData = {
				MaBP: oRowData.MaBP,
				ID: oRowData.ID,
				BankKey: oRowData.BankKey,
				CR: oRowData.CR,        // ← lấy đúng từ row, không default
				BankName: "",   // sẽ fetch bên dưới
				BankBranch: "",   // sẽ fetch bên dưới
				BankCountry: "",                    // ← thêm, _fetchBankInfo sẽ fill
				BankAccount: oRowData.BankAccount,
				ExtID: oRowData.ExtID,
				AccountHolderName: oRowData.AccountHolderName,
				AccountName: oRowData.AccountName
			};

			var oUpdateModel = new JSONModel(oUpdateData);
			oView.setModel(oUpdateModel, "updateModel");
			this._oUpdateModel = oUpdateModel;

			// Fetch BankName + Branch ngay khi mở dialog
			this._fetchBankInfoFromBackend(oRowData.BankKey, oUpdateModel);

			if (!this._oUpdateDialog) {
				Fragment.load({
					id: oView.getId(),
					name: "zudtbpbank.ext.fragment.UpdateBankDialog",
					controller: this
				}).then(function (oDialog) {
					that._oUpdateDialog = oDialog;
					oView.addDependent(oDialog);
					oDialog.open();
				}).catch(function (oError) {
					MessageBox.error("Fragment load failed: " + oError.message);
				});
			} else {
				this._oUpdateDialog.open();
			}
		},

		onUpdateBankConfirm: function () {
			var oData = this._oUpdateModel.getData();
			var that = this;

			var oContext = this._oUpdateContext.getModel().bindContext(
				NS_UPDATE,
				this._oUpdateContext
			);

			oContext.setParameter("MaBP", oData.MaBP);
			oContext.setParameter("BankKey", oData.BankKey);
			oContext.setParameter("BankName", oData.BankName);
			oContext.setParameter("BankBranch", oData.BankBranch);   // ← thêm
			oContext.setParameter("BankCountry", oData.BankCountry);  // ← thêm
			oContext.setParameter("BankAccount", oData.BankAccount);
			oContext.setParameter("ExtID", oData.ExtID);
			oContext.setParameter("AccountHolderName", oData.AccountHolderName);
			oContext.setParameter("AccountName", oData.AccountName);

			oContext.execute().then(function () {
				MessageToast.show("Cập nhật thành công!");
				that.base.getExtensionAPI().refresh();
				that._oUpdateDialog.close();
			}).catch(function (oError) {
				MessageBox.error("Lỗi cập nhật:\n" + oError.message);
			});
		},

		onUpdateBankCancel: function () {
			if (this._oUpdateDialog) { this._oUpdateDialog.close(); }
		},

		// ── onBankKeyChange ──────────────────────────────────────
		onBankKeyChange: function (oEvent) {
			var oSource = oEvent.getSource();
			var sBankKey = oEvent.getParameter("value");
			var sId = oSource.getId();
			var oModel = sId.indexOf("crt_") !== -1
				? this._oCreateModel
				: this._oUpdateModel;

			if (!oModel) { return; }

			this._fetchBankInfoFromBackend(sBankKey, oModel);
		},

		// ── onCheckBankKey ────────────────────────────────────────
		onCheckBankKey: function (oEvent) {
			var oSource = oEvent.getSource();
			var sId = oSource.getId();
			var oModel = sId.indexOf("crt_") !== -1
				? this._oCreateModel
				: this._oUpdateModel;

			if (!oModel) { return; }

			var sBankKey = oModel.getProperty("/BankKey");

			if (!sBankKey) {
				MessageBox.warning("Vui lòng nhập Bank Key trước.");
				return;
			}

			this._fetchBankInfoFromBackend(sBankKey, oModel);
		},

		// ── Fetch via RAP static function (dùng technical user ở backend) ──
		_fetchBankInfoFromBackend: function (sBankKey, oModel) {
			var oODataModel = this.base.getView().getModel();
			var sCR = oModel.getProperty("/CR") || "";
			// Bound function → phải bind vào header context của list
			var oListBinding = oODataModel.bindList("/UdtBpBank");
			var oHeaderCtx = oListBinding.getHeaderContext();

			var oCtx = oODataModel.bindContext(
				"com.sap.gateway.srvd.zui_bp_bank_account.v0001.getBankInfo(...)",
				oHeaderCtx
			);

			oCtx.setParameter("BankKey", sBankKey);
			oCtx.setParameter("CR", sCR);

			oCtx.execute().then(function () {
				var oResult = oCtx.getBoundContext().getObject();
				console.log("getBankInfo result:", JSON.stringify(oResult));

				// Kiểm tra BankName có giá trị không
				if (!oResult.BankName && !oResult.BankBranch) {
					MessageBox.error(
						"Bank Key '" + sBankKey + "' không tồn tại trên hệ thống."
					);
					oModel.setProperty("/BankName", "");
					oModel.setProperty("/BankBranch", "");
					oModel.setProperty("/BankCountry", "");
					return;
				}

				oModel.setProperty("/BankName", oResult.BankName || "");
				oModel.setProperty("/BankBranch", oResult.BankBranch || "");
				oModel.setProperty("/BankCountry", oResult.BankCountry || "");
				MessageToast.show("Đã lấy thông tin ngân hàng.");
			}).catch(function (oErr) {
				console.error("getBankInfo failed:", oErr);
				MessageBox.error("Không lấy được thông tin ngân hàng:\n" + oErr.message);
			});
		},
	});
});