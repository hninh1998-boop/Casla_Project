sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zhhdvov4/test/integration/pages/HHDVHeadList.gen",
	"zhhdvov4/test/integration/pages/HHDVHeadObjectPage.gen",
	"zhhdvov4/test/integration/pages/HHDVItemObjectPage.gen"
], function (JourneyRunner, HHDVHeadListGenerated, HHDVHeadObjectPageGenerated, HHDVItemObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zhhdvov4') + '/test/flp.html#app-preview',
        pages: {
			onTheHHDVHeadListGenerated: HHDVHeadListGenerated,
			onTheHHDVHeadObjectPageGenerated: HHDVHeadObjectPageGenerated,
			onTheHHDVItemObjectPageGenerated: HHDVItemObjectPageGenerated
        },
        async: true
    });

    return runner;
});

