sap.ui.define(["sap/m/MessageBox", "sap/m/MessageToast", "sap/ui/core/Messaging"], function (MessageBox, MessageToast, Messaging) {
  "use strict";

  const ENTITY_SET = "/zc_MASSCHANGE_PRODUCT_ORDER";
  const ACTION_NAMESPACE = "com.sap.gateway.srvd.zsd_masschange_product_order.v0001";

  // Field names of ZI_FILE_ABS (parameters of ExcelUpload, result of DownloadTemplate)
  const FILE_FIELDS = {
    content: "fileContent",
    name: "fileName",
    mimeType: "mimeType",
    extension: "fileExtension"
  };

  const DOWNLOAD_PARAMETER = "json_string";

  const XLSX_MIME_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

  function getText(oExtensionAPI, sKey) {
    return oExtensionAPI.getModel("i18n").getResourceBundle().getText(sKey);
  }

  function invokeStaticAction(oModel, sAction, mParameters) {
    const oOperation = oModel.bindContext(ENTITY_SET + "/" + ACTION_NAMESPACE + "." + sAction + "(...)");
    Object.keys(mParameters).forEach(function (sName) {
      oOperation.setParameter(sName, mParameters[sName]);
    });
    // invoke() replaces execute() as of UI5 1.123
    const pInvoked = oOperation.invoke ? oOperation.invoke() : oOperation.execute();
    return pInvoked.then(function () {
      return oOperation.getBoundContext();
    });
  }

  function pickFile() {
    return new Promise(function (resolve) {
      const oInput = document.createElement("input");
      oInput.type = "file";
      oInput.accept = ".xlsx,.xls";
      oInput.onchange = function () {
        resolve(oInput.files[0]);
      };
      oInput.click();
    });
  }

  function readAsBase64(oFile) {
    return new Promise(function (resolve, reject) {
      const oReader = new FileReader();
      oReader.onload = function () {
        resolve(oReader.result.split(",")[1]);
      };
      oReader.onerror = reject;
      oReader.readAsDataURL(oFile);
    });
  }

  // OData V4 transports Edm.Binary as base64url
  function toBase64Url(sBase64) {
    return sBase64.replace(/\+/g, "-").replace(/\//g, "_");
  }

  function fromBase64Url(sBase64Url) {
    return sBase64Url.replace(/-/g, "+").replace(/_/g, "/");
  }

  function saveFile(sBase64, sFileName, sMimeType) {
    const sBinary = atob(sBase64);
    const aBytes = new Uint8Array(sBinary.length);
    for (let i = 0; i < sBinary.length; i++) {
      aBytes[i] = sBinary.charCodeAt(i);
    }
    const sUrl = URL.createObjectURL(new Blob([aBytes], { type: sMimeType }));
    const oLink = document.createElement("a");
    oLink.href = sUrl;
    oLink.download = sFileName;
    oLink.click();
    URL.revokeObjectURL(sUrl);
  }

  // The handler deserializes json_string into a table of { manufacturingorder }
  function buildDownloadJson(aContexts) {
    return JSON.stringify(
      aContexts.map(function (oContext) {
        return { ManufacturingOrder: oContext.getProperty("ManufacturingOrder") };
      })
    );
  }

  // The backend returns the file name without extension
  function buildFileName(oFile) {
    const sName = oFile[FILE_FIELDS.name] || "Template";
    const sExtension = oFile[FILE_FIELDS.extension] || "xlsx";
    return sName.toLowerCase().endsWith("." + sExtension.toLowerCase()) ? sName : sName + "." + sExtension;
  }

  function getMessages() {
    return Messaging.getMessageModel().getData().slice();
  }

  // Returns the messages raised since aOldMessages was taken and removes them from the
  // message model, so they are not shown a second time by a later action.
  function takeNewMessages(aOldMessages) {
    const aNewMessages = getMessages().filter(function (oMessage) {
      return aOldMessages.indexOf(oMessage) === -1;
    });
    Messaging.removeMessages(aNewMessages);
    return aNewMessages;
  }

  function joinMessages(aMessages) {
    return aMessages
      .map(function (oMessage) {
        return oMessage.getMessage();
      })
      .join("\n");
  }

  function showError(oError) {
    MessageBox.error((oError && oError.message) || String(oError));
  }

  return {
    /**
     * "Update TT LSX": uploads an Excel file through static action ExcelUpload.
     */
    onExcelUpload: function () {
      const oExtensionAPI = this;
      let aOldMessages = [];

      pickFile()
        .then(function (oFile) {
          return readAsBase64(oFile).then(function (sBase64) {
            const iDot = oFile.name.lastIndexOf(".");
            const mParameters = {};
            mParameters[FILE_FIELDS.content] = toBase64Url(sBase64);
            mParameters[FILE_FIELDS.name] = oFile.name;
            mParameters[FILE_FIELDS.mimeType] = oFile.type || XLSX_MIME_TYPE;
            mParameters[FILE_FIELDS.extension] = iDot > -1 ? oFile.name.slice(iDot + 1) : "";
            aOldMessages = getMessages();
            return invokeStaticAction(oExtensionAPI.getModel(), "ExcelUpload", mParameters);
          });
        })
        .then(function () {
          // Some backend checks report an error without failing the action (HTTP 2xx)
          const aMessages = takeNewMessages(aOldMessages);
          const aErrors = aMessages.filter(function (oMessage) {
            return oMessage.getType() === "Error";
          });
          if (aErrors.length) {
            MessageBox.error(joinMessages(aErrors));
            return undefined;
          }
          const aWarnings = aMessages.filter(function (oMessage) {
            return oMessage.getType() === "Warning";
          });
          if (aWarnings.length) {
            MessageBox.warning(joinMessages(aWarnings));
          } else {
            MessageToast.show(aMessages.length ? joinMessages(aMessages) : getText(oExtensionAPI, "msgUploadSuccess"));
          }
          return oExtensionAPI.refresh();
        })
        .catch(function (oError) {
          takeNewMessages(aOldMessages);
          showError(oError);
        });
    },

    /**
     * "Download": downloads the Excel template through static action DownloadTemplate.
     */
    onDownloadTemplate: function () {
      const oExtensionAPI = this;

      const mParameters = {};
      mParameters[DOWNLOAD_PARAMETER] = buildDownloadJson(oExtensionAPI.getSelectedContexts());

      invokeStaticAction(oExtensionAPI.getModel(), "DownloadTemplate", mParameters)
        .then(function (oResultContext) {
          const oFile = oResultContext && oResultContext.getObject();
          if (!oFile || !oFile[FILE_FIELDS.content]) {
            MessageBox.warning(getText(oExtensionAPI, "msgDownloadEmpty"));
            return;
          }
          saveFile(
            fromBase64Url(oFile[FILE_FIELDS.content]),
            buildFileName(oFile),
            oFile[FILE_FIELDS.mimeType] || XLSX_MIME_TYPE
          );
        })
        .catch(showError);
    }
  };
});
