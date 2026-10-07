sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"managecongdoan/test/integration/pages/CongDoansList.gen",
	"managecongdoan/test/integration/pages/CongDoansObjectPage.gen"
], function (JourneyRunner, CongDoansListGenerated, CongDoansObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('managecongdoan') + '/test/flp.html#app-preview',
        pages: {
			onTheCongDoansListGenerated: CongDoansListGenerated,
			onTheCongDoansObjectPageGenerated: CongDoansObjectPageGenerated
        },
        async: true
    });

    return runner;
});

