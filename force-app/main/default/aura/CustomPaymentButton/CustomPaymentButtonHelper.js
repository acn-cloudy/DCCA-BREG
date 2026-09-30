({
	getNecessaryInfo : function(component, event, helper)
    {   
        var filingId = component.get("v.recordId");

        var action = component.get("c.getNecessaryInfoFromServer");

        action.setParams({
            "filingId": filingId,
            "checkboxApiName": component.get("v.checkboxApiName")
        });

        action.setCallback(self, function(a) 
        { 
            if(a.getReturnValue().errorMessage == '')
            { 
                component.set("v.serverResponse", a.getReturnValue());       
            }
            else
            {
                var toastType = 'error';
                var toastTitle = 'Server Error';
                var toastMessage = a.getReturnValue().errorMessage;
                var toastMode = 'sticky';
    
                helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
            }
        });

        // Enqueue the action
        $A.enqueueAction(action);
    },

	showToastMessage : function(type, title, message, mode) 
    {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "type": type,
            "title": title,
            "message": message,
            "mode": mode
        });
        toastEvent.fire();
    }
})