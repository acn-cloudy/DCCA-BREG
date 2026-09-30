({
	handleBlur : function(component, event, helper) {
        const inputCmp = event.getSource();
        const isValid = helper.validateInput(component, inputCmp);
        const df = component.get("v.dependField");
        const dv = component.get("v.dependValue"); 
        const daction =  component.get("v.dependAction");
        const value    = inputCmp.get("v.value");
        if(isValid) {
            if (df!=null && dv!=null)
            {
                var theevent = component.get("e.sc_ApplicationDependFieldEvent");
                if(theevent) {
                    theevent.setParams({
                        "dependfield": df,
                        "dependaction": daction,
                        "dvalue" : dv,
                        "value" : value,
                        "valuetoset" : component.get("v.dependentValueToSet")
                    }).fire();
                }
           }
        }
        const fieldName = component.get("v.fieldName"); 
        const dependentValueChange = component.getEvent ("dependentValueChange");
        dependentValueChange.setParams({"type": "fieldDependentCalculate", "payload": {"value": value, "fieldName": fieldName}});
        dependentValueChange.fire();
        
    },
    checkValidity: function(component, event, helper) {
        const customDateField = component.find("customDateField");
        if(customDateField) {
            return customDateField.validate();
        }
        let textField =  component.find("field");
        
        if(textField){
            if(Array.isArray(textField)) textField = textField[0];
            return helper.validateInput(component, textField);
        }
       
        return true;

    },
    doInit: function(component) {
        const value = component.get("v.value");
        const fieldType = component.get("v.fieldType");
        if(fieldType === "checkbox") {
            if(value == true) {
                let items = component.find("field");
                if (Array.isArray(items) && items.length > 0) {
                    items = items[0];
                }
                if(items) {
                    items.set("v.checked", true);
                }
                
            }
        }
    },
    getVal: function(component, event, helper) {
        const clmFile = component.find("clmFile");
        return clmFile.getVal();
    },
    captureClmFile: function(component, event, helper) {
        event.stopPropagation();
        const value = event.getParams().value;
        component.set("v.value", value);
        component.set("v.errors", null);
    },
    captureFileData: function(component, event, helper) {
        var df = component.get("v.dependField");
       var dv = component.get("v.dependValue"); 
       var name = component.get("v.fieldName"); 
       var inputCmp = event.getSource();
       var value    = inputCmp.get("v.value");
       var daction =  component.get("v.dependAction");
       if (df!=null && dv!=null)
       {
                
               var theevent = component.get("e.sc_ApplicationDependFieldEvent");
              
               theevent.setParams({
    				"dependfield": df,
                   "dependaction": daction,
                   "dvalue" : dv,
                   "value" : value,
                   "valuetoset" : component.get("v.dependentValueToSet")
				}).fire();

       }
    },
    checkboxChanged: function(component, event, helper) {
       var df = component.get("v.dependField");
       var dv = component.get("v.dependValue"); 
       var fieldName = component.get("v.fieldName"); 
       var inputCmp = event.getSource();
       var value    = inputCmp.get("v.checked");
       component.set("v.value", value);
       var daction =  component.get("v.dependAction");
        
       if (df!=null && dv!=null)
       {
                
               var theevent = component.get("e.sc_ApplicationDependFieldEvent");
              
               theevent.setParams({
    				"dependfield": df,
                   "dependaction": daction,
                   "dvalue" : dv,
                   "value" : value + "",
                   "valuetoset" : component.get("v.dependentValueToSet")
				}).fire();

       }

       const dependentValueChange = component.getEvent ("dependentValueChange");
       dependentValueChange.setParams({"type": "fieldDependentCalculate", "payload": {"value": value, "fieldName": fieldName}});
       dependentValueChange.fire();

	}
})