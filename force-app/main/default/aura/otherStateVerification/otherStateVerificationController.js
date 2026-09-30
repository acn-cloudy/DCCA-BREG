({
    doInit: function(component, event, helper) {
        const valueMap = component.get("v.valueMap");
        const stateLicenses = valueMap.StateLicensure;
        let isWait = false;
        if(stateLicenses && stateLicenses.length) {
            const licenses = JSON.parse(stateLicenses);
            licenses.forEach(license => {
                if(license.StateofLicensure__c === "Pennsylvania") {
                    // display checkbox;
                    let labelReference = $A.getReference("$Label.c.ApplicationForm_OtherState");
                    component.set("v.message", labelReference);
                    component.set("v.confirmMessage", $A.getReference("$Label.c.ApplicationForm_ConfirmPennsy"));
                    component.set("v.displayItem", true);
                    isWait = true;
                }
            });
        }
        if(!isWait) {
            helper.confirmNext(component);
        }
        
        
    },
    confirm: function(component, event, helper) {
        helper.confirmNext(component);
    },
    closeApp: function(component, event, helper) {
        component.set("v.displayItem", false);
        helper.destroyCmp(component);
    }
})