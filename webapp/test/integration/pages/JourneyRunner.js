sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"mcofaupl/test/integration/pages/ManageFileList.gen",
	"mcofaupl/test/integration/pages/ManageFileObjectPage.gen",
	"mcofaupl/test/integration/pages/DataObjectPage.gen"
], function (JourneyRunner, ManageFileListGenerated, ManageFileObjectPageGenerated, DataObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('mcofaupl') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFileListGenerated: ManageFileListGenerated,
			onTheManageFileObjectPageGenerated: ManageFileObjectPageGenerated,
			onTheDataObjectPageGenerated: DataObjectPageGenerated
        },
        async: true
    });

    return runner;
});

