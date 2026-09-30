({
    search: function(component) {
        if (this.validateBeforeSearch(component)) {
            this.searchAccount(component).then(function(accounts) {
                component.set("v.accounts", accounts);
                component.set("v.searchAccount", true);
            });
        }  
    },
	getDisplayFields : function(component, fieldSetName) {
		var action = component.get("c.getFieldSetByName");
        action.setParams({fieldSetName: fieldSetName});
        this.execute(action).then($A.getCallback(function(res){
            var displayOptions = JSON.parse(res.getReturnValue());
            component.set("v.displayOptions", displayOptions);
            var headNames = [];
            var columnNames = [];
            displayOptions.forEach(function(sglOption) {
                headNames.push(sglOption.label);
                columnNames.push(sglOption.name);
            })
            component.set('v.headNames', headNames);
            component.set('v.columnNames', columnNames);
        }));
	},
    validateBeforeSearch: function(component) {
        var accountType = component.get("v.accountType");
        var isValid = false;
        if(accountType === "Person Account") {
            
            var accountBPID = component.get('v.accountBPID');
            var bpIDCmp = component.find('bpId');
            if (!accountBPID) {
                 bpIDCmp.set("v.errors", [
                     {
                         message: "Social Security Number is required"
                     }
                 ]);
            } else if (isNaN(accountBPID)) {
               bpIDCmp.set("v.errors", [
                   {
                       message: "Social Security Number must be a number"
                   }
               ]);
            } else {
                bpIDCmp.set("v.errors", null);
                isValid = true;
            }
        } else {
            isValid = true;
            var accountName = component.get("v.accountName");
            var accountFEIN = component.get("v.accountFEIN");
            var nameCMP = component.find("accountName");
            var feinCMP = component.find("accountFEIN");
            if((!accountName || (! accountName.length)) && (!accountFEIN || (!accountFEIN.length))) {
                nameCMP.set("v.errors", [{
                    message: "Please provide either Business Name or FEIN."
                }]);
                isValid = false;
                feinCMP.set("v.errors", [{
                    message: "Please provide either Business Name or FEIN."
                }]);
                isValid = false;
            } else {
                nameCMP.set("v.errors", null);
                feinCMP.set("v.errors", null);
            }
        }
        return isValid;
    },
    searchAccount: function(component) {
        var bpID = component.get("v.accountBPID");
        var accountName = component.get("v.accountName");
        var accountFEIN = component.get("v.accountFEIN");
        var accountType = component.get("v.accountType");
        var action = component.get("c.searchAccountByBPID");
        action.setParams({BPID: bpID, accountType: accountType, accountName: accountName, accountFEIN: accountFEIN});
        return this.execute(action).then($A.getCallback(function(res){
            return JSON.parse(res.getReturnValue());
        }));
    }
})