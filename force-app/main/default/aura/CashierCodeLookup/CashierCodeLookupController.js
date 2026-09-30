({
	searchRec : function(component, event, helper) {
        component.set('v.showRecords', 'false');
        component.set('v.records', []);
        if (component.get("v.code").length >= 2)
			helper.searchCodes(component, event, helper);
	},
    
    divFocus : function(component, event, helper) {
        component.set('v.showRecords', component.get('v.records').length > 0 ? 'true' : 'false');
	},
    
    divBlur : function(component, event, helper) {
        window.setTimeout(
            $A.getCallback(function() {
                component.set('v.showRecords', 'false');
            }), 200
        );
	},
    
    selectValue : function(component, event, helper) {
        component.set('v.value', event.currentTarget.getAttribute('data-codeId'));
        component.set('v.code', event.currentTarget.getAttribute('data-codeName'));
        component.set('v.amount', event.currentTarget.getAttribute('data-codeAmount'));

        var parentCmp = component.get('v.parentCmp');
        var lines = parentCmp.get('v.transactionLines');
        var total = 0;
        for(var i =0 ; i<lines.length; i++){
            var amount = parseFloat(lines[i].oldAmount) || 0;
            var newAmount = parseFloat(lines[i].amount) || 0;
            if(newAmount !== 0){
                amount = newAmount;
            }
            total += amount;
        }
        parentCmp.set('v.totalAmount', total);
    },

    updateValues : function (component, event, helper) {
        var currentCode = component.get('v.code');
        var currentAmount = component.get('v.amount');
        if(currentCode == null || currentCode == ''){
            component.set('v.value', '');
            component.set('v.code', '');
            component.set('v.amount', '');

            var parentCmp = component.get('v.parentCmp');
            var lines = parentCmp.get('v.transactionLines');
            var total = 0;
            for(var i =0 ; i<lines.length; i++){
                var amount = parseFloat(lines[i].oldAmount) || 0;
                var newAmount = parseFloat(lines[i].amount) || 0;
                if(newAmount !== 0){
                    amount = newAmount;
                }
                total += amount;
            }
            parentCmp.set('v.totalAmount', total);
        }
    }
})