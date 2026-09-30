({
    submit : function(component, event, helper) {
        const action = component.get("c.getDraftApp");
        const name = component.find("appNo").get("v.value");
        action.setParams({name});
        helper.execute(action).then(res => {
            const app = JSON.parse(res.getReturnValue())[0];
            component.set("v.applicationName", app.Application_Meta_Data__r.Name);
            component.set("v.applicationLabel", app.Application_Meta_Data__r.Label__c);
            component.set("v.applicationcacheid", app.Name);
            component.set("v.appId", app.Id);
            component.set("v.formData", app.FormData__c);
            component.set("v.showApplication", true);
        }).catch(ex => {
            console.log("ex", ex);
        });
    }   
})