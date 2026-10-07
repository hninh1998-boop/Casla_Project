sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"managetransaction/test/integration/pages/AllocationTransactionsList.gen",
	"managetransaction/test/integration/pages/AllocationTransactionsObjectPage.gen"
], function (JourneyRunner, AllocationTransactionsListGenerated, AllocationTransactionsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('managetransaction') + '/test/flp.html#app-preview',
        pages: {
			onTheAllocationTransactionsListGenerated: AllocationTransactionsListGenerated,
			onTheAllocationTransactionsObjectPageGenerated: AllocationTransactionsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

