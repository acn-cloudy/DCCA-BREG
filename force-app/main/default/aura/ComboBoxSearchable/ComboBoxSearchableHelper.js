({
    initSelectableItems: function (cmp) {
        var options = cmp.get('v.options') || [];
        var searchText = cmp.get('v.selectedValue') || '';
        cmp.set('v.body', []);
        var onClick = function (params) {
            cmp.set('v.selectedValue', params['value']);
            cmp.set('v.selectedLabel', params['label']);
            var elem = cmp.find('comboBoxInputSearch');
            if ($A.util.hasClass(elem, 'slds-is-open')) {
                $A.util.removeClass(elem, 'slds-is-open');
            }
        };

        for (var i = 0; i < options.length; i++) {
            var option = options[i];

            $A.createComponent(
                'c:ComboBoxSearchableItem', {
                    label: option['label'],
                    value: option['value'],
                    onclick: $A.getCallback(onClick)
                }, function (newComp, status, errMessage) {
                    if (status === 'SUCCESS') {
                        var body = cmp.get('v.body') || [];
                        if (searchText && searchText.length > 0) {
                            if (!(option['value'].indexOf(searchText) < 0)) {
                                body.push(newComp);
                                cmp.set('v.body', body);
                            }
                        } else {
                            body.push(newComp);
                            cmp.set('v.body', body);
                        }
                    }

                });
        }
    },
    _createItems: function (cmp, option) {
        $A.createComponent(
            'c:ComboBoxSearchableItem', {
                label: option['label'],
                value: option['value'],
                onclick: $A.getCallback(onClick)
            }, function (newComp, status, errMessage) {
                if (status === 'SUCCESS') {
                    var body = cmp.get('v.body') || [];
                    body.push(newComp);
                    cmp.set('v.body', body);
                }
            });
    }
})