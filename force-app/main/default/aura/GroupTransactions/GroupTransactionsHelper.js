({
	initTransaction : function(component, event, helper) {
		
        var action = component.get("c.initTransaction");
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set('v.transaction', response.getReturnValue());
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
    
    fetchTransactions: function(component, event, helper) {
        
        var action = component.get("c.getTransactions");
        action.setCallback(this, function(response) {
            if (response.getState() == "SUCCESS") {
                var allValues = response.getReturnValue();
                component.set("v.transactions", allValues);
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
        /*if (trns.TransactionType__c == null || trns.TransactionType__c == '') {
            component.set("v.errorSaving", 'Please select a transaction type');
			return;
        }*/
        
        var action = component.get("c.saveTransaction");
        action.setParams({
            "currenttransaction": trns,
            "transactions": JSON.stringify(component.get("v.lines"))
        });
        action.setCallback(this, function(response) {
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
            }
        });
        $A.enqueueAction(action);
    },
    
    resetSelection : function(component, event, helper) {
        var codes = component.get('v.transactions');
        for (var i = 0; i < codes.length; i++) {
            codes[i].Selected = false;
            codes[i].Visible = true;
        }
        component.set('v.transactions', codes);
        component.set('v.filterText', '');
    },
    
    filterLines : function(component, event, helper) {
        var codes = component.get('v.transactions');
        var filterText = component.get('v.filterText');
        var filterName = component.get('v.filterName');
        //alert('filterText ' + filterText);
           // alert('filterName ' + filterName);
        for (var i = 0; i < codes.length; i++) {
            if(filterText.length > 0 && filterName == '')
            {
                if (codes[i].Account__r.Name.indexOf(filterText) >= 0) {
                    codes[i].Visible = true;
                } else {
                    codes[i].Visible = false;
                }
            }
            if(filterName.length > 0 && filterText == '')
            {
                if (codes[i].Name.indexOf(filterName) >= 0) {
                    codes[i].Visible = true;
                } else {
                    codes[i].Visible = false;
                }
            }
            if(filterName.length > 0 && filterText.length > 0)
            {
                if (codes[i].Account__r.Name.indexOf(filterText) >= 0 && codes[i].Name.indexOf(filterName) >= 0) {
                    codes[i].Visible = true;
                } else {
                    codes[i].Visible = false;
                }
            }
            
        }
        component.set('v.transactions', codes);
    },
    
    
    
    addLines : function(component, event, helper) {
        var codes = component.get('v.transactions');
        var lines = component.get('v.lines');
        var trLineEx = component.get('v.exampleLine');
        
        var total = 0;
        var arr = [];
        //for (var i = 0; i < lines.length; i++) {
            //arr.push(codes[i].Name);
        //}
        for (var i = 0; i < codes.length; i++) {
            if (codes[i].Selected == true) {
                lines.push(codes[i]);
            } else {
                arr.push(codes[i]);
            }
        }
        for (var i = 0; i < lines.length; i++) {
            total += lines[i].TotalAmount__c;
        }
        component.set('v.transactions', arr);
        component.set('v.lines', lines);
        component.set('v.totalAmount', total);
    }
    
})