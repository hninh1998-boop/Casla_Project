sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zextendewmprod/test/integration/pages/ExtendEWMProductList",
	"zextendewmprod/test/integration/pages/ExtendEWMProductObjectPage"
], function (JourneyRunner, ExtendEWMProductList, ExtendEWMProductObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zextendewmprod') + '/test/flp.html#app-preview',
        pages: {
			onTheExtendEWMProductList: ExtendEWMProductList,
			onTheExtendEWMProductObjectPage: ExtendEWMProductObjectPage
        },
        async: true
    });

    return runner;
});

