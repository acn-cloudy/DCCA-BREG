({
	doInit : function(component, event, helper) {
        helper.fetchTransactions(component, event, helper);
        helper.initTransaction(component, event, helper);
	},
    
    saveForm : function(component, event, helper) {
        helper.saveForm(component, event, helper);
    },
    
    cancelForm : function(component, event, helper) {
        $A.get('e.force:closeQuickAction').fire();
    },
    
    addLines : function(component, event, helper) {
        helper.resetSelection(component, event, helper);
        component.set('v.showPopup', true);
    },
    
    filterLines : function(component, event, helper) {
        helper.filterLines(component, event, helper);
    },
    
    finishAddLines : function(component, event, helper) {
        helper.addLines(component, event, helper);
        component.set('v.showPopup', false);
    },
    
    closeAddLines : function(component, event, helper) {
        component.set('v.showPopup', false);
    }
})