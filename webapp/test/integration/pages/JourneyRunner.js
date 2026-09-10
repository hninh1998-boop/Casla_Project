sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zciov4/test/integration/pages/zce_ciList.gen",
	"zciov4/test/integration/pages/zce_ciObjectPage.gen"
], function (JourneyRunner, zce_ciListGenerated, zce_ciObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zciov4') + '/test/flp.html#app-preview',
        pages: {
			onThezce_ciListGenerated: zce_ciListGenerated,
			onThezce_ciObjectPageGenerated: zce_ciObjectPageGenerated
        },
        async: true
    });

    return runner;
});

