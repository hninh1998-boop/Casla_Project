sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheExtendProductList.iSeeThisPage();
            Then.onTheExtendProductList.onFilterBar().iCheckFilterField("Product");
            Then.onTheExtendProductList.onFilterBar().iCheckFilterField("Plant");
            Then.onTheExtendProductList.onFilterBar().iCheckFilterField("Storage Location");
            Then.onTheExtendProductList.onTable().iCheckColumns(6, {"Product":{"header":"Product"},"Plant":{"header":"Plant"},"StorageLocation":{"header":"Storage Location"},"LocalCreatedBy":{"header":"Created By"},"LastChangedBy":{"header":"Changed By"},"LastChangedAt":{"header":"Changed At"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheExtendProductList.onFilterBar().iExecuteSearch();
            
            Then.onTheExtendProductList.onTable().iCheckRows();

            When.onTheExtendProductList.onTable().iPressRow(0);
            Then.onTheExtendProductObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});