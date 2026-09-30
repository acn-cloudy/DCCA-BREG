({
    doinit: function (component, event, helper) {
        var currentAcc = component.get("v.currentAcc");
        var fieldName = component.get("v.fieldName");

        component.set("v.fieldValue", currentAcc[fieldName]);
    }

})