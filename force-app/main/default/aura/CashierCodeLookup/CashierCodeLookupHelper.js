({
	searchCodes : function(component, event, helper) {
		var action = component.get("c.searchCodes");
        action.setParams({
            'code' : component.get("v.code")
        });

        action.setCallback(this, function(response) 
        {
            var recs = response.getReturnValue();
            component.set('v.showRecords', recs.length > 0 ? 'true' : 'false');
            component.set('v.records', recs);
        });

        $A.enqueueAction(action);
	}
})