sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheExtendBpRoleRefList.iSeeThisPage();
            Then.onTheExtendBpRoleRefList.onFilterBar().iCheckFilterField("Business Partner");
            Then.onTheExtendBpRoleRefList.onFilterBar().iCheckFilterField("Org Code");
            Then.onTheExtendBpRoleRefList.onFilterBar().iCheckFilterField("Customer");
            Then.onTheExtendBpRoleRefList.onTable().iCheckColumns(6, {"BusinessPartner":{"header":"Business Partner"},"OrgCode":{"header":"Org Code"},"FLCU00_Customer":{"header":"Customer"},"FLCU01_CustomerFin":{"header":"Customer (Fin.Accounting)"},"FLVN00_Supplier":{"header":"Supplier"},"FLVN01_SupplierFin":{"header":"Supplier (Fin.Accounting)"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheExtendBpRoleRefList.onFilterBar().iExecuteSearch();
            
            Then.onTheExtendBpRoleRefList.onTable().iCheckRows();

            When.onTheExtendBpRoleRefList.onTable().iPressRow(0);
            Then.onTheExtendBpRoleRefObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});