({
	deleteFiles : function(component, cache, contid) {
		var action = component.get("c.deleteAttachedFiles"); 
            
        action.setParams({
            cache: cache,
            cid: contid
           
        });
       
        
        action.setCallback(this, function(a) {
        	if (a.getState() == "SUCCESS")
            {
            	var succ = a.getReturnValue();
            }
        	
        });
        
        $A.enqueueAction(action);
	},
    broadcastValue : function(component, event) {
        var df = component.get("v.dependField");
        var dv = component.get("v.dependValue"); 
        var inputCmp = event.getSource();
        var value    = inputCmp.get("v.value");
        var daction =  component.get("v.dependAction");
        var fieldName = component.get("v.fieldName");
        if (df!=null && dv!=null)
        {
            var theevent = $A.get("e.c:sc_ApplicationDependFieldEvent");
            theevent.setParams({
                "dependfield": df,
                "dependaction": daction,
                "dvalue" : dv,
                "value" : value,
                "valuetoset" : component.get("v.dependentValueToSet")
            }).fire();
            
        }
        var dependentValueChange = component.getEvent ("dependentValueChange");
        dependentValueChange.setParams({"type": "fieldDependentCalculate", "payload": {"value": value, "fieldName": fieldName}});
		dependentValueChange.fire();
    }
})