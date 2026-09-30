({
    doInit: function (component, event, helper) {
        helper.checkAvailability(component);
    },
    buttonAction: function (component, event, helper) {
        helper.openDialog(component);
    },
    hideButton: function (component, event, helper) {
        component.set("v.hide", true);
    },
    updateData: function (component, event, helper) {
        const params = event.getParams();
        let inputs = component.get("v.bodyInputFields");
        inputs.forEach(item => {
            if (params[item.apiName]) {
                item.value = params[item.apiName];
            }
        });
        //component.set("v.bodyInputFields", inputs);
    },
    saveAction: function (component, event, helper) {
        if (helper.validate(component)) {
            // create filds object {apiName: value}
            var bodyInputFields = component.get("v.bodyInputFields");

            var fieldsObj = bodyInputFields.reduce(function (obj, item) {
                obj[item.apiName] = item.value;
                return obj;
            }, {});
            fieldsObj["Id"] = component.get("v.recordId");
            fieldsObj["attributes"] = {
                type: component.get("v.objectName")
            };
            // update action
            var action = component.get("c.updateRecord");
            action.setParams({
                //recordId: component.get("v.recordId"),
                fieldsListString: JSON.stringify(fieldsObj)
            });
            action.setCallback(this, function (response) {
                if (response.getState() === "SUCCESS") {
                    component.set("v.hide", true);
                    $A.get('e.force:refreshView').fire();
                }
            });
            $A.enqueueAction(action);
        }
    }
});