({
    hidePopOver: function (cmp) {
        cmp.set('v.mouseOut', true);
        if (cmp.__overLay) {
            setTimeout(function () {
                cmp.__overLay.close(0);
                delete cmp.__overLay;
            }, 100);
        }
    },
    /**
     * Special handler for mouse over showPopOver event for license objects
     * @param cmp
     * @returns {boolean|boolean}
     * @See Case 00007690
     */
    isReferenceAndLicense: function (cmp) {
        let def = cmp.get('v.fieldDef');
        return (def.type === 'REFERENCE' && def.referenceObjectName === 'License__c');
    }
})