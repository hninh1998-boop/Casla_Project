sap.ui.define(['sap/ui/core/mvc/ControllerExtension',
	'sap/ui/export/Spreadsheet',
	'sap/m/MessageBox',
	'sap/m/MessageToast'
],
	function (ControllerExtension, Spreadsheet, MessageBox, MessageToast) {
		'use strict';

		return ControllerExtension.extend('zficc.ext.controller.CCExcelUploadExt', {
			// this section allows to extend lifecycle hooks or hooks provided by Fiori elements
			override: {
				/**
				 * Called when a controller is instantiated and its View controls (if available) are already created.
				 * Can be used to modify the View before it is displayed, to bind event handlers and do other one-time initialization.
				 * @memberOf zficc.ext.controller.CCExcelUploadExt
				 */
				onInit: function () {
					// you can access the Fiori elements extensionAPI via this.base.getExtensionAPI
					var oModel = this.base.getExtensionAPI().getModel();
					this.oServicePath = "/CostCenter/com.sap.gateway.srvd.zui_0226_cc.v0001.";
				},
				editFlow: {
					onAfterActionExecution: function (oEvent) {
						if (oEvent.split(".")[6] === 'downloadTemplate') {
							this.downloadTemplate();
						}
					}
				}
			},
			downloadTemplate: function (oDownload) {
				//1. Create the column required
				var oCol = [
					{ label: "Cost Center", property: "CostCenter", type: "string" },
					{ label: "Cost Center Group", property: "CostCenterGroup", type: "string" },
					{ label: "Valid To", property: "ValidTo", type: "string" },
					{ label: "Valid From", property: "ValidFrom", type: "string" },
					{ label: "Company Code", property: "CompanyCode", type: "string" },
					{ label: "Cost Center Type", property: "CostCenterType", type: "string" },
					{ label: "Name", property: "Name", type: "string" },
					{ label: "Person Responsible", property: "PersonResP", type: "string" },
					{ label: "Profit Center", property: "ProfitCenter", type: "string" }

				];
				//2. To prepare the setting for excel
				var oSettings = {
					workbook: { columns: oCol },
					dataSource: [{}],
					fileName: "Template.xlsx",
					showProgress: false
				}
				//3. To build the excel with settings
				var oSpreadsheet = new Spreadsheet(oSettings);
				//4. If build is success then show success message
				oSpreadsheet.build().then(function () {
					MessageToast.show('Template.xlsx downloaded Successfully')
					//5. If failed then catch the error and show error message
				}).catch(function (oError) {
					MessageBox.error(oError + "Download Failed")
					//6. Destroy the sheet
				}).finally(function () {
					oSpreadsheet.destroy();
				})
			},
			uploadexceldialog: function () {
				//1. Get this current view, where will add the pop up
				var oView = this.getView();
				//2.If pop up has not created we will create it using fragment
				if (!this.oDialog) {
					this.oDialog = sap.ui.core.Fragment.load({
						id: oView.getId(),
						controller: this,
						name: "zficc.ext.fragment.filedialog"
						//3. Else we will add the pop up to the view
					}).then(function (oDialog) {
						oView.addDependent(oDialog);
						return oDialog;
					})
				}

				//4. Now we will open the pop up
				this.oDialog.then(function (oDialog) {
					oDialog.open();
				})
			},
			onFileChange: function (oChange) {
				//1. Get the file
				//2. Check if it is defined or not
				var ofile = oChange.getParameters().files[0];
				//3. Separate the file type, mime type
				this.fileType = ofile.type;
				this.fileName = ofile.name;
				//4. Create new javascript file reader
				var that = this; // ✅ lưu lại context controller
				var ofilereader = new FileReader();
				//5. Once the file reading is finished, load the file and get the file content
				ofilereader.onload = function (oEvent) {
					//6. Save the content in a variable
					that.ofilecontent = oEvent.target.result.split(",")[1];
				};
				//7. Now read the file
				ofilereader.readAsDataURL(ofile);
			},
			onUploadPress: function () {
				this.oFileUploaderInput = this.base.getView().byId("idFileUpload");
				//1. Check if the file selected is defined or not
				if (this.ofilecontent === '' || this.ofilecontent === undefined) {
					//2. If not throw error
					MessageBox.error("Invalid File. Please Select a file to upload.");
				}
				//3. Get the model (odata V4 model)
				var oModel = this.base.getModel();
				//4. Create the binding context and set the parameter of action defined in metadata
				var oContext = oModel.bindContext(this.oServicePath + "uploadExcel(...)")
				// execute and send the file content to backend
				oContext.setParameter("mimeType", this.fileType);
				oContext.setParameter("fileName", this.fileName);
				oContext.setParameter("fileContent", this.ofilecontent);
				// if success then show success
				oContext.execute().then(function () {
					MessageToast.show("Excel Uploaded Successfully");
					this.base.getExtensionAPI().refresh(); // refresh the data
					this.oDialog.then(function (oDialog) {
						oDialog.close();
					});
					this.oFileUploaderInput.clear();
					this.ofilecontent = '';
					// if failed then show error
				}.bind(this)).catch(function (oError) {
					MessageBox.error(oError + ":Upload Failed");
					this.oDialog.then(function (oDialog) {
						oDialog.close();
					});
					this.oFileUploaderInput.clear();
					this.ofilecontent = '';
				}.bind(this))
			},
			onCancelUpload: function () {
				this.getView().byId("idFileUploadDialog").close();
			}
		});
	});
