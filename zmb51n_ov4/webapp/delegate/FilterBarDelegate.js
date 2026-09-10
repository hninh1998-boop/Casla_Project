sap.ui.define(
    [
        "sap/ui/mdc/FilterBarDelegate",
        "sap/ui/mdc/FilterField",
        "sap/ui/core/Element",
        "sap/ui/core/Fragment",
        "sap/ui/model/Filter",
        "sap/ui/model/FilterOperator",
        "sap/ui/model/FilterType"
    ],
    function (FilterBarDelegate, FilterField, Element, Fragment, Filter, FilterOperator, FilterType) {
        "use strict";

        // Standard SAP value-help search syntax (same convention as the built-in
        // sap.ui.mdc basic search field / classic ABAP search helps): "=value" forces an
        // exact match, a trailing/leading "*" forces starts-with/ends-with, both forces
        // contains - all three go through $filter (Application) since $search on these F4
        // collections does plain-text/fuzzy ranking (see CDS @Search.fuzzinessThreshold),
        // not substring matching. Bare text with no operator keeps using $search, which is
        // the only thing that reliably narrows results for free-text discovery here.
        function parseSearchText(sText) {
            if (!sText) {
                return { mode: "none" };
            }
            if (sText.charAt(0) === "=") {
                return { mode: "EQ", value: sText.slice(1) };
            }
            var bStarts = sText.charAt(0) === "*",
                bEnds = sText.charAt(sText.length - 1) === "*";
            if (bStarts || bEnds) {
                var sValue = sText.replace(/^\*+|\*+$/g, "");
                if (bStarts && bEnds) {
                    return { mode: "Contains", value: sValue };
                }
                return { mode: bEnds ? "StartsWith" : "EndsWith", value: sValue };
            }
            return { mode: "search", value: sText };
        }

        var Delegate = Object.assign({}, FilterBarDelegate);

        function getPropertyInfo(oFilterBar) {
            var oPayload = oFilterBar.getPayload();
            return (oPayload && oPayload.propertyInfo) || [];
        }

        // F4 collection info is carried in a separate payload key (not on the PropertyInfo
        // objects themselves - see List.controller.js#_buildPropertyInfo for why).
        function getF4Info(oFilterBar, sPropertyKey) {
            var oPayload = oFilterBar.getPayload();
            return (oPayload && oPayload.f4InfoByKey && oPayload.f4InfoByKey[sPropertyKey]) || null;
        }

        Delegate.fetchProperties = function (oFilterBar) {
            return Promise.resolve(getPropertyInfo(oFilterBar));
        };

        // "Table of F4 rows" content (eager-loading, plain sap.m.Table wrapped in vhc:MTable)
        // for the Dialog. filterBar (when given) is nested INSIDE vhc:MTable - it is an
        // aggregation of the content wrapper itself, not of the surrounding vh:Dialog.
        // Fixed per-column width (rather than letting the table auto-shrink columns to fit a
        // hardcoded overall width) so headers/values stop wrapping into unreadable multi-line
        // cells once a ValueList has several columns (compound key + extra display columns).
        var COLUMN_WIDTH_REM = 9;

        function buildMTableXml(oProperty, oInfo, sMode, sFilterBarXml) {
            var sDesc = oInfo.descriptionProperty,
                aColumns = ['<Column width="' + COLUMN_WIDTH_REM + 'rem"><header><Text text="' + oProperty.label + '"/></header></Column>'],
                aCells = ["<Text text=\"{f4>" + oInfo.keyProperty + '}"/>'];

            if (sDesc) {
                aColumns.push('<Column width="' + COLUMN_WIDTH_REM + 'rem"><header><Text text="' + sDesc + '"/></header></Column>');
                aCells.push("<Text text=\"{f4>" + sDesc + '}"/>');
            }

            // Extra key/display parameters the ValueList metadata declares beyond the primary
            // key+description pair (e.g. Plant alongside StorageLocation for a compound VH key)
            // - which columns exist is driven entirely by metadataHelper.requestValueHelpInfo,
            // not hardcoded here.
            (oInfo.extraColumns || []).forEach(function (oColumn) {
                aColumns.push('<Column width="' + COLUMN_WIDTH_REM + 'rem"><header><Text text="' + oColumn.label + '"/></header></Column>');
                aCells.push("<Text text=\"{f4>" + oColumn.property + '}"/>');
            });

            var iTableWidthRem = Math.max(30, aColumns.length * COLUMN_WIDTH_REM);

            return (
                '<vhc:MTable keyPath="' +
                oInfo.keyProperty +
                '"' +
                (sDesc ? ' descriptionPath="' + sDesc + '"' : "") +
                ">" +
                (sFilterBarXml ? "<vhc:filterBar>" + sFilterBarXml + "</vhc:filterBar>" : "") +
                '<Table items="{f4>/' +
                oInfo.collectionPath +
                '}" width="' +
                iTableWidthRem +
                'rem" mode="' +
                sMode +
                '">' +
                "<columns>" +
                aColumns.join("") +
                "</columns>" +
                "<items>" +
                '<ColumnListItem type="Active"><cells>' +
                aCells.join("") +
                "</cells></ColumnListItem>" +
                "</items>" +
                "</Table>" +
                "</vhc:MTable>"
            );
        }

        // Full Dialog (opened via the field's value help icon): reuses the same eager-loading
        // vhc:MTable/sap.m.Table content as the typeahead (proven to show all rows immediately,
        // unlike vhc:MDCTable/mdc:Table which withholds data until a search/filter runs), plus a
        // nested vhfb:FilterBar (basic search field) inside vhc:MTable's own filterBar aggregation
        // so the search box actually filters the same content.
        function buildDialogXml(oProperty, oInfo) {
            var sFilterBarXml =
                '<vhfb:FilterBar delegate="{name: \'zmb51nov4/delegate/FilterBarDelegate\', payload: {propertyInfo: [' +
                "{key: '$search', label: 'Search', dataType: 'sap.ui.model.type.String', maxConditions: 1}" +
                "]}}\">" +
                "<vhfb:basicSearchField>" +
                '<mdc:FilterField delegate="{name: \'sap/ui/mdc/field/FieldBaseDelegate\'}"' +
                ' dataType="sap.ui.model.type.String" propertyKey="$search" maxConditions="1"/>' +
                "</vhfb:basicSearchField>" +
                "</vhfb:FilterBar>";

            return (
                '<vh:Dialog title="' +
                oProperty.label +
                '">' +
                buildMTableXml(oProperty, oInfo, "MultiSelect", sFilterBarXml) +
                '<vhc:Conditions label="' +
                oProperty.label +
                '"/>' +
                "</vh:Dialog>"
            );
        }

        // A mdc.ValueHelp with only a full Dialog (opened via the field's value help icon, with
        // its own "Define Conditions" tab) bound to the F4 collection resolved via
        // metadataHelper.requestValueHelpInfo, built as an inline XML fragment - the standard
        // sap.ui.mdc pattern (see SAP-samples/ui5-mdc-json-tutorial, NameValueHelp.fragment.xml)
        // is authored as static XML, so we template the same shape with the runtime field info.
        //
        // No <mdc:typeahead> (the small live-suggestion Popover shown while typing): its content
        // filtering is hardcoded framework behavior (FilterableListContent's own as-you-type
        // search, independent of the filterFields XML attribute - removing that attribute was
        // tried and did not stop it) that always builds a contains(tolower(...)) OData filter,
        // and this backend's F4 services 501 on the tolower() function - so any typeahead content
        // here is guaranteed to error while the user is still typing. Dropping it entirely avoids
        // that; Enter-key resolution still works via ValueHelpDelegate#getItemForValue below, and
        // browsing/picking still works via the Dialog.
        function buildValueHelpFragmentXml(oProperty, oInfo) {
            return (
                '<core:FragmentDefinition xmlns="sap.m" xmlns:core="sap.ui.core" xmlns:mdc="sap.ui.mdc"' +
                ' xmlns:vh="sap.ui.mdc.valuehelp" xmlns:vhc="sap.ui.mdc.valuehelp.content"' +
                ' xmlns:vhfb="sap.ui.mdc.filterbar.vh">' +
                '<mdc:ValueHelp delegate="{name: \'zmb51nov4/delegate/ValueHelpDelegate\', payload: {}}">' +
                "<mdc:dialog>" +
                buildDialogXml(oProperty, oInfo) +
                "</mdc:dialog>" +
                "</mdc:ValueHelp>" +
                "</core:FragmentDefinition>"
            );
        }

        // The Dialog's basicSearchField is only wired into sap.ui.mdc's own condition-model/
        // property-engine machinery, which our lightweight setup (plain "$filters" JSON model,
        // no full PropertyInfo/StateUtil integration on this inner FilterBar) does not
        // participate in - so the framework's built-in ValueHelpDelegate#getFilters never
        // reflects what was typed. Wired manually here instead: listen to the inner FilterBar's
        // "search" event (fired on Go/Enter) and parse the text with the standard SAP value-help
        // search convention (see parseSearchText) - "=value" -> exact $filter EQ, leading/
        // trailing "*" -> $filter StartsWith/EndsWith/Contains, bare text -> $search. Bare-text
        // $filter/contains() was tried first and found broken even for Plant (I_PlantStdVH, a
        // proper dataCategory #VALUE_HELP view where $search works fine), so free text still
        // goes through $search (which itself does CDS full-text/fuzzy ranking rather than
        // substring matching - see @Search.fuzzinessThreshold on the underlying CDS views) while
        // the explicit "=" and "*" operators go through $filter, which does appear to accept
        // EQ/StartsWith/EndsWith even where bare Contains was rejected.
        /* eslint-disable no-console */
        function wireDialogSearch(oDialog, oInfo) {
            var oContent = (oDialog.getContent() || []).filter(function (oItem) {
                return oItem.isA("sap.ui.mdc.valuehelp.content.MTable");
            })[0];
            var oInnerFilterBar = oContent && oContent.getFilterBar();
            var oTable = oContent && oContent.getTable();
            var oSearchField = oInnerFilterBar && oInnerFilterBar.getBasicSearchField();

            console.log("[FilterBarDelegate] wireDialogSearch:", {
                hasContent: !!oContent,
                hasFilterBar: !!oInnerFilterBar,
                hasTable: !!oTable,
                hasSearchField: !!oSearchField
            });

            if (!oInnerFilterBar || !oTable || !oSearchField) {
                console.warn("[FilterBarDelegate] wireDialogSearch: missing element, search box will stay inert");
                return;
            }

            // Guard against wireDialogSearch running twice on the same inner FilterBar (e.g. if
            // the framework's own addItem lifecycle re-enters createValueHelp). A duplicate
            // attachSearch registration would fire two overlapping filter() calls per user
            // action - exactly the "search fired" flood seen in the console, which races two
            // ODataListBinding requests against each other and can leave the stale (unfiltered)
            // one as the winner ("ignoring response from inactive cache").
            if (oInnerFilterBar._zFilterWired) {
                return;
            }
            oInnerFilterBar._zFilterWired = true;

            // Only the most recently issued filter() call is allowed to log/act on its
            // response - any older, now-superseded request is dropped so a slow unfiltered
            // response can't land after a faster filtered one and undo it.
            var iFilterToken = 0;

            oInnerFilterBar.attachSearch(function () {
                var iToken = ++iFilterToken;
                try {
                    var aConditions = oSearchField.getConditions() || [],
                        sText = aConditions.length && aConditions[0].values && aConditions[0].values[0],
                        oBinding = oTable.getBinding("items"),
                        oParsed = parseSearchText(sText);

                    console.log("[FilterBarDelegate] search fired:", { token: iToken, conditions: aConditions, text: sText, parsed: oParsed, hasBinding: !!oBinding });

                    if (!oBinding) {
                        return;
                    }

                    var aFilters = [];
                    if (oParsed.mode === "EQ") {
                        aFilters = [new Filter(oInfo.keyProperty, FilterOperator.EQ, oParsed.value)];
                    } else if (oParsed.mode === "Contains" || oParsed.mode === "StartsWith" || oParsed.mode === "EndsWith") {
                        var aFieldFilters = [new Filter(oInfo.keyProperty, FilterOperator[oParsed.mode], oParsed.value)];
                        if (oInfo.descriptionProperty) {
                            aFieldFilters.push(new Filter(oInfo.descriptionProperty, FilterOperator[oParsed.mode], oParsed.value));
                        }
                        aFilters = [new Filter({ filters: aFieldFilters, and: false })];
                    }

                    console.log("[FilterBarDelegate] applying search:", {
                        token: iToken,
                        bindingType: oBinding.getMetadata && oBinding.getMetadata().getName(),
                        parsed: oParsed,
                        rowCountBefore: oTable.getItems().length
                    });

                    if (oParsed.mode === "search") {
                        // Free text: server-side $search (CDS full-text/fuzzy ranking) - the only
                        // system query option this F4 collection's metadata allows, confirmed by
                        // FilterType.Application silently producing zero network activity (the V4
                        // model itself suppresses the request once it reads Filterable: false off
                        // the entity set's Capabilities annotation - not a bug, a hard backend
                        // restriction with no frontend workaround).
                        oBinding.filter([], FilterType.Control);
                        oBinding.changeParameters({ $search: oParsed.value });
                        oBinding.attachEventOnce("dataReceived", function (oEvent) {
                            if (iToken !== iFilterToken) {
                                console.log("[FilterBarDelegate] dataReceived ignored (stale token):", { token: iToken, currentToken: iFilterToken });
                                return;
                            }
                            console.log("[FilterBarDelegate] dataReceived after search:", {
                                token: iToken,
                                error: oEvent.getParameter("error"),
                                rowCountNow: oTable.getItems().length
                            });
                        });
                    } else {
                        // "=", "*value", "value*", "*value*": FilterType.Control filters purely
                        // client-side over whatever rows the binding already fetched - no request,
                        // so it works regardless of the Filterable:false restriction, at the cost
                        // of only ever matching within the already-loaded page (rowCountBefore).
                        oBinding.changeParameters({ $search: undefined });
                        oBinding.filter(aFilters, FilterType.Control);
                        Promise.resolve().then(function () {
                            if (iToken !== iFilterToken) {
                                return;
                            }
                            console.log("[FilterBarDelegate] client filter applied:", {
                                token: iToken,
                                rowCountNow: oTable.getItems().length
                            });
                        });
                    }
                } catch (oError) {
                    console.error("[FilterBarDelegate] search handler failed", oError);
                }
            });
        }
        /* eslint-enable no-console */

        function createValueHelp(oFilterBar, oProperty, oInfo) {
            var sValueHelpId = oFilterBar.getId() + "--vh--" + oProperty.key;

            return Fragment.load({
                definition: buildValueHelpFragmentXml(oProperty, oInfo),
                id: sValueHelpId
            }).then(function (oValueHelp) {
                oValueHelp.setModel(oInfo.model, "f4");
                oFilterBar.addDependent(oValueHelp);

                var oDialog = oValueHelp.getDialog();
                if (oDialog) {
                    wireDialogSearch(oDialog, oInfo);
                }

                return oValueHelp;
            });
        }

        Delegate.addItem = function (oFilterBar, sPropertyKey) {
            var aPropertyInfo = getPropertyInfo(oFilterBar),
                oProperty = aPropertyInfo.filter(function (oProp) {
                    return oProp.key === sPropertyKey;
                })[0];

            if (!oProperty) {
                return Promise.resolve(null);
            }

            var sId = oFilterBar.getId() + "--filter--" + sPropertyKey,
                oExisting = Element.getElementById(sId);

            if (oExisting) {
                return Promise.resolve(oExisting);
            }

            var oInfo = getF4Info(oFilterBar, sPropertyKey);

            // No explicit "conditions" binding here: once this field is added to the FilterBar's
            // filterItems (FilterBarDelegate.addItem's caller does that), FilterBarBase itself
            // auto-binds "conditions" to its own internal condition model based on propertyKey
            // (see FilterBarBase#_enhanceFilterField) - the framework's own real state store, not
            // a model we manage by hand.
            var oFilterField = new FilterField(sId, {
                dataType: oProperty.dataType,
                propertyKey: sPropertyKey,
                label: oProperty.label,
                maxConditions: oProperty.maxConditions,
                delegate: { name: "sap/ui/mdc/field/FieldBaseDelegate", payload: {} }
            });

            if (!oInfo) {
                return Promise.resolve(oFilterField);
            }

            return createValueHelp(oFilterBar, oProperty, oInfo).then(function (oValueHelp) {
                if (oValueHelp) {
                    oFilterField.setValueHelp(oValueHelp);
                }
                return oFilterField;
            });
        };

        return Delegate;
    }
);
