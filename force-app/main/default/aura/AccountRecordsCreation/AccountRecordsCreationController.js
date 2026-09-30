({
	doInit : function(component, event, helper) {
		var recordTypeName = component.get('v.recordTypeName');
        if (recordTypeName === 'Business Account') {
            component.set('v.layoutName', 'PVL Account Layout - Community Create');
        } else {
            component.set('v.layoutName', 'PVL Person Account Layout - Community Create');
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