({
	validateAndUpdate : function(component, event, helper) {
        var phoneVal = event.getSource().get("v.value");
        if(!helper.validatePhone(phoneVal)){
            component.find(
                "field").set(
                "v.errors", helper.addErrorMessage(
                    "Enter a valid Australian Mobile or Landline number"));
        } else {
            component.find(
                "field").set(
                "v.errors",null);
        }
        $A.enqueueAction(component.get("v.change"));
	}
})