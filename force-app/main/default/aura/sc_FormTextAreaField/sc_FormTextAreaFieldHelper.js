({
    handleRegression : function(component, value, inputCmp) {
        const validations = component.get("v.validationRegression");
        if(validations && validations.length) {
            const validation = JSON.parse(validations);
            const regression = validation.regression;
            const pattern = new RegExp(regression, 'i');

            const message = validation.error;
            if(pattern.test(value)) {
                inputCmp.set("v.errors", [{ message }]); // Set Error
                return false;
            } else {
                inputCmp.set("v.errors", []); // Set Error
                return true;
            }
        }
        return true;

    }
})