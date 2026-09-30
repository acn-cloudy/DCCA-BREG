({
    validateAndRedirect: function (cmp) {
        var tlCount = cmp.get('v.transactionRecord').TransactionLinesCount__c;
        var outstandingAmount = cmp.get('v.transactionRecord').AmountOutstanding__c;
        var transactionType = cmp.get('v.transactionRecord').TransactionType__c;
        $A.get('e.force:closeQuickAction').fire();
        if (tlCount <= 0 && transactionType != 'Group') {
            cmp.find('notifLib').showNotice({
                'variant': 'error',
                'header': 'Invalid action!',
                'message': 'Please enter at least one transaction line before making a payment.'
            });

            return;
        }

        if (outstandingAmount <= 0) {
            cmp.find('notifLib').showNotice({
                'variant': 'error',
                'header': 'Invalid action!',
                'message': 'Please make sure the outstanding amount is greater than zero before making a payment.'
            });

            return;
        }

        var urlEvent = $A.get('e.force:navigateToURL');
        urlEvent.setParams({
            'url': '/apex/pymt__CashEntry?csid=' + cmp.get('v.transactionRecord').Id
        });
        urlEvent.fire();
    }
})