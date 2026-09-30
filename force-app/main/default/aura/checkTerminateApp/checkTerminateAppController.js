({
    closeApp: function(component, event, helper) {
        component.set("v.displayItem", false);
        const cancelActions = component.get("v.cancelActions");
        if(cancelActions ) {
            $A.enqueueAction(cancelActions);
        } else {
            helper.destroyCmp(component);
        }
        
    },
    doInit: function(component, event, helper) {
        component.set("v.isLoading", true);
        const value = component.get("v.value");
        const valueMap = component.get("v.valueMap");
        const card = component.get("v.card");
        for(var key in value) {
            if(key === "syncApp") {
                if(value[key]) {
                    component.set("v.syncApp", true);
                    component.set("v.cardStr", JSON.stringify(valueMap));
                }
                
            } else if(card  && (!card.Field_Meta_Data1__r.records.find(item => item.Name == key) || !card.Field_Meta_Data1__r.records.find(item => item.Name == key).Hidden__c) && valueMap[key] === value[key].value) {
                const title = value[key].title;
                var labelReference = $A.getReference("$Label.c." + title);
                component.set("v.title", labelReference);
                component.set("v.displayItem", true);
                component.set("v.isLoading", false);
                return;
            }
        }
        const actions = component.get("v.nextActions");
        if(actions ) {
            $A.enqueueAction(actions);
        } else {
            helper.confirmNext(component);
        }
        component.set("v.isLoading", false);
    },
    setErrors: function(component, event, helper) {
        var params = event.getParam('arguments');
        var errorMessage = params.errorMessage; 
        component.set("v.title", errorMessage);
        component.set("v.displayItem", true);
    }
})