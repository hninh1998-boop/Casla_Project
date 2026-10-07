sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"manageshift/test/integration/pages/ShiftsList.gen",
	"manageshift/test/integration/pages/ShiftsObjectPage.gen"
], function (JourneyRunner, ShiftsListGenerated, ShiftsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('manageshift') + '/test/flp.html#app-preview',
        pages: {
			onTheShiftsListGenerated: ShiftsListGenerated,
			onTheShiftsObjectPageGenerated: ShiftsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

