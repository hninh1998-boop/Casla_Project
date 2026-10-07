sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"managerole/test/integration/pages/RolesList.gen",
	"managerole/test/integration/pages/RolesObjectPage.gen",
	"managerole/test/integration/pages/RoleFunctionsObjectPage.gen"
], function (JourneyRunner, RolesListGenerated, RolesObjectPageGenerated, RoleFunctionsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('managerole') + '/test/flp.html#app-preview',
        pages: {
			onTheRolesListGenerated: RolesListGenerated,
			onTheRolesObjectPageGenerated: RolesObjectPageGenerated,
			onTheRoleFunctionsObjectPageGenerated: RoleFunctionsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

