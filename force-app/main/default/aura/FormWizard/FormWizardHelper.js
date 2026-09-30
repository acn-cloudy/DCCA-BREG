({
    initializeProgressIndicator: function (cmp) {
        var body = cmp.get('v.body'),
            sections = cmp.get('v.sections'),
            _self = this;

        for (var i = 0; i < body.length; i++) {
            if (body[i].getName() === 'cFormWizardSection') {
                var section = body[i];
                sections.push(section);

                $A.createComponent(
                    'lightning:progressStep', {
                        label: section.get('v.label'),
                        value: i
                    }, function (newProg, status, errMessage) {
                        if (status === 'SUCCESS') {
                            var progressSteps = cmp.get('v.progressSteps') || [];
                            progressSteps.push(newProg);
                            cmp.set('v.progressSteps', progressSteps);
                            _self.updateTitle(cmp);
                        }
                    }
                );
            }
        }

        cmp.set('v.sections', sections);
    },
    disableGoNext: function (cmp) {
        var currentStep = cmp.get('v.currentStep');
        var sections = cmp.get('v.progressSteps');
        if (currentStep >= sections.length - 1) {
            cmp.set('v.goNextButtonDisabled', true);
        } else {
            cmp.set('v.goNextButtonDisabled', false);
        }
    },
    disableGoBack: function (cmp) {
        var currentStep = cmp.get('v.currentStep');
        if (currentStep <= 0) {
            cmp.set('v.goBackButtonDisabled', true);
        } else {
            cmp.set('v.goBackButtonDisabled', false);
        }
    },
    updateTitle: function (cmp) {
        var currentStep = cmp.get('v.currentStep');
        var progressSteps = cmp.get('v.progressSteps') || [];
        var title = progressSteps[currentStep].get('v.label');
        cmp.set('v.currentTitle', title);
    },
    toggleSections: function (cmp) {
        var currentStep = cmp.get('v.currentStep');
        var sections = cmp.get('v.sections');

        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            if (i != currentStep) {
                $A.util.addClass(section.getElement(), 'slds-hide');
            } else {
                $A.util.removeClass(section.getElement(), 'slds-hide');
            }
        }
    }
})