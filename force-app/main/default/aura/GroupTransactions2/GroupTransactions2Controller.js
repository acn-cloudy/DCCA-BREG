({
    doInit : function(component, event, helper) {
        component.set('v.disableSave', false);
		helper.getInitialInfo(component, event, helper);
	},
    
    searchAccount1 : function(component, event, helper) {
        helper.searchAccount1(component, event, helper);
    },
    
	saveForm : function(component, event, helper) {
        component.set('v.disableSave', true);
        helper.saveForm(component, event, helper);
    },
    
    cancelForm : function(component, event, helper) {
        var navEvt = $A.get("e.c:BatchTransactionRedirect");
        navEvt.fire();
    },

    backToFirstPage : function(component, event, helper) {
        component.set("v.step", "1");
        component.set('v.errors', []);
    },
    
    addLines : function(component, event, helper) {
        component.set('v.showPopup', true);
        component.set('v.filterAccountName', '');
        component.set('v.filterFileId', '');
        component.set('v.filterPVLBPId', '');
        component.set('v.filterOAH', '');
        component.set('v.filterPrjNo', '');
        component.set('v.filterCRDNumber', '');
        component.set('v.filterWorkItemId', '');
        component.set('v.foundTransactions', []);
        component.set('v.errors', []);
    },
    
    selectAccount : function(component, event, helper) {
        var selectedRows = event.getParam('selectedRows');
        selectedRows = JSON.parse(JSON.stringify(selectedRows));
        component.set("v.recordId", selectedRows[0].Id);
        component.set("v.step", "3");
    },
    
    createAccount1 : function(component, event, helper) {
        component.set("v.step", "2");
    },
    
    saveAccount1 : function(component, event, helper) {
        helper.saveAccount(component, event, helper);
    },
    
    closeAddLines : function(component, event, helper) {
        component.set('v.showPopup', false);
    },
    
    searchTransaction : function(component, event, helper) {
        helper.searchTransaction(component, event, helper);
    },
    
    finishAddLines : function(component, event, helper) {
        var transactions = component.get('v.transactions');
        var foundTransactions = component.get('v.foundTransactions');
        for (var i = 0; i < foundTransactions.length; i++) {
            if (foundTransactions[i].Selected) {
                transactions.push(foundTransactions[i]);
            }
        }
        component.set('v.transactions', transactions);
        component.set('v.showPopup', false);
    },
    
    savedClose : function(component, event, helper) {
        var navEvt = $A.get("e.c:BatchTransactionRedirect");
        navEvt.fire();
    },
    calcTotalTransactionalAmount: function(cmp){
        var transactions = cmp.get('v.transactions');
        var totalOutstanding = 0;
        for(var i =0 ; i < transactions.length; i++){
            totalOutstanding += parseFloat(transactions[i].TotalAmount__c);
        }
        cmp.set('v.totalTransactionalAmount', totalOutstanding);
    },
    keyCheck : function(component, event, helper) {
        //13 is the Enter button
        if (event.which == 13) {
            helper.searchAccount1(component, event, helper);
        }
    },
    keyCheckTransactions : function(component, event, helper) {
        //13 is the Enter button
        if (event.which == 13) {
            helper.searchTransaction(component, event, helper);
        }
    },

    onNextAccountPage : function(component, event, helper) {
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber+1);
        helper.searchAccount1(component, event, helper);
        window.scrollTo(0, 0);

    },

    onPrevAccountPage : function(component, event, helper) {
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber-1);
        helper.searchAccount1(component, event, helper);
    }
})