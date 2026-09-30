({
	handleBlur : function(component, event, helper) {
                var inputCmp = event.getSource();
                var value    = inputCmp.get("v.value");
                var req = component.get("v.required");
                var fieldLabel = component.get("v.fieldLabel");
                
                if (req && (value.trim()==null || value.trim() === '')) {
                inputCmp.set("v.errors", [{message: fieldLabel + " is required"}]); // Set Error
                } else {
                        helper.handleRegression(component, value, inputCmp);
                }
        },
        checkValidity: function(component, event, helper) {
                const inputCmp = component.find("textarea");
                const value = component.get("v.value");
                const req = component.get("v.required");
                const fieldLabel = component.get("v.fieldLabel");
                if (req && (!value || value.trim() === '')) {
                        inputCmp.set("v.errors", [{message: fieldLabel + " is required"}]); // Set Error
                        return false;
                } else {
                        return helper.handleRegression(component, value, inputCmp);
                }
        }
})