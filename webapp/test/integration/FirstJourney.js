sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheCostCenterList.iSeeThisPage();
            Then.onTheCostCenterList.onFilterBar().iCheckFilterField("Cost Center");
            Then.onTheCostCenterList.onFilterBar().iCheckFilterField("Cost Center Group");
            Then.onTheCostCenterList.onFilterBar().iCheckFilterField("Valid From");
            Then.onTheCostCenterList.onTable().iCheckColumns(12, {"Costcenter":{"header":"Cost Center"},"CostctrHierGrp":{"header":"Cost Center Group"},"ValidTo":{"header":"valid To"},"ValidFrom":{"header":"valid From"},"CostcenterType":{"header":"Cost Center Type"},"CompCode":{"header":"Company Code"},"ProfitCtr":{"header":"Profit Center"},"PersonInCharge":{"header":"Person Responsible"},"Name":{"header":"Cost Center Name"},"LocalCreatedBy":{"header":"Created By"},"LastChangedBy":{"header":"Changed By"},"LastChangedAt":{"header":"Changed At"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheCostCenterList.onFilterBar().iExecuteSearch();
            
            Then.onTheCostCenterList.onTable().iCheckRows();

            When.onTheCostCenterList.onTable().iPressRow(0);
            Then.onTheCostCenterObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});