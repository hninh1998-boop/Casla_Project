sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"manageworkcontext/test/integration/pages/WorkContextsList.gen",
	"manageworkcontext/test/integration/pages/WorkContextsObjectPage.gen"
], function (JourneyRunner, WorkContextsListGenerated, WorkContextsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('manageworkcontext') + '/test/flp.html#app-preview',
        pages: {
			onTheWorkContextsListGenerated: WorkContextsListGenerated,
			onTheWorkContextsObjectPageGenerated: WorkContextsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

