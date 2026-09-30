({
	toggle : function(component, event, helper) {
        var open = component.get('v.open');
        component.set('v.open', !open);
        $A.util.toggleClass(component, "slds-is-open");
	}
})