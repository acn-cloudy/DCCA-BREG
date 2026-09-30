({
    doInit: function(component, event, helper) {
        const dateValidation = component.get("v.dateValidation");
        if(dateValidation && dateValidation.length) {
            try {
                const validation = JSON.parse(dateValidation);
                const base = validation.max.base;
                

                if(base === "{today}") {
                    const today  = new Date();
                    const year = validation.max.year;
                    let validateDate = today;
                    if(year !== undefined) {
                        validateDate = new Date(today.setFullYear(today.getFullYear() + year));
                    }
                    
                    const maxDate = helper.convertToFormat(validateDate);
                    component.set("v.maxDate", maxDate);
                }
            } catch(ex) {}
        }
    },
    doValidate: function(component, event, helper) {
        return component.find("input").reportValidity();

    },
	handleBlur : function(component, event, helper) {
       const req = component.get("v.required");      
       const inputCmp = event.getSource();      
       const fieldLabel = component.get("v.fieldLabel");  
       const value = inputCmp.get("v.value");
        
        
        if (req && (value==null || value==''))
        {
             var str = fieldLabel;
             str = str.endsWith(":") ? str.substring(0, str.length - 1) :str;
             inputCmp.set("v.errors", [{message: str + " is required"}]); // Set Error
        } else {
            inputCmp.set("v.value", value);
            inputCmp.set("v.errors", null);  
        }      
	},
    excutePrintError : function(component, event, helper) {
        const params = event.getParam('arguments');
        const errorMessage = params.message;
        component.find("dateInput").set("v.errors", [{message: errorMessage}]);
    }
    
})