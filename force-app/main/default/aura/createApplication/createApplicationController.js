({
	handleCreateApplication : function(component, event, helper) {
		  component.set('v.showModalApplication', true);
    },
    
    handleAppMessage : function(component, event){
        var message = event.getParam("type");
        var payload = event.getParam("payload");
        component.set('v.showModalApplication', false);
        if(message === "lodge-draft"){
            component.set('v.applicationcacheid', payload);
            component.set('v.showModalApplication', true);
        } else if(message === "exit-lodge") {
            component.set('v.showModalApplication', false);
        }
        
    }
})