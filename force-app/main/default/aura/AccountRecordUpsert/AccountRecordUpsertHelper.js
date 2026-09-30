({
    loadData: function(component) {
        var layoutName = component.get("v.layoutName");
		var action = component.get("c.loadAccount");
        action.setParams({recordId: component.get("v.recordId"), 
                          layoutName: layoutName});
        this.execute(action).then($A.getCallback(function(response) {
            var returnValueJSON = response.getReturnValue();
            var accounts = JSON.parse(returnValueJSON);
            console.log("accounts::::: ", accounts);
            component.set("v.sObj", accounts[0]);
            component.set("v.showAccPage", true);
        }));
        
    },
    initiate: function(component) {
        var recordTypeName = component.get('v.recordTypeName');
        if (recordTypeName === 'Business Account') {
            component.set("v.sObjectName", "Account");
        } else {
            component.set("v.sObjectName", "PersonAccount");
        }
    },
    createAccount : function(component, record) {
        var _self = this;
        var recordTypeName = component.get("v.recordTypeName");
        if(recordTypeName === "Person Account") {
            record.Salutation = record.Salutation__c;
            record.FirstName = record.FirstName__c;
            record.LastName = record.LastName__c;
            record.MiddleName = record.MiddleName__c;
            if(record.Name) {
                delete record.Name;
            }
            if(record.PersonMailingAddress) {
                delete record.PersonMailingAddress;
            }   
        }
        if(record.BillingAddress) {
            delete record.BillingAddress;
        }
        if(record.MailingAddress) {
            delete record.MailingAddress;
        }
        if(record.ShippingAddress) {
            delete record.ShippingAddress;
        }
        if(component.get("v.recordId") && component.get("v.recordId").length) {
            record.Id = component.get("v.recordId");
        }
        if(record.attributes) {
            delete record.attributes;
        }
        var action =component.get("c.createAccount");
        action.setParams({record: JSON.stringify(record), recordTypeName: recordTypeName});
        _self.execute(action).then($A.getCallback(
            function(response) {
                var result = JSON.parse(response.getReturnValue());
                if(result.status === "OK") {
                    record.Id = result.id;
                    _self.logMessage(component, "Account Saved Successfully!", "Success", "success");
                    // var toastEvent = $A.get("e.force:showToast");
                    // toastEvent.setParams({
                    //     "type": "Success",
                    //     "title": "Success",
                    //     "message": "Account Saved Successfully!"
                    // });
                    // toastEvent.fire();
                    component.set("v.recordId", record.Id);
                    var message = component.getEvent ("message");
                    _self.fireMessage(message, "Account Saved", {record: record});
                } else {
                    if(result.message.indexOf("DUPLICATE_VALUE, duplicate value found: BPID__c")  !== -1) {
                        _self.logError(component, "This BP ID already exists on an Account");
                    } else {
                        _self.logError(component, result.message);
                    }
                    
                }
            }
        ));
    }
})