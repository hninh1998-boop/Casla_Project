sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zficc/test/integration/pages/CostCenterList",
	"zficc/test/integration/pages/CostCenterObjectPage"
], function (JourneyRunner, CostCenterList, CostCenterObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zficc') + '/test/flp.html#app-preview',
        pages: {
			onTheCostCenterList: CostCenterList,
			onTheCostCenterObjectPage: CostCenterObjectPage
        },
        async: true
    });

    return runner;
});

