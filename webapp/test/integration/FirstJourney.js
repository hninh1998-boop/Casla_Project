sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheExtendEWMProductList.iSeeThisPage();
            Then.onTheExtendEWMProductList.onFilterBar().iCheckFilterField("Product");
            Then.onTheExtendEWMProductList.onFilterBar().iCheckFilterField("Plant");
            Then.onTheExtendEWMProductList.onFilterBar().iCheckFilterField("Storage Location");
            Then.onTheExtendEWMProductList.onFilterBar().iCheckFilterField("Storage Type");
            Then.onTheExtendEWMProductList.onTable().iCheckColumns(7, {"Product":{"header":"Product"},"EntitledToDisposeParty":{"header":"Plant"},"EwmWarehouse":{"header":"Storage Location"},"Control":{"header":"Storage Type"},"LocalCreatedBy":{"header":"Created By"},"LastChangedBy":{"header":"Changed By"},"LastChangedAt":{"header":"Changed At"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheExtendEWMProductList.onFilterBar().iExecuteSearch();
            
            Then.onTheExtendEWMProductList.onTable().iCheckRows();

            When.onTheExtendEWMProductList.onTable().iPressRow(0);
            Then.onTheExtendEWMProductObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});