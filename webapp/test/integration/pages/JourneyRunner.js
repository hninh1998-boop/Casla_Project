sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zextendmaterial/test/integration/pages/ExtendProductList",
	"zextendmaterial/test/integration/pages/ExtendProductObjectPage"
], function (JourneyRunner, ExtendProductList, ExtendProductObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zextendmaterial') + '/test/flp.html#app-preview',
        pages: {
			onTheExtendProductList: ExtendProductList,
			onTheExtendProductObjectPage: ExtendProductObjectPage
        },
        async: true
    });

    return runner;
});

