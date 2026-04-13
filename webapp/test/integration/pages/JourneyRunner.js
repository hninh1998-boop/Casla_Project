sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zextendbproleref/test/integration/pages/ExtendBpRoleRefList",
	"zextendbproleref/test/integration/pages/ExtendBpRoleRefObjectPage"
], function (JourneyRunner, ExtendBpRoleRefList, ExtendBpRoleRefObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zextendbproleref') + '/test/flp.html#app-preview',
        pages: {
			onTheExtendBpRoleRefList: ExtendBpRoleRefList,
			onTheExtendBpRoleRefObjectPage: ExtendBpRoleRefObjectPage
        },
        async: true
    });

    return runner;
});

