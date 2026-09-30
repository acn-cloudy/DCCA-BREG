({
    initiateAction: function(component, event, helper) {
        var params = event.getParam('arguments');
        var fieldSetName = params.fieldSetName;
        helper.getDisplayFields(component, fieldSetName);  
        var accountType = component.get("v.accountType");
        if(accountType == "Business Account") {
            component.set("v.sObjectName", "Account");
            component.set("v.layoutName", "PVL Account Layout - Community Create");

        } else {
            component.set("v.sObjectName", "PersonAccount");
            component.set("v.layoutName", "PVL Person Account Layout - Community Create");

        }
    },
    handleCreateAccountRecords: function(component, event, helper) {
        var type = event.getParams().type;        
        if(type === "Account Saved"){
            var record = event.getParams().payload.record;
            // console.log("recordId", recordId);
            event.stopPropagation();
            var BPNumber = record.BPID__c;
            var accountName= record.Name;
            var accountFEIN= record.FEIN__c;
            component.set("v.accountName", accountName);
            component.set("v.accountFEIN", accountFEIN);
            component.set("v.accountBPID", BPNumber);
            var accountValueMap = {};
            accountValueMap[record.Id] = true;
            component.set("v.accountValueMap", accountValueMap);
            helper.searchAccount(component).then(function(accounts) {
                component.set("v.accounts", accounts);
                component.set("v.searchAccount", true);
                component.set("v.newAccountModal", false); 
                $A.enqueueAction(component.get("v.next"));
            });
        }
    },
	search : function(component, event, helper) {
        helper.search(component);
	}, 
    createNewAccount : function(component, event, helper) {
        component.set("v.newAccountModal", true);
    },
    cancelCreateAccount: function(component, event, helper) {
        component.set("v.newAccountModal", false);        
    },
    create: function(component, event, helper) {
        component.find("newAccount").submit();
    }
})