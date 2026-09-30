({
    loadMetadataPickListValues: function (cmp) {
        cmp.set('v.showSpinner', true);
        let getPickListEntries = cmp.get('c.getPickListEntries'), _self = this;

        let errorHandler = function (response) {
            let error = response.getError(),
                errMsg = error[0].message || 'Something went wrong. Please contact your administrator.';
            _self.showErrorToast('Failed!', errMsg);
            cmp.set('v.showSpinner', false);
        };

        _self.callServerSideAction(getPickListEntries).then(function (response) {
            let retVal = response.getReturnValue();
            cmp.set('v.statusOptions', retVal['Status__c']);
            cmp.set('v.typeOptions', retVal['Type__c']);
            cmp.set('v.renewingPermitToPracticeOptions', retVal['RenewingPermitToPractice__c']);
            cmp.set('v.renewByPermitToPracticeOptions', retVal['RenewByPermitToPractice__c']);
        }).catch(errorHandler).finally(function () {
            cmp.set('v.showSpinner', false);
        });
    },
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
    checkFieldsValidity: function (cmp) {
        let licenses = cmp.find('inputRequired'), fieldsValid = true;

        licenses.forEach((item) => {
            if (!item.checkValidity()) {
                item.showHelpMessageIfInvalid();
                fieldsValid = false;
            }
        });

        return fieldsValid;
    },
    resetForm: function (cmp) {
        cmp.set('v.licenses', null);
        cmp.set('v.type', null);
        cmp.set('v.renewByPermitToPractice', null);
        cmp.set('v.renewingPermitToPractice', null);
        cmp.set('v.receivedDate', null);
        cmp.set('v.status', null);
        cmp.set('v.isActive', false);
        cmp.set('v.scanResult', null);
        cmp.set('v.screen', 'scan');
        cmp.set('v.isCpaPa', false);
    },
    showErrorToast: function (title, message) {
        let toast = this._newToast({
            title: title,
            message: message,
            type: 'error'
        });
        toast.fire();
    },
    showSuccessToast: function (title, message) {
        let toast = this._newToast({
            title: title,
            message: message,
            type: 'success'
        });
        toast.fire();
    },
    _newToast: function (options) {
        let toastEvent = $A.get('e.force:showToast');
        toastEvent.setParams(options);
        return toastEvent;
    },
    convertArrayOfObjectsToCSV: function (args) {
        let result, ctr, keys, columnDelimiter, lineDelimiter, data;

        data = args.data || null;
        if (data == null || !data.length) {
            return null;
        }

        columnDelimiter = args.columnDelimiter || ',';
        lineDelimiter = args.lineDelimiter || '\n';

        keys = Object.keys(data[0]);

        result = '';
        result += keys.join(columnDelimiter);
        result += lineDelimiter;

        data.forEach(function (item) {
            ctr = 0;
            keys.forEach(function (key) {
                if (ctr > 0) result += columnDelimiter;

                result += item[key];
                ctr++;
            });
            result += lineDelimiter;
        });

        return result;

    },
    downloadCsv: function downloadCSV(args) {
        let data, filename, link;
        let csv = this.convertArrayOfObjectsToCSV({data: args.data});

        if (csv == null) return;

        filename = args.filename || 'export.csv';

        if (!csv.match(/^data:text\/csv/i)) {
            csv = 'data:text/csv;charset=utf-8,' + csv;
        }
        data = encodeURI(csv);

        link = document.createElement('a');
        link.setAttribute('href', data);
        link.setAttribute('download', filename);
        link.click();
    }
})