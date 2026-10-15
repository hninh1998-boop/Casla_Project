sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zuploadzbomrp/test/integration/pages/ManageFileList",
	"zuploadzbomrp/test/integration/pages/ManageFileObjectPage",
	"zuploadzbomrp/test/integration/pages/DataFileObjectPage"
], function (JourneyRunner, ManageFileList, ManageFileObjectPage, DataFileObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zuploadzbomrp') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFileList: ManageFileList,
			onTheManageFileObjectPage: ManageFileObjectPage,
			onTheDataFileObjectPage: DataFileObjectPage
        },
        async: true
    });

    return runner;
});

