sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"manageallocation/test/integration/pages/OperationAllocationsList.gen",
	"manageallocation/test/integration/pages/OperationAllocationsObjectPage.gen"
], function (JourneyRunner, OperationAllocationsListGenerated, OperationAllocationsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('manageallocation') + '/test/flp.html#app-preview',
        pages: {
			onTheOperationAllocationsListGenerated: OperationAllocationsListGenerated,
			onTheOperationAllocationsObjectPageGenerated: OperationAllocationsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

