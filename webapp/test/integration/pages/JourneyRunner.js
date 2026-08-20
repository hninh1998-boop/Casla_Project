sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"empxnsl/test/integration/pages/ZC_EMPLOYEEList.gen",
	"empxnsl/test/integration/pages/ZC_EMPLOYEEObjectPage.gen"
], function (JourneyRunner, ZC_EMPLOYEEListGenerated, ZC_EMPLOYEEObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('empxnsl') + '/test/flp.html#app-preview',
        pages: {
			onTheZC_EMPLOYEEListGenerated: ZC_EMPLOYEEListGenerated,
			onTheZC_EMPLOYEEObjectPageGenerated: ZC_EMPLOYEEObjectPageGenerated
        },
        async: true
    });

    return runner;
});

