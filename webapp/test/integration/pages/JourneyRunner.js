sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"baocaonxtnvlnhagiacong/test/integration/pages/ZCE_NGC_STOCK_CUSTOMList.gen",
	"baocaonxtnvlnhagiacong/test/integration/pages/ZCE_NGC_STOCK_CUSTOMObjectPage.gen"
], function (JourneyRunner, ZCE_NGC_STOCK_CUSTOMListGenerated, ZCE_NGC_STOCK_CUSTOMObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('baocaonxtnvlnhagiacong') + '/test/flp.html#app-preview',
        pages: {
			onTheZCE_NGC_STOCK_CUSTOMListGenerated: ZCE_NGC_STOCK_CUSTOMListGenerated,
			onTheZCE_NGC_STOCK_CUSTOMObjectPageGenerated: ZCE_NGC_STOCK_CUSTOMObjectPageGenerated
        },
        async: true
    });

    return runner;
});

