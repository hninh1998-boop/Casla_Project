sap.ui.define([
	"sap/m/MessageBox"
], function (MessageBox) {
	"use strict";

	// Function import parameters travel in the URL even for POST, so the
	// serialised filter has to stay well below usual gateway URL limits.
	var MAX_PAYLOAD_LENGTH = 4000;

	// SmartFilterBar operation names -> ABAP range OPTION codes. Unmapped
	// operations are passed through unchanged so the backend can report them
	// instead of silently dropping a filter the user did set.
	var OPERATION_MAP = {
		EQ: "EQ",
		NE: "NE",
		LE: "LE",
		LT: "LT",
		GE: "GE",
		GT: "GT",
		BT: "BT",
		Contains: "CP",
		StartsWith: "CP",
		EndsWith: "CP",
		Empty: "EQ"
	};

	function findFilterBar(oView) {
		return oView.findAggregatedObjects(true, function (oControl) {
			return oControl.isA("sap.ui.comp.smartfilterbar.SmartFilterBar");
		})[0];
	}

	function formatValue(vValue) {
		if (vValue === null || vValue === undefined) {
			return "";
		}
		if (vValue instanceof Date) {
			// Date-only field -> ABAP dats (local parts, the control has no time).
			var sMonth = String(vValue.getMonth() + 1);
			var sDay = String(vValue.getDate());
			return String(vValue.getFullYear()) +
				(sMonth.length < 2 ? "0" + sMonth : sMonth) +
				(sDay.length < 2 ? "0" + sDay : sDay);
		}
		// "|" and ";" are the payload separators.
		return String(vValue).replace(/[|;]/g, "");
	}

	// Turns one SmartFilterBar entry into ABAP-style range tuples
	// [field, sign, option, low, high]. The control uses several shapes
	// depending on the field: a plain value for single-select, "items" for
	// multi-select value helps, "ranges" for multi-input, and low/high for
	// date ranges.
	function collectRanges(sField, vFilterValue, aOut) {
		if (vFilterValue === null || vFilterValue === undefined || vFilterValue === "") {
			return;
		}

		if (typeof vFilterValue !== "object" || vFilterValue instanceof Date) {
			aOut.push([sField, "I", "EQ", formatValue(vFilterValue), ""]);
			return;
		}

		(vFilterValue.items || []).forEach(function (oItem) {
			aOut.push([sField, "I", "EQ", formatValue(oItem.key), ""]);
		});

		(vFilterValue.ranges || []).forEach(function (oRange) {
			var sOption = OPERATION_MAP[oRange.operation] || oRange.operation;
			var sLow = formatValue(oRange.value1);

			if (oRange.operation === "Contains") {
				sLow = "*" + sLow + "*";
			} else if (oRange.operation === "StartsWith") {
				sLow = sLow + "*";
			} else if (oRange.operation === "EndsWith") {
				sLow = "*" + sLow;
			}

			aOut.push([
				sField,
				oRange.exclude ? "E" : "I",
				sOption,
				sLow,
				formatValue(oRange.value2)
			]);
		});

		if (vFilterValue.value) {
			aOut.push([sField, "I", "EQ", formatValue(vFilterValue.value), ""]);
		}

		if (vFilterValue.low !== undefined && vFilterValue.low !== null) {
			aOut.push([
				sField,
				"I",
				vFilterValue.high ? "BT" : "EQ",
				formatValue(vFilterValue.low),
				formatValue(vFilterValue.high)
			]);
		}
	}

	function serialiseFilter(oFilterBar) {
		var oFilterData = oFilterBar.getFilterData() || {};
		var aRanges = [];

		Object.keys(oFilterData).forEach(function (sField) {
			// "_CUSTOM" and friends are SmartFilterBar internals, not fields.
			if (sField.charAt(0) !== "_") {
				collectRanges(sField, oFilterData[sField], aRanges);
			}
		});

		console.log("[ExplodeExcelBOM] filter data:", oFilterData);

		return aRanges.map(function (aRange) {
			return aRange.join("|");
		}).join(";");
	}

	return {
		/**
		 * Handler for the "Explode Excel BOM" table toolbar button.
		 * Configured with requiresSelection: false: it always runs for every BOM
		 * header matching the current list filters, no row selection needed.
		 *
		 * Only the CURRENT FILTER is sent, not the header list: one call to the
		 * static action scheduleExcelExport, which stores the filter and lets the
		 * Application Job (zcl_zbom_export_buffer / zcl_zbom_export_job) do the
		 * header selection, explosion and mail on the server.
		 *
		 * That keeps the button instant and makes the authorization check
		 * (get_global_authorizations, object ZBOM_EXP) the very first thing that
		 * happens, so a user without permission gets an error right away.
		 *
		 * The filter is serialised as ABAP-style range tuples
		 * "field|sign|option|low|high", separated by ";", because the backend
		 * cannot recover the filter on its own: get_as_sql_string() only exists
		 * on the query request during a list read, and zce_zbom_header is a
		 * custom entity, so it can be read neither with ABAP SQL nor with
		 * READ ENTITIES by filter.
		 */
		onExplodeExcelBOM: function () {
			var oExtensionAPI = this.extensionAPI;
			var oView = this.getView();
			var oModel = oView.getModel();
			var oFilterBar = findFilterBar(oView);

			if (!oFilterBar) {
				MessageBox.error("Không lấy được bộ lọc hiện tại.");
				return;
			}

			var sFilterRanges = serialiseFilter(oFilterBar);
			var sSearch = typeof oFilterBar.getBasicSearchValue === "function"
				? (oFilterBar.getBasicSearchValue() || "")
				: "";

			console.log("[ExplodeExcelBOM] ranges:", sFilterRanges);
			console.log("[ExplodeExcelBOM] search:", sSearch);

			if (sFilterRanges.length > MAX_PAYLOAD_LENGTH) {
				MessageBox.error(
					"Bộ lọc hiện tại quá dài để gửi sang job. " +
					"Vui lòng thu hẹp bộ lọc (bớt giá trị trong các ô lọc)."
				);
				return;
			}

			oExtensionAPI.securedExecution(function () {
				var pCall = new Promise(function (resolve, reject) {
					oModel.callFunction("/scheduleExcelExport", {
						method: "POST",
						urlParameters: {
							FilterRanges: sFilterRanges,
							SearchString: sSearch
						},
						success: function (oData) {
							resolve(oData);
						},
						error: function (oError) {
							reject(oError);
						}
					});
				});

				oModel.submitChanges();
				return pCall;
			}, { busy: { set: true, check: true } }).then(function () {
				MessageBox.success(
					"Đã lên lịch xuất Excel cho toàn bộ danh sách đang lọc. " +
					"Vui lòng theo dõi tiến trình và kiểm tra email khi job hoàn tất."
				);
			}).catch(function (oError) {
				// No MessageBox here: securedExecution already shows the
				// backend's own error dialog, so adding one produced two
				// stacked dialogs for the same failure.
				console.error("[ExplodeExcelBOM] failed:", oError);
			});
		}
	};
});
