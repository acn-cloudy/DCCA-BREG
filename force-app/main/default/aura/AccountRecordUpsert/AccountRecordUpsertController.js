({
	doInit : function(component, event, helper) {
        helper.initiate(component);
        var recordId = component.get("v.recordId");
        if(recordId) {
            helper.loadData(component);
        } else {
                        component.set("v.showAccPage", true);
        } 
	},
    submitToSave: function(component, event, helper) {
        component.find("account").save();
    },
    saveRecord: function(component, event, helper) {
        if(component.get("v.executeOnce")) {
            return;
        }
		var type = event.getParams().type;        
		if(type === "saveRecord"){
			var record = event.getParams().payload.record;
			// console.log("recordId", recordId);
			event.stopPropagation();
			helper.createAccount(component, record);
        }
	} 
})