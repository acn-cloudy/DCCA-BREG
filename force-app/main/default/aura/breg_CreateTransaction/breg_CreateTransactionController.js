({
	doInit : function(component, event, helper) {
        helper.fetchPickListVal(component, event, helper, 'v.statuses', 'Transaction__c', 'Status__c');
        helper.fetchPickListVal(component, event, helper, 'v.transactionTypes', 'Transaction__c', 'TransactionType__c');
        //helper.fetchPickListVal(component, event, helper, 'v.dccaSections', 'Transaction__c', 'DCCASection__c');
        helper.fetchCashierCodes(component, event, helper);
        helper.initTransactions(component, event, helper);
	},
    
    saveForm : function(component, event, helper) {
        component.set('v.disableSave', true);
        helper.saveForm(component, event, helper);
    },
    
    cancelForm : function(component, event, helper) {
        $A.get('e.force:closeQuickAction').fire();
    },
    
    addLines : function(component, event, helper) {
        component.set('v.showPopup', true);
        helper.resetSelection(component, event, helper);
    },
    
    filterLines : function(component, event, helper) {
        if(event != null && event.keyCode == 13){
        	helper.filterLines(component, event, helper);
        }
    },
    
    filterLines2 : function(component, event, helper) {
        helper.filterLines(component, event, helper);
    },
    
    loadMoreLines : function(component, event, helper) {
       
        helper.loadMoreLines(component, event, helper);
    },

    finishAddLines : function(component, event, helper) {
        helper.addLines(component, event, helper);
        component.set('v.showPopup', false);
    },
    
    closeAddLines : function(component, event, helper) {
        component.set('v.showPopup', false);
    }
})