sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zmassprov4/test/integration/pages/ManageFilePR1List.gen",
	"zmassprov4/test/integration/pages/ManageFilePR1ObjectPage.gen",
	"zmassprov4/test/integration/pages/DataFilePR1ObjectPage.gen"
], function (JourneyRunner, ManageFilePR1ListGenerated, ManageFilePR1ObjectPageGenerated, DataFilePR1ObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zmassprov4') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFilePR1ListGenerated: ManageFilePR1ListGenerated,
			onTheManageFilePR1ObjectPageGenerated: ManageFilePR1ObjectPageGenerated,
			onTheDataFilePR1ObjectPageGenerated: DataFilePR1ObjectPageGenerated
        },
        async: true
    });

    return runner;
});

