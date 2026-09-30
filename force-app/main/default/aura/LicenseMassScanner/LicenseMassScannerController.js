({
    init: function (cmp, event, helper) {
        helper.loadMetadataPickListValues(cmp);
    },
    handleLicenseChange: function (cmp, event) {
        let licenses = cmp.get('v.licenses');
        licenses = licenses.replace('\n', ',');

        let licensesSplit = licenses.split(',');

        if (licenses.endsWith(',')) {
            for (let i = 0; i < licensesSplit.length; i++) {
                let lic = licensesSplit[i];
                let licSplit = lic.split('.');

                if (licSplit.length <= 1) {
                    licSplit = lic.split(' ');
                    if (licSplit.length <= 1) {
                        continue;
                    }
                }

                let licNo = licSplit[1].trim();
                licNo = licNo.substr(0, 7);

                let licNo2 = licSplit[1].trim();
                licNo2 = licNo2.substr(7, 10);

                //remove trailing zeroes
                licNo = licNo.replace(/^0+(\d)/, '$1');
                licNo2 = licNo2.replace(/^0+(\d)/, '$1');

                licensesSplit[i] = licSplit[0] + '-' + licNo + '-' + licNo2;
            }
            licenses = licensesSplit.join();
        }
        cmp.set('v.licenses', licenses);
        if (licenses.indexOf('CPA-') >= 0 || licenses.indexOf('PA-') > 0) {
            cmp.set('v.isCpaPa', true);
        } else {
            cmp.set('v.isCpaPa', false);
            cmp.set('v.renewingPermitToPractice', null);
            cmp.set('v.renewByPermitToPractice', null);
        }
    },
    handleRenewingPermitToPracticeChange: function (cmp, event) {
        let val = event.getSource().get('v.value');
        if (val === 'No') {
            cmp.set('v.renewByPermitToPractice', null);
        }
    },
    handleExportClick: function (cmp, event, helper) {
        let scanResult = cmp.get('v.scanResult'),
            successData = scanResult.success || [],
            failedData = scanResult.failed || [];

        let tempData = successData.concat(failedData);
        let downloadData = [];

        tempData.forEach(function (item) {
            let d = {
                'LicenseNumber__c': item['LicenseNumber__c'],
            }

            // if (item['License__r'] && item['License__r']['LicenseeNameFormula__c']) {
            //     d['License.LicenseeNameFormula__c'] = item['License__r']['LicenseeNameFormula__c']
            // } else {
            //     d['License.LicenseeNameFormula__c'] = '';
            // }

            d['License__c'] = item['License__c'];

            d['Status__c'] = item['Status__c'];
            d['Comments__c'] = item['Comments__c'];

            downloadData.push(d);
        });

        helper.downloadCsv({
            data: downloadData,
            filename: 'result.csv'
        });
    },
    handlePrintClick: function (cmp, event, helper) {
        cmp.set('v.showSpinner', true);

        let action = cmp.get('c.printResult'),
            scanResult = cmp.get('v.scanResult');

        action.setParam('scanResult', JSON.stringify(scanResult));

        helper.callServerSideAction(action).then(function (response) {
            let urlEvent = $A.get('e.force:navigateToURL'),
                downloadUrl = response.getReturnValue();
            urlEvent.setParams({
                url: downloadUrl
            });
            urlEvent.fire();
            cmp.set('v.showSpinner', false);
        }).catch(function (response) {
            let error = response.getError(),
                errMsg = error[0].message || 'Something went wrong. Please contact your administrator.';
            helper.showErrorToast('Failed!', errMsg);
            cmp.set('v.showSpinner', false);
        });
    },
    handleSubmitClick: function (cmp, event, helper) {
        if (!helper.checkFieldsValidity(cmp)) return;

        cmp.set('v.showSpinner', true);

        let licenses = cmp.get('v.licenses') || '';
        licenses = licenses.split(',');

        let scanMode = cmp.get('v.mode');
        let scan = (scanMode === 'Create') ? cmp.get('c.scanCreate') : cmp.get('c.scanRenewalUpdate'),
            receivedDate = cmp.get('v.receivedDate'),
            status = cmp.get('v.status'),
            type = cmp.get('v.type'),
            renewingPermitToPractice = cmp.get('v.renewingPermitToPractice'),
            renewByPermitToPractice = cmp.get('v.renewByPermitToPractice'),
            renewInactive = cmp.get('v.isActive');
        scan.setParam('licenseNumbers', licenses);
        scan.setParam('receivedDate', receivedDate);
        scan.setParam('status', status);
        scan.setParam('renewInactive', renewInactive);
        scan.setParam('renewingPermitToPractice', renewingPermitToPractice);
        scan.setParam('renewByPermitToPractice', renewByPermitToPractice);
        scan.setParam('type', type);

        helper.callServerSideAction(scan).then(function (response) {
            let res = response.getReturnValue();
            cmp.set('v.scanResult', res);

            if (res.success) {
                cmp.set('v.successCount', res.success.length);
            }

            if (res.failed) {
                cmp.set('v.failCount', res.failed.length);
            }

            cmp.set('v.showSpinner', false);
            cmp.set('v.screen', 'result');
        }).catch(function (response) {
            let error = response.getError(),
                errMsg = error[0].message || 'Something went wrong. Please contact your administrator.';
            helper.showErrorToast('Failed!', errMsg);
            cmp.set('v.showSpinner', false);
        });
    },
    handleSaveClick: function (cmp, event, helper) {
        cmp.set('v.showSpinner', true);

        let save = cmp.get('c.commitScanResult'),
            scanResult = cmp.get('v.scanResult');

        /*if ((scanResult.failed && scanResult.failed.length > 0) || !scanResult.failed) {
            helper.showErrorToast('Failed!', 'Can not Submit Renewal Application Updates if there are Fails.');
            cmp.set('v.showSpinner', false);
            return false;
        }*/

        save.setParam('scanResult', JSON.stringify(scanResult));
        helper.callServerSideAction(save).then(function () {
            let toast = helper._newToast({
                title: 'Done.',
                type: "success",
                message: 'The licenses are now being processed.'
            });
            toast.fire();
            helper.resetForm(cmp);
            cmp.set('v.showSpinner', false);
        }).catch(function (response) {
            let error = response.getError(),
                errMsg = error[0].message || 'Something went wrong. Please contact your administrator.';

            if (error[0]['fieldErrors']) {
                let fieldErrors = error[0]['fieldErrors'];
                for (let property in fieldErrors) {
                    if (fieldErrors.hasOwnProperty(property)) {
                        if (fieldErrors[property][0].message) {
                            errMsg = fieldErrors[property][0].message;
                            break;
                        }
                    }
                }
            }

            helper.showErrorToast('Failed!', errMsg);
            cmp.set('v.showSpinner', false);
        });
    },
    handleBackClick: function (cmp) {
        cmp.set('v.screen', 'scan');
    },
    handleClearClick: function (cmp, event, helper) {
        helper.resetForm(cmp);
    }
})