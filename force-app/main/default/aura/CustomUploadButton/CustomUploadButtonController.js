({
	doInit : function(component, event, helper) 
    {
        if(!component.get("v.recordId"))
        {
            var toastType = 'error';
            var toastTitle = 'Server Error';
            var toastMessage = 'No record Id was found. Please use this component in a Filing detail page.';
            var toastMode = 'sticky';

            helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
        }
        else 
        {
            helper.getNecessaryInfo(component, event, helper);
        }
    },

    goToUploadSection : function(component, event, helper) 
    {
    	// redirect to the design given URL
        var eUrl = $A.get("e.force:navigateToURL");

        eUrl.setParams({
          "url": '/' + component.get("v.uploadFilePageName")+ '?recordId=' + component.get("v.recordId")
        });
        
        eUrl.fire();
    }
})