sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zmcanmatdoc/test/integration/pages/ZC_M_CAN_MATDOCList.gen",
	"zmcanmatdoc/test/integration/pages/ZC_M_CAN_MATDOCObjectPage.gen"
], function (JourneyRunner, ZC_M_CAN_MATDOCListGenerated, ZC_M_CAN_MATDOCObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zmcanmatdoc') + '/test/flp.html#app-preview',
        pages: {
			onTheZC_M_CAN_MATDOCListGenerated: ZC_M_CAN_MATDOCListGenerated,
			onTheZC_M_CAN_MATDOCObjectPageGenerated: ZC_M_CAN_MATDOCObjectPageGenerated
        },
        async: true
    });

    return runner;
});

