({
    execute : function(action) {
        return new Promise(function(resolve, reject) {
            action.setCallback(this, function(response) {
                var state = response.getState();
                if (state === "SUCCESS") {
                    resolve(response);
                }else if (state === "ERROR") {
                    reject(response);
                }
            });
            $A.enqueueAction(action);
        });
    },
    initiateData: function(component) {
        this.initiateContact(component);
        this.initiateCashier(component);
    },
    initiateContact: function(component) {
        var action = component.get("c.loadGenericContact");
        var contactId = component.get("v.contactId");
        action.setParams({contactId: contactId});
        action.setCallback(this, function(response) {
            if(response.getState() === "SUCCESS") {

                component.set("v.contactRecord", response.getReturnValue())
            } 
        });
        $A.enqueueAction(action);
    },
    initiateCashier: function(component) {
        var action = component.get("c.loadCashierCode");
        var codeId = component.get("v.cashierCodeId");
        action.setParams({cashierCodeId: codeId});
        action.setCallback(this, function(response) {
            if(response.getState() === "SUCCESS") {

                component.set("v.cachierRecord", response.getReturnValue())
            } 
        });
        $A.enqueueAction(action);
    },
	createScript: function(component, transcript) {
        var _self = this;
		var action = component.get("c.createTranscript");
		var contactRecord = component.get("v.contactRecord");
		var cachierRecord = component.get("v.cachierRecord");
        component.set("v.executeOnce", true);
		action.setParams({transcriptStr: JSON.stringify(transcript), 
				contactStr: contactRecord, 
				cashierStr: cachierRecord, 
                division: component.get("v.division"),
                currencyCode: component.get("v.currencyCode")});
        _self.execute(action).then(
            $A.getCallback(function(response) {
                console.log("response", response);                
                component.set("v.paymentId", response.getReturnValue());
                _self.openPaymentPage(component);
                _self.checkPaymentStatus(component);
                component.set("v.executeOnce", false);
            })
        ).catch(function(response) {
            var errorMessage = response.getError()[0].message;
            _self.customErrorMessage(component, errorMessage);
            component.set("v.executeOnce", false);
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                "type": "error",
                "title": "Error saving!",
                "message": component.get("v.customMessage")
            });
            toastEvent.fire();
        });

	},
    openPaymentPage: function(component) {
        component.set("v.showPayment", true);
        var paymentURL = component.get('v.paymentPageURL') + '?pid=' + component.get("v.paymentId");
        component.set("v.paymentURL", paymentURL);
        //Object.assign(document.createElement('a'), { target: '_blank', href: paymentURL}).click();
        window.open(paymentURL, "_blank"); 
       
    },
    showThanksLabel: function(component) {
      	  component.set("v.showThanks", true);
    },
    checkPaymentStatus: function(component) {
        var _self = this;
    	var action = component.get("c.checkPaymentStatus");
        action.setParams({paymentId: component.get("v.paymentId")});
        action.setCallback(this, function(response) {
            if(response.getState() === "SUCCESS") {
             	_self.showThanksLabel(component);    
            } else {
                _self.checkPaymentStatus(component);
            }
        });
        $A.enqueueAction(action);
    }, 
    customErrorMessage: function(component, message) {
        // Hint is important to make sure the label to be load when initiates
		// $Label.c.TranscriptMismatchName 
        if(message !== null && message.indexOf("FIELD_CUSTOM_VALIDATION_EXCEPTION") !== -1) {
            var errorMessage = message.split("FIELD_CUSTOM_VALIDATION_EXCEPTION, ")[1];
            errorMessage = errorMessage.split(": []")[0];
            component.set("v.customMessage", $A.getReference("$Label.c." + errorMessage));
            if(!$A.getReference("$Label.c." + errorMessage)) {
                component.set("v.customMessage", errorMessage);
            }
        } else {
            component.set("v.customMessage", message);
        }
    },
})