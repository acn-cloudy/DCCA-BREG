({
	check : function(component, event, helper) {
		console.log('event', event);
        var source = event.getSource();
        var value = source.get("v.value");
        component.set('v.value', value);
	},
    validate : function(component) {
        var value = component.get('v.value');
        if(!component.get('v.required')){
            return;
        }
        if(value === undefined || value.length === 0) {
        	component.set('v.valid', false);            
        } else {
            component.set('v.valid', true);
        }        
    }
})