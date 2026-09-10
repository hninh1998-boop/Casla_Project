sap.ui.define(["sap/ui/mdc/ValueHelpDelegate"], function (ValueHelpDelegate) {
    "use strict";

    var Delegate = Object.assign({}, ValueHelpDelegate);

    // Called by the framework when a field with this value help attached needs to resolve
    // typed-then-Enter text into a {key, description} condition (no dialog/popover interaction
    // involved). The default implementation queries the value help's own F4 collection
    // (typeahead content) to find a matching item - but these F4 collections are Filterable:
    // false (confirmed while debugging the value-help search boxes: FilterType.Application
    // silently produces zero network activity there), so that lookup fails outright here with
    // "Type cannot be determined, no metadata for path: /<Collection>/<Property>" and then
    // surfaces as FilterBar's generic "inconsistent or invalid data" error - never the plain
    // "type it, press Enter, get a token" flow standard SAP search fields give you. Trusting the
    // typed text directly as the key skips that broken lookup entirely; the value-help icon/
    // Dialog (wired in FilterBarDelegate.js#wireDialogSearch) is unaffected and still lets the
    // user browse/pick instead of typing.
    Delegate.getItemForValue = function (oValueHelp, oConfig) {
        if (!oConfig || !oConfig.value) {
            return Promise.resolve(null);
        }
        return Promise.resolve({ key: oConfig.value, description: undefined });
    };

    // The framework's default selection matching (createConditionPayload returns no payload;
    // compareConditions compares only values[0] - see sap/ui/mdc/ValueHelpDelegate) treats a
    // "Search and Select" row as selected purely by VALUE, not by which physical row was
    // clicked. For value helps like Delivery Item (I_DeliveryDocumentItem), where the local
    // field (DeliveryItem) maps only to part of the F4 collection's real key, many rows share
    // the same value across different documents - so ticking one ticks all of them, and they
    // collapse into a single condition/chip. This is confirmed intentional, documented framework
    // behavior (createConditionPayload/compareConditions exist specifically as extension points
    // for this), not a bug - but the user explicitly asked for row-level selection instead, aware
    // that it changes the trade-off: selecting two different rows sharing a value now yields two
    // separate (same-looking) chips instead of collapsing into one. Both filter to the same
    // "field = value" condition either way, so this only affects the selection UI, not the actual
    // $filter query sent to the backend - the payload never reaches OData.
    //
    // Tagging each row's condition with its own OData context path (unique per physical row,
    // works for ANY value help generically - no per-field key configuration needed) and requiring
    // payloads to also match makes selection track the physical row. Falls back to the default
    // value-only comparison whenever either side has no payload - e.g. a value typed directly
    // into the field (see getItemForValue above) never goes through a row context, so it still
    // matches every row with that value, same as before.
    Delegate.createConditionPayload = function (oValueHelp, oContent, aValues, oContext) {
        return oContext ? { contextPath: oContext.getPath() } : undefined;
    };

    Delegate.compareConditions = function (oValueHelp, oConditionA, oConditionB) {
        if (!ValueHelpDelegate.compareConditions.call(this, oValueHelp, oConditionA, oConditionB)) {
            return false;
        }
        var oPayloadA = oConditionA.payload,
            oPayloadB = oConditionB.payload;
        if (oPayloadA && oPayloadA.contextPath && oPayloadB && oPayloadB.contextPath) {
            return oPayloadA.contextPath === oPayloadB.contextPath;
        }
        return true;
    };

    return Delegate;
});
