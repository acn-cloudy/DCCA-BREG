({
    getInitialInfo : function(component, event, helper) {
        var action = component.get("c.getInitialValues");
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var response = response.getReturnValue();
                var accountColumnFields = response.accountColumnFields;
                
                component.set('v.recordTypes', response.recTypes);
                component.set('v.createType', response.recTypes[0].Id);
                
                component.set('v.showPVL', response.showPVL);
                component.set('v.showFile', response.showFile);
                component.set('v.showOAH', response.showOAH);
                component.set('v.showPrjNo', response.showPrjNo);
                component.set('v.colspanNoResults', response.colspanNoResults);

                var columnFields = [];
                for (var index = 0; index < accountColumnFields.length; ++index) {
                    var columnFieldData = {  label: accountColumnFields[index]['label'], fieldName: accountColumnFields[index]['name'], type: 'text' };
                    columnFields.push(columnFieldData);
                }
                component.set('v.accountColumns', columnFields);
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                 errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
    },
    showToastMessage : function(type, title, message, mode) 
    {
    	const toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "type": type,
            "title": title,
            "message": message,
            "mode": mode
        });
        toastEvent.fire();
    },
	saveForm : function(component, event, helper) {
        component.set('v.errorStr', '');
        component.set("v.errors", []);
		var action = component.get("c.saveTransactions");
        
        var transIds = [];
        var transactions = component.get("v.transactions");
        for (var i = 0; i < transactions.length; i++) {
            transIds.push(transactions[i].Id);
        }
        if(transIds.length < 2 ) {
            // throw error message
            const message = "You must select more than one Transaction to complete a Group Transaction.";
            component.set("v.errors", [{message }]);
            component.set('v.disableSave', false);
            return;
        }
        
        action.setParams({
            "accId": component.get("v.recordId"),
            "transIds": transIds
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var trId = response.getReturnValue(); 
                
                if (trId.indexOf('Error') == 0) {
                    component.set('v.errorStr', trId);
                    component.set('v.disableSave', false);
                } else {
                    var navEvt = $A.get("e.c:NewTransactionRedirect");
                    navEvt.setParams({
                      "transactionId": trId
                    });
                    navEvt.fire();
                }
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                 errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
                component.set('v.disableSave', false);
            }
        });
        $A.enqueueAction(action);
	},
    
    searchAccount1 : function(component, event, helper) {
        component.set('v.filtering1', 'true');
        component.set('v.showNoResultsMessage', 'true');

    	var action = component.get("c.searchLines1");
        
        action.setParams({
            "name": component.get("v.filterAccountName1"),
            "fileId": component.get("v.filterFileId1"),
            "pvlbpId": component.get("v.filterPVLBPId1"),
            "oah": component.get("v.filterOAH1"),
            "prjNo": component.get("v.filterPrjNo1"),
            "crdNumber": component.get("v.filterCRDNumber1"),
            "accountsPerPage": component.get("v.accountsPerPage"),
            "pageNumber": component.get("v.pageNumber")
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var accs = response.getReturnValue();
                
                component.set('v.foundAccounts1', accs);

                if(accs.length < component.get("v.accountsPerPage")){
                    component.set("v.isLastPage", true);
                } else{
                    component.set("v.isLastPage", false);
                }
                component.set("v.resultSize", accs.length);
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                 errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
            component.set('v.filtering1', 'false');
        });
        $A.enqueueAction(action);
	},
    
    searchTransaction : function(component, event, helper) {
        component.set('v.filtering', 'true');
        
    	var action = component.get("c.searchLines");
        
        action.setParams({
            "name": component.get("v.filterAccountName"),
            "fileId": component.get("v.filterFileId"),
            "pvlbpId": component.get("v.filterPVLBPId"),
            "workItemId": component.get("v.filterWorkItemId"),
            "crdNumber": component.get("v.filterCRDNumber"),
            "refNum": component.get('v.filterRefNum')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var accs = response.getReturnValue();
                
                component.set('v.foundTransactions', accs);
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                 errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
            component.set('v.filtering', 'false');
        });
        $A.enqueueAction(action);
	},
    
    saveAccount : function(component, event, helper) {
        component.set('v.creating', 'true');
        debugger;
    	var action = component.get("c.saveNewAccount");
        
        action.setParams({
            "accType": component.get("v.createType"),
            "name": component.get("v.createName"),
            "firstname": component.get("v.createFirstName"),
            "lastname": component.get("v.createLastName"),
            "fileId": component.get("v.createFileId"),
            "pvlbpId": component.get("v.createPVLBPId"),
            "oah": component.get("v.createOAH"),
            "prjNo": component.get("v.createPrjNo"),
            "licenses": component.get("v.createLicense")
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var resp = response.getReturnValue();
                if (resp.length == 15 || resp.length == 18) {
                	component.set('v.recordId', resp);
                    component.set('v.step', '3');
                } else {
                    component.set('v.createError', resp);
                }
            }
            else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                 errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
            component.set('v.creating', 'false');
        });
        $A.enqueueAction(action);
	}
})