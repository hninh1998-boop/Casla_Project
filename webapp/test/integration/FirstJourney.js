sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheManageFileList.iSeeThisPage();
            Then.onTheManageFileList.onFilterBar().iCheckFilterField("Status");
            Then.onTheManageFileList.onFilterBar().iCheckFilterField("File name");
            Then.onTheManageFileList.onFilterBar().iCheckFilterField("Total line of File");
            Then.onTheManageFileList.onFilterBar().iCheckFilterField("Created By");
            Then.onTheManageFileList.onFilterBar().iCheckFilterField("Created On");
            Then.onTheManageFileList.onFilterBar().iCheckFilterField("Changed By");
            Then.onTheManageFileList.onFilterBar().iCheckFilterField("Changed On");
            Then.onTheManageFileList.onTable().iCheckColumns(11, {"Uuid":{"header":"UUID"},"Zcount":{"header":"No."},"Status":{"header":"Status"},"Attachment":{"header":"Attachment"},"Mimetype":{"header":"Mime type"},"Filename":{"header":"File name"},"Countline":{"header":"Total line of File"},"Createdbyuser":{"header":"Created By"},"Createddate":{"header":"Created On"},"Changedbyuser":{"header":"Changed By"},"Changeddate":{"header":"Changed On"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheManageFileList.onFilterBar().iExecuteSearch();
            
            Then.onTheManageFileList.onTable().iCheckRows();

            When.onTheManageFileList.onTable().iPressRow(0);
            Then.onTheManageFileObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});