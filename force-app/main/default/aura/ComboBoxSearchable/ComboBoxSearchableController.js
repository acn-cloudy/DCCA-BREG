({
    init: function (cmp, event, helper) {
        helper.initSelectableItems(cmp);
    },
    initItems: function (cmp, event, helper) {
        helper.initSelectableItems(cmp);
    },
    showOptions: function (cmp) {
        var elem = cmp.find('comboBoxInputSearch');
        if (!$A.util.hasClass(elem, 'slds-is-open')) {
            $A.util.addClass(elem, 'slds-is-open');
        }
    }
})