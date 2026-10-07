sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"workerxnsl/test/integration/pages/ZC_TB_KB_NHANCONG_QRList.gen",
	"workerxnsl/test/integration/pages/ZC_TB_KB_NHANCONG_QRObjectPage.gen"
], function (JourneyRunner, ZC_TB_KB_NHANCONG_QRListGenerated, ZC_TB_KB_NHANCONG_QRObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('workerxnsl') + '/test/flp.html#app-preview',
        pages: {
			onTheZC_TB_KB_NHANCONG_QRListGenerated: ZC_TB_KB_NHANCONG_QRListGenerated,
			onTheZC_TB_KB_NHANCONG_QRObjectPageGenerated: ZC_TB_KB_NHANCONG_QRObjectPageGenerated
        },
        async: true
    });

    return runner;
});

