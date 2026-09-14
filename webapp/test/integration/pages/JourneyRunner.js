sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"mcsoheader/test/integration/pages/ManageFileList.gen",
	"mcsoheader/test/integration/pages/ManageFileObjectPage.gen",
	"mcsoheader/test/integration/pages/DataFileObjectPage.gen"
], function (JourneyRunner, ManageFileListGenerated, ManageFileObjectPageGenerated, DataFileObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('mcsoheader') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFileListGenerated: ManageFileListGenerated,
			onTheManageFileObjectPageGenerated: ManageFileObjectPageGenerated,
			onTheDataFileObjectPageGenerated: DataFileObjectPageGenerated
        },
        async: true
    });

    return runner;
});

