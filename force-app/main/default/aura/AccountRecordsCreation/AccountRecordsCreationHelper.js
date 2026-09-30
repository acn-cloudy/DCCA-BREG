({
    createAccount : function(component, record) {
        var _self = this;
        var recordTypeName = component.get("v.recordTypeName");
        if(recordTypeName === "Person Account") {
            record.Salutation = record.Salutation__c;
            record.FirstName = record.FirstName__c;
            record.LastName = record.LastName__c;
            record.MiddleName = record.MiddleName__c;
        }
        var action =component.get("c.createAccount");
        action.setParams({record: JSON.stringify(record), recordTypeName: recordTypeName});
        _self.execute(action).then($A.getCallback(
            function(response) {
                var result = JSON.parse(response.getReturnValue());
                if(result.status === "OK") {
                    record.Id = result.id;
                    var message = component.getEvent ("message");
                    _self.fireMessage(message, "Account Saved", {record: record});
                } else {
                    _self.logError(component, result.message);
                }
            }
        ));
    }
})