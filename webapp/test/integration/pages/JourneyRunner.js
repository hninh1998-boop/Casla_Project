sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zdongiangcov4/test/integration/pages/dgthList.gen",
	"zdongiangcov4/test/integration/pages/dgthObjectPage.gen"
], function (JourneyRunner, dgthListGenerated, dgthObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zdongiangcov4') + '/test/flp.html#app-preview',
        pages: {
			onThedgthListGenerated: dgthListGenerated,
			onThedgthObjectPageGenerated: dgthObjectPageGenerated
        },
        async: true
    });

    return runner;
});

