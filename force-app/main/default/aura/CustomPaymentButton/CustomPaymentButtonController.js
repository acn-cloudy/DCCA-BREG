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

    goToPaymentSection : function(component, event, helper) 
    {
        if(component.get('v.serverResponse.paymentId'))
        { 
            // Redirect to the Payment URL
            window.open(component.get('v.paymentPageURL') + '?pid=' + component.get('v.serverResponse.paymentId'));  
        }
        else
        {
            var toastType = 'error';
            var toastTitle = 'Server Error';
            var toastMessage = 'No payment found for this filing record.';
            var toastMode = 'sticky';

            helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
        }       
    }
})