({
    clearValue : function(component, event, helper) {
        component.set("v.value", "");
    },
	updateOptions : function(component, event, helper) {
		console.log("event", event);
	}
})