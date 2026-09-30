({
	initTransactions : function(component, event, helper) {
		
        var action = component.get("c.initTransaction");
        var lines = component.get('v.lines');
        
        action.setParams({ recordId : component.get("v.recordId") });
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var retvalue = response.getReturnValue();
                component.set('v.transaction', retvalue.trns);
                var lineskeep = retvalue.lines;
                var trLineEx = retvalue.exampleLine;
                var total = 0;
                if(lineskeep.length > 0)
                {
                    for (var i = 0; i < lineskeep.length; i++) {
                        var newline = Object.assign({}, trLineEx);
                        newline.Id = lineskeep[i].Id;
                        newline.CashierCode__c = lineskeep[i].CashierCode__c;
                        newline.Amount__c = lineskeep[i].Amount__c||0;
                        if (lineskeep[i].CashierCode__r != null) {
                        	newline.Code = lineskeep[i].CashierCode__r.Name;
                            newline.FormDescription = lineskeep[i].CashierCode__r.FormDescription__c;
                            newline.Description = lineskeep[i].CashierCode__r.Description__c;
                            newline.Division = lineskeep[i].CashierCode__r.Division__c;
                            newline.Category = lineskeep[i].CashierCode__r.Category__c;
                            newline.FeeCode = lineskeep[i].CashierCode__r.FeeCode__c;
                        }
                        lines.push(newline);
                        total += newline.Amount__c;
                    }
                }
                component.set('v.initialized', true);
                component.set('v.totalAmount', total);
                helper.resetSelection(component, event, helper);
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
    
    fetchPickListVal: function(component, event, helper, varName, objName, fieldName) {
        
        var action = component.get("c.getSelectOptions");
        action.setParams({
            "objName": objName,
            "fieldName": fieldName
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var allValues = response.getReturnValue();
                component.set(varName, allValues);
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
    
    fetchCashierCodes: function(component, event, helper) {
        
        var action = component.get("c.getCashierCodes");
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var allValues = response.getReturnValue();
                component.set("v.cashierCodes", allValues);
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
    
    saveForm : function(component, event, helper) {
        
        component.set("v.errorSaving", "");
        var trns = component.get("v.transaction");
        trns.TransactionType__c = 'Payment';

        var action = component.get("c.saveTransaction");
        action.setParams({
            "trns": trns,
            "lines": JSON.stringify(component.get("v.lines"))
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (response.getState() == "SUCCESS") {
                var trId = response.getReturnValue();
                
                var navEvt = $A.get("e.force:navigateToSObject");
                navEvt.setParams({
                  "recordId": trId,
                  "slideDevName": "Detail"
                });
                navEvt.fire();
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
    
    resetSelection : function(component, event, helper) {
        component.set('v.filtering', 'true');
        
        window.setTimeout(
            $A.getCallback(function() {
                var codes = component.get('v.cashierCodes');
                var maxDisplay = component.get('v.maxDisplaySize');
                var displayMore = false;
                var displayCodes = [];
                for (var i = 0; i < codes.length; i++) {
                    codes[i].Selected = false;
                    codes[i].Visible = true;
                    if (displayCodes.length < maxDisplay) {
                        displayCodes.push(codes[i]);
                    } else {
                        displayMore = true;
                        break;
                    }
                }
                component.set('v.displayCashierCodes', displayCodes);
                component.set('v.displayMoreCodes', displayMore);
                
                component.set('v.filterText', '');
                
                component.set('v.filtering', 'false');
            }), 1
        );
        
    },
    
    
    
    filterLines : function(component, event, helper) {
        component.set('v.filtering', 'true');
        
        window.setTimeout(
            $A.getCallback(function() {
        
                var codes = component.get('v.cashierCodes');
                var displayCodes = [];
                var maxDisplay = component.get('v.maxDisplaySize');
                var displayMore = false;
                
                var filterTextCashierCode = (component.get('v.filterTextCashierCode')).toUpperCase().trim();
                var filterTextFeeCode = (component.get('v.filterTextFeeCode')).toUpperCase().trim();
                var filterTextCategory = (component.get('v.filterTextCategory')).toUpperCase().trim();
                var filterTextFormDescription = (component.get('v.filterTextFormDescription')).toUpperCase().trim();
                var filterTextDescription = (component.get('v.filterTextDescription')).toUpperCase().trim();
                
                if(filterTextCashierCode != '' || filterTextFeeCode != '' || filterTextCategory != '' || filterTextFormDescription != '' || filterTextDescription != '') {
                    for (var i = 0; i < codes.length; i++) {            
                        var cashierCode = '';
                        var feeCode = '';
                        var category = '';
                        var formDescription = '';
                        var description = '';
                        if(codes[i].CashierCode__c != null && codes[i].CashierCode__c != '')
                            cashierCode = (codes[i].CashierCode__c).toUpperCase();
                        if(codes[i].FeeCode__c != null && codes[i].FeeCode__c != '') 
                            feeCode = (codes[i].FeeCode__c).toUpperCase();
                        if(codes[i].Category__c != null && codes[i].Category__c != '') 
                            category = (codes[i].Category__c).toUpperCase();
                        if(codes[i].FormDescription__c != null && codes[i].FormDescription__c != '') 
                            formDescription = (codes[i].FormDescription__c).toUpperCase();
                        if(codes[i].Description__c != null && codes[i].Description__c != '') 
                            description = (codes[i].Description__c).toUpperCase();
                        
                        if ((cashierCode != null && filterTextCashierCode != '' && cashierCode.indexOf(filterTextCashierCode) == 0) || 
                        (feeCode != null && filterTextFeeCode != '' && feeCode.indexOf(filterTextFeeCode) > -1) ||
                        (category != null && filterTextCategory != '' && category.indexOf(filterTextCategory) > -1) ||    
                        (formDescription != null && filterTextFormDescription != ''  && formDescription.indexOf(filterTextFormDescription) > -1) || 
                        (description != null && filterTextDescription != '' && description.indexOf(filterTextDescription) > -1))
                        {
                            codes[i].Visible = true;
                            if (displayCodes.length < maxDisplay) {
                                displayCodes.push(codes[i]);
                            } else {
                                displayMore = true;
                                break;
                            }
                        } else {
                            codes[i].Visible = false;
                        }
                    }
                    
                } else {
                    for (var i = 0; i < codes.length; i++) {  
                        codes[i].Visible = true;
                        if (displayCodes.length < maxDisplay) {
                            displayCodes.push(codes[i]);
                        } else {
                            displayMore = true;
                            break;
                        }
                    }
                }
                
                component.set('v.displayCashierCodes', displayCodes);
                component.set('v.displayMoreCodes', displayMore);
                
                component.set('v.filtering', 'false');
            }), 10
        );
        
    },
    
    loadMoreLines : function(component, event, helper) {
        var maxDisplay = component.get('v.maxDisplaySize');
        maxDisplay += 30;
        component.set('v.maxDisplaySize', maxDisplay);
        helper.filterLines(component, event, helper);
    },
    
    addLines : function(component, event, helper) {
        var codes = component.get('v.displayCashierCodes');
        var lines = component.get('v.lines');
        var trLineEx = component.get('v.exampleLine');
        
        //var total = 0;
        var total = component.get('v.totalAmount');
        for (var i = 0; i < codes.length; i++) {
            if (codes[i].Selected == true) {
                var newline = Object.assign({}, trLineEx);
                newline.CashierCode__c = codes[i].Id;
                if(codes[i].AmountOverride__c != null)
                    newline.Amount__c = codes[i].AmountOverride__c;
                else
                	newline.Amount__c = codes[i].Amount__c||0;
                newline.Code = codes[i].Name;
                newline.AmountOverride__c = codes[i].AmountOverride__c;
                newline.FormDescription = codes[i].FormDescription__c;
                newline.Description = codes[i].Description__c;
                newline.Division = codes[i].Division__c;
                newline.Category = codes[i].Category__c;
                newline.FeeCode = codes[i].FeeCode__c;
                lines.push(newline);
                total += parseFloat(newline.Amount__c);
            }
        }
        component.set('v.lines', lines);
        component.set('v.totalAmount', total);
    }
    
})