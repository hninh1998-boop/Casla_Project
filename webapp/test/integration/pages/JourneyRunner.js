sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zmasspoov42/test/integration/pages/ManageFilePOSubCompList.gen",
	"zmasspoov42/test/integration/pages/ManageFilePOSubCompObjectPage.gen",
	"zmasspoov42/test/integration/pages/DataFilePOSubCompObjectPage.gen"
], function (JourneyRunner, ManageFilePOSubCompListGenerated, ManageFilePOSubCompObjectPageGenerated, DataFilePOSubCompObjectPageGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zmasspoov42') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFilePOSubCompListGenerated: ManageFilePOSubCompListGenerated,
			onTheManageFilePOSubCompObjectPageGenerated: ManageFilePOSubCompObjectPageGenerated,
			onTheDataFilePOSubCompObjectPageGenerated: DataFilePOSubCompObjectPageGenerated
        },
        async: true
    });

    return runner;
});

