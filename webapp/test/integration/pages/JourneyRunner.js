sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zbp/test/integration/pages/BpList",
	"zbp/test/integration/pages/BpObjectPage"
], function (JourneyRunner, BpList, BpObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zbp') + '/test/flp.html#app-preview',
        pages: {
			onTheBpList: BpList,
			onTheBpObjectPage: BpObjectPage
        },
        async: true
    });

    return runner;
});

