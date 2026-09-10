sap.ui.define([], function () {
    "use strict";

    // A collection annotation entry can show up as a plain path string, a
    // {$PropertyPath: "..."} constant, or a DataField record ({Value: {$Path: "..."}}),
    // depending on the annotation term and how the backend metadata extension was written.
    function extractFieldName(vEntry) {
        if (typeof vEntry === "string") {
            return vEntry;
        }
        if (vEntry && typeof vEntry.$PropertyPath === "string") {
            return vEntry.$PropertyPath;
        }
        if (vEntry && vEntry.Value && typeof vEntry.Value.$Path === "string") {
            return vEntry.Value.$Path;
        }
        return undefined;
    }

    function isKeyParameter(oParameter) {
        return /ValueListParameter(InOut|Out)$/.test((oParameter && oParameter.$Type) || "");
    }

    function isDisplayParameter(oParameter) {
        return /ValueListParameterDisplayOnly$/.test((oParameter && oParameter.$Type) || "");
    }

    /**
     * Resolves Common.Label + $Type + value help presence for a single property.
     */
    function requestFieldDetail(oMetaModel, sEntityPath, sName) {
        return Promise.all([
            oMetaModel.requestObject(sEntityPath + "/" + sName + "@com.sap.vocabularies.Common.v1.Label"),
            oMetaModel.requestObject(sEntityPath + "/" + sName),
            oMetaModel.requestObject(sEntityPath + "/" + sName + "@com.sap.vocabularies.Common.v1.ValueListReferences"),
            oMetaModel.requestObject(sEntityPath + "/" + sName + "@com.sap.vocabularies.Common.v1.ValueList"),
            oMetaModel.requestObject(sEntityPath + "/" + sName + "@com.sap.vocabularies.Common.v1.IsDigitSequence")
        ]).then(function (aResult) {
            var oProperty = aResult[1] || {};
            return {
                name: sName,
                label: aResult[0] || sName,
                type: oProperty.$Type || "Edm.String",
                maxLength: oProperty.$MaxLength,
                precision: oProperty.$Precision,
                scale: oProperty.$Scale,
                hasValueHelp: !!((aResult[2] && aResult[2].length) || aResult[3]),
                isDigitSequence: !!aResult[4]
            };
        });
    }

    /**
     * Resolves a Common.Label + $Type (+ value help presence) annotated field list from the
     * OData V4 $metadata at runtime, driven by a UI.LineItem / UI.SelectionFields style annotation.
     */
    function requestFieldList(oMetaModel, sEntityPath, sAnnotationTerm) {
        return oMetaModel.requestObject(sEntityPath + "/@" + sAnnotationTerm).then(function (aCollection) {
            var aFieldNames = (aCollection || []).map(extractFieldName).filter(function (sName) {
                return !!sName;
            });

            return Promise.all(
                aFieldNames.map(function (sName) {
                    return requestFieldDetail(oMetaModel, sEntityPath, sName);
                })
            );
        });
    }

    // Property reference inside a FilterExpressionRestrictions record can be a bare path string
    // or a {$PropertyPath: "..."} constant, same ambiguity as other collection entries.
    function extractPropertyPath(vProperty) {
        if (typeof vProperty === "string") {
            return vProperty;
        }
        return vProperty && vProperty.$PropertyPath;
    }

    /**
     * Resolves the set of property names restricted to a range/interval filter expression
     * (Org.OData.Capabilities.V1.FilterRestrictions.FilterExpressionRestrictions with an
     * AllowedExpressions ending in "Range" - what @Consumption.filter.selectionType: #INTERVAL
     * compiles to). Returns an empty array when the entity set declares no such restriction.
     */
    function requestIntervalFieldNames(oMetaModel, sEntitySetPath) {
        return oMetaModel
            .requestObject(sEntitySetPath + "@Org.OData.Capabilities.V1.FilterRestrictions")
            .then(function (oRestrictions) {
                var aExpressions = (oRestrictions && oRestrictions.FilterExpressionRestrictions) || [];
                return aExpressions
                    .filter(function (oRestriction) {
                        return /Range$/.test((oRestriction && oRestriction.AllowedExpressions) || "");
                    })
                    .map(function (oRestriction) {
                        return extractPropertyPath(oRestriction.Property);
                    })
                    .filter(Boolean);
            })
            .catch(function () {
                return [];
            });
    }

    /**
     * Resolves the value help (F4) collection for a property, following Common.ValueListReferences /
     * Common.ValueList via the built-in ODataMetaModel#requestValueListInfo. Returns null when the
     * property has no value help (instead of rejecting).
     *
     * A ValueList can carry more than one InOut/Out parameter (a compound VH key, e.g.
     * I_StorageLocationStdVH has both Plant and StorageLocation) plus more than one DisplayOnly
     * parameter - picking just "the first of each" (as an earlier version did) silently drops
     * every column beyond the first. keyProperty is resolved as whichever parameter's
     * LocalDataProperty matches the field actually being helped (sPropertyPath's last segment) -
     * that is the one the framework writes the picked value back into - falling back to the
     * first key parameter if none names this field explicitly. Every other parameter (extra key
     * columns, extra display columns) is returned as extraColumns so the F4 table can show
     * whatever the metadata actually declares instead of a hardcoded 2-column shape.
     */
    function requestValueHelpInfo(oMetaModel, sPropertyPath) {
        var sFieldName = sPropertyPath.split("/").pop();

        return oMetaModel
            .requestValueListInfo(sPropertyPath, true)
            .then(function (mValueListInfo) {
                var aQualifiers = Object.keys(mValueListInfo || {});
                if (!aQualifiers.length) {
                    return null;
                }
                var oInfo = mValueListInfo[""] || mValueListInfo[aQualifiers[0]],
                    aParameters = oInfo.Parameters || [],
                    aKeyParameters = aParameters.filter(isKeyParameter),
                    oKeyParameter =
                        aKeyParameters.filter(function (oParam) {
                            return oParam.LocalDataProperty === sFieldName;
                        })[0] || aKeyParameters[0],
                    oDisplayParameter = aParameters.filter(isDisplayParameter)[0];

                if (!oInfo.$model || !oInfo.CollectionPath || !oKeyParameter) {
                    return null;
                }

                var aExtraParameters = aParameters.filter(function (oParam) {
                        return oParam !== oKeyParameter && oParam !== oDisplayParameter;
                    }),
                    oValueListMetaModel = oInfo.$model.getMetaModel(),
                    sCollectionPath = "/" + oInfo.CollectionPath;

                return Promise.all(
                    aExtraParameters.map(function (oParam) {
                        return oValueListMetaModel.requestObject(
                            sCollectionPath + "/" + oParam.ValueListProperty + "@com.sap.vocabularies.Common.v1.Label"
                        );
                    })
                ).then(function (aLabels) {
                    return {
                        model: oInfo.$model,
                        collectionPath: oInfo.CollectionPath,
                        keyProperty: oKeyParameter.ValueListProperty,
                        descriptionProperty: oDisplayParameter && oDisplayParameter.ValueListProperty,
                        extraColumns: aExtraParameters.map(function (oParam, i) {
                            return { property: oParam.ValueListProperty, label: aLabels[i] || oParam.ValueListProperty };
                        }),
                        label: oInfo.Label
                    };
                });
            })
            .catch(function () {
                return null;
            });
    }

    return {
        requestFieldDetail: requestFieldDetail,
        requestFieldList: requestFieldList,
        requestIntervalFieldNames: requestIntervalFieldNames,
        requestValueHelpInfo: requestValueHelpInfo
    };
});
