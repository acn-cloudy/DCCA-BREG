({
    callServerSideAction: function (action) {
        return new Promise(function (resolve, reject) {
            action.setCallback(this, function (response) {
                let state = response.getState();
                if (state === 'SUCCESS') {
                    resolve(response);
                } else if (state === 'ERROR') {
                    reject(response);
                }
            });

            $A.enqueueAction(action);
        });
    },
    calculateTotals: function (cmp, inputFieldName) {
        let totalDeposit = 0,
            t3Receipts = 0,
            t13Receipts = 0,
            totalReceipts = 0,
            totalCash = 0,
            totalCoins = 0,
            t3Cash = parseFloat(cmp.get('v.terminal3TotalCash') || 0),
            t3Coins = parseFloat(cmp.get('v.terminal3TotalCoins') || 0),
            t13Cash = parseFloat(cmp.get('v.terminal13TotalCash') || 0),
            t13Coins = parseFloat(cmp.get('v.terminal13TotalCoins') || 0),
            tape1 = parseFloat(cmp.get('v.tape1Check') || 0),
            tape2 = parseFloat(cmp.get('v.tape2Check') || 0),
            tape3 = parseFloat(cmp.get('v.tape3Check') || 0),
            tape4 = parseFloat(cmp.get('v.tape4Check') || 0),
            tape5 = parseFloat(cmp.get('v.tape5Check') || 0),
            tape6 = parseFloat(cmp.get('v.tape6Check') || 0),
            t3Gov = parseFloat(cmp.get('v.gov3TotalCheck') || 0),
            t13Gov = parseFloat(cmp.get('v.gov13TotalCheck') || 0);

        totalCash = t3Cash + t13Cash;
        totalCoins = t3Coins + t13Coins;
        totalDeposit = totalCash + totalCoins + tape1 + tape2 + tape3 + tape4 + tape5 + tape6;
        t3Receipts = t3Cash + t3Coins + tape1;
        t13Receipts = t13Cash + t13Coins + tape2;
        totalReceipts = totalDeposit + t3Gov + t13Gov;

        if (inputFieldName !== 'totalCash') {
            cmp.set('v.totalCash', totalCash);
        }

        if (inputFieldName !== 'totalCoins') {
            cmp.set('v.totalCoins', totalCoins);
        }

        if (inputFieldName !== 'totalDeposit') {
            cmp.set('v.totalDeposit', totalDeposit);
        }

        if (inputFieldName !== 'totalT3Receipts') {
            cmp.set('v.terminal3TotalReceipts', t3Receipts);
        }

        if (inputFieldName !== 'totalT13Receipts') {
            cmp.set('v.terminal13TotalReceipts', t13Receipts);
        }

        cmp.set('v.totalReceipt', totalReceipts);
    },
    resetAllValues: function (cmp) {
        let today = $A.localizationService.formatDate(new Date(), 'YYYY-MM-DD');
        cmp.set('v.batchDate', today);
        cmp.set('v.runningUser', {});
        cmp.set('v.terminal3TotalCash', 0);
        cmp.set('v.terminal13TotalCash', 0);
        cmp.set('v.totalCash', 0);

        cmp.set('v.terminal3TotalCoins', 0);
        cmp.set('v.terminal13TotalCoins', 0);
        cmp.set('v.totalCoins', 0);

        cmp.set('v.terminal3TotalCheck', 0);
        cmp.set('v.terminal13TotalCheck', 0);
        cmp.set('v.terminal3TotalReceipts', 0);
        cmp.set('v.terminal13TotalReceipts', 0);

        cmp.set('v.tape1Check', 0);
        cmp.set('v.tape2Check', 0);
        cmp.set('v.tape3Check', 0);
        cmp.set('v.tape4Check', 0);
        cmp.set('v.tape5Check', 0);
        cmp.set('v.tape6Check', 0);

        cmp.set('v.gov3TotalCheck', 0);
        cmp.set('v.gov13TotalCheck', 0);

        cmp.set('v.totalDeposit', 0);
        cmp.set('v.totalReceipt', 0);
    }
})