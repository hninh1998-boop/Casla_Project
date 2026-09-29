sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zmodheadov4/test/integration/pages/ManageFileList.gen",
	"zmodheadov4/test/integration/pages/ManageFileObjectPage.gen",
	"zmodheadov4/test/integration/pages/DataFileObjectPage.gen"
], function (JourneyRunner, ManageFileListGenerated, ManageFileObjectPageGenerated, DataFileObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zmodheadov4') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFileListGenerated: ManageFileListGenerated,
			onTheManageFileObjectPageGenerated: ManageFileObjectPageGenerated,
			onTheDataFileObjectPageGenerated: DataFileObjectPageGenerated
        },
        async: true
    });

    return runner;
});

