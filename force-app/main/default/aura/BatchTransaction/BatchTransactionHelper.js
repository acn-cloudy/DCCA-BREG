({
	getInitialInfo : function(component, event, helper) {
        var action = component.get("c.getInitialValues");
        action.setParams({
            "location": component.get('v.location')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var response = response.getReturnValue();
                var accountColumnFields = response.columnAccountFields;

                component.set('v.showPVL', response.showPVL);
                component.set('v.showFile', response.showFile);
                component.set('v.showOAH', response.showOAH);
                component.set('v.showPrjNo', response.showPrjNo);

                component.set('v.searchAccountFields', response.searchAccountFields);
                component.set('v.columnAccountFields', response.columnAccountFields);
                component.set('v.printAccountFields', response.printAccountFields);
                component.set('v.printFields', response.printFields);

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
    saveForms: function(component, event, helper) {
        const button = event.getSource();
        component.set('v.saveResults', null);
        component.set('v.errorStr', '');
        const accounts = component.get("v.accounts");
        const accRecords = accounts.reduce((result, item ) => {
            result.push({id: item.Id, workitem: item.TR_WorkItemId, description: item.TR_Description});
            return result;
        }, []);
        helper.saveSingleBatch(component, button, accRecords, 0);
        
    },
    saveSingleBatch: function(component, button, accRecords, start) {
        // if(accRecords.length > 50) {
        //     for(let start = 0;start< accRecords.length; start +=50) {
        //         let end = start + 50;
        //         if(end > accRecords.length ) end = accRecords.length;
        //         const part = accRecords.slice(start, end);

        //     }
        // }
        let end = start + 50;
        if(end > accRecords.length ) end = accRecords.length;
        const part = accRecords.slice(start, end);
        
        const action = component.get("c.saveTransactions");

        action.setParams({
            "accIds": JSON.stringify(part),
            "lines": JSON.stringify(component.get("v.transactionLines")),
            "unserializedFields": component.get("v.printFields"),
            "accountFields": component.get('v.printAccountFields')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                // debugger;
                var saveResponse = response.getReturnValue();
                
                

                if (saveResponse.success) {
                    let currentSaveResponse  = component.get('v.saveResults');
                    if(currentSaveResponse) {
                        for(let key in saveResponse.transactionAccountsMap) {
                            currentSaveResponse.transactionAccountsMap[key] = saveResponse.transactionAccountsMap[key];
                        }
                        currentSaveResponse.transactions = currentSaveResponse.transactions.concat(saveResponse.transactions);
                        currentSaveResponse.transactionSummaryList = currentSaveResponse.transactionSummaryList.concat(saveResponse.transactionSummaryList);
                    } else {
                        currentSaveResponse = saveResponse;
                    }
                    component.set('v.saveResults', currentSaveResponse);
                } else {
                    let errorStr = component.get('v.errorStr');
                    errorStr += saveResponse.error + " ";
                    component.set('v.errorStr', errorStr);

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
            if(end < accRecords.length) {
                this.saveSingleBatch(component, button, accRecords, end);
            } else {
                button.set('v.disabled',false);
                component.set('v.saved', 'true');
            }

        });
        $A.enqueueAction(action);
    },
	saveForm : function(component, event, helper) {
        var button = event.getSource();
        component.set('v.errorStr', '');
		var action = component.get("c.saveTransactions");
        
        var accIds = '[';
        var accounts = component.get("v.accounts");
        for (var i = 0; i < accounts.length; i++) {
            if (i > 0)
                accIds += ',';
            accIds += '{ "id" : "' + accounts[i].Id + '", "workitem" : "' + accounts[i].TR_WorkItemId + '", "description" : "' + accounts[i].TR_Description + '" }';
        }
        accIds += ']';
        
        action.setParams({
            "accIds": accIds,
            "lines": JSON.stringify(component.get("v.transactionLines")),
            "unserializedFields": component.get("v.printFields"),
            "accountFields": component.get('v.printAccountFields')
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                button.set('v.disabled',false);
                // debugger;
                var saveResponse = response.getReturnValue();
                component.set('v.saveResults', saveResponse);

                if (saveResponse.success) {
                    component.set('v.saved', 'true');
                    component.set('v.saveResults', saveResponse);

                } else {
                    component.set('v.errorStr', saveResponse.error);
                }
            }
            else if (state === "ERROR") {
                button.set('v.disabled',true);
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
    
    searchAccount : function(component, event, helper) {
        component.set('v.filtering', 'true');
        component.set('v.showNoResultsMessage', 'true');

    	var action = component.get("c.searchLines");
        
        action.setParams({
            "accountFieldValues": component.get("v.searchAccountFields"),
            "columnAccountFields": component.get("v.columnAccountFields"),
            "accountsPerPage": component.get("v.accountsPerPage"),
            "pageNumber": component.get("v.pageNumber")
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var accs = response.getReturnValue();
                component.set('v.foundAccounts', accs);

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
            component.set('v.filtering', 'false');
        });
        $A.enqueueAction(action);
	}
})