sap.ui.define([
    "sap/ui/test/opaQunit",
    "./pages/JourneyRunner"
], function (opaTest, runner) {
    "use strict";

    function journey() {
        QUnit.module("First journey");

        opaTest("Start application", function (Given, When, Then) {
            Given.iStartMyApp();

            Then.onTheUdtBpBankList.iSeeThisPage();
            Then.onTheUdtBpBankList.onFilterBar().iCheckFilterField("Mã BP");
            Then.onTheUdtBpBankList.onFilterBar().iCheckFilterField("Bank Key");
            Then.onTheUdtBpBankList.onFilterBar().iCheckFilterField("Bank Account");
            Then.onTheUdtBpBankList.onTable().iCheckColumns(11, {"MaBP":{"header":"Mã BP"},"TenNCC":{"header":"Tên NCC"},"ID":{"header":"ID"},"CR":{"header":"C/R"},"BankKey":{"header":"Bank Key"},"BankAccount":{"header":"Bank Account"},"ExtID":{"header":"Ext. ID"},"AccountHolderName":{"header":"Account Holder Name"},"AccountName":{"header":"Account Name"},"BankName":{"header":"Bank Name"},"BankBranch":{"header":"Bank Branch"}});

        });


        opaTest("Navigate to ObjectPage", function (Given, When, Then) {
            // Note: this test will fail if the ListReport page doesn't show any data
            
            When.onTheUdtBpBankList.onFilterBar().iExecuteSearch();
            
            Then.onTheUdtBpBankList.onTable().iCheckRows();

            When.onTheUdtBpBankList.onTable().iPressRow(0);
            Then.onTheUdtBpBankObjectPage.iSeeThisPage();

        });

        opaTest("Teardown", function (Given, When, Then) { 
            // Cleanup
            Given.iTearDownMyApp();
        });
    }

    runner.run([journey]);
});