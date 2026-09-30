({
    handleCaptureFileUploadInfo: function(component, event) {
        component.set("v.uploadInProgress", true);
    },
    handleTerminateFileUpload: function(component) {
        component.set("v.uploadInProgress", false);
    },
	handleUploadFinished: function (component, event) 
    {
        component.set("v.uploadInProgress", false);
        // Get the list of uploaded files
        const uploadedFiles = event.getParam("files");
        
        if(uploadedFiles)
        {
        	component.set("v.uploadedFileWrapper.uploadedFileName", uploadedFiles[0].name);
            if(uploadedFiles[0].documentId) {
                component.set("v.uploadedFileWrapper.contentDocumentId", uploadedFiles[0].documentId);
            } else if(uploadedFiles[0].fileUrl) {
                component.set("v.uploadedFileWrapper.fileUrl", uploadedFiles[0].fileUrl);
            }
        }
    },
    checkIfValid: function(component) {
        if(component.get("v.uploadInProgress")) {
            return false;
        } else {
            return true;
        }
    }
})