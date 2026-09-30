({
    
    loadAccountFields: function (component, event, helper) 
    {
        var action = component.get('c.getAccountFields');

        action.setCallback(this, function (response) 
        {
            var state = response.getState();

            if (state === 'SUCCESS') 
            {
                var returnValue = response.getReturnValue();
                component.set('v.accountFields', returnValue);
            } 
            else if (state === 'ERROR') 
            {
                var errors = response.getError();

                if (errors && errors[0] && errors[0].message) 
                {
                    helper.showToast({
                        title: 'Error',
                        message: errors[0].message,
                        type: 'error'
                    });
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    loadContactFields: function (component, event, helper) 
    {
        var action = component.get('c.getContactFields');

        action.setCallback(this, function (response) 
        {
            var state = response.getState();

            if (state === 'SUCCESS') 
            {
                var returnValue = response.getReturnValue();
                component.set('v.contactFields', returnValue);
            } 
            else if (state === 'ERROR') 
            {
                var errors = response.getError();

                if (errors && errors[0] && errors[0].message) 
                {
                    helper.showToast({
                        title: 'Error',
                        message: errors[0].message,
                        type: 'error'
                    });
                }
            }
        });

        $A.enqueueAction(action);
    },
    
    getExistingContact: function (cmp, callback) 
    {
        var _self = this;
        cmp.set('v.isProcessing', true);
        var contact = cmp.get('v.contact');

        var action = cmp.get('c.getExistingContact');

        var params = 
        {
            params: JSON.stringify({
                'firstName': contact.FirstName,
                'lastName': contact.LastName,
                'email': contact.Email,
                'profileName': cmp.get('v.profileName')
            })
        };

        action.setParams(params);

        action.setCallback(this, function (response) 
        {
            var state = response.getState();

            if (state === 'SUCCESS') 
            {
                var returnValue = response.getReturnValue();
                callback(returnValue);
            } 
            else if (state === 'ERROR') 
            {
                var errors = response.getError();

                if (errors && errors[0] && errors[0].message) 
                {
                    _self.showToast({
                        title: 'Error',
                        message: errors[0].message,
                        type: 'error'
                    });
                }
            }

            cmp.set('v.isProcessing', false);
        });

        $A.enqueueAction(action);
    },
    
    getExistingAccount: function (cmp, callback) 
    {
        var _self = this;
        cmp.set('v.isProcessing', true);

        var account = cmp.get('v.account');
        var action = cmp.get('c.getExistingAccount');
        
        var params = 
        {
            params: JSON.stringify({
                'accountName': account.Name,
                'crd': account.CRD__c,
                'dba': account.DBA__c,
                'street': account.BillingStreet,
                'businessAccRecordTypeDeveloperName': cmp.get('v.businessAccRecordTypeDeveloperName')
            })
        };

        action.setParams(params);

        action.setCallback(this, function (response) 
        {
            var state = response.getState();

            if (state === 'SUCCESS') 
            {
                callback(response.getReturnValue());
            } 
            else if (state === 'ERROR') 
            {
                var errors = response.getError();

                if (errors && errors[0] && errors[0].message) 
                {
                    _self.showToast({
                        title: 'Error',
                        message: errors[0].message,
                        type: 'error'
                    });
                }
            }

            cmp.set('v.isProcessing', false);
        });

        $A.enqueueAction(action);
    },
    
    createRecords: function (cmp) 
    {
        var _self = this;
        
        cmp.set('v.isProcessing', true);
        
        var action = cmp.get('c.finalizeRecords');

        var params = {
            'account' : cmp.get('v.account'),
            'contact' : cmp.get('v.contact'),
            'profileName': cmp.get('v.profileName'),
            'workForCompany': cmp.get('v.workForCompany') ? "true" : "false",
            'useExistingAccount': cmp.get('v.useExistingAccount') ? "true" : "false",
            'businessAccRecordTypeDeveloperName': cmp.get('v.businessAccRecordTypeDeveloperName'),
            'personAccRecordTypeDeveloperName': cmp.get('v.personAccRecordTypeDeveloperName')
        };

        action.setParams(params);
        
        action.setCallback(this, function (response) 
        {
            var state = response.getState();

            if (state === 'SUCCESS') 
            {                
				var result = response.getReturnValue();

                if (result.success) 
                {
                    cmp.set('v.step', '7');
                } 
                else 
                {
                    _self.showToast({
                        title: 'Error',
                        message: result.errorMessage,
                        type: 'error'
                    });
                }
                
            } 
            else if (state === 'ERROR') 
            {
                var errors = response.getError();

                if (errors && errors[0] && errors[0].message) 
                {
                    _self.showToast({
                        title: 'Error',
                        message: errors[0].message,
                        type: 'error'
                    });
                }
            }

            cmp.set('v.isProcessing', false);
        });

        $A.enqueueAction(action);        
    },
    
    showToast: function (params) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": params.title,
            "message": params.message,
            "type": params.type,
            "mode": 'sticky'
        });
        toastEvent.fire();
    }
    
})