sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"mchso/test/integration/pages/ZC_M_MCH_SO_U_FILEList.gen",
	"mchso/test/integration/pages/ZC_M_MCH_SO_U_FILEObjectPage.gen",
	"mchso/test/integration/pages/ZC_D_MCH_SO_U_DATAObjectPage.gen"
], function (JourneyRunner, ZC_M_MCH_SO_U_FILEListGenerated, ZC_M_MCH_SO_U_FILEObjectPageGenerated, ZC_D_MCH_SO_U_DATAObjectPageGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('mchso') + '/test/flp.html#app-preview',
        pages: {
			onTheZC_M_MCH_SO_U_FILEListGenerated: ZC_M_MCH_SO_U_FILEListGenerated,
			onTheZC_M_MCH_SO_U_FILEObjectPageGenerated: ZC_M_MCH_SO_U_FILEObjectPageGenerated,
			onTheZC_D_MCH_SO_U_DATAObjectPageGenerated: ZC_D_MCH_SO_U_DATAObjectPageGenerated
        },
        async: true
    });

    return runner;
});

