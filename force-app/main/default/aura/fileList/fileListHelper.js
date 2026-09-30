({
    showSpinner: function(component) {
        var spinner = component.find("mySpinner");
        $A.util.removeClass(spinner, "slds-hide");
    },
    hideSpinner: function(component) {
        var spinner = component.find("mySpinner");
        $A.util.addClass(spinner, "slds-hide");
    },
    showToast : function(title, message, type) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "type": type
        });
        toastEvent.fire();
    },
    removeFiles : function(component, recordId) {
        var files = component.get("v.files");
        var filteredFiles = files.filter(function(file) {
            return file.documentId != recordId;
        });
        component.set("v.files", filteredFiles);
    },
    updateFiles : function(component) {
        var fileId = component.get("v.selectedFileId");
        var comment = component.get("v.selectedComment");
        var fileName = component.get("v.selectedFileName");
		var files = component.get("v.files");
        files.forEach(function(file){
            if(file.documentId === fileId) {
                file.comment = comment;
            }
        });
        try{
        component.set("v.files", files);
        } catch(err) {}
        this.closeBox(component);
    },
    closeBox: function(component) {

        component.set("v.selectedFileId", null);
        component.set("v.selectedComment", null);
        component.set("v.selectedFileName", null);
    }
})