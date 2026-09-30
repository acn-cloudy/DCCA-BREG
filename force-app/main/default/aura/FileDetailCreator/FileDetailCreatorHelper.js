({
    showToast: function (options) {
        var toast = $A.get('e.force:showToast');
        options = options || {};
        toast.setParams(options);
        toast.fire();
    },
    handleAsyncCallErrors: function (errors) {
        var __self = this;
        if (errors) {
            if (errors[0] && errors[0].message) {
                console.log('Error message: ' + errors[0].message);
            }
        } else {
            console.log('Unknown error');
            console.log(errors);
        }
        __self.showToast({
            title: 'Failed!',
            message: 'Something went wrong please contact your administrator.',
            type: 'error'
        });
    },
    isVisible: function (cmp) {
        var __self = this;
        var visibilityField = cmp.get('v.visibilityField');
        if (!visibilityField) {
            cmp.set('v.isVisible', true);
            return;
        }

        var action = cmp.get('c.isVisible');
        action.setParam('recordId', cmp.get('v.recordId'));
        action.setParam('fieldName', visibilityField);
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === 'SUCCESS') {
                cmp.set('v.isVisible', response.getReturnValue());
            } else if (state === 'ERROR') {
                var errors = response.getError();
                __self.handleAsyncCallErrors(errors);
            }
        });
        $A.enqueueAction(action);
    },
    getRecordTypes: function (cmp) {
        cmp.set('v.showSpinner', true);
        var __self = this;
        var action = cmp.get('c.getAvailableRecordTypes');
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === 'SUCCESS') {
                var result = response.getReturnValue();
                var availableRecordTypes = [];
                if (result.length > 1) {
                    cmp.set('v.multipleRecordTypes', true);

                    for (var i = 0; i < result.length; i++) {
                        availableRecordTypes.push({
                            label: result[i].label,
                            value: result[i].id
                        });

                        if (result[i].isDefault) {
                            cmp.set('v.recordTypeId', result[i].id);
                        }
                    }
                    cmp.set('v.availableRecordTypes', availableRecordTypes);
                } else {
                    cmp.set('v.recordTypeId', result[0].id);
                }
            } else if (state === 'ERROR') {
                var errors = response.getError();
                __self.handleAsyncCallErrors(errors);
            }

            cmp.set('v.showSpinner', false);
        });

        //for some reason this resolves that issue in UAT community
        //where in Filing Detail Page the Record Banner is messed up when this component is on the page
        //my guess is there could be a conflict in asynchronous calls
        setTimeout(function () {
            $A.enqueueAction(action);
        }, 1);
    },
    deleteFileDetail: function (cmp, cb) {
        var __self = this;
        cmp.set('v.showSpinner', true);
        const action = cmp.get('c.deleteFileDetail');
        const fileDetailId = cmp.get('v.fileDetailId');
         if(fileDetailId) {
            action.setParam('fileDetailId', fileDetailId);
            action.setCallback(this, function (response) {
                var state = response.getState();
                if (state === 'SUCCESS') {
                    cb(cmp);
                }
                else if (state === 'ERROR') {
                    var errors = response.getError();
                    __self.handleAsyncCallErrors(errors);
                }
                cmp.set('v.showSpinner', false);
            });
            $A.enqueueAction(action);
         } else {
            cmp.set('v.showSpinner', false);
         }
        
    },
    resetForm: function (cmp) {
        var nextBtn = cmp.find('nextBtn');
        var saveBtn = cmp.find('saveBtn');
        cmp.set('v.fileDetailCreated', false);
        cmp.set('v.fileUploaded', false);
        cmp.set('v.fileDetailId', '');
        cmp.set('v.uploadMore', 'No');
        $A.util.addClass(nextBtn, 'slds-hide');
        $A.util.removeClass(saveBtn, 'slds-hide');
    }
})