({
	doInit : function(component, event, helper) {
		var transactionLines = [];
        
        for (var i = 0; i < 6; i++) {
            transactionLines.push({ code: "", amount: "", description: "" });
        }
        
        component.set('v.transactionLines', transactionLines);
        helper.getInitialInfo(component, event, helper);
	},
    
    addRow : function(component, event, helper) {
		var transactionLines = component.get('v.transactionLines');
        
        transactionLines.push({ code: "", amount: "", description: "" });
        
        component.set('v.transactionLines', transactionLines);
	},
    
    removeAcc : function(component, event, helper) {
        var accId = event.currentTarget.dataset.accid;
        
        var accounts = component.get('v.accounts');
        for (var i = 0; i < accounts.length; i++) {
            if (accounts[i].Id == accId) {
                accounts.splice(i, 1);
            }
        }
        component.set('v.accounts', accounts);
    },
    
    saveForm : function(component, event, helper) {
        component.set('v.disableSave', true);
        helper.saveForms(component, event, helper);
    },

    cancelForm : function(component, event, helper) {
        var myEvent = $A.get("e.c:BatchTransactionRedirect");
        myEvent.fire();
    },

    backToFirstScreen : function(component, event, helper) {
        location.reload();
    },

    addLines : function(component, event, helper) {
        component.set('v.showNoResultsMessage', false);
        component.set('v.showPopup', true);
        component.set('v.filterAccountName', '');
        component.set('v.filterFileId', '');
        component.set('v.filterPVLBPId', '');
        component.set('v.foundAccounts', []);
        component.set('v.selectedAccounts', []);
        component.set('v.finalSelectedAccounts', []);
    },

    selectAccDT : function(component, event, helper) {
        var selectedRows = event.getParam('selectedRows');
        component.set('v.selectedAccounts', selectedRows);
    },
    
    selectAcc : function(component, event, helper) {
    	var accId = event.currentTarget.dataset.accid;

        var accounts = component.get('v.selectedAccounts');
        var foundAccounts = component.get('v.foundAccounts');
        for (var i = 0; i < foundAccounts.length; i++) {
            if (foundAccounts[i].Id == accId) {
                foundAccounts[i].TR_WorkItemId = '';
                foundAccounts[i].TR_Description = '';
                accounts.push(foundAccounts[i]);
            }
        }
        component.set('v.selectedAccounts', accounts);
    },
    
    removeSelAcc : function(component, event, helper) {
        var accId = event.currentTarget.dataset.accid;
        var accounts = component.get('v.selectedAccounts');

        for (var i = 0; i < accounts.length; i++) {
            if (accounts[i].Id == accId) {
                accounts.splice(i, 1);
            }
        }

        component.set('v.selectedAccounts', accounts);

        var cmpnent = component.find("accountsTable");
        var selectedRows = cmpnent.get('v.selectedRows');
        var selectedRowsRemoved = cmpnent.get('v.selectedRows');
        for (var m = 0; m < accounts.length; m++) {
            for(var j = 0; j < selectedRowsRemoved.length ; j++){
                if (accounts[m].Id == selectedRowsRemoved[j]) {
                    selectedRowsRemoved.splice(j, 1);
                }
            }
        }

        for (var k = 0; k < selectedRows.length; k++) {
            for(var l = 0; l < selectedRowsRemoved.length ; l++){
                if (selectedRows[k] == selectedRowsRemoved[l]) {
                    selectedRows.splice(k, 1);
                }
            }
        }

        cmpnent.set('v.selectedRows', selectedRows);
    },

    removeFinalSelAcc : function(component, event, helper) {
        var accId = event.currentTarget.dataset.accid;
        var accounts = component.get('v.finalSelectedAccounts');

        for (var i = 0; i < accounts.length; i++) {
            if (accounts[i].Id == accId) {
                accounts.splice(i, 1);
            }
        }

        component.set('v.finalSelectedAccounts', accounts);
    },
    
    closeAddLines : function(component, event, helper) {
        component.set('v.showPopup', false);
    },
    
    searchAccount : function(component, event, helper) {
        var foundFinalAccounts = component.get('v.finalSelectedAccounts');
        var selectedAccounts = component.get('v.selectedAccounts');
        for (var i = 0; i < selectedAccounts.length; i++) {
            foundFinalAccounts.push(selectedAccounts[i]);
        }
        component.set('v.finalSelectedAccounts', foundFinalAccounts);
        component.set('v.selectedAccounts', []);

        var cmpnent = component.find("accountsTable");
        cmpnent.set('v.selectedRows', []);

	    component.set('v.pageNumber', 1);
        component.set('v.isLastPage', false);
        component.set('v.resultSize', 0);

        helper.searchAccount(component, event, helper);
    },
    
    finishAddLines : function(component, event, helper) {
        var accounts = component.get('v.accounts');
        var foundFinalAccounts = component.get('v.finalSelectedAccounts');
        for (var j = 0; j < foundFinalAccounts.length; j++) {
            accounts.push(foundFinalAccounts[j]);
        }

        var foundAccounts = component.get('v.selectedAccounts');
        for (var i = 0; i < foundAccounts.length; i++) {
            accounts.push(foundAccounts[i]);
        }
        component.set('v.accounts', accounts);
        component.set('v.showPopup', false);
    },

    calcTotalAmount: function(cmp){
        var lines = cmp.get('v.transactionLines');
        var total = 0;
        for(var i =0 ; i<lines.length; i++){
            var amount = parseFloat(lines[i].oldAmount) || 0;
            var newAmount = parseFloat(lines[i].amount) || 0;
            if(newAmount !== 0){
                amount = newAmount;
            }
            total += amount;
        }
        cmp.set('v.totalAmount', total);
    },
    keyCheck: function(component, event, helper){
        if (event.which == 13){
            var foundFinalAccounts = component.get('v.finalSelectedAccounts');
            var selectedAccounts = component.get('v.selectedAccounts');
            for (var i = 0; i < selectedAccounts.length; i++) {
                foundFinalAccounts.push(selectedAccounts[i]);
            }
            component.set('v.finalSelectedAccounts', foundFinalAccounts);
            component.set('v.selectedAccounts', []);

            var cmpnent = component.find("accountsTable");
            cmpnent.set('v.selectedRows', []);

            helper.searchAccount(component, event, helper);
        }
    },

    onNextAccountPage : function(component, event, helper) {
        var foundFinalAccounts = component.get('v.finalSelectedAccounts');
        var selectedAccounts = component.get('v.selectedAccounts');
        for (var i = 0; i < selectedAccounts.length; i++) {
            foundFinalAccounts.push(selectedAccounts[i]);
        }
        component.set('v.finalSelectedAccounts', foundFinalAccounts);
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber+1);
        helper.searchAccount(component, event, helper);
    },

    onPrevAccountPage : function(component, event, helper) {
        var foundFinalAccounts = component.get('v.finalSelectedAccounts');
        var selectedAccounts = component.get('v.selectedAccounts');
        for (var i = 0; i < selectedAccounts.length; i++) {
            foundFinalAccounts.push(selectedAccounts[i]);
        }
        component.set('v.finalSelectedAccounts', foundFinalAccounts);
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber-1);
        helper.searchAccount(component, event, helper);
    }
})