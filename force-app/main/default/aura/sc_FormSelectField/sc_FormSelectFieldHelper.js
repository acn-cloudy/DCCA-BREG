({
    broadcastValue : function(component, event) {
        var df = component.get("v.dependField");
        var dv = component.get("v.dependValue"); 
        var inputCmp = event.getSource();
        var value    = inputCmp.get("v.value");
        var daction =  component.get("v.dependAction");
        var fieldName = component.get("v.fieldName");
        if (df!=null && dv!=null)
        {
            var theevent = $A.get("e.c:sc_ApplicationDependFieldEvent");
            theevent.setParams({
                "dependfield": df,
                "dependaction": daction,
                "dvalue" : dv,
                "value" : value,
                "valuetoset" : component.get("v.dependentValueToSet")
            }).fire();
            
        }
        var dependentValueChange = component.getEvent ("dependentValueChange");
        dependentValueChange.setParams({"type": "fieldDependentCalculate", "payload": {"value": value, "fieldName": fieldName}});
		dependentValueChange.fire();
    },
    validate: function(component) {
        const isRequired = component.get("v.required");
        const inputCmp = component.find("picklist");
        const value = inputCmp.get("v.value");
        if(isRequired && (!value || value == '-None-')) {
            component.set("v.errors", [{message: "This field is required"}]); // Set Error
            return false;
        } else {
            component.set("v.errors", []); // Set Error
        }
        return true;
    }
})