({
    
    reviewFiles : function(component, event, helper) {
        var fileId = event.target.getAttribute("data-row-index")
        $A.get('e.lightning:openFiles').fire({
                recordIds: [fileId]
            });
    }, 
    deleteDoc: function(component, event, helper) {
        var fileId = event.getSource().get("v.accesskey");
        var action = component.get("c.deleteFile");
        helper.showSpinner(component);
        action.setParams({fileId: fileId});
        helper.execute(action).then($A.getCallback(function(response){
            // Success delete files
            try{
            helper.removeFiles(component, fileId);
            }catch(err) {}
            helper.showToast("Success", "File removed", "Success");
            helper.hideSpinner(component);
        })).catch($A.getCallback(function(response){
            helper.showToast("Error", "There is an exception when trying to delete the file.", "error");            
            helper.hideSpinner(component);
        }));
        helper.closeBox(component);
    },
    openCommentBox: function(component, event, helper) {
        var fileId = event.getSource().get("v.accesskey");
        var selectdFiles = component.get("v.files").filter(function(file){
           return file.documentId === fileId;
        });
        component.set("v.selectedFileId", fileId);
        component.set("v.selectedFileName", selectdFiles[0].name);
        component.set("v.selectedComment", selectdFiles[0].comment);
    },
    saveComment: function(component, event, helper) {
        var fileId = component.get("v.selectedFileId");
        var comment = component.get("v.selectedComment");
        var action = component.get("c.updateDescription");
        action.setParams({fileId: fileId, comment: comment});
        helper.showSpinner(component);
        helper.execute(action).then($A.getCallback(function(response){
            
            helper.updateFiles(component, fileId);
            helper.showToast("Success", "Comment saved", "success");
            helper.hideSpinner(component); 
        })).catch($A.getCallback(function(res){
            helper.showToast("Error", "There is an exception when trying to update the file.", "error");      
            helper.hideSpinner(component); 
        }));                 
    },
    closeComment: function(component, event, helper) {
        helper.closeBox(component);
    }
})