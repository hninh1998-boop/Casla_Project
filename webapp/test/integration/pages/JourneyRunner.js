sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"mfgordoperwc/test/integration/pages/ZR_MFGORD_OPER_WCList.gen",
	"mfgordoperwc/test/integration/pages/ZR_MFGORD_OPER_WCObjectPage.gen"
], function (JourneyRunner, ZR_MFGORD_OPER_WCListGenerated, ZR_MFGORD_OPER_WCObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('mfgordoperwc') + '/test/flp.html#app-preview',
        pages: {
			onTheZR_MFGORD_OPER_WCListGenerated: ZR_MFGORD_OPER_WCListGenerated,
			onTheZR_MFGORD_OPER_WCObjectPageGenerated: ZR_MFGORD_OPER_WCObjectPageGenerated
        },
        async: true
    });

    return runner;
});

