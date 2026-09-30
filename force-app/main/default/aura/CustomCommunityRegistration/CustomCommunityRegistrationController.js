({
    doInit: function (component, event, helper) 
    {
        helper.loadAccountFields(component, event, helper);
        helper.loadContactFields(component, event, helper);

        component.set('v.contact', { "MailingCountryCode" : "US" });
        component.set('v.account', { "BillingCountryCode" : "US" });
    },
    
	//enter contact details and find existing contact
    step1Continue: function (cmp, event, helper) 
    {
        var contact = cmp.get('v.contact');
        var firstName = contact.FirstName;
        var lastName = contact.LastName;
        var email = contact.Email;

        if (!firstName || !lastName || !email) 
        {
            helper.showToast({
                title: 'Missing fields',
                message: 'Please fill in all mandatory fields to continue',
                type: 'Error',
                mode: 'sticky'
            });
            return;
        }

        helper.getExistingContact(cmp, function (contact) 
        {
            if (contact && contact.Id) {
                cmp.set('v.step', '2');
            } else if (contact && contact.IsUserCreated) {
                cmp.set('v.step', '7');
            } else {
                cmp.set('v.step', '3')
            }
        });
    },
    
    //contact found, use existing?
    //yes, proceed to step 3
    step2Yes: function (cmp) {
        let btnLink = $A.get('$Label.c.CustomRegistrationCreateNewUserBtnLink');
        let urlEvent = $A.get('e.force:navigateToURL');
        urlEvent.setParams({
            url: btnLink
        });
        urlEvent.fire();
    },
    //contact found, use existing?
    //no abort registration
    step2No: function (cmp) {
        let btnLink = $A.get('$Label.c.CustomRegistrationHomeBtnLink');
        let urlEvent = $A.get('e.force:navigateToURL');
        urlEvent.setParams({
            url: btnLink
        });
        urlEvent.fire();
    },
    
    //is working for a company?
    //yes, proceed to step 4
    step3Yes: function (cmp) {
        cmp.set('v.workForCompany', true);
        cmp.set('v.step', '4');
    },
    //is working for a company
    //no, create person account record
    step3No: function (cmp, evt, helper) {
        cmp.set('v.workForCompany', false);
        helper.createRecords(cmp);
    },
    
    //enter account details, find existing account
    step4Search: function (cmp, evt, helper) {
        var account = cmp.get('v.account');
        var accountName = account.Name;
        var accountStreet = account.BillingStreet; 
        var accountCRD = account.CRD__c;
        var accountDBA = account.DBA__c;

        if (!accountName)
        {
            helper.showToast({
                title: 'Missing fields',
                message: 'Please fill in the name of the firm to continue',
                type: 'Error',
                mode: 'sticky'
            });
            return;
        }
        if (!accountStreet && !accountCRD && !accountDBA)
        {
			helper.showToast({
                title: 'Missing fields',
                message: 'Please fill in either the CRD# or DBA or Street',
                type: 'Error',
                mode: 'sticky'
            });
            return;            
        }

        helper.getExistingAccount(cmp, function (existingAccounts) {
            cmp.set('v.accountsFound', existingAccounts);
            cmp.set('v.accountsFoundResults', existingAccounts.length > 0); 
            cmp.set('v.accountsSearch', true);
        });
    },
    
    step4Continue: function (cmp, evt, helper) 
    {    
	    var ctarget = evt.currentTarget;
	    var id_str = ctarget.dataset.accid;
        cmp.set('v.useExistingAccount', true);
        

        var accountsFound = cmp.get('v.accountsFound');
        
        for (var acc in accountsFound) 
        {
        	if (accountsFound[acc].Id == id_str) 
        	{
        		cmp.set('v.account', accountsFound[acc]);
        	}
        }

        helper.createRecords(cmp);
        
    },
    step4Create: function (cmp, evt, helper) {
        cmp.set('v.step', '6');
    },
    
    step6Continue: function(cmp, evt, helper) {
        helper.createRecords(cmp);
    }
})