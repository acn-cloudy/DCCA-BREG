({
    checkIsRequired: function(component){
        var errors = component.get("v.errors");
        var errorList = [];
        if(errors) {
            errors.forEach(function(error) {
                if(error.message !="This field is required" ){
                    errorList.push(error);
                }
            });
            if(errorList.length === 0 ){
                component.set("v.errors", null);         
            } else {
                component.set("v.errors", errorList);
            }
        }
        
        var isRequired = component.get("v.required") ;
        var value = component.get("v.value");
        if(!isRequired){
            return;
        }
        var fieldCMP = component.find("field");
        if(!value || value === null || value === "--None--"){
            if(component.get("v.type") == "picklist" && 
               (component.get("v.options")== null || !component.get("v.options").length )) {
                
            } else {
                var info = "This field is required";
                this.setErrorMessage(fieldCMP, info);
            }
        } 
    },
    checkCustomiseValidation: function(component) {
        var validator = component.get("v.validator");
        if(validator && validator.length) {
            var value = component.get("v.value");
            var regex = RegExp(validator);
            var errorMessage=component.get("v.errorMessage");
            var errors = component.get("v.errors");
            if(errors) {
                var errorList = [];
                errors.forEach(function(error) {
                    if(error.message !== errorMessage ){
                        errorList.push(error);
                    }
                });
                if(errorList.length === 0 ){
                    component.set("v.errors", null);         
                } else {
                    component.set("v.errors", errorList);
                }
            }
            if(!regex.test(value)) {
                var fieldCMP = component.find("field");
                this.setErrorMessage(fieldCMP, errorMessage);
            }
            
        }
    },
    setErrorMessage: function(fieldCMP, info) {
        var message = [{message: info}];
        fieldCMP.set("v.errors", message);
    }
})