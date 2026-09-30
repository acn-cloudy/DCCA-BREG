({
    init: function (cmp) {
        let today = $A.localizationService.formatDate(new Date(), 'YYYY-MM-DD');
        cmp.set('v.batchDate', today);
    },
    handleSave: function (cmp, event, helper) {
        let saveData = {
                runningUser: cmp.get('v.runningUser'),
                batchDate: cmp.get('v.batchDate'),
                terminal3TotalCash: cmp.get('v.terminal3TotalCash'),
                terminal13TotalCash: cmp.get('v.terminal13TotalCash'),
                terminal3TotalCoins: cmp.get('v.terminal3TotalCoins'),
                terminal13TotalCoins: cmp.get('v.terminal13TotalCoins'),
                terminal3TotalCheck: cmp.get('v.terminal3TotalReceipts'),
                terminal13TotalCheck: cmp.get('v.terminal13TotalReceipts'),
                tape1Check: cmp.get('v.tape1Check'),
                tape2Check: cmp.get('v.tape2Check'),
                tape3Check: cmp.get('v.tape3Check'),
                tape4Check: cmp.get('v.tape4Check'),
                tape5Check: cmp.get('v.tape5Check'),
                tape6Check: cmp.get('v.tape6Check'),
                gov3TotalCheck: cmp.get('v.gov3TotalCheck'),
                gov13TotalCheck: cmp.get('v.gov13TotalCheck'),
                totalDeposit: cmp.get('v.totalDeposit'),
                totalCash: cmp.get('v.totalCash'),
                totalCoins: cmp.get('v.totalCoins'),
                totalReceipt: cmp.get('v.totalReceipt'),
            },
            action = cmp.get('c.saveAndCreateFile');
        cmp.set('v.showSpinner', true);
        action.setParams({
            data: JSON.stringify(saveData),
            recordTypeId: cmp.get('v.recordTypeId')
        });

        helper.callServerSideAction(action).then(function (response) {
            let navEvt = $A.get('e.force:navigateToSObject'),
                recordId = response.getReturnValue();
            navEvt.setParams({
                recordId: recordId
            });
            navEvt.fire();
            helper.resetAllValues(cmp);
        }).catch(function (response) {

        }).finally(function () {
            cmp.set('v.showSpinner', false);
        });
    },
    handleGenerateReportClicked: function (cmp, event, helper) {
        cmp.set('v.showSpinner', true);
        let action = cmp.get('c.runReport'),
            batchDate = cmp.get('v.batchDate');

        action.setParam('filterDate', batchDate);

        helper.callServerSideAction(action).then(function (response) {
            let result = response.getReturnValue();
            result = JSON.parse(result);
            cmp.set('v.runningUser', result['runningUser']);
            cmp.set('v.batchDate', result['batchDate']);
            cmp.set('v.terminal3TotalCash', result['terminalTotalCash']['Terminal #3'] || 0);
            cmp.set('v.terminal13TotalCash', result['terminalTotalCash']['Terminal #13'] || 0);
            cmp.set('v.terminal3TotalCoins', result['terminalTotalCoins']['Terminal #3'] || 0);
            cmp.set('v.terminal13TotalCoins', result['terminalTotalCoins']['Terminal #13'] || 0);
            cmp.set('v.terminal3TotalCheck', result['terminalTotalCheck']['Terminal #3'] || 0);
            cmp.set('v.terminal13TotalCheck', result['terminalTotalCheck']['Terminal #13'] || 0);
            cmp.set('v.tape1Check', result['terminalTotalCheck']['Terminal #3'] || 0);
            cmp.set('v.tape2Check', result['terminalTotalCheck']['Terminal #13'] || 0);
            helper.calculateTotals(cmp, 'none');
        }).catch(function (response) {
            let res = JSON.stringify(response);
            console.log((JSON.parse(res)));
        }).finally(function () {
            cmp.set('v.showSpinner', false);
        });
    },
    handleValueChanged: function (cmp, event, helper) {
        helper.calculateTotals(cmp, event.getSource().get('v.name') || 'none');
    }
})