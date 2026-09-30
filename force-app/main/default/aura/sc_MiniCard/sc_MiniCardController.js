({
    refresh : function(component, event, helper) {
        // Clear data in value map
        helper.refreshBody(component, helper);
    },
    updateValueMap : function(component, event, helper) {
		helper.updateValues(component, event);        
    },
    validate : function(component, event, helper) {
        var fieldInputs = component.find("sections").find("fieldInput");
        fieldInputs = Array.isArray(fieldInputs)?fieldInputs: [fieldInputs];
        var isValid = true;
        fieldInputs = fieldInputs.filter(function(f) {
            return f && f.getElement() !== null;
        });
        fieldInputs.forEach(function(fieldInput) {
            var isRequired = fieldInput.get("v.required");
            var hidden = fieldInput.get('v.hidden');
            if(!hidden) {
                if(fieldInput.get("v.errors") && fieldInput.get("v.errors").length > 0){
                    isValid = false;
                } else if(isRequired && !fieldInput.get("v.value")) {
                    if(fieldInput.get("v.type") == "picklist" && 
                    (fieldInput.get("v.options")== null || !fieldInput.get("v.options").length )) {
                        
                    } else {
                        isValid= false;
                        fieldInput.set("v.errors", [{"message":"This field is required"}]);
                    }
                } else if(fieldInput.get("v.type") === "date") {
                    isValid = isValid && fieldInput.find("field").validate();
                }
            }
        });
        const validationRegression = component.get("v.field").Validation_Regression__c;
        const valueMap = component.get("v.valueMap");
        const value = helper.convertValueMap(valueMap).record;
        if(validationRegression) {
            const validationRules = JSON.parse(validationRegression);
            validationRules.forEach( validationRule => {
                const combineVal = validationRule.rule.reduce((result, item) => {
                    result += value[item] || "";
                    return result;
                }, "");
                if(!combineVal) {
                    component.set("v.errorMap.generalError", [{"message": validationRule.errorMessage}]);
                    isValid = false;
                }
            });
        }
        return isValid;
    },
    convertToValueMap : function(component, event, helper) {
        const valueMap = component.get("v.valueMap");
        console.log("valueMap", valueMap);
        return helper.convertValueMap(valueMap);
    }
})