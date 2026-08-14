sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"ordcfm/test/integration/pages/ZI_ORD_CONF_ITEMList.gen",
	"ordcfm/test/integration/pages/ZI_ORD_CONF_ITEMObjectPage.gen"
], function (JourneyRunner, ZI_ORD_CONF_ITEMListGenerated, ZI_ORD_CONF_ITEMObjectPageGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('ordcfm') + '/test/flp.html#app-preview',
        pages: {
			onTheZI_ORD_CONF_ITEMListGenerated: ZI_ORD_CONF_ITEMListGenerated,
			onTheZI_ORD_CONF_ITEMObjectPageGenerated: ZI_ORD_CONF_ITEMObjectPageGenerated
        },
        async: true
    });

    return runner;
});

