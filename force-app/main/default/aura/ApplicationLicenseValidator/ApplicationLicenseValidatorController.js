({
    doInit: function(component, event, helper) {
        const value = component.get("v.value");
        const valueMap = component.get("v.valueMap");
        for(var key in value) {
            if(valueMap[key] === value[key].value) {
                const title = value[key].title;
                let labelReference = $A.getReference("$Label.c." + title);
                component.set("v.message", labelReference);
                component.set("v.displayItem", true);
                return;
            }
        }
        helper.checkLicense(component);
    },
    closeApp: function(component, event, helper) {
        component.set("v.displayItem", false);
        helper.destroyCmp(component);
    }
})