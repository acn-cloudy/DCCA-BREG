({
    init: function (cmp) {
        var test = [
            {
                label: 'test1',
                value: 'test1'
            },
            {
                label: 'test2',
                value: 'test2'
            },
            {
                label: 'test3',
                value: 'test3'
            }
        ];
        cmp.set('v.selectableLicense', test);
    },
    goNext: function (cmp) {
        var wizardForm = cmp.find('wizardForm');
        wizardForm.goNext();
    },
    goBack: function (cmp) {
        var wizardForm = cmp.find('wizardForm');
        wizardForm.goBack();
    }
})