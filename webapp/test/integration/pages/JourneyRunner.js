sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"managefunc/test/integration/pages/FunctionsList.gen",
	"managefunc/test/integration/pages/FunctionsObjectPage.gen"
], function (JourneyRunner, FunctionsListGenerated, FunctionsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('managefunc') + '/test/flp.html#app-preview',
        pages: {
			onTheFunctionsListGenerated: FunctionsListGenerated,
			onTheFunctionsObjectPageGenerated: FunctionsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

