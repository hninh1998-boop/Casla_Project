sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zudtbpbank/test/integration/pages/UdtBpBankList",
	"zudtbpbank/test/integration/pages/UdtBpBankObjectPage"
], function (JourneyRunner, UdtBpBankList, UdtBpBankObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zudtbpbank') + '/test/flp.html#app-preview',
        pages: {
			onTheUdtBpBankList: UdtBpBankList,
			onTheUdtBpBankObjectPage: UdtBpBankObjectPage
        },
        async: true
    });

    return runner;
});

