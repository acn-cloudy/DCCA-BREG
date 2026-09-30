({
    doInit: function(component, event, helper) {
        helper.initiateData(component);
    },
    saveRecord: function(component, event, helper) {
        if(component.get("v.executeOnce")) {
            return;
        }
        
        var type = event.getParams().type;        
        if(type === "saveRecord"){
            
            var record = event.getParams().payload.record;
            record.Disclaimer__c = "";
            event.stopPropagation();
            if(record.SignatureFirstName__c  !== record.FirstName__c 
               || record.SignatureLastName__c  !== record.LastName__c ) {
                component.set("v.requestRecord", record);
                component.set("v.showWarning", true);
                return;
            } else {
                // console.log("recordId", recordId);
                helper.createScript(component, record);
                
            }

		}
	},
    proceedToCreate: function(component, event, helper) {
        var record = component.get("v.requestRecord");
        component.set("v.showWarning", false);
        helper.createScript(component, record);
    },
    cancelToUpdate: function(component, event, helper) {
        component.set("v.showWarning", false);
    }
})