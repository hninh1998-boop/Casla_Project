sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zextmatass/test/integration/pages/ManageFileList",
	"zextmatass/test/integration/pages/ManageFileObjectPage",
	"zextmatass/test/integration/pages/DataFileObjectPage"
], function (JourneyRunner, ManageFileList, ManageFileObjectPage, DataFileObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zextmatass') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFileList: ManageFileList,
			onTheManageFileObjectPage: ManageFileObjectPage,
			onTheDataFileObjectPage: DataFileObjectPage
        },
        async: true
    });

    return runner;
});

