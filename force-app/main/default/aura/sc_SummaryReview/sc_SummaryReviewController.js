({
	generateSummary : function(component, event, helper) {
        var params = event.getParam('arguments');       
		var appCacheName = params.applicationcacheid;
        var action1 = component.get("c.loadSummaryValues");
        action1.setParams({
            appCacheName
        });
        action1.setCallback(this, function(response) {
            var state1 = response.getState(); // gets the state of the action returned from the server
            if (state1 === "SUCCESS") {
                console.log('Success');
                component.set("v.summary", response.getReturnValue());
            }
            
        });
        $A.enqueueAction(action1);
	},
    cancelsummary: function(component, event, helper){
        var message = component.getEvent("cmpMessage");
        message.setParams({
            "type" : "cancel-summary"
        });
		message.fire();
    }, 
    printsummary: function(component, event, helper){
        var message = component.getEvent("cmpMessage");
        message.setParams({
            "type" : "print-summary"
        });
		message.fire();
    },      
    finalsubmit: function(component, event, helper){
        var message = component.getEvent("cmpMessage");
        message.setParams({
            "type" : "final-submit"
        });
		message.fire();
    }
})