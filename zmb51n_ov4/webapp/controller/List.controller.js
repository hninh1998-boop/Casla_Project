sap.ui.define(
    [
        "sap/ui/core/mvc/Controller",
        "sap/ui/model/Filter",
        "sap/ui/model/FilterOperator",
        "sap/ui/mdc/FilterBar",
        "sap/ui/mdc/enums/FilterBarP13nMode",
        "sap/m/VariantManagement",
        "sap/m/VariantItem",
        "sap/ui/util/Storage",
        "sap/m/Label",
        "sap/m/Text",
        "sap/m/HBox",
        "sap/m/Button",
        "sap/m/List",
        "sap/m/StandardListItem",
        "sap/m/Table",
        "sap/m/Column",
        "sap/m/ColumnListItem",
        "sap/m/ResponsivePopover",
        "sap/m/Dialog",
        "sap/m/Select",
        "sap/ui/core/Item",
        "sap/ui/core/Icon",
        "sap/ui/core/HTML",
        "sap/m/MessageToast",
        "sap/ui/core/CustomData",
        "sap/ui/core/format/NumberFormat",
        "sap/base/security/encodeXML",
        "sap/ui/model/json/JSONModel",
        "sap/ui/table/Column",
        "sap/ui/export/Spreadsheet",
        "sap/m/p13n/Popup",
        "sap/m/p13n/SelectionPanel",
        "zmb51nov4/model/metadataHelper",
        "zmb51nov4/model/mdcConditionConverter",
        "zmb51nov4/delegate/FilterBarDelegate"
    ],
    function (
        Controller,
        Filter,
        FilterOperator,
        FilterBar,
        FilterBarP13nMode,
        VariantManagement,
        VariantItem,
        Storage,
        Label,
        Text,
        HBox,
        Button,
        List,
        StandardListItem,
        MTable,
        MColumn,
        ColumnListItem,
        ResponsivePopover,
        Dialog,
        Select,
        Item,
        Icon,
        HTML,
        MessageToast,
        CustomData,
        NumberFormat,
        encodeXML,
        JSONModel,
        Column,
        Spreadsheet,
        P13nPopup,
        SelectionPanel,
        metadataHelper,
        mdcConditionConverter,
        FilterBarDelegate
    ) {
        "use strict";

        var ENTITY_PATH = "/zce_zmb51n";

        // Why sap.m.VariantManagement (pure UI control) instead of sap.ui.fl.variants.
        // VariantManagement: the flex control persists the FilterBar's state through the
        // sap.ui.fl / p13n layer, which this app's FilterBar doesn't feed properly -
        //   * filter fields are added imperatively (oFilterBar.addFilterItem in a loop, see
        //     _applyMainEntityFields), not via flex "addItem" changes, so on variant apply flex
        //     resets the bar to its own "default" field set and the per-Main-Entity extra
        //     fields (EXTRA_FIELDS_BY_MAIN_ENTITY) vanish;
        //   * p13nMode carries no Value entry, so filter VALUES were never captured in a variant
        //     at all (matching the getConditions()-returns-empty note on _getCurrentFilters).
        // sap.m.VariantManagement fires save/select/manage and leaves persistence entirely to
        // us: each variant's { title, mainEntity, conditions, executeOnSelect } is written to
        // sap.ui.util.Storage (local), keyed by a variant key we mint ourselves. The Main
        // Entity (Nhom) - a plain Select above the bar, never part of the FilterBar - rides
        // along in that same record, and _applyVariantState switches it (rebuilding the bar for
        // the right field set) before writing the stored conditions back onto the fields.
        var VARIANT_STORAGE_ID = "zmb51nov4";
        var VARIANT_STORAGE_KEY = "filterVariants";
        var STANDARD_VARIANT_KEY = "*standard*";

        // DebitCreditCode ('S' Debit / 'H' Credit) has no @UI.lineItem of its own - it only
        // exists to color the quantity cells' TEXT (see DEBIT_CREDIT_COLORED_FIELDS and
        // _createColoredQuantityCellTemplate below), matching the standard ZMB51 app's
        // green/red Signed Quantity text on a plain white background.
        var DEBIT_CREDIT_FIELD_NAME = "DebitCreditCode";
        var DEBIT_CREDIT_COLORS = {
            S: "#006100",
            H: "#9C0006"
        };

        // Which columns get DebitCreditCode-driven text coloring.
        var DEBIT_CREDIT_COLORED_FIELDS = ["QuantityInEntryUnit", "QuantityInBaseUnit"];

        // Fields that get a "Totals" (sum-per-unit) button in their column header - a plain
        // single sum would be meaningless across rows with different units/currencies, so each
        // opens a popover listing one sum per distinct value of its paired field instead (see
        // onShowTotals/_requestTotals). Covers the whole filtered result set, not just the rows
        // currently loaded into the table - summed client-side, see _requestTotals for why.
        var TOTALS_UNIT_FIELD = {
            QuantityInEntryUnit: "EntryUnit",
            QuantityInBaseUnit: "MaterialBaseUnit",
            StockAmountInCoCdCurrency: "CompanyCodeCurrency"
        };

        // Page size and concurrency used by _fetchAllRows (Totals + Group By's full-dataset
        // reads). Each individual requestContexts call stays a bounded, known-safe size (unlike
        // the earlier one-huge-range attempt that hung); GROUP_FETCH_CONCURRENCY pages are then
        // requested at once via Promise.all so UI5's own "$auto" group batches them into a single
        // $batch call, cutting wall-clock time without ever asking the backend for everything at
        // once. Tune down if this concurrency turns out to strain the backend after all.
        //
        // These are Group By's numbers specifically - its rows carry the group field, its
        // description, the 4 key fields and both quantity/unit pairs (see _getGroupDetailFields),
        // so they're sized conservatively for that wider payload. _requestTotals below overrides
        // both with TOTALS_FETCH_* instead: it only ever $selects 2 columns (one quantity + its
        // unit), so it used to run far fewer/heavier round trips before it started sharing this
        // helper with Group By - without its own bigger page size it was throttled down to Group
        // By's pacing despite carrying a fraction of the data per row, which is what made it feel
        // slow once Subtotal shipped.
        var GROUP_FETCH_PAGE_SIZE = 1000;
        var GROUP_FETCH_CONCURRENCY = 4;
        var TOTALS_FETCH_PAGE_SIZE = 5000;
        var TOTALS_FETCH_CONCURRENCY = 4;

        // Just the two quantity fields (not StockAmountInCoCdCurrency) get a subtotal line in the
        // Group By dialog's group headers - looked up against TOTALS_UNIT_FIELD for their paired
        // unit field, so adding a field here is enough, no separate unit mapping needed.
        var GROUP_SUBTOTAL_FIELDS = ["QuantityInEntryUnit", "QuantityInBaseUnit"];

        // The 4 fields making up zce_zmb51n's own key (see the CDS's "key ..." declarations) -
        // always shown in Subtotal's detail columns, regardless of which field is grouped by
        // (see _getGroupDetailFields), and excluded from the Group By field picker itself (see
        // _buildGroupByFields) since grouping by a key that's already unique per row/shown on
        // every detail row wouldn't do anything useful.
        var GROUP_KEY_FIELDS = ["MaterialDocumentYear", "MaterialDocument", "MaterialDocumentItem", "Nhom"];

        // Amount fields excluded from the Group By field picker (_buildGroupByFields) alongside
        // GROUP_KEY_FIELDS and GROUP_SUBTOTAL_FIELDS - grouping by a currency amount is rarely
        // meaningful, unlike its paired currency CODE (CompanyCodeCurrency), which stays eligible.
        var GROUP_BY_EXCLUDED_FIELDS = ["StockAmountInCoCdCurrency"];

        // <field> -> its own description/name field, both excluded from the field PICKER
        // (descriptions aren't meaningful group-by dimensions on their own) and pulled in
        // automatically as an extra detail column whenever <field> is the one grouped by - see
        // _buildGroupByFields and _getGroupDetailFields.
        var GROUP_FIELD_DESCRIPTIONS = {
            Material: "MaterialDescription",
            Plant: "PlantName",
            StorageLocation: "StorageLocationName",
            Supplier: "SupplierName",
            GoodsMovementType: "MovementTypeDescription"
        };

        // sap.ui.mdc PropertyInfo dataType is a UI5 data type module name, not the raw Edm type.
        var EDM_TO_MDC_TYPE = {
            "Edm.Date": "sap.ui.model.type.Date",
            "Edm.Boolean": "sap.ui.model.type.Boolean"
        };

        // Extra filter fields to show on top of the standard @UI.SelectionFields set,
        // depending on which Main Entity (Nhom) is selected. Not discoverable from
        // metadata alone since these fields carry no @UI.selectionField annotation.
        var EXTRA_FIELDS_BY_MAIN_ENTITY = {
            BOTMAU: ["Loai2", "MaHang2", "NhaCungCap2", "Lot2", "NgaySanXuat2", "HanSuDung2"],
            NVL: [
                "Loai3",
                "DaiHat3",
                "NhaCungCap3",
                "SoLotNCC3",
                "Lot3",
                "NhapMuaSX3",
                "STTBao3",
                "ChatLuong3",
                "MauSac3",
                "KhoiLuong3",
                "TinhTrang3",
                "CumMay3",
                "CongDoan3",
                "GhiChu13",
                "GhiChu23"
            ],
            SLAB: [
                "MaHang4",
                "DoDay4",
                "Vein4",
                "CheDoMai4",
                "Lot4",
                "STTSlab4",
                "LineRungEp4",
                "NgaySanXuat4",
                "PhanLoaiSX4",
                "LineMai4",
                "Shade4",
                "KhachHang4",
                "ChatLuong4",
                "NgayMaiMoiNhat4",
                "NgayKiemMoiNhat4",
                "KhoiLuong4",
                "MangPhu4",
                "TrangThai4",
                "DaSua4",
                "GhiChu4"
            ],
            TP: ["MaHang5", "CheDoMai5", "ChieuDai5", "ChieuRong5", "DoDay5", "MaDuAn5", "KieuMaiCanh5", "DungSai5", "TemMau5", "MauSac5"],
            DA: ["MaHang6", "DoDay6", "CheDoMai6", "Vein6", "ChieuDai6", "ChieuRong6", "Lot6", "STTSlab6", "Shade6"]
        };

        return Controller.extend("zmb51nov4.controller.List", {
            onInit: function () {
                var oModel = this.getOwnerComponent().getModel(),
                    oMetaModel = oModel.getMetaModel(),
                    oTable = this.byId("materialDocumentsTable");

                this._oMetaModel = oMetaModel;

                oTable.setBusy(true);

                Promise.all([
                    metadataHelper.requestFieldList(oMetaModel, ENTITY_PATH, "com.sap.vocabularies.UI.v1.LineItem"),
                    metadataHelper.requestFieldList(oMetaModel, ENTITY_PATH, "com.sap.vocabularies.UI.v1.SelectionFields"),
                    oMetaModel.requestObject(ENTITY_PATH + "/Nhom@com.sap.vocabularies.Common.v1.Label"),
                    metadataHelper.requestIntervalFieldNames(oMetaModel, ENTITY_PATH),
                    oMetaModel.requestObject(ENTITY_PATH + "/@com.sap.vocabularies.UI.v1.HeaderInfo")
                ])
                    .then(
                        function (aResults) {
                            var aColumns = aResults[0],
                                aFilterFields = aResults[1].filter(function (oField) {
                                    return oField.name !== "Nhom";
                                }),
                                sMainEntityLabel = aResults[2],
                                oHeaderInfo = aResults[4];

                            this._aIntervalFieldNames = aResults[3];
                            this._aBaseColumnsMeta = aColumns;
                            this._aBaseFilterFieldsMeta = this._markIntervalFields(aFilterFields);
                            this._sTypeNamePlural = (oHeaderInfo && oHeaderInfo.TypeNamePlural) || "Records";

                            if (sMainEntityLabel) {
                                this.byId("mainEntityPanel").setHeaderText(sMainEntityLabel);
                                this.byId("mainEntityLabel").setText(sMainEntityLabel);
                            }

                            return this._applyMainEntityFields(this.byId("mainEntitySelect").getSelectedKey());
                        }.bind(this)
                    )
                    .then(
                        function () {
                            oTable.setBusy(false);
                            this._applyDefaultVariant();
                        }.bind(this)
                    )
                    .catch(function (oError) {
                        oTable.setBusy(false);
                        /* eslint-disable-next-line no-console */
                        console.error("Failed to load field metadata for " + ENTITY_PATH, oError);
                    });
            },

            // On load, apply whichever saved variant the user marked as Default (nothing to do
            // for the built-in Standard one - the page already loads in that empty state). No
            // async flex layer here to wait for, unlike the sap.ui.fl control this replaced -
            // the record is read straight from Storage - so this is a plain inline call.
            _applyDefaultVariant: function () {
                var mData = this._readVariantData(),
                    sDefaultKey = mData.defaultKey;

                if (sDefaultKey && sDefaultKey !== STANDARD_VARIANT_KEY && mData.variants[sDefaultKey]) {
                    this._applyVariantState(sDefaultKey);
                }
            },

            _buildColumns: function (oTable, aColumns) {
                // Kept for onExport, which needs the same {name, label} pairs to build the
                // Spreadsheet's column config - re-derived here rather than read back off the
                // table's sap.ui.table.Column controls since Column has no public "field name".
                this._aCurrentColumnsMeta = aColumns;
                // Immutable snapshot of the default order/set (all visible) - the Settings
                // dialog's Reset restores to this, see _onSettingsReset.
                this._aDefaultColumnsMeta = aColumns.slice();

                aColumns.forEach(function (oField) {
                    oTable.addColumn(
                        new Column({
                            width: "12rem",
                            // Enables sap.ui.table.Column's own built-in header menu entries
                            // (Sort Ascending / Sort Descending) - no custom UI needed.
                            sortProperty: oField.name,
                            label: this._createColumnHeader(oField),
                            template:
                                DEBIT_CREDIT_COLORED_FIELDS.indexOf(oField.name) !== -1
                                    ? this._createColoredQuantityCellTemplate(oField.name)
                                    : new Text({ text: "{" + oField.name + "}" })
                        })
                    );
                }, this);
            },

            // Plain Label for most columns; a Label + "Totals" button (sap-icon://sum) for the
            // fields in TOTALS_UNIT_FIELD, matching the reference report. The field name travels
            // with the button as CustomData since one shared onShowTotals handles all of them.
            _createColumnHeader: function (oField) {
                var oLabel = new Label({ text: oField.label });

                if (!TOTALS_UNIT_FIELD[oField.name]) {
                    return oLabel;
                }

                return new HBox({
                    alignItems: "Center",
                    items: [
                        oLabel,
                        new Button({
                            icon: "sap-icon://sum",
                            type: "Transparent",
                            tooltip: "{i18n>table.totals}",
                            press: this.onShowTotals.bind(this)
                        }).addCustomData(new CustomData({ key: "field", value: oField.name }))
                    ]
                });
            },

            // sap.m.Text/sap.ui.table's standard Text template has no per-value text-color
            // property, so a control whose bound "content" is raw markup is the simplest way to
            // color just the text (background stays the table's normal white). DebitCreditCode
            // isn't its own column, but binding it here still makes autoExpandSelect pull it into
            // the OData request.
            _createColoredQuantityCellTemplate: function (sFieldName) {
                return new HTML({
                    content: {
                        parts: [sFieldName, DEBIT_CREDIT_FIELD_NAME],
                        formatter: function (sQuantity, sDebitCredit) {
                            var sColor = DEBIT_CREDIT_COLORS[sDebitCredit],
                                sText = encodeXML(sQuantity === undefined || sQuantity === null ? "" : String(sQuantity)),
                                sStyle =
                                    "display:flex;align-items:center;justify-content:flex-end;width:100%;height:100%;box-sizing:border-box;padding:0 .5rem;";

                            if (sColor) {
                                sStyle += "color:" + sColor + ";";
                            }

                            return '<div style="' + sStyle + '">' + sText + "</div>";
                        }
                    }
                });
            },

            // Opens the "Totals" popover for the field named in the pressed button's CustomData
            // (see _createColumnHeader). A single sum across rows with different units/currencies
            // would be meaningless, so this lists one sum per distinct unit instead, computed over
            // the CURRENT filters (same ones onGo uses) - covering every matching row, not just
            // what's loaded into the table.
            onShowTotals: function (oEvent) {
                var oButton = oEvent.getSource(),
                    sField = oButton.data("field"),
                    sUnitField = TOTALS_UNIT_FIELD[sField];

                if (!this._oTotalsList) {
                    this._oTotalsList = new List();
                    // Same "X / Y rows" live feedback as Group By's dialog (_updateGroupProgress) -
                    // fetching everything can take a while, so this replaces a bare busy spinner
                    // with something that shows it's actually making progress, see
                    // _updateTotalsProgress.
                    this._oTotalsProgressText = new Text().addStyleClass("sapUiSmallMarginBegin sapUiTinyMarginBottom");
                    this._oTotalsPopover = new ResponsivePopover({
                        title: "{i18n>table.totals}",
                        placement: "Bottom",
                        content: [this._oTotalsProgressText, this._oTotalsList]
                    });
                    this.getView().addDependent(this._oTotalsPopover);
                }

                this._oTotalsList.destroyItems();
                this._oTotalsProgressText.setText("");
                this._oTotalsPopover.setBusy(true);
                this._oTotalsPopover.openBy(oButton);

                this._requestTotals(sField, sUnitField)
                    .then(
                        function (aRows) {
                            if (!aRows.length) {
                                this._oTotalsList.addItem(new StandardListItem({ title: this._formatTotal(0) }));
                                return;
                            }
                            aRows.forEach(function (oRow) {
                                this._oTotalsList.addItem(
                                    new StandardListItem({
                                        title: this._formatTotal(oRow.Total),
                                        info: oRow[sUnitField] || "",
                                        infoState: "None"
                                    })
                                );
                            }, this);
                        }.bind(this)
                    )
                    .catch(
                        function (oError) {
                            /* eslint-disable-next-line no-console */
                            console.error("Failed to load totals for " + sField, oError);
                            this._oTotalsPopover.close();
                            this._showResourceText("table.totalsError", MessageToast.show);
                        }.bind(this)
                    )
                    .finally(
                        function () {
                            this._oTotalsPopover.setBusy(false);
                            this._oTotalsProgressText.setText("");
                        }.bind(this)
                    );
            },

            // A raw fetch() straight to getDownloadUrl() left the request PENDING forever against
            // the real backend - it bypasses the model's own request plumbing (CSRF token
            // handling, $batch wrapping, whatever else this backend's Gateway/proxy layer expects
            // of a "real" OData request), unlike normal table scrolling, which reads fine because
            // it goes through that same plumbing via requestContexts. Sequential 200-row
            // requestContexts calls worked but were slow purely from round-trip latency (10+
            // requests, one after another). This fetches the first page alone (both real data and,
            // via $count, an accurate page count), then requests the rest GROUP_FETCH_CONCURRENCY
            // pages at a time via Promise.all - concurrent calls on one binding get coalesced by
            // UI5's own "$auto" group into a single $batch request, so this is still one HTTP round
            // trip per chunk, just carrying several pages instead of one.
            //
            // fnProgress(iFetched, iTotal) is optional - both Group By's dialog and Totals'
            // popover use it (via _updateGroupProgress/_updateTotalsProgress) to show live
            // "X / Y rows" feedback instead of leaving the user staring at a bare busy indicator.
            //
            // iPageSize/iConcurrency default to Group By's (conservative, wide-row) numbers;
            // _requestTotals passes its own bigger TOTALS_FETCH_* pair since its rows are just 2
            // columns wide, see the comment on those constants above.
            _fetchAllRows: function (aSelectFields, fnProgress, iRequestedPageSize, iRequestedConcurrency) {
                var iPageSize = iRequestedPageSize || GROUP_FETCH_PAGE_SIZE,
                    iConcurrency = iRequestedConcurrency || GROUP_FETCH_CONCURRENCY,
                    oBinding = this.getOwnerComponent()
                        .getModel()
                        .bindList(ENTITY_PATH, undefined, undefined, this._getCurrentFilters(), {
                            $select: aSelectFields.join(","),
                            $count: true
                        });

                return oBinding.requestContexts(0, iPageSize).then(
                    function (aFirstPageContexts) {
                        var aAllRows = aFirstPageContexts.map(function (oContext) {
                                return oContext.getObject();
                            }),
                            iTotalCount = oBinding.getCount();

                        this._reportFetchProgress(aAllRows.length, iTotalCount, fnProgress);

                        // Fewer rows than asked for means this was already the only/last page -
                        // an unknown $count (some backends never send it) also isn't safe to plan
                        // further pages against, so stop here rather than guess.
                        if (aAllRows.length < iPageSize || iTotalCount === undefined || aAllRows.length >= iTotalCount) {
                            return aAllRows;
                        }

                        var aRemainingStarts = [];
                        for (var iStart = iPageSize; iStart < iTotalCount; iStart += iPageSize) {
                            aRemainingStarts.push(iStart);
                        }

                        return this._fetchPagesInChunks(
                            oBinding,
                            aRemainingStarts,
                            aAllRows.length,
                            iTotalCount,
                            fnProgress,
                            iPageSize,
                            iConcurrency
                        ).then(function (aRemainingRows) {
                            return aAllRows.concat(aRemainingRows);
                        });
                    }.bind(this)
                );
            },

            // Works through aStarts iConcurrency at a time (rather than all at once, which would
            // mean firing potentially a dozen-plus concurrent requests at a backend that's already
            // shown itself fragile under load - see the $apply/getDownloadUrl comments elsewhere in
            // this file).
            _fetchPagesInChunks: function (oBinding, aStarts, iFetchedSoFar, iTotalCount, fnProgress, iPageSize, iConcurrency) {
                if (!aStarts.length) {
                    return Promise.resolve([]);
                }

                var aChunkStarts = aStarts.slice(0, iConcurrency),
                    aRestStarts = aStarts.slice(iConcurrency);

                return Promise.all(
                    aChunkStarts.map(function (iStart) {
                        return oBinding.requestContexts(iStart, iPageSize);
                    })
                ).then(
                    function (aPagesOfContexts) {
                        var aChunkRows = aPagesOfContexts.reduce(function (aFlat, aContexts) {
                            return aFlat.concat(
                                aContexts.map(function (oContext) {
                                    return oContext.getObject();
                                })
                            );
                        }, []);

                        this._reportFetchProgress(iFetchedSoFar + aChunkRows.length, iTotalCount, fnProgress);

                        return this._fetchPagesInChunks(
                            oBinding,
                            aRestStarts,
                            iFetchedSoFar + aChunkRows.length,
                            iTotalCount,
                            fnProgress,
                            iPageSize,
                            iConcurrency
                        ).then(function (aRestRows) {
                            return aChunkRows.concat(aRestRows);
                        });
                    }.bind(this)
                );
            },

            _reportFetchProgress: function (iFetched, iTotal, fnProgress) {
                /* eslint-disable-next-line no-console */
                console.log("[GroupBy/Totals] fetched " + iFetched + (iTotal !== undefined ? " / " + iTotal : "") + " rows");
                if (fnProgress) {
                    fnProgress(iFetched, iTotal);
                }
            },

            // zce_zmb51n is a RAP custom entity (@ObjectModel.query.implementedBy), not a plain
            // CDS view over a DB table - there's no SQL engine underneath for the framework to
            // push a GROUP BY/SUM into, so $apply=groupby/aggregate would only work if the
            // backend's query provider class explicitly implemented aggregation handling, which
            // it doesn't. Summing client-side instead: fetch every matching row (same filters as
            // the table) but ONLY the two columns actually needed, then group+sum in JS. Costs
            // more data on the wire than a real aggregate request would, but works against any
            // custom entity that supports plain filter+$select+paging - no backend changes needed.
            _requestTotals: function (sField, sUnitField) {
                return this._fetchAllRows(
                    [sUnitField, sField],
                    this._updateTotalsProgress.bind(this),
                    TOTALS_FETCH_PAGE_SIZE,
                    TOTALS_FETCH_CONCURRENCY
                ).then(function (aRows) {
                    var mSumByUnit = {};

                    aRows.forEach(function (oRow) {
                        var sUnit = oRow[sUnitField] || "",
                            fValue = Number(oRow[sField]) || 0;

                        mSumByUnit[sUnit] = (mSumByUnit[sUnit] || 0) + fValue;
                    });

                    return Object.keys(mSumByUnit).map(function (sUnit) {
                        var oRow = {};
                        oRow[sUnitField] = sUnit;
                        oRow.Total = mSumByUnit[sUnit];
                        return oRow;
                    });
                });
            },

            _formatTotal: function (fValue) {
                if (!this._oNumberFormat) {
                    this._oNumberFormat = NumberFormat.getFloatInstance({ groupingEnabled: true, maxFractionDigits: 3 });
                }
                return this._oNumberFormat.format(fValue);
            },

            // Reuses the real @UI.lineItem label (e.g. "Quantity in Entry Unit") already loaded
            // for the table's own columns, so the Group By header text ("Quantity in Entry Unit:
            // 14,819 KG · Quantity in Base Unit: 28,587 KG") says which number is which instead of
            // two unlabeled totals side by side.
            _getFieldLabel: function (sFieldName) {
                var oField = (this._aCurrentColumnsMeta || []).filter(function (oCandidate) {
                    return oCandidate.name === sFieldName;
                })[0];
                return (oField && oField.label) || sFieldName;
            },

            _showResourceText: function (sKey, fnShow) {
                var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();
                if (oBundle && typeof oBundle.then === "function") {
                    oBundle.then(function (oResolvedBundle) {
                        fnShow(oResolvedBundle.getText(sKey));
                    });
                } else {
                    fnShow(oBundle.getText(sKey));
                }
            },

            // Every @UI.lineItem field is a Group By candidate EXCEPT: the entity's own key
            // (GROUP_KEY_FIELDS - already unique per row, shown on every detail row regardless),
            // amount fields (GROUP_BY_EXCLUDED_FIELDS - grouping by a currency amount isn't
            // meaningful), the 2 quantity fields themselves (they're the subtotal TARGETS, not
            // dimensions), and description/name fields - excluded both by name
            // (GROUP_FIELD_DESCRIPTIONS' values) and, as a catch-all for any not explicitly
            // mapped there, by an ...Description/...Name suffix check. A description field still
            // shows up automatically as an extra detail column whenever its paired field (the
            // GROUP_FIELD_DESCRIPTIONS key) is the one actually grouped by - see
            // _getGroupDetailFields.
            _buildGroupByFields: function (aColumns) {
                var aExcludedFields = GROUP_KEY_FIELDS.concat(GROUP_BY_EXCLUDED_FIELDS, GROUP_SUBTOTAL_FIELDS),
                    aDescriptionFields = Object.keys(GROUP_FIELD_DESCRIPTIONS).map(function (sField) {
                        return GROUP_FIELD_DESCRIPTIONS[sField];
                    });

                return aColumns
                    .filter(function (oField) {
                        return (
                            aExcludedFields.indexOf(oField.name) === -1 &&
                            aDescriptionFields.indexOf(oField.name) === -1 &&
                            !/(Description|Name)$/.test(oField.name)
                        );
                    })
                    .map(function (oField) {
                        return { key: oField.name, label: oField.label, descriptionField: GROUP_FIELD_DESCRIPTIONS[oField.name] };
                    });
            },

            // Deliberately a standalone dialog reading a client-side JSONModel, NOT grouped rows
            // inside materialDocumentsTable itself - see the comment on groupByButton in
            // List.view.xml for why. Built once; reopening just re-runs _loadGroupData for
            // whatever field is currently selected, picking up the table's current filters.
            onOpenGroupBy: function () {
                if (!this._oGroupDialog) {
                    // Resolved once and cached rather than awaited inline in _buildGroupHeaderRow,
                    // which must return its row object synchronously for the JSONModel.
                    this._sGroupEmptyValueText = "(Blank)";
                    this._showResourceText("groupBy.emptyValue", function (sText) {
                        this._sGroupEmptyValueText = sText;
                    }.bind(this));

                    this._oGroupModel = new JSONModel({ rows: [], progressText: "" });

                    // Items are (re)populated on every open (see below the dialog-building block),
                    // not just here - this._aGroupByFields depends on the current Main Entity's
                    // extra fields (see _applyMainEntityFields), which can change after this
                    // dialog was first built.
                    this._oGroupFieldSelect = new Select({
                        change: function (oEvent) {
                            this._loadGroupData(oEvent.getSource().getSelectedKey());
                        }.bind(this)
                    });

                    // Fetching the full filtered result set (see _loadGroupData/_fetchAllRows) can
                    // take a while at 200 rows/request against this backend, so this stands in for
                    // "loading..." with actual "X / Y rows" feedback rather than a bare spinner -
                    // set from _fetchAllRows's fnProgress callback via _updateGroupProgress.
                    this._oGroupProgressText = new Text({ text: "{/progressText}" }).addStyleClass(
                        "sapUiSmallMarginBegin sapUiTinyMarginBottom"
                    );
                    this._oGroupProgressText.setModel(this._oGroupModel);

                    // 13k+ rows can mean thousands of distinct groups - sap.m.Table renders its
                    // entire items aggregation eagerly with no virtualization unless "growing" is
                    // on, so without this a large enough result set doesn't just render slowly, it
                    // can lock up the render thread badly enough to look like the dialog is stuck
                    // showing only the first chunk, even though _aGroupRawRows already has
                    // everything (see the fetched X / Y console log this reads from).
                    //
                    // A real column table instead of a stacked ObjectListItem list - group headers
                    // (see _createGroupListItem) are ColumnListItems too, with their summary text
                    // in the first cell and the rest left blank, since ColumnListItem has no
                    // built-in cell-spanning. Columns are built by _rebuildGroupColumns (called
                    // from _loadGroupData) rather than fixed here, since they depend on which
                    // field is currently grouped by - see _getGroupDetailFields.
                    this._oGroupTable = new MTable({
                        growing: true,
                        growingThreshold: 50,
                        // NOT growingScrollToLoad - it attaches its own scroll listener on the
                        // dialog's shared scroll container, and opening a popover (Show Details,
                        // Totals) inside that same container can trigger a scroll/resize event
                        // that listener misreads as "user scrolled near the end", silently
                        // resetting growing back to the first page and yanking the view back to
                        // the top - not what the "Show Details" button that was actually clicked
                        // asked for. The explicit "More" trigger growing renders by default has no
                        // such scroll-listener side effect.
                        sticky: ["ColumnHeaders"],
                        alternateRowColors: true,
                        items: {
                            path: "/rows",
                            factory: this._createGroupListItem.bind(this)
                        }
                    });
                    this._oGroupTable.setModel(this._oGroupModel);

                    this._oGroupDialog = new Dialog({
                        title: "{i18n>groupBy.title}",
                        // Percentage rather than a fixed rem value - GROUP_KEY_FIELDS alone is 4
                        // columns, plus the group field/description and the 2 quantities, so a
                        // fixed width that looked fine at 7 columns needed manual resizing once an
                        // 8th (Nhom) showed up. This scales with the viewport instead of needing
                        // that every time the column count/labels change.
                        contentWidth: "95%",
                        contentHeight: "85%",
                        resizable: true,
                        draggable: true,
                        content: [
                            new HBox({
                                alignItems: "Center",
                                items: [new Label({ text: "{i18n>groupBy.field}", labelFor: this._oGroupFieldSelect }), this._oGroupFieldSelect]
                            }).addStyleClass("sapUiSmallMargin"),
                            this._oGroupProgressText,
                            this._oGroupTable
                        ],
                        beginButton: new Button({
                            text: "{i18n>groupBy.close}",
                            press: function () {
                                this._oGroupDialog.close();
                            }.bind(this)
                        }),
                        endButton: new Button({
                            text: "{i18n>table.export}",
                            icon: "sap-icon://excel-attachment",
                            press: this.onExportGroupSubtotal.bind(this)
                        })
                    });
                    this.getView().addDependent(this._oGroupDialog);
                }

                // Refreshed every open (not just the first) so switching Main Entity between one
                // Subtotal use and the next picks up that entity's own extra fields - keep the
                // current selection if it's still a valid field for the new entity, otherwise fall
                // back to the first one.
                var sPreviousKey = this._oGroupFieldSelect.getSelectedKey(),
                    bStillValid = this._aGroupByFields.some(function (oField) {
                        return oField.key === sPreviousKey;
                    });

                this._oGroupFieldSelect.destroyItems();
                this._aGroupByFields.forEach(function (oField) {
                    this._oGroupFieldSelect.addItem(new Item({ key: oField.key, text: oField.label }));
                }, this);
                this._oGroupFieldSelect.setSelectedKey(bStillValid ? sPreviousKey : this._aGroupByFields[0].key);

                this._oGroupDialog.open();
                this._loadGroupData(this._oGroupFieldSelect.getSelectedKey());
            },

            // Header rows (summary text in the first cell, rest blank - see _oGroupTable's column
            // comment) vs. detail rows (one cell per column, matching _oGroupTable's 7 columns) -
            // which one a given /rows entry renders as is decided by _rebuildGroupDisplay's
            // "__group" flag. Both are ColumnListItem so they line up under the same columns and
            // header presses (onToggleGroup) work the same way StandardListItem's did before.
            // Detail-field cells are built from this._aGroupDetailFields (set by _loadGroupData
            // for whichever field is currently grouped by - see _getGroupDetailFields) rather than
            // named individually, so this needs no changes when that field list changes.
            _createGroupListItem: function (sId, oContext) {
                var oRow = oContext.getObject(),
                    aDetailFields = this._aGroupDetailFields || [];

                if (oRow.__group) {
                    var aHeaderCells = [
                        new HBox({
                            items: [
                                new Icon({
                                    src: oRow.__expanded ? "sap-icon://navigation-down-arrow" : "sap-icon://navigation-right-arrow"
                                }).addStyleClass("sapUiTinyMarginEnd"),
                                new Label({ text: oRow.__label, design: "Bold" })
                            ]
                        })
                    ];
                    aDetailFields.slice(1).forEach(function () {
                        aHeaderCells.push(new Text());
                    });
                    aHeaderCells.push(this._createGroupSubtotalCell(oRow.__key, "QuantityInEntryUnit"));
                    aHeaderCells.push(this._createGroupSubtotalCell(oRow.__key, "QuantityInBaseUnit"));

                    return new ColumnListItem(sId, {
                        type: "Active",
                        press: this.onToggleGroup.bind(this),
                        // Same left-edge highlight bar mechanism as the main table's Debit/Credit
                        // indicator (RowSettings#highlight there, ListItemBase#highlight here) -
                        // marks group/subtotal rows at a glance among the plain detail rows below.
                        highlight: "Information",
                        cells: aHeaderCells
                    }).addCustomData(new CustomData({ key: "groupKey", value: oRow.__key }));
                }

                var aDetailCells = aDetailFields.map(function (sFieldName) {
                    return new Text({ text: oRow[sFieldName] });
                });
                aDetailCells.push(new Text({ text: this._formatTotal(oRow.QuantityInEntryUnit) + " " + (oRow.EntryUnit || "") }));
                aDetailCells.push(new Text({ text: this._formatTotal(oRow.QuantityInBaseUnit) + " " + (oRow.MaterialBaseUnit || "") }));

                return new ColumnListItem(sId, { cells: aDetailCells });
            },

            // A group whose rows all share one unit for this field shows the value directly; one
            // that mixes units (e.g. some rows in KG, others in CAI) shows a "Show Details" button
            // instead of the full breakdown - showing it inline is what silently got clipped by
            // the column's fixed width before (see the conversation this replaced), and a plain
            // wider column doesn't fix that in general since a group can mix arbitrarily many units.
            _createGroupSubtotalCell: function (sKey, sQtyField) {
                var mByUnit = (this._mGroupSubtotals[sKey] && this._mGroupSubtotals[sKey].totals[sQtyField]) || {},
                    aUnits = Object.keys(mByUnit);

                if (aUnits.length <= 1) {
                    var sUnit = aUnits[0];
                    return new Label({ text: sUnit ? this._formatTotal(mByUnit[sUnit]) + " " + sUnit : "", design: "Bold" });
                }

                return new Button({
                    text: "{i18n>groupBy.showDetails}",
                    type: "Transparent",
                    press: this.onShowGroupSubtotalDetails.bind(this)
                })
                    .addCustomData(new CustomData({ key: "groupKey", value: sKey }))
                    .addCustomData(new CustomData({ key: "qtyField", value: sQtyField }));
            },

            // Opens the same per-unit-sum popover pattern as onShowTotals, but scoped to one
            // group's already-computed subtotals (_mGroupSubtotals) - no new request needed, the
            // full breakdown was already there, just not shown inline (see
            // _createGroupSubtotalCell).
            onShowGroupSubtotalDetails: function (oEvent) {
                var oButton = oEvent.getSource(),
                    sKey = oButton.data("groupKey"),
                    sQtyField = oButton.data("qtyField"),
                    mByUnit = (this._mGroupSubtotals[sKey] && this._mGroupSubtotals[sKey].totals[sQtyField]) || {};

                if (!this._oGroupSubtotalDetailPopover) {
                    this._oGroupSubtotalDetailList = new List();
                    this._oGroupSubtotalDetailPopover = new ResponsivePopover({
                        title: "{i18n>table.totals}",
                        placement: "Bottom",
                        content: [this._oGroupSubtotalDetailList]
                    });
                    this.getView().addDependent(this._oGroupSubtotalDetailPopover);
                }

                this._oGroupSubtotalDetailList.destroyItems();
                Object.keys(mByUnit).forEach(
                    function (sUnit) {
                        this._oGroupSubtotalDetailList.addItem(
                            new StandardListItem({ title: this._formatTotal(mByUnit[sUnit]), info: sUnit, infoState: "None" })
                        );
                    }.bind(this)
                );

                this._oGroupSubtotalDetailPopover.openBy(oButton);
            },

            onToggleGroup: function (oEvent) {
                var sKey = oEvent.getSource().data("groupKey");
                this._mGroupExpanded[sKey] = !this._mGroupExpanded[sKey];
                this._rebuildGroupDisplay();
            },

            // The field being grouped by, its description field (if this._aGroupByFields declares
            // one), and GROUP_KEY_FIELDS - in that order, deduplicated. Drives both the detail
            // columns (_rebuildGroupColumns) and each detail row's cells (_createGroupListItem),
            // so a group-by field with no description just doesn't get that column, without any
            // other code needing to know the difference.
            _getGroupDetailFields: function (sField) {
                var oFieldConfig = this._aGroupByFields.filter(function (oCandidate) {
                        return oCandidate.key === sField;
                    })[0],
                    aFields = [sField];

                if (oFieldConfig && oFieldConfig.descriptionField) {
                    aFields.push(oFieldConfig.descriptionField);
                }
                GROUP_KEY_FIELDS.forEach(function (sKeyField) {
                    if (aFields.indexOf(sKeyField) === -1) {
                        aFields.push(sKeyField);
                    }
                });
                return aFields;
            },

            // aDetailFields (plain text columns) followed by GROUP_SUBTOTAL_FIELDS (right-aligned,
            // see _createGroupSubtotalCell for why they're not just more Text cells).
            _rebuildGroupColumns: function (aDetailFields) {
                this._oGroupTable.destroyColumns();
                aDetailFields.concat(GROUP_SUBTOTAL_FIELDS).forEach(
                    function (sFieldName, i) {
                        this._oGroupTable.addColumn(
                            new MColumn({
                                hAlign: i >= aDetailFields.length ? "End" : "Begin",
                                header: new Text({ text: this._getFieldLabel(sFieldName) })
                            })
                        );
                    }.bind(this)
                );
            },

            // Fetches every row matching the CURRENT filters (same ones onGo/Totals use) but only
            // the columns actually needed here - _getGroupDetailFields's result and the
            // quantity/unit pairs from TOTALS_UNIT_FIELD - then computes per-group subtotals and
            // counts client-side. Same "no $apply" reasoning as _requestTotals: zce_zmb51n is a
            // RAP custom entity with no backend aggregation support.
            _loadGroupData: function (sField) {
                this._sGroupByField = sField;
                this._mGroupExpanded = {};
                this._oGroupTable.setBusy(true);
                this._oGroupModel.setProperty("/progressText", "");

                this._aGroupDetailFields = this._getGroupDetailFields(sField);
                this._rebuildGroupColumns(this._aGroupDetailFields);

                var aSelectFields = this._aGroupDetailFields.concat(
                    GROUP_SUBTOTAL_FIELDS,
                    GROUP_SUBTOTAL_FIELDS.map(function (sQtyField) {
                        return TOTALS_UNIT_FIELD[sQtyField];
                    })
                );

                this._fetchAllRows(aSelectFields, this._updateGroupProgress.bind(this))
                    .then(
                        function (aRows) {
                            aRows.sort(function (a, b) {
                                return String(a[sField] || "").localeCompare(String(b[sField] || ""));
                            });

                            this._aGroupRawRows = aRows;
                            this._mGroupSubtotals = this._computeGroupSubtotals(aRows, sField);
                            this._rebuildGroupDisplay();
                        }.bind(this)
                    )
                    .catch(
                        function (oError) {
                            /* eslint-disable-next-line no-console */
                            console.error("Failed to load grouped data for " + sField, oError);
                            this._showResourceText("groupBy.loadError", MessageToast.show);
                        }.bind(this)
                    )
                    .finally(
                        function () {
                            this._oGroupTable.setBusy(false);
                            this._oGroupModel.setProperty("/progressText", "");
                        }.bind(this)
                    );
            },

            // Shared by Group By's model-bound progress text and Totals' plain Text control -
            // fnApply(sText) is however the caller actually wants the formatted string applied.
            _formatFetchProgress: function (iFetched, iTotal, fnApply) {
                var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle(),
                    aArgs = [iFetched, iTotal !== undefined ? iTotal : iFetched];

                if (oBundle && typeof oBundle.then === "function") {
                    oBundle.then(function (oResolvedBundle) {
                        fnApply(oResolvedBundle.getText("groupBy.progress", aArgs));
                    });
                } else if (oBundle) {
                    fnApply(oBundle.getText("groupBy.progress", aArgs));
                }
            },

            _updateGroupProgress: function (iFetched, iTotal) {
                this._formatFetchProgress(
                    iFetched,
                    iTotal,
                    function (sText) {
                        this._oGroupModel.setProperty("/progressText", sText);
                    }.bind(this)
                );
            },

            _updateTotalsProgress: function (iFetched, iTotal) {
                this._formatFetchProgress(
                    iFetched,
                    iTotal,
                    function (sText) {
                        this._oTotalsProgressText.setText(sText);
                    }.bind(this)
                );
            },

            // { <group key>: { count, totals: { <quantity field>: { <unit>: <sum> } } } }
            _computeGroupSubtotals: function (aRows, sField) {
                var mSubtotals = {};

                aRows.forEach(function (oRow) {
                    var sKey = oRow[sField] || "";

                    if (!mSubtotals[sKey]) {
                        mSubtotals[sKey] = { count: 0, totals: {} };
                        GROUP_SUBTOTAL_FIELDS.forEach(function (sQtyField) {
                            mSubtotals[sKey].totals[sQtyField] = {};
                        });
                    }
                    mSubtotals[sKey].count++;

                    GROUP_SUBTOTAL_FIELDS.forEach(function (sQtyField) {
                        var sUnitField = TOTALS_UNIT_FIELD[sQtyField],
                            sUnit = oRow[sUnitField] || "",
                            fValue = Number(oRow[sQtyField]) || 0,
                            mByUnit = mSubtotals[sKey].totals[sQtyField];

                        mByUnit[sUnit] = (mByUnit[sUnit] || 0) + fValue;
                    });
                });

                return mSubtotals;
            },

            // Rebuilds the flat /rows array (group headers + expanded children, per
            // this._mGroupExpanded) from the already-fetched this._aGroupRawRows - no new request,
            // so toggling a group open/closed is instant.
            _rebuildGroupDisplay: function () {
                var sField = this._sGroupByField,
                    aRaw = this._aGroupRawRows || [],
                    aDisplay = [],
                    sCurrentKey = null;

                aRaw.forEach(
                    function (oRow) {
                        var sKey = oRow[sField] || "";

                        if (sKey !== sCurrentKey) {
                            sCurrentKey = sKey;
                            aDisplay.push(this._buildGroupHeaderRow(sKey));
                        }
                        if (this._mGroupExpanded[sKey]) {
                            var oDisplayRow = Object.assign({ __group: false }, oRow);
                            aDisplay.push(oDisplayRow);
                        }
                    }.bind(this)
                );

                this._oGroupModel.setProperty("/rows", aDisplay);
            },

            // Per-field subtotal display is built later, in _createGroupSubtotalCell (called from
            // _createGroupListItem with __key + the field name) - it needs to know how many
            // distinct units a field has for THIS group to decide between showing the value
            // directly or a "Show Details" button, which this row object alone can't capture.
            _buildGroupHeaderRow: function (sKey) {
                var oInfo = this._mGroupSubtotals[sKey] || { count: 0, totals: {} };

                return {
                    __group: true,
                    __key: sKey,
                    __expanded: !!this._mGroupExpanded[sKey],
                    __label: (sKey || this._sGroupEmptyValueText) + " (" + oInfo.count + ")"
                };
            },

            // sap.ui.export.Spreadsheet (used by the main table's onExport) can't color cells at
            // all - confirmed against its own JSDoc/restrictions, not a guess - so an ALV-style
            // export (yellow bold SUBTOTAL row per group, that group's own detail rows
            // underneath) needs a library that actually supports cell styling. ExcelJS, loaded
            // from webapp/libs/exceljs.min.js, is that library - bundled locally rather than
            // pulled from a CDN because S/4HANA Cloud's CSP blocks that (this exact local-bundle
            // approach has precedent elsewhere in this repo's history).
            _loadExcelJs: function () {
                if (window.ExcelJS) {
                    return Promise.resolve();
                }
                if (!this._pExcelJsLoad) {
                    this._pExcelJsLoad = new Promise(function (resolve, reject) {
                        // Loading a plain UMD script has no UI5-control equivalent - there's
                        // nothing to wrap this in besides the DOM APIs directly.
                        /* eslint-disable-next-line @sap-ux/fiori-tools/sap-no-element-creation */
                        var oScript = document.createElement("script");
                        oScript.src = sap.ui.require.toUrl("zmb51nov4/libs/exceljs.min.js");
                        oScript.onload = resolve;
                        oScript.onerror = reject;
                        /* eslint-disable-next-line @sap-ux/fiori-tools/sap-no-dom-insertion */
                        document.head.appendChild(oScript);
                    });
                }
                return this._pExcelJsLoad;
            },

            _addGroupSubtotalRow: function (oSheet, sField, sKey) {
                var oInfo = this._mGroupSubtotals[sKey] || { count: 0, totals: {} },
                    oRowData = {},
                    iMaxUnitLines = 1;

                oRowData[sField] = (sKey || this._sGroupEmptyValueText) + " (" + oInfo.count + ")";
                GROUP_SUBTOTAL_FIELDS.forEach(
                    function (sQtyField) {
                        var mByUnit = oInfo.totals[sQtyField] || {},
                            aUnits = Object.keys(mByUnit);

                        // One unit per line (not a comma-joined single line) so a group mixing
                        // several units doesn't spill out of the cell/column illegibly - paired
                        // with wrapText + a row height tall enough for however many lines that
                        // needs, below.
                        oRowData[sQtyField] = aUnits
                            .map(
                                function (sUnit) {
                                    return this._formatTotal(mByUnit[sUnit]) + (sUnit ? " " + sUnit : "");
                                }.bind(this)
                            )
                            .join("\n");
                        iMaxUnitLines = Math.max(iMaxUnitLines, aUnits.length);
                    }.bind(this)
                );

                var oRow = oSheet.addRow(oRowData);

                oRow.eachCell({ includeEmpty: true }, function (oCell) {
                    oCell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFFF00" } };
                    oCell.font = { bold: true };
                    oCell.alignment = { wrapText: true, vertical: "top" };
                });
                // ExcelJS default row height is ~15pt per line - not recalculated automatically
                // for wrapped text, so it has to be set explicitly or multi-line cells just get
                // vertically clipped instead of actually showing every line.
                if (iMaxUnitLines > 1) {
                    oRow.height = iMaxUnitLines * 15;
                }
            },

            _addGroupDetailRow: function (oSheet, aColumnFields, oRawRow) {
                var oRowData = {};

                aColumnFields.forEach(function (sFieldName) {
                    if (sFieldName === "QuantityInEntryUnit") {
                        oRowData[sFieldName] = this._formatTotal(oRawRow.QuantityInEntryUnit) + " " + (oRawRow.EntryUnit || "");
                    } else if (sFieldName === "QuantityInBaseUnit") {
                        oRowData[sFieldName] = this._formatTotal(oRawRow.QuantityInBaseUnit) + " " + (oRawRow.MaterialBaseUnit || "");
                    } else {
                        oRowData[sFieldName] = oRawRow[sFieldName];
                    }
                }, this);

                oSheet.addRow(oRowData);
            },

            // Standard Blob + temporary <a download> trigger - no UI5-control equivalent for
            // "hand the browser a generated binary file to save" either, same as _loadExcelJs.
            _downloadWorkbook: function (oWorkbook, sFileName) {
                return oWorkbook.xlsx.writeBuffer().then(function (oBuffer) {
                    var oBlob = new Blob([oBuffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }),
                        sUrl = URL.createObjectURL(oBlob),
                        oLink = document.createElement("a");

                    oLink.href = sUrl;
                    oLink.download = sFileName;
                    /* eslint-disable-next-line @sap-ux/fiori-tools/sap-no-dom-insertion */
                    document.body.appendChild(oLink);
                    oLink.click();
                    document.body.removeChild(oLink);
                    URL.revokeObjectURL(sUrl);
                });
            },

            // ALV-style export: for each group (in the same order shown on screen) a yellow bold
            // subtotal row, immediately followed by that group's own detail rows - matching
            // exactly what's on screen instead of the earlier one-row-per-group summary. Reads
            // straight from the already-computed this._aGroupRawRows/_mGroupSubtotals - no new
            // request.
            onExportGroupSubtotal: function (oEvent) {
                var sField = this._sGroupByField,
                    aRawRows = this._aGroupRawRows || [],
                    aDetailFields = this._aGroupDetailFields || [];

                if (!aRawRows.length) {
                    return;
                }

                var oButton = oEvent.getSource();
                oButton.setBusy(true);

                this._loadExcelJs()
                    .then(
                        function () {
                            var oFieldConfig = this._aGroupByFields.filter(function (oCandidate) {
                                    return oCandidate.key === sField;
                                })[0],
                                sFieldLabel = (oFieldConfig && oFieldConfig.label) || sField,
                                aColumnFields = aDetailFields.concat(GROUP_SUBTOTAL_FIELDS),
                                oWorkbook = new window.ExcelJS.Workbook(),
                                oSheet = oWorkbook.addWorksheet(sFieldLabel),
                                sCurrentKey = null;

                            oSheet.columns = aColumnFields.map(
                                function (sFieldName) {
                                    return { header: this._getFieldLabel(sFieldName), key: sFieldName, width: 20 };
                                }.bind(this)
                            );
                            oSheet.getRow(1).font = { bold: true };

                            aRawRows.forEach(
                                function (oRawRow) {
                                    var sKey = oRawRow[sField] || "";

                                    if (sKey !== sCurrentKey) {
                                        sCurrentKey = sKey;
                                        this._addGroupSubtotalRow(oSheet, sField, sKey);
                                    }
                                    this._addGroupDetailRow(oSheet, aColumnFields, oRawRow);
                                }.bind(this)
                            );

                            // getTitle(), not the "{i18n>groupBy.title}" binding string itself -
                            // that syntax only resolves when assigned to an actual control
                            // property (like the Dialog's own title), not in plain concatenation.
                            return this._downloadWorkbook(oWorkbook, this._oGroupDialog.getTitle() + " - " + sFieldLabel + ".xlsx");
                        }.bind(this)
                    )
                    .catch(
                        function (oError) {
                            /* eslint-disable-next-line no-console */
                            console.error("Failed to export grouped data", oError);
                            this._showResourceText("groupBy.exportError", MessageToast.show);
                        }.bind(this)
                    )
                    .finally(function () {
                        oButton.setBusy(false);
                    });
            },

            // Flags each field meta with isInterval based on the entity set's
            // FilterExpressionRestrictions (Range-typed properties = @Consumption.filter.selectionType: #INTERVAL).
            // Kept for reference/columns even though mdc FilterField derives its own date operators
            // from dataType + maxConditions rather than this flag.
            _markIntervalFields: function (aFields) {
                aFields.forEach(
                    function (oField) {
                        oField.isInterval = this._aIntervalFieldNames.indexOf(oField.name) !== -1;
                    }.bind(this)
                );
                return aFields;
            },

            // Converts our own field metadata ({name, label, type, hasValueHelp, ...}) into
            // sap.ui.mdc PropertyInfo objects consumed by FilterBarDelegate. sap.ui.mdc.util.
            // PropertyHelper strictly validates these objects and throws "Property contains
            // invalid attribute '<name>'" for ANY key outside its own fixed schema (key, label,
            // path, dataType, maxConditions, ...) - so F4 collection info can't be attached
            // directly onto them. It's returned separately as a { key -> f4Info } map instead,
            // resolved eagerly here (there are only ever one or two such fields) and passed to
            // the FilterBar via a distinct payload key (see _applyMainEntityFields).
            _buildPropertyInfo: function (aFields) {
                var mF4InfoByKey = {};

                return Promise.all(
                    aFields.map(function (oField) {
                        var oProperty = {
                            key: oField.name,
                            label: oField.label,
                            path: oField.name,
                            dataType: EDM_TO_MDC_TYPE[oField.type] || "sap.ui.model.type.String",
                            // Boolean/Date fields get a single condition slot so mdc renders its
                            // simple built-in value help (Select / DynamicDateRange-style "Single
                            // Dates, Date Ranges" picker) instead of the multi-row "Define
                            // Conditions" dialog, which is reserved for multi-value String fields.
                            maxConditions: oField.type === "Edm.Boolean" || oField.type === "Edm.Date" ? 1 : -1
                        };

                        if (!oField.hasValueHelp) {
                            return oProperty;
                        }

                        return metadataHelper
                            .requestValueHelpInfo(this._oMetaModel, ENTITY_PATH + "/" + oField.name)
                            .then(function (oInfo) {
                                if (oInfo) {
                                    mF4InfoByKey[oProperty.key] = oInfo;
                                }
                                return oProperty;
                            });
                    }, this)
                ).then(function (aPropertyInfo) {
                    return { propertyInfo: aPropertyInfo, f4InfoByKey: mF4InfoByKey };
                });
            },

            onMainEntityChange: function (oEvent) {
                var oTable = this.byId("materialDocumentsTable");
                oTable.setBusy(true);

                // A manual Main Entity switch steps outside whatever saved view was selected
                // (its field set no longer matches) - drop back to Standard, unmarked.
                if (this._oVariantManagement && !this._bApplyingVariant) {
                    this._oVariantManagement.setSelectedKey(STANDARD_VARIANT_KEY);
                    this._oVariantManagement.setModified(false);
                }

                this._applyMainEntityFields(oEvent.getSource().getSelectedKey()).then(function () {
                    oTable.setBusy(false);
                });
            },

            // Rebuilds table columns + the mdc FilterBar (base @UI.LineItem/@UI.SelectionFields set
            // plus any extra fields for the given Main Entity) and rebinds the table to match, in
            // that order - columns must exist before the rows are bound so autoExpandSelect picks
            // them up. The FilterBar itself is destroyed and recreated rather than having its
            // filterItems patched in place, since sap.ui.mdc caches PropertyInfo per instance.
            _applyMainEntityFields: function (sMainEntity) {
                var oTable = this.byId("materialDocumentsTable"),
                    oHolder = this.byId("filterBarHolder"),
                    aExtraFieldNames = EXTRA_FIELDS_BY_MAIN_ENTITY[sMainEntity] || [];

                // Suppresses the "modified" (*) marker while the bar is torn down and rebuilt -
                // the FilterField adds below fire filtersChanged that _onFilterBarFiltersChanged
                // would otherwise read as a user edit. Cleared in the terminal handler.
                this._bBuildingFilterBar = true;

                return Promise.all(
                    aExtraFieldNames.map(function (sName) {
                        return metadataHelper.requestFieldDetail(this._oMetaModel, ENTITY_PATH, sName);
                    }, this)
                )
                    .then(
                        function (aExtraFields) {
                            this._markIntervalFields(aExtraFields);

                            var aAllColumns = this._aBaseColumnsMeta.concat(aExtraFields);

                            oTable.destroyColumns();
                            this._buildColumns(oTable, aAllColumns);
                            // Recomputed on every Main Entity switch, not just once in onInit - the
                            // Subtotal field picker (onOpenGroupBy) should offer whatever extra
                            // fields (Loai2, MaHang2, ...) the CURRENT Main Entity actually has,
                            // same as the table's own columns do.
                            this._aGroupByFields = this._buildGroupByFields(aAllColumns);

                            var aFilterFields = this._aBaseFilterFieldsMeta.concat(aExtraFields);
                            this._aFilterFieldsMeta = aFilterFields;

                            return this._buildPropertyInfo(aFilterFields);
                        }.bind(this)
                    )
                    .then(
                        function (oPropertyInfoResult) {
                            oHolder.destroyItems();

                            var aPropertyInfo = oPropertyInfoResult.propertyInfo,
                                // Adapt Filters' Item p13n (add/remove a filter field) works by
                                // creating a sap.ui.fl change targeting the FilterBar - flex
                                // refuses to build a selector for a control with a framework-
                                // generated ID (BaseTreeModifier#checkControlId, confirmed against
                                // both the 1.96.34 local cache and the live 1.142.10 source: throws
                                // "Generated ID attribute found..." otherwise), so pressing OK would
                                // silently fail to remove anything without this. createId() gives it
                                // the same view-prefixed, stable ID shape a plain XML-declared
                                // control would have. Reused as-is across Main Entity switches -
                                // oHolder.destroyItems() above always frees it before recreation.
                                oFilterBar = new FilterBar(this.createId("filterBar"), {
                                    width: "100%",
                                    liveMode: false,
                                    showGoButton: false,
                                    // Enables the framework's own "Adapt Filters" button/dialog
                                    // (sap.ui.mdc.p13n.subcontroller.AdaptFiltersController) - the
                                    // same List/Group-tab, eye+X icon, "Add Filter" dropdown UI the
                                    // standard SAP list report uses, entirely framework-managed. It
                                    // takes every field currently in filterItems (all of them, per
                                    // the addFilterItem loop below) as the starting "visible" set,
                                    // so this needs no separate default-hidden-fields list to work.
                                    p13nMode: [FilterBarP13nMode.Item],
                                    delegate: {
                                        name: "zmb51nov4/delegate/FilterBarDelegate",
                                        payload: {
                                            propertyInfo: aPropertyInfo,
                                            f4InfoByKey: oPropertyInfoResult.f4InfoByKey
                                        }
                                    },
                                    search: this.onGo.bind(this)
                                });
                            this._oFilterBar = oFilterBar;
                            oHolder.addItem(oFilterBar);
                            this._wireVariantManagement(oFilterBar);

                            // Fields without a value help resolve addItem() near-synchronously;
                            // fields with one go through Fragment.load() first, which takes
                            // noticeably longer. Adding each field to the FilterBar as soon as
                            // ITS OWN promise settles (inside a per-item .then()) would let the
                            // faster fields race ahead and land first regardless of their
                            // @UI.selectionField position - so all fields are created first,
                            // then added in a single pass over the original (ordered) array.
                            return Promise.all(
                                aPropertyInfo.map(function (oProperty) {
                                    return FilterBarDelegate.addItem(oFilterBar, oProperty.key);
                                })
                            ).then(function (aFilterFields) {
                                aFilterFields.forEach(function (oFilterField) {
                                    if (oFilterField) {
                                        oFilterBar.addFilterItem(oFilterField);
                                    }
                                });
                            });
                        }.bind(this)
                    )
                    .then(
                        function () {
                            // Rows are NOT (re)bound here - only columns/filter fields change
                            // when Main Entity switches or on initial load; data only loads on
                            // an explicit Go (see onGo), which does the actual bind. unbindRows()
                            // clears out whatever the table showed for the PREVIOUS Main Entity
                            // (a no-op on the very first call, since nothing is bound yet) so
                            // switching never leaves stale, no-longer-matching rows on screen -
                            // the table goes back to empty until Go loads the new selection.
                            oTable.unbindRows();
                            this._updateRecordCount();
                        }.bind(this)
                    )
                    .finally(
                        function () {
                            this._bBuildingFilterBar = false;
                        }.bind(this)
                    );
            },

            // Built once and reused. The FilterBar underneath is destroyed and rebuilt on every
            // Main Entity switch (see _applyMainEntityFields), so the per-bar "filtersChanged"
            // listener - the only thing that drives the "modified" (*) indicator - is re-attached
            // here on every rebuild. There is no "for" association: sap.m.VariantManagement is a
            // plain UI control that knows nothing about the FilterBar, we feed it entirely
            // through addItem/setSelectedKey and drive persistence ourselves (see the
            // VARIANT_STORAGE_ID comment and _readVariantData / _applyVariantState).
            _wireVariantManagement: function (oFilterBar) {
                if (!this._oVariantManagement) {
                    var mData = this._readVariantData();

                    this._oVariantManagement = new VariantManagement(this.createId("variantManagement"), {
                        // "H2" matches the page-title-sized variant name in the reference
                        // screenshot (the control default is the smaller "Auto").
                        titleStyle: "H2",
                        supportFavorites: false,
                        supportPublic: false,
                        supportApplyAutomatically: true,
                        save: this.onVariantSave.bind(this),
                        select: this.onVariantSelect.bind(this),
                        manage: this.onVariantManage.bind(this)
                    });

                    // The built-in empty view - not removable, not renamable.
                    this._oVariantManagement.addItem(
                        new VariantItem({
                            key: STANDARD_VARIANT_KEY,
                            title: this._getResourceText("variant.standard") || "Standard",
                            remove: false,
                            rename: false
                        })
                    );
                    Object.keys(mData.variants).forEach(function (sKey) {
                        this._oVariantManagement.addItem(
                            new VariantItem({
                                key: sKey,
                                title: mData.variants[sKey].title,
                                remove: true,
                                rename: true,
                                executeOnSelect: !!mData.variants[sKey].executeOnSelect
                            })
                        );
                    }, this);

                    this._oVariantManagement.setDefaultKey(mData.defaultKey || STANDARD_VARIANT_KEY);
                    this._oVariantManagement.setSelectedKey(mData.defaultKey || STANDARD_VARIANT_KEY);

                    this.byId("variantManagementHolder").addItem(this._oVariantManagement);
                }

                oFilterBar.attachFiltersChanged(this._onFilterBarFiltersChanged, this);
            },

            // ---- Variant persistence (sap.ui.util.Storage, local) --------------------------
            // Shape: { defaultKey: <string>, variants: { <key>: { title, mainEntity,
            // conditions, executeOnSelect } } }. Storage#get/#put do the JSON (de)serialization
            // and swallow a disabled/full Web Storage internally, so a read just comes back
            // null (-> the empty shape) and a write is a silent no-op - the feature degrades to
            // "views not remembered", never a thrown error mid-save.
            _getVariantStore: function () {
                if (!this._oVariantStore) {
                    this._oVariantStore = new Storage(Storage.Type.local, VARIANT_STORAGE_ID);
                }
                return this._oVariantStore;
            },

            _readVariantData: function () {
                var mData = this._getVariantStore().get(VARIANT_STORAGE_KEY) || {};
                return { defaultKey: mData.defaultKey || "", variants: mData.variants || {} };
            },

            _writeVariantData: function (mData) {
                this._getVariantStore().put(VARIANT_STORAGE_KEY, mData);
            },

            _getResourceText: function (sKey) {
                var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();
                return oBundle && typeof oBundle.getText === "function" ? oBundle.getText(sKey) : "";
            },

            // The source the rest of this controller already trusts for live filter values (see
            // the note on _getCurrentFilters): each FilterField's own getConditions(), not
            // FilterBar.getConditions() which stays empty in this setup. Returns
            // { <propertyKey>: [<condition>, ...] }, plain and JSON-safe.
            _readFilterBarConditions: function () {
                var mConditions = {};
                if (this._oFilterBar) {
                    this._oFilterBar.getFilterItems().forEach(function (oItem) {
                        var aItemConditions = oItem.getConditions();
                        if (aItemConditions && aItemConditions.length) {
                            mConditions[oItem.getPropertyKey()] = aItemConditions;
                        }
                    });
                }
                /* eslint-disable-next-line no-console */
                console.log("[variant] read conditions", JSON.stringify(mConditions));
                return mConditions;
            },

            // Which filter fields are currently in the bar (Adapt Filters removes fields from the
            // filterItems aggregation, see the p13nMode note on _applyMainEntityFields), so a
            // view can restore the same reduced set - not just the values.
            _readVisibleFilterFieldKeys: function () {
                return this._oFilterBar
                    ? this._oFilterBar.getFilterItems().map(function (oItem) {
                          return oItem.getPropertyKey();
                      })
                    : [];
            },

            // Pushes stored conditions back onto the matching FilterFields and clears every
            // other field, so the bar ends up showing exactly what the view captured. Waits for
            // the freshly (re)built bar to finish initializing first - setting conditions on a
            // FilterField whose data type module is still loading gets silently dropped. A plain
            // JSON round-trip (via Storage) is enough for the values: the filter fields are
            // string codes plus a few dates, and mdc keeps date condition values as ISO strings
            // internally, which survive stringify/parse unchanged. The clone guards our stored
            // copy against mdc mutating the array in place.
            _writeFilterBarConditions: function (mConditions) {
                var oFilterBar = this._oFilterBar;
                if (!oFilterBar) {
                    return Promise.resolve();
                }
                var mSafe = mConditions || {},
                    pReady = typeof oFilterBar.initialized === "function" ? oFilterBar.initialized() : Promise.resolve();

                return pReady.then(function () {
                    oFilterBar.getFilterItems().forEach(function (oItem) {
                        var aStored = mSafe[oItem.getPropertyKey()];
                        oItem.setConditions(aStored ? JSON.parse(JSON.stringify(aStored)) : []);
                    });
                    /* eslint-disable-next-line no-console */
                    console.log(
                        "[variant] wrote conditions ->",
                        JSON.stringify(
                            oFilterBar.getFilterItems().map(function (oItem) {
                                return { key: oItem.getPropertyKey(), conditions: oItem.getConditions() };
                            })
                        )
                    );
                });
            },

            // Reduces the (freshly rebuilt, all-fields) bar to just the fields the view had
            // visible. A missing/!Array list means "leave every field shown" - covers Standard
            // and any view saved before visibleFields was recorded.
            _applyVisibleFilterFields: function (aVisibleKeys) {
                if (!this._oFilterBar || !Array.isArray(aVisibleKeys)) {
                    return;
                }
                this._oFilterBar.getFilterItems()
                    .slice()
                    .forEach(function (oItem) {
                        if (aVisibleKeys.indexOf(oItem.getPropertyKey()) === -1) {
                            this._oFilterBar.removeFilterItem(oItem);
                        }
                    }, this);
            },

            // The Material Documents table's column set/order/visibility - the state the gear
            // ("Settings") dialog edits, see onSettings / _applyColumnOrder. Captured as
            // [{ name, visible }, ...] in on-screen order, aligned with _aCurrentColumnsMeta.
            _readTableColumnState: function () {
                var oTable = this.byId("materialDocumentsTable");
                if (!oTable || !this._aCurrentColumnsMeta) {
                    return null;
                }
                return oTable.getColumns().map(function (oColumn, i) {
                    return { name: this._aCurrentColumnsMeta[i].name, visible: oColumn.getVisible() };
                }, this);
            },

            // Re-applies a saved column state onto the freshly rebuilt (full, default-order)
            // table. Tolerates drift: saved entries whose column no longer exists are dropped,
            // and any current column the saved list didn't mention is appended visible so a
            // newly added column is never silently hidden. Reuses _applyColumnOrder for the
            // actual reordering (same path the Settings dialog uses).
            _applyTableColumnState: function (aColumnState) {
                if (!Array.isArray(aColumnState) || !aColumnState.length || !this._aCurrentColumnsMeta) {
                    return;
                }
                var mCurrent = {},
                    mMentioned = {},
                    aP13nData;

                this._aCurrentColumnsMeta.forEach(function (oMeta) {
                    mCurrent[oMeta.name] = true;
                });
                aP13nData = aColumnState.filter(function (oItem) {
                    return mCurrent[oItem.name];
                });
                aP13nData.forEach(function (oItem) {
                    mMentioned[oItem.name] = true;
                });
                this._aCurrentColumnsMeta.forEach(function (oMeta) {
                    if (!mMentioned[oMeta.name]) {
                        aP13nData.push({ name: oMeta.name, visible: true });
                    }
                });

                this._applyColumnOrder(aP13nData);
                /* eslint-disable-next-line no-console */
                console.log("[variant] applied table columns", JSON.stringify(aP13nData));
            },

            _onFilterBarFiltersChanged: function () {
                // Ignore the filtersChanged storms our own rebuild / apply cause - only a real
                // user edit should light up the "modified" marker. setConditions() fires a
                // trailing, debounced filtersChanged that lands a few hundred ms AFTER the apply
                // chain (and its _bApplyingVariant flag) has finished, so a short grace window
                // past the last apply covers it too.
                if (
                    this._bApplyingVariant ||
                    this._bBuildingFilterBar ||
                    !this._oVariantManagement ||
                    (this._iVariantAppliedAt && Date.now() - this._iVariantAppliedAt < 1500)
                ) {
                    return;
                }
                this._oVariantManagement.setModified(true);
            },

            // "save" fires for both Save (overwrite) and Save As (new). The event only carries
            // "key" when overwrite is true; for Save As we mint our own. Standard can never be
            // overwritten - a Save on it is always a new view.
            onVariantSave: function (oEvent) {
                var bOverwrite = oEvent.getParameter("overwrite"),
                    sName = oEvent.getParameter("name"),
                    bExecute = !!oEvent.getParameter("execute"),
                    bDefault = !!oEvent.getParameter("def"),
                    oVM = this._oVariantManagement,
                    mData = this._readVariantData(),
                    sKey = bOverwrite ? oEvent.getParameter("key") || oVM.getSelectedKey() : "z" + Date.now() + Math.floor(Math.random() * 1000);

                if (sKey === STANDARD_VARIANT_KEY) {
                    sKey = "z" + Date.now() + Math.floor(Math.random() * 1000);
                    bOverwrite = false;
                }

                mData.variants[sKey] = {
                    title: sName || (mData.variants[sKey] && mData.variants[sKey].title) || sKey,
                    mainEntity: this.byId("mainEntitySelect").getSelectedKey(),
                    conditions: this._readFilterBarConditions(),
                    visibleFields: this._readVisibleFilterFieldKeys(),
                    tableColumns: this._readTableColumnState(),
                    executeOnSelect: bExecute
                };
                /* eslint-disable-next-line no-console */
                console.log("[variant] saved", sKey, JSON.stringify(mData.variants[sKey]));

                if (bDefault) {
                    mData.defaultKey = sKey;
                } else if (mData.defaultKey === sKey) {
                    mData.defaultKey = "";
                }
                this._writeVariantData(mData);

                if (bOverwrite) {
                    var oExisting = oVM.getItemByKey(sKey);
                    if (oExisting) {
                        oExisting.setTitle(mData.variants[sKey].title);
                        oExisting.setExecuteOnSelect(bExecute);
                    }
                } else {
                    oVM.addItem(
                        new VariantItem({
                            key: sKey,
                            title: mData.variants[sKey].title,
                            remove: true,
                            rename: true,
                            executeOnSelect: bExecute
                        })
                    );
                }

                oVM.setSelectedKey(sKey);
                oVM.setDefaultKey(mData.defaultKey || STANDARD_VARIANT_KEY);
                oVM.setModified(false);
            },

            onVariantSelect: function (oEvent) {
                if (this._bApplyingVariant) {
                    return;
                }
                this._applyVariantState(oEvent.getParameter("key"));
            },

            // Standard (or an unknown key) just clears the bar's conditions, keeping the current
            // Main Entity. Otherwise: switch Nhom + rebuild the bar for that entity's field set
            // (so e.g. SLAB's extra fields exist again), then push the stored conditions back
            // onto the fields. The whole run is flagged so the filtersChanged the rebuild and
            // the setConditions calls fire aren't mistaken for a user edit.
            _applyVariantState: function (sKey) {
                var oTable = this.byId("materialDocumentsTable"),
                    oVM = this._oVariantManagement,
                    mData = this._readVariantData(),
                    oRecord = sKey && sKey !== STANDARD_VARIANT_KEY ? mData.variants[sKey] : null,
                    bExecute = !!(oRecord && oRecord.executeOnSelect),
                    // No record (Standard / unknown key) -> stay on the current Main Entity and
                    // just reset to a clean, full, empty bar.
                    sEntity = (oRecord && oRecord.mainEntity) || this.byId("mainEntitySelect").getSelectedKey();

                /* eslint-disable-next-line no-console */
                console.log("[variant] apply", sKey, "entity", sEntity, "record", JSON.stringify(oRecord));

                this._bApplyingVariant = true;
                oTable.setBusy(true);
                // Own the selection here (harmless no-op when onVariantSelect already set it),
                // so callers like _applyDefaultVariant don't risk a second apply by nudging it.
                oVM.setSelectedKey(sKey);
                this.byId("mainEntitySelect").setSelectedKey(sEntity);

                // Always rebuild from the full field set, then narrow + fill - otherwise a
                // previously applied view's removed fields / stale values would linger.
                this._applyMainEntityFields(sEntity)
                    .then(
                        function () {
                            this._applyVisibleFilterFields(oRecord ? oRecord.visibleFields : null);
                            this._applyTableColumnState(oRecord ? oRecord.tableColumns : null);
                            return this._writeFilterBarConditions(oRecord ? oRecord.conditions : {});
                        }.bind(this)
                    )
                    .then(
                        function () {
                            oVM.setModified(false);
                            // Grace window read by _onFilterBarFiltersChanged so the trailing
                            // debounced filtersChanged from setConditions doesn't re-mark it.
                            this._iVariantAppliedAt = Date.now();
                            if (bExecute) {
                                this.onGo();
                            }
                        }.bind(this)
                    )
                    .catch(
                        function (oError) {
                            /* eslint-disable-next-line no-console */
                            console.error("Failed to apply view " + sKey, oError);
                            this._showResourceText("variant.applyError", MessageToast.show);
                        }.bind(this)
                    )
                    .finally(
                        function () {
                            this._bApplyingVariant = false;
                            // onGo runs its own busy/dataReceived cycle - don't clear it here or
                            // the spinner disappears while the request is still in flight.
                            if (!bExecute) {
                                oTable.setBusy(false);
                            }
                        }.bind(this)
                    );
            },

            onVariantManage: function (oEvent) {
                var oVM = this._oVariantManagement,
                    mData = this._readVariantData(),
                    aRenamed = oEvent.getParameter("renamed") || [],
                    aDeleted = oEvent.getParameter("deleted") || [],
                    aExe = oEvent.getParameter("exe") || [],
                    sDef = oEvent.getParameter("def");

                aRenamed.forEach(function (oRen) {
                    if (mData.variants[oRen.key]) {
                        mData.variants[oRen.key].title = oRen.name;
                    }
                    var oItem = oVM.getItemByKey(oRen.key);
                    if (oItem) {
                        oItem.setTitle(oRen.name);
                    }
                });

                aExe.forEach(function (oExe) {
                    if (mData.variants[oExe.key]) {
                        mData.variants[oExe.key].executeOnSelect = !!oExe.exe;
                    }
                });

                aDeleted.forEach(function (sDeletedKey) {
                    delete mData.variants[sDeletedKey];
                    if (mData.defaultKey === sDeletedKey) {
                        mData.defaultKey = "";
                    }
                    var oItem = oVM.getItemByKey(sDeletedKey);
                    if (oItem) {
                        oVM.removeItem(oItem);
                        oItem.destroy();
                    }
                });

                if (sDef !== undefined && sDef !== null) {
                    mData.defaultKey = sDef === STANDARD_VARIANT_KEY ? "" : sDef;
                }

                this._writeVariantData(mData);
                oVM.setDefaultKey(mData.defaultKey || STANDARD_VARIANT_KEY);

                // The selected view may have just been deleted - fall back to Standard.
                if (aDeleted.indexOf(oVM.getSelectedKey()) !== -1) {
                    this._applyVariantState(STANDARD_VARIANT_KEY);
                }
            },

            // Reflects @UI.headerInfo/TypeNamePlural + the live row count ("Material Documents
            // (212)") next to the table, re-run whenever the rows binding changes (filter, sort,
            // Main Entity switch) since it's attached to that binding's "change" event.
            _updateRecordCount: function () {
                var oTable = this.byId("materialDocumentsTable"),
                    oBinding = oTable.getBinding("rows"),
                    oTitle = this.byId("recordCountTitle"),
                    iCount = oBinding && oBinding.getCount();

                if (oTitle) {
                    oTitle.setText(this._sTypeNamePlural + (typeof iCount === "number" ? " (" + iCount + ")" : ""));
                }
            },

            // FilterBar#getConditions() (getCurrentState().filter under the hood) comes back
            // empty in this setup even when a field visibly holds selected values - the p13n
            // Engine/StateUtil state it reads from apparently isn't kept in sync here. Each
            // FilterField's OWN "conditions" property is reliably up to date though (confirmed
            // via console logging), so conditions are read directly off the filterItems instead.
            // Shared with _requestTotals so the Totals popover always reflects the same filters
            // as whatever is currently on screen (or about to be, if Go hasn't been pressed yet).
            _getCurrentFilters: function () {
                var aFilters = [],
                    sMainEntity = this.byId("mainEntitySelect").getSelectedKey(),
                    oConditions = {};

                if (this._oFilterBar) {
                    this._oFilterBar.getFilterItems().forEach(function (oItem) {
                        var aItemConditions = oItem.getConditions();
                        if (aItemConditions && aItemConditions.length) {
                            oConditions[oItem.getPropertyKey()] = aItemConditions;
                        }
                    });
                }

                if (sMainEntity) {
                    aFilters.push(new Filter("Nhom", FilterOperator.EQ, sMainEntity));
                }

                return aFilters.concat(mdcConditionConverter.convertConditionsToFilters(oConditions));
            },

            onGo: function () {
                var oTable = this.byId("materialDocumentsTable"),
                    aFilters = this._getCurrentFilters(),
                    oBinding = oTable.getBinding("rows");
                oTable.setBusy(true);

                if (!oBinding) {
                    // First Go ever - the table has no rows binding at all until now (see
                    // _applyMainEntityFields), by design: data only loads on an explicit Go,
                    // including right after the initial page load or a Main Entity switch.
                    // $$getKeepAliveContext lets Detail.controller.js look this binding up by
                    // path and reuse a row's already-fetched context instead of doing a fresh
                    // GET-by-key - see onRowPress: the backend's key for this entity isn't
                    // actually unique, so a fresh single-entity read 500s ("Multiple instances
                    // returned...using given key") for any row the list hasn't already loaded.
                    oTable.bindRows({
                        path: ENTITY_PATH,
                        filters: aFilters,
                        parameters: { $count: true, $$getKeepAliveContext: true }
                    });
                    oBinding = oTable.getBinding("rows");
                    oBinding.attachChange(this._updateRecordCount, this);
                } else {
                    oBinding.filter(aFilters);
                }

                // Force a fresh round-trip to the backend even when the filter conditions are
                // identical to the ones already applied (filter() alone skips the request in that case).
                oBinding.refresh();
                oBinding.attachEventOnce("dataReceived", function () {
                    oTable.setBusy(false);
                });
            },

            // sap.ui.table.Column's own header menu (enabled via sortProperty in _buildColumns)
            // only offers Sort Ascending/Sort Descending, no "back to original order" entry -
            // this covers that: clears the binding's sorters and each column's sort indicator.
            onResetSort: function () {
                var oTable = this.byId("materialDocumentsTable"),
                    oBinding = oTable.getBinding("rows");

                oTable.getColumns().forEach(function (oColumn) {
                    oColumn.setSorted(false);
                });

                if (oBinding) {
                    oBinding.sort([]);
                }
            },

            // Opens the "View Settings"-style column show/hide/reorder dialog (sap.m.p13n.Popup +
            // SelectionPanel give the standard Fiori Columns tab - search, count, drag-to-reorder -
            // for free). The panel is built once and re-seeded from the table's current column
            // order/visibility on every open, so it always reflects whatever the user set last
            // (including after a Main Entity switch rebuilds the columns from scratch).
            onSettings: function () {
                var oTable = this.byId("materialDocumentsTable");

                if (!this._oSettingsPopup) {
                    this._oSelectionPanel = new SelectionPanel({
                        showHeader: true,
                        enableCount: true,
                        fieldColumn: "{i18n>table.settings.columns}",
                        // SelectionPanel's own default is MultiSelectMode.ClearAll, which only
                        // renders a Deselect-All icon - "Default" is what actually gives a
                        // tri-state Select-All checkbox in the header.
                        multiSelectMode: "Default"
                    });
                    this._oSettingsPopup = new P13nPopup({
                        title: "{i18n>table.settings.title}",
                        warningText: "{i18n>table.settings.resetWarning}",
                        reset: this._onSettingsReset.bind(this),
                        close: this._onSettingsClose.bind(this)
                    });
                    this._oSettingsPopup.addPanel(this._oSelectionPanel);
                    this.getView().addDependent(this._oSettingsPopup);
                }

                this._oSelectionPanel.setP13nData(
                    oTable.getColumns().map(function (oColumn, i) {
                        return {
                            name: this._aCurrentColumnsMeta[i].name,
                            label: this._aCurrentColumnsMeta[i].label,
                            visible: oColumn.getVisible()
                        };
                    }, this)
                );
                this._oSettingsPopup.open(this.byId("settingsButton"));
            },

            _onSettingsClose: function (oEvent) {
                if (oEvent.getParameter("reason") !== "Ok") {
                    return;
                }
                this._applyColumnOrder(this._oSelectionPanel.getP13nData());
            },

            // Reset applies the default order/visibility straight away (the confirmation
            // MessageBox sap.m.p13n.Popup already shows first is guard enough) and re-seeds the
            // panel so the still-open dialog reflects it too, rather than requiring a second OK.
            _onSettingsReset: function () {
                var aDefaultP13nData = this._aDefaultColumnsMeta.map(function (oField) {
                    return { name: oField.name, label: oField.label, visible: true };
                });
                this._applyColumnOrder(aDefaultP13nData);
                this._oSelectionPanel.setP13nData(aDefaultP13nData);
            },

            // Applies the new order/visibility onto the table's EXISTING Column instances (removed
            // and re-added, never destroyed) so the QuantityInEntryUnit column keeps its special
            // HTML cell template instead of being rebuilt from scratch - see _createQuantityCellTemplate.
            _applyColumnOrder: function (aP13nData) {
                var oTable = this.byId("materialDocumentsTable"),
                    mColumnByName = {},
                    mMetaByName = {};

                oTable.getColumns().forEach(function (oColumn, i) {
                    var sName = this._aCurrentColumnsMeta[i].name;
                    mColumnByName[sName] = oColumn;
                    mMetaByName[sName] = this._aCurrentColumnsMeta[i];
                    oTable.removeColumn(oColumn);
                }, this);

                this._aCurrentColumnsMeta = aP13nData.map(function (oItem) {
                    var oColumn = mColumnByName[oItem.name];
                    oColumn.setVisible(oItem.visible);
                    oTable.addColumn(oColumn);
                    return mMetaByName[oItem.name];
                });
            },

            // Passing the ListBinding directly as dataSource makes Spreadsheet judge "how many
            // rows" by isLengthFinal() (whether the client has scrolled through everything) -
            // with sap.ui.table's default lazy/viewport-driven fetching that's false even though
            // the server-side $count (already shown in the title as "(97)") is known, so it warns
            // "unknown number of rows". Passing dataUrl+count explicitly instead (the documented
            // OData export shape) gives it the real resolved count up front - no more guessing,
            // no warning - while still respecting the binding's current $filter/$search/sort via
            // getDownloadUrl(). Fetching all matching rows for real still shows the standard
            // "Fetching data from server... X / Y" progress dialog.
            onExport: function () {
                var oTable = this.byId("materialDocumentsTable"),
                    oBinding = oTable.getBinding("rows"),
                    // Only currently visible columns (see onSettings) - exporting a column the
                    // user just hid on screen would be surprising.
                    aColumns = (this._aCurrentColumnsMeta || [])
                        .filter(function (oField, i) {
                            return oTable.getColumns()[i].getVisible();
                        })
                        .map(function (oField) {
                            return { label: oField.label, property: oField.name };
                        });

                var oSheet = new Spreadsheet({
                    workbook: { columns: aColumns },
                    dataSource: {
                        type: "odata",
                        dataUrl: oBinding.getDownloadUrl(),
                        count: oBinding.getCount()
                    },
                    fileName: (this._sTypeNamePlural || "Export") + ".xlsx"
                });

                oSheet.build().finally(function () {
                    oSheet.destroy();
                });
            },

            // Fired by the RowActionItem's own "press" event (see List.view.xml's
            // rowActionTemplate), not a row/cell click - its "row" parameter is the
            // sap.ui.table.Row instance the action button sits in.
            //
            // setKeepAlive marks this row's already-fetched context so Detail.controller.js can
            // reuse it (via the model's getKeepAliveContext, matched through the
            // $$getKeepAliveContext binding above) instead of issuing its own GET-by-key - see
            // the bindRows comment for why that fresh read doesn't work against this backend.
            onRowPress: function (oEvent) {
                var oRow = oEvent.getParameter("row"),
                    oRowContext = oRow && oRow.getBindingContext();
                if (!oRowContext) {
                    return;
                }
                oRowContext.setKeepAlive(true);
                var sKey = encodeURIComponent(oRowContext.getPath().substring(1));
                this.getOwnerComponent().getRouter().navTo("detail", { key: sKey });
            }
        });
    }
);
