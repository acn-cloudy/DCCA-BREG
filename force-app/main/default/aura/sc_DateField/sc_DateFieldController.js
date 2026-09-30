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

    }
})