sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zupdnttrp/test/integration/pages/DnttListList.gen",
	"zupdnttrp/test/integration/pages/DnttListObjectPage.gen"
], function (JourneyRunner, DnttListListGenerated, DnttListObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zupdnttrp') + '/test/flp.html#app-preview',
        pages: {
			onTheDnttListListGenerated: DnttListListGenerated,
			onTheDnttListObjectPageGenerated: DnttListObjectPageGenerated
        },
        async: true
    });

    return runner;
});

