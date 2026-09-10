sap.ui.define(["sap/ui/model/Filter", "sap/ui/model/FilterOperator"], function (Filter, FilterOperator) {
    "use strict";

    // sap.ui.mdc condition operator names line up with sap.ui.model.FilterOperator almost 1:1.
    var OPERATOR_MAP = {
        EQ: FilterOperator.EQ,
        NE: FilterOperator.NE,
        BT: FilterOperator.BT,
        Contains: FilterOperator.Contains,
        StartsWith: FilterOperator.StartsWith,
        EndsWith: FilterOperator.EndsWith,
        LT: FilterOperator.LT,
        LE: FilterOperator.LE,
        GT: FilterOperator.GT,
        GE: FilterOperator.GE
    };

    // mdc Date fields (dataType "sap.ui.model.type.Date", no "source" format option - see
    // List.controller.js#_buildPropertyInfo) store condition values as plain JS Date objects.
    // OData V4's _Helper.formatLiteral does NOT stringify Edm.Date/Edm.DateTimeOffset values -
    // it inserts whatever is given straight into the $filter literal (confirmed against
    // sap/ui/model/odata/v4/lib/_Helper.js) - so a raw Date here becomes something like
    // "PostingDate eq Fri Aug 15 2025 00:00:00 GMT+0700 ...", a malformed literal the backend
    // can't match against anything, making the filter silently no-op. Converts to the Edm.Date
    // literal shape ("YYYY-MM-DD") using LOCAL date parts (not toISOString, which is UTC and
    // would shift the date backward for any timezone ahead of UTC, e.g. UTC+7 at local midnight).
    function formatDateValue(vValue) {
        if (!(vValue instanceof Date)) {
            return vValue;
        }
        var sYear = String(vValue.getFullYear()).padStart(4, "0"),
            sMonth = String(vValue.getMonth() + 1).padStart(2, "0"),
            sDay = String(vValue.getDate()).padStart(2, "0");
        return sYear + "-" + sMonth + "-" + sDay;
    }

    /**
     * Converts a sap.ui.mdc FilterBar conditions map ({ fieldName: [{operator, values}, ...] })
     * into a flat sap.ui.model.Filter[] (one entry per field, ORed internally when a field has
     * several conditions), ready to pass to ListBinding#filter().
     */
    function convertConditionsToFilters(oConditions) {
        var aFieldFilters = [];

        Object.keys(oConditions || {}).forEach(function (sField) {
            var aOrFilters = (oConditions[sField] || [])
                .map(function (oCondition) {
                    var sOperator = OPERATOR_MAP[oCondition.operator],
                        aValues = oCondition.values || [];

                    if (!sOperator) {
                        /* eslint-disable-next-line no-console */
                        console.warn("Unmapped mdc filter operator: " + oCondition.operator);
                        return null;
                    }

                    return new Filter(sField, sOperator, formatDateValue(aValues[0]), formatDateValue(aValues[1]));
                })
                .filter(Boolean);

            if (aOrFilters.length === 1) {
                aFieldFilters.push(aOrFilters[0]);
            } else if (aOrFilters.length > 1) {
                aFieldFilters.push(new Filter({ filters: aOrFilters, and: false }));
            }
        });

        return aFieldFilters;
    }

    return {
        convertConditionsToFilters: convertConditionsToFilters
    };
});
