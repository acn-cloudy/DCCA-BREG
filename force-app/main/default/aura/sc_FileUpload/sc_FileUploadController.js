({
	uploadFinished : function(component, event, helper) {
		console.log("event", event);
        var change = component.get("v.change");
        var uploadedFiles = event.getParam("files")[0];
        component.set("v.value", uploadedFiles.documentId);
        console.log("uploadedFiles", uploadedFiles);
        var successMessage = component.get("v.successMessage");
        component.set("v.msg", successMessage.replace("${fileName}", uploadedFiles.name));
		$A.enqueueAction(change);
	}
})