sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheBpList.iSeeThisPage();
            Then.onTheBpList.onFilterBar().iCheckFilterField("Customer");
            Then.onTheBpList.onFilterBar().iCheckFilterField("Sales Org");
            Then.onTheBpList.onTable().iCheckColumns(10, {"Customer":{"header":"Customer"},"SalesOrg":{"header":"Sales Org"},"DistribChannel":{"header":"Distribution Channel"},"Division":{"header":"Division"},"PartnerCounter":{"header":"Partner Counter"},"PartnerFunction":{"header":"Partner Function"},"Supplier":{"header":"Supplier"},"LocalCreatedBy":{"header":"Created By"},"LastChangedBy":{"header":"Changed By"},"LastChangedAt":{"header":"Changed At"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheBpList.onFilterBar().iExecuteSearch();
            
            Then.onTheBpList.onTable().iCheckRows();

            When.onTheBpList.onTable().iPressRow(0);
            Then.onTheBpObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});