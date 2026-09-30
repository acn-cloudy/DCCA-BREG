({
	doInit : function(component, event, helper) {
        helper.initiateJSONValues(component);
        if(component.get("v.defaultOpen")) {
        	helper.getAllRecords(component);    
        }
	},
    openResults : function(component, event, helper) {
        helper.getAllRecords(component);
    }
    
})