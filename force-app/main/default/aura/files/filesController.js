({
	uploadFinished : function(component, event, helper) {
		console.log("event", event);
        var uploadedFiles = event.getParam("files");
        uploadedFiles.forEach(function(file) {
           file.createdDate = helper.recordDate(); 
        });
        var files = component.get("v.files");
        uploadedFiles.forEach(function(file){
            files.push(file);
        });
        component.set("v.files", files);        
	},
    wrapValue: function(component, event, helper) {
        var files = component.get("v.files");
        if(!files || files.length === 0) {
            component.set("v.value", "");            
        } else {
            component.set("v.value", JSON.stringify(files));            
        }

        const change = component.get("v.change");
        if(change) $A.enqueueAction(change);
    }
})