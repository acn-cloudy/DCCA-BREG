({
	doInit : function(component, event, helper) {
		var transactionLines = [];

        for (var i = 0; i < 6; i++) {
            transactionLines.push({ code: "", amount: "", description: "" });
        }

        component.set('v.transactionLines', transactionLines);

        helper.getInitialInfo(component, event, helper);
	},

    searchAccount : function(component, event, helper) {
        helper.searchAccount(component, event, helper);
    },

    selectAccount : function(component, event, helper) {
        var selectedRows = event.getParam('selectedRows');
        component.set("v.recordId", selectedRows[0].Id);
        helper.loadLicenseNumbers(component, event, helper);
        component.set("v.step", "3");
    },

    createAccount : function(component, event, helper) {
        component.set("v.step", "2");
    },

    saveAccount : function(component, event, helper) {
        helper.saveAccount(component, event, helper);
    },

    addRow : function(component, event, helper) {
		var transactionLines = component.get('v.transactionLines');

        transactionLines.push({ code: "", amount: "", description: "" });

        component.set('v.transactionLines', transactionLines);
	},

    saveForm : function(component, event, helper) {
	    component.set('v.disableSave', true);
        helper.saveForm(component, event, helper);
    },

    backToFirstScreen : function(component, event, helper) {
        component.set("v.step", "1");

        var lines = component.get('v.transactionLines');
        for(var i =0 ; i<lines.length; i++){
            lines[i].amount = '';
            lines[i].code = '';
            lines[i].amount = '';
            lines[i].oldAmount = '';
        }
        component.set('v.totalAmount', 0);
    },

    cancelForm : function(component, event, helper) {
        var myEvent = $A.get("e.c:NewTransactionRedirect");
        myEvent.fire();
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
    keyCheck : function(component, event, helper) {
	    //13 is the Enter button
	    if (event.which == 13) {
            helper.searchAccount(component, event, helper);
        }
    },

    onNextAccountPage : function(component, event, helper) {
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber+1);
        helper.searchAccount(component, event, helper);
    },

    onPrevAccountPage : function(component, event, helper) {
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber-1);
        helper.searchAccount(component, event, helper);
    }
})