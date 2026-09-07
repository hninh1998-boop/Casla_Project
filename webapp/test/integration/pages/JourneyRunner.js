sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zudbank/test/integration/pages/ZC_TBBANK_UPLList.gen",
	"zudbank/test/integration/pages/ZC_TBBANK_UPLObjectPage.gen"
], function (JourneyRunner, ZC_TBBANK_UPLListGenerated, ZC_TBBANK_UPLObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zudbank') + '/test/flp.html#app-preview',
        pages: {
			onTheZC_TBBANK_UPLListGenerated: ZC_TBBANK_UPLListGenerated,
			onTheZC_TBBANK_UPLObjectPageGenerated: ZC_TBBANK_UPLObjectPageGenerated
        },
        async: true
    });

    return runner;
});

