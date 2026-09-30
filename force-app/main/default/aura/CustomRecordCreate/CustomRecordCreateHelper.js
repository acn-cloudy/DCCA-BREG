({
	loadLayout : function(component, event, helper) {
		
		var action = component.get("c.GetLayout");
        console.log('helper layoutName   ::::: ' + component.get('v.layoutName'));
        console.log('helper layoutName   ::::: ' + component.get('v.recordTypeName'));
		action.setParams({
            "sObjName": component.get('v.sObjectName'),
            "layoutName": component.get('v.layoutName'),
            //"layoutName": 'PVL Account Layout',            
            "recordType": component.get('v.recordTypeName')
        });
        action.setCallback(self, function(a) {
            console.log(a.getReturnValue());
            let layout = a.getReturnValue();
            let index = 0;
            layout.sections.forEach( section=> {section.fields.forEach(field=> {
                if(field.field1)  {
                    field.field1.tabIndex = index;
                }
                if(field.field2) {
                    field.field2.tabIndex = 100 + index;

                }
                index ++;
            })});
            component.set("v.layout", a.getReturnValue());
        });
        // Enqueue the action
        $A.enqueueAction(action);
        
	},
	
	saveRecord : function(component, event, helper) {
		var _self = this;
		var sObj = component.get('v.sObj');
        var action = component.get("c.SaveRecord");
        // Send the record to the outer component to handle.
		if(component.get("v.fireMessageEvent") == "true") {
            _self.fireMessage(component, "saveRecord", {record: sObj});
            return;
        }
		action.setParams({
            "sObjName": component.get('v.sObjectName'),
            "recordType": component.get('v.recordTypeName'),
            "record": JSON.stringify(sObj)
        });
        action.setCallback(self, function(a) {
        	var retObj = JSON.parse(a.getReturnValue());
        	console.log(retObj);
        	if (retObj.status == 'OK') {
        		var displayUpload = component.get("v.displayUpload");
                
        		if (displayUpload == 'true') {
        			component.set("v.recordId", retObj.id);
        			component.set("v.step", "2");
        		} else {
	        		var navEvt = $A.get("e.force:navigateToSObject");
				    navEvt.setParams({
				      "recordId": retObj.id,
				      "slideDevName": "details"
				    });
				    navEvt.fire();
				}
        	} else {
				var errorMessage = retObj.message;
				_self.customErrorMessage(component, errorMessage);
        		// var toastEvent = $A.get("e.force:showToast");
			    // toastEvent.setParams({
			    // 	"type": "error",
			    //     "title": "Error saving!",
			    //     "message": component.get("v.customMessage")
			    // });
                // toastEvent.fire();
                this.logError(component, component.get("v.customMessage"), "Error saving!");
        	}
        });
        // Enqueue the action
        $A.enqueueAction(action);
        
	},
    customErrorMessage: function(component, message) {
        // Hint is important to make sure the label to be load when initiates
		// $Label.c.TranscriptMismatchName 
        if(message !== null && message.indexOf("FIELD_CUSTOM_VALIDATION_EXCEPTION") !== -1) {
            var errorMessage = message.split("FIELD_CUSTOM_VALIDATION_EXCEPTION, ")[1];
            errorMessage = errorMessage.split(": []")[0];
            component.set("v.customMessage", $A.getReference("$Label.c." + errorMessage));
            if(!$A.getReference("$Label.c." + errorMessage)) {
                component.set("v.customMessage", errorMessage);
            }
        } else {
            component.set("v.customMessage", message);
        }
    },
    fireMessage: function(component, type,  payload) {
        var message = component.getEvent ("message");
        message.setParams({"type": type, "payload": payload});
        message.fire();    
    },
    createFileDetails: function(component) {
        return component.find("files").reduce(function(allFiles, file){
            let record = {};
            var label = file.get("v.label") || "";
            var fileList = file.get("v.files") || [];
            label = label.replace("- Max Size:2 GB", "");
            const results = fileList.reduce(function(results, fileRecord) {
                results.push({
                    Type__c: label,
                    Category__c: "SEB Complaint",
                    Description__c: fileRecord.comment,
                    SEB_Case__c : component.get("v.recordId"),
                    ContentDocumentTitle__c : fileRecord.name,
                    ContentDocumentId__c: fileRecord.documentId
                             	});
                return results;
            }, []);
            return allFiles.concat(results);
        }, []);
    }
     
    
})