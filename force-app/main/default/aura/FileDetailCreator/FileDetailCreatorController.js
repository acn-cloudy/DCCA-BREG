({
    init: function (cmp, event, helper) {
        helper.getRecordTypes(cmp);
        cmp.set('v.yesNoOptions', [
            {label: 'Yes', value: 'Yes'},
            {label: 'No', value: 'No'}
        ]);
        let today = $A.localizationService.formatDate(new Date(), "YYYY-MM-DD");
        cmp.set('v.today', today);
        helper.isVisible(cmp);
    },
    handleRecordTypeChange: function (cmp) {
        cmp.set('v.showSpinner', true);
    },
    handleLoad: function (cmp) {
        cmp.set('v.showSpinner', false);
    },
    handleSubmit: function (cmp) {
        cmp.set('v.showSpinner', true);
    },
    handleError: function (cmp) {
        // errors are handled by lightning:inputField and lightning:nessages
        // so this just hides the spinner
        cmp.set('v.showSpinner', false);
    },
    handleSuccess: function (cmp, event) {
        
    },
    handleUploadFinished: function (cmp, event) {
        const params = event.getParams();
        const fileUrl = params.files[0].fileUrl;
        cmp.set("v.fileUrl", fileUrl);
        const saveRecord = cmp.get("c.saveRecord");
        cmp.set('v.showSpinner', true);
        const record = cmp.get("v.record");
        saveRecord.setParams({fileUrl, record});
        saveRecord.setCallback(this, function (response) {
            cmp.set('v.showSpinner', false);
            const state = response.getState();
            if (state === 'SUCCESS') {
                var nextButton = cmp.find('nextBtn');
                $A.util.removeClass(nextButton, 'slds-hide');
                const recordId = response.getReturnValue();
                cmp.set('v.fileDetailCreated', true);
                cmp.set('v.fileUploaded', true);
                cmp.set('v.fileDetailId', recordId);
            } else if (state === 'ERROR') {
            }
        });
        $A.enqueueAction(saveRecord);

        
    },
    handleNext: function (cmp, event, helper) {
        var uploadMore = cmp.get('v.uploadMore');
        helper.resetForm(cmp);
        if (uploadMore === 'No') {
            helper.resetForm(cmp);
            cmp.set('v.openCard', false);
        }
    },
    handleSave: function (cmp) {
        console.log("fileDetailCreatorForm", cmp.find('fileDetailCreatorForm'));
        const fields = cmp.find("field");
        const isValid = fields.reduce((result, item) => item.reportValidity() && result, true);
        if(isValid) {
            const value = fields.reduce((result, item) => {
                if(item.get("v.value")) result[item.get("v.fieldName")]= item.get("v.value");
                return result;
              }, {});
            console.log("value", value);
            // cmp.find('fileDetailCreatorForm').submit();
            cmp.set("v.record", value);
            cmp.set('v.fileDetailCreated', true);
            cmp.set('v.showSpinner', false);
            var saveButton = cmp.find('saveBtn');
            $A.util.addClass(saveButton, 'slds-hide');
        }
        
    },
    handleShowForm: function (cmp, event, helper) {
        helper.resetForm(cmp);
        cmp.set('v.showSpinner', true);
        cmp.set('v.openCard', true);
    },
    handleCloseForm: function (cmp, event, helper) {
        var fileDetailCreated = cmp.get('v.fileDetailCreated');
        var fileUploaded = cmp.get('v.fileUploaded');
        if (fileDetailCreated && !fileUploaded) {
            var c = confirm('No file was uploaded. The file detail will be deleted. Are you sure you want to continue?');
            if (c) {
                helper.resetForm(cmp);
                // cmp.set('v.openCard', false);
            }
        } else {
            cmp.set('v.openCard', false);
        }
    }
})