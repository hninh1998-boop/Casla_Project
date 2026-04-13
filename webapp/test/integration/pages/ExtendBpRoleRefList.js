sap.ui.define(['sap/fe/test/ListReport'], function(ListReport) {
    'use strict';

    var CustomPageDefinitions = {
        actions: {},
        assertions: {}
    };

    return new ListReport(
        {
            appId: 'zextendbproleref',
            componentId: 'ExtendBpRoleRefList',
            contextPath: '/ExtendBpRoleRef'
        },
        CustomPageDefinitions
    );
});