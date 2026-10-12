sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zsalesdaov4/test/integration/pages/zce_sales_daList.gen",
	"zsalesdaov4/test/integration/pages/zce_sales_daObjectPage.gen"
], function (JourneyRunner, zce_sales_daListGenerated, zce_sales_daObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zsalesdaov4') + '/test/flp.html#app-preview',
        pages: {
			onThezce_sales_daListGenerated: zce_sales_daListGenerated,
			onThezce_sales_daObjectPageGenerated: zce_sales_daObjectPageGenerated
        },
        async: true
    });

    return runner;
});

