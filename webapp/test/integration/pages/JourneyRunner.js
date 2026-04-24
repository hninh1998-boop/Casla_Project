sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zextrout/test/integration/pages/ExtendRoutList",
	"zextrout/test/integration/pages/ExtendRoutObjectPage"
], function (JourneyRunner, ExtendRoutList, ExtendRoutObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zextrout') + '/test/flp.html#app-preview',
        pages: {
			onTheExtendRoutList: ExtendRoutList,
			onTheExtendRoutObjectPage: ExtendRoutObjectPage
        },
        async: true
    });

    return runner;
});

