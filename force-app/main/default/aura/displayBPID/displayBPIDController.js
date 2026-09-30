({
    doInit: function(component, event, helper) {
        const valueMap = component.get("v.valueMap");
        const formData = component.get("v.formData");
        if(formData) {
            const fData = JSON.parse(formData);
            const cancelURL = fData.cancel_url;
            component.set("v.cancelURL", cancelURL);
        }
        const cardCaches = component.get("v.cardCaches");
        const licenseType = cardCaches["Select License Type"].cachedValue.SelectLicenseType;
        const bpId = valueMap.socialSecurityNo;
        if(bpId) {
            const action = component.get("c.validateBPIDs");
            action.setParams({ bpId, licenseType });
            helper.execute(action).then($A.getCallback(function(response) {

                const accountName = response.getReturnValue();
                component.set("v.accountName", accountName);
                if(!accountName) {
                    helper.confirmNext(component);
                }else {
                    component.set("v.displayItem", true);
                }
            })).catch(function(ex) {
                const errors = ex.getError();
                const error = errors[0];
                try {
                    const err = JSON.parse(error.message);
                    const duplicateError = err.DuplicateError;
                    if(duplicateError) component.find("terminateApp").setError(duplicateError);
                } catch(ex1) {}
            });
        } else {
            helper.confirmNext(component);
        }
        

    },
    destroyAction: function(component, event, helper) {
        helper.destroyCmp(component);
    },
    confirm : function(component, event, helper) {
        helper.confirmNext(component);
        
    },
    cancel : function(component, event, helper) {
        component.set("v.notTheUser", true);
    },
    closeApp: function(component, event, helper) {
        component.set("v.displayItem", false);
        // window.location.href= component.get("v.cancelURL");
    }
})