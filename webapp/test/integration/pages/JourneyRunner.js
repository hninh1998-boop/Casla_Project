sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zcrtbatchov4/test/integration/pages/ManageFileList",
	"zcrtbatchov4/test/integration/pages/ManageFileObjectPage",
	"zcrtbatchov4/test/integration/pages/DataFileObjectPage"
], function (JourneyRunner, ManageFileList, ManageFileObjectPage, DataFileObjectPage) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zcrtbatchov4') + '/test/flp.html#app-preview',
        pages: {
			onTheManageFileList: ManageFileList,
			onTheManageFileObjectPage: ManageFileObjectPage,
			onTheDataFileObjectPage: DataFileObjectPage
        },
        async: true
    });

    return runner;
});

