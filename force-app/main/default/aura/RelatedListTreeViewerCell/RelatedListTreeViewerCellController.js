({
    init: function (cmp) {
        let fieldDef = cmp.get('v.fieldDef');
        let cellClass = 'col-fit';

        cmp.set('v.uniqueClass', 'popover' + String(Math.floor(Math.random() * 100000)));

        switch (fieldDef['type']) {
            case 'TEXTAREA': {
                cellClass += ' ' + 'col-textarea';
                break;
            }
            case 'DATE': {
                cellClass += ' ' + 'col-date';
                break;
            }
        }

        cmp.set('v.cellClass', cellClass);
    },
    goEditMode: function (cmp) {
        if (cmp.get('v.mode') === 'edit') return;

        cmp.set('v.mode', 'edit');

        let rowData = cmp.get('v.rowData'),
            fieldDef = cmp.get('v.fieldDef');

        if (fieldDef.type === 'BOOLEAN') {
            let currentVal = cmp.get('v.value');

            rowData[fieldDef['fieldApiName']] = !currentVal;

            cmp.set('v.rowData', rowData);
            cmp.set('v.value', !currentVal);
        }
    },
    goReadMode: function (cmp) {
        cmp.set('v.mode', 'read');
    },
    handleValueChange: function (cmp) {
        if (cmp.get('v.isDoneInitialRender') && cmp.get('v.fieldDef') !== 'REFERENCE') {
            let rowData = cmp.get('v.rowData'),
                fieldDef = cmp.get('v.fieldDef');
            rowData[fieldDef['fieldApiName']] = cmp.get('v.value');

            cmp.set('v.rowData', rowData);
        }
    },
    showPopover: function (cmp, event, helper) {
        if (!helper.isReferenceAndLicense(cmp)) {
            return;
        }

        cmp.set('v.mouseOut', false);

        if (cmp.get('v.refMouseHoverLoading')) {
            return;
        }

        cmp.set('v.refMouseHoverLoading', true);

        $A.createComponent('c:LicensePopover', {
            recordId: cmp.get('v.value')
        }, function (popOver, status, err) {
            if (status === 'SUCCESS') {
                setTimeout(function () {
                    cmp.find('overlayLib').showCustomPopover({
                        body: popOver,
                        referenceSelector: '.' + cmp.get('v.uniqueClass'),
                        cssClass: 'popoverClass,cRelatedListTreeViewerCell'
                    }).then(function (lib) {
                        cmp.__overLay = lib;
                        cmp.set('v.refMouseHoverLoading', false);
                        if (cmp.get('v.mouseOut')) {
                            helper.hidePopOver(cmp);
                        }
                    });
                }, 300);

            }
        });
    },
    hidePopOver: function (cmp, event, helper) {
        if (!helper.isReferenceAndLicense(cmp)) {
            return;
        }

        helper.hidePopOver(cmp);
    },
    handleMassAction: function (cmp, event, helper) {
        let params = event.getParam('arguments');
        if (params) {
            let {action} = params;
            let fields = action.fields;
            let currentField = cmp.get('v.fieldDef.fieldApiName');
            let updateDef = fields.find(field => field.field === currentField);
            if(updateDef){
                let currentValue = cmp.get('v.value');
                let toValue = updateDef.value;
                if(currentValue != toValue){
                    cmp.set('v.value',toValue);
                }
            }
        }

    },
})