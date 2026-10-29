sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zprsalesv3/test/integration/pages/zce_sales_v3List.gen",
	"zprsalesv3/test/integration/pages/zce_sales_v3ObjectPage.gen"
], function (JourneyRunner, zce_sales_v3ListGenerated, zce_sales_v3ObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zprsalesv3') + '/test/flp.html#app-preview',
        pages: {
			onThezce_sales_v3ListGenerated: zce_sales_v3ListGenerated,
			onThezce_sales_v3ObjectPageGenerated: zce_sales_v3ObjectPageGenerated
        },
        async: true
    });

    return runner;
});

