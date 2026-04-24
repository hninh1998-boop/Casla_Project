sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheExtendRoutList.iSeeThisPage();
            Then.onTheExtendRoutList.onFilterBar().iCheckFilterField("Group");
            Then.onTheExtendRoutList.onFilterBar().iCheckFilterField("Routing");
            Then.onTheExtendRoutList.onFilterBar().iCheckFilterField("Product");
            Then.onTheExtendRoutList.onFilterBar().iCheckFilterField("Plant");
            Then.onTheExtendRoutList.onFilterBar().iCheckFilterField("Sales Order");
            Then.onTheExtendRoutList.onFilterBar().iCheckFilterField("Sales Order Item");
            Then.onTheExtendRoutList.onTable().iCheckColumns(10, {"ProductionRoutingGroup":{"header":"Group"},"ProductionRouting":{"header":"Routing"},"Product":{"header":"Product"},"Plant":{"header":"Plant"},"SalesOrder":{"header":"Sales Order"},"SalesOrderItem":{"header":"Sales Order Item"},"Status":{"header":"Status"},"LocalCreatedBy":{"header":"Created By"},"LastChangedBy":{"header":"Changed By"},"LastChangedAt":{"header":"Changed At"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheExtendRoutList.onFilterBar().iExecuteSearch();
            
            Then.onTheExtendRoutList.onTable().iCheckRows();

            When.onTheExtendRoutList.onTable().iPressRow(0);
            Then.onTheExtendRoutObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});