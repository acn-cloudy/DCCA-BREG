({
    doInit: function (component, event, helper) {
        const action = component.get("c.validateTransaction");
        const recordId = component.get("v.recordId");
        action.setParams({ recordId });
        action.setCallback(this, function (res) {
            if (res.getState() === "SUCCESS") {
                let options = res.getReturnValue();
                if(options.length === 0 || options.length === 1 ) {
                     component.set("v.showWarning", true);
                }
                if(options.length === 1) {
                    component.set("v.warningTitle", options[0]);
                    options = [];
                }
                component.set("v.options", options);
                component.set("v.show", true);
            } else {
                const error = res.getError()[0].message;
                component.find('notifLib').showNotice({
                    'variant': 'error',
                    'header': 'Invalid action!',
                    'message': error
                });
            }

        });
        $A.enqueueAction(action);
    },
    updateTransaction: function (component, event, helper) {
        helper.updateTransaction(component);
    },
    processPayment: function(component, event, helper) {
        const paymentTerminal = component.find("paymentTerminal");
        paymentTerminal.find("internalCheckoutComponent").submitPayment();

    },
    savePayment: function (component, event, helper) {
        const paymentTerminal = component.find("paymentTerminal");
        console.log("paymentTerminal", paymentTerminal);
        const payment = event.getParam("payment");
        const recordId = component.get("v.recordId");
        payment.Transaction__c = recordId;
        payment.pymt__Memo__c = component.get("v.memo");
        payment.pymt__Payment_Type__c = component.get("v.paymentType");
        const paymentStr = JSON.stringify(payment);
        const action = component.get("c.updatePayment");
        action.setParams({ paymentStr });
        action.setCallback(this, function (res) {
            $A.get('e.force:refreshView').fire();
            var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                recordId: payment.Id, //paymentId
                slideDevName: "Detail"
            });
            navEvt.fire();

        });

        $A.enqueueAction(action);
        component.set("v.hide", true);
    }
})