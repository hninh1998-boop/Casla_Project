sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"manageaccount/test/integration/pages/AccountsList.gen",
	"manageaccount/test/integration/pages/AccountsObjectPage.gen",
	"manageaccount/test/integration/pages/UserRolesObjectPage.gen"
], function (JourneyRunner, AccountsListGenerated, AccountsObjectPageGenerated, UserRolesObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('manageaccount') + '/test/flp.html#app-preview',
        pages: {
			onTheAccountsListGenerated: AccountsListGenerated,
			onTheAccountsObjectPageGenerated: AccountsObjectPageGenerated,
			onTheUserRolesObjectPageGenerated: UserRolesObjectPageGenerated
        },
        async: true
    });

    return runner;
});

