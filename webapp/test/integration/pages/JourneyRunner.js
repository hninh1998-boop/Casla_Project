sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"tkngc/test/integration/pages/ZC_TBTON_NGCList.gen",
	"tkngc/test/integration/pages/ZC_TBTON_NGCObjectPage.gen"
], function (JourneyRunner, ZC_TBTON_NGCListGenerated, ZC_TBTON_NGCObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('tkngc') + '/test/flp.html#app-preview',
        pages: {
			onTheZC_TBTON_NGCListGenerated: ZC_TBTON_NGCListGenerated,
			onTheZC_TBTON_NGCObjectPageGenerated: ZC_TBTON_NGCObjectPageGenerated
        },
        async: true
    });

    return runner;
});

