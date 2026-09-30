({
    doInit: function (component, event, helper) {
        helper.initiateData(component);
    },
    saveRecord: function (component, event, helper) {
        if (component.get("v.executeOnce")) {
            return;
        }

        let type = event.getParams().type;
        if (type === "saveRecord") {
            let record = event.getParams().payload.record;
            event.stopPropagation();
            if (!record['sobjectType']) {
                record['sobjectType'] = component.get('v.sObjectName');
            }

            helper.createSObj(component, record);
        }
    },
    proceedToCreate: function (component, event, helper) {
        let record = component.get("v.requestRecord");
        component.set("v.showWarning", false);
        helper.createScript(component, record);
    },
    cancelToUpdate: function (component, event, helper) {
        component.set("v.showWarning", false);
    }
})