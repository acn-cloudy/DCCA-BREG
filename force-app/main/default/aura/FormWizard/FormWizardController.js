({
    init: function (cmp, event, helper) {
        helper.initializeProgressIndicator(cmp);
    },
    goNext: function (cmp, event, helper) {
        var currentStep = cmp.get('v.currentStep');
        var sections = cmp.get('v.progressSteps');
        if (currentStep < sections.length - 1) {
            currentStep += 1;
            cmp.set('v.currentStep', currentStep);
        }

        helper.disableGoBack(cmp);
        helper.disableGoNext(cmp);
        helper.updateTitle(cmp);
        helper.toggleSections(cmp);
    },
    goBack: function (cmp, event, helper) {
        var currentStep = cmp.get('v.currentStep');
        if (currentStep > 0) {
            currentStep -= 1;
            cmp.set('v.currentStep', currentStep);
        }

        helper.disableGoBack(cmp);
        helper.disableGoNext(cmp);
        helper.updateTitle(cmp);
        helper.toggleSections(cmp);
    }
})