({
    initData: function (cmp) {
        let self = this,
            action = cmp.get('c.getChild1Columns'),
            child1Rel = cmp.get('v.childRelationship1ApiName'),
            child2Rel = cmp.get('v.childRelationship2ApiName');

        this.showSpinner(cmp);

        let params = {
            parentId: cmp.get('v.recordId'),
            childRel1: child1Rel,
            childRel2: child2Rel,
            fields: cmp.get('v.child1Columns'),
            editableFields: cmp.get('v.child1EditableColumns')
        };

        action.setParams(params);
        self.callServerSideAction(action).then(function (response) {
            let data = response.getReturnValue();
            cmp.set('v.gridColumns', data);
            self.hideSpinner(cmp);
            self.getData(cmp);
        }).catch(function (response) {
            self.hideSpinner(cmp);
            let error = response.getError();
            console.log(error);
        });
    },
    getData: function (cmp) {
        let action = cmp.get('c.getData'),
            self = this,
            data = cmp.get('v.data'),
            child1Rel = cmp.get('v.childRelationship1ApiName'),
            child2Rel = cmp.get('v.childRelationship2ApiName'),
            child1RelSortField = cmp.get('v.child1SortFieldApiName'),
            child1RelSortDirection = cmp.get('v.child1SortDirection'),
            child1RelAdditionalSort = cmp.get('v.child1AdditionalOrderByStatement'),
            child1RecordLimit = cmp.get('v.child1RecordLimit'),
            child2RelSortField = cmp.get('v.child2SortFieldApiName'),
            child2RelSortDirection = cmp.get('v.child2SortDirection');

        self.showSpinner(cmp);

        if (data) {
            self.hideSpinner(cmp);
            return;
        }


        let childRelApiName = cmp.get('v.childRelationship1ApiName');
        let origChild1RecordLimit = child1RecordLimit;
        child1RecordLimit = (childRelApiName === 'AssociatedEmployee__r' || childRelApiName === 'AssociatedEntities__r') ? 0 : child1RecordLimit;
        let params = {
            parentId: cmp.get('v.recordId'),
            childRel1: child1Rel,
            childRel2: child2Rel,
            childRel1SortField: child1RelSortField || '',
            childRel1SortDirection: child1RelSortDirection,
            child1RelAdditionalSort: child1RelAdditionalSort || '',
            child1RecordLimit: child1RecordLimit,
            childRel2SortField: child2RelSortField || '',
            childRel2SortDirection: child2RelSortDirection
        };

        action.setParams(params);
        this.callServerSideAction(action).then(function (response) {
            let data = response.getReturnValue();
            if(data && (childRelApiName === 'AssociatedEmployee__r' || childRelApiName === 'AssociatedEntities__r')){
                let erbPrincipalData = [];
                let eprincipalData = [];
                let enonPrincipalData = [];

                let rbPrincipalData = [];
                let principalData = [];
                let nonPrincipalData = [];
                data.forEach(datum => {
                    if(datum.hasOwnProperty('EmploymentStatus__c') && datum.EmploymentStatus__c == 'Employed'){                        
                        if(datum.hasOwnProperty('Position__c') && datum.Position__c == 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)'){
                            erbPrincipalData.push(datum);
                        } else if(datum.hasOwnProperty('PositionStatus__c') && datum.PositionStatus__c == 'P - PRINCIPAL') {
                            eprincipalData.push(datum);
                        } else {
                            enonPrincipalData.push(datum);
                        }
                    } else {                        
                        if(datum.hasOwnProperty('Position__c') && datum.Position__c == 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)'){
                            rbPrincipalData.push(datum);
                        } else if(datum.hasOwnProperty('PositionStatus__c') && datum.PositionStatus__c == 'P - PRINCIPAL') {
                            principalData.push(datum);
                        } else {
                            nonPrincipalData.push(datum);
                        }
                    }
                });

                data = erbPrincipalData.concat(eprincipalData, enonPrincipalData, rbPrincipalData, principalData, nonPrincipalData);
                data = data.slice(0, origChild1RecordLimit);
            }

            for (let i = 0; i < data.length; i++) {
                if (data[i][child2Rel] && data[i][child2Rel].length > 0) {
                    data[i]['_children'] = data[i][child2Rel];
                }
            }
            cmp.set('v.dataBeforeUpdate', JSON.parse(JSON.stringify(data)));
            cmp.set('v.data', data);
            self.hideSpinner(cmp);
        }).catch(function (response) {
            self.hideSpinner(cmp);
            let error = response.getError();
            console.log(error);
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
    showSpinner: function (cmp) {
        cmp.set('v.showSpinner', true);
    },
    hideSpinner: function (cmp) {
        cmp.set('v.showSpinner', false);
    },
    showSuccessToast: function (title, message) {
        let toast = this._newToast({
            title: title,
            message: message,
            type: 'success'
        });
        toast.fire();
    },
    showErrorToast: function (title, message) {
        let toast = this._newToast({
            title: title,
            message: message,
            type: 'error'
        });
        toast.fire();
    },
    autoSave: function (cmp, rows) {
        cmp.set('v.isSaving', true);
        let updateChildAction = cmp.get('c.saveUpdate');
        let _self = this;
        updateChildAction.setParam('sObjects', rows);

        let errorHandler = function (response) {
            let error = response.getError();
            let errMsg = error[0].message || 'Something went wrong. Please contact your administrator.';

            if (error[0]['pageErrors'] && error[0]['pageErrors'][0].message) {
                errMsg = error[0]['pageErrors'][0].message;
            }

            _self.showErrorToast('Failed!', errMsg);
            cmp.set('v.isSaving', false);
        };

        _self.callServerSideAction(updateChildAction).then(function (response) {
            cmp.set('v.isSaving', false);
        }).catch(errorHandler);
    },
    collapseRows: function (cmp) {
        let rows = cmp.find('row');
        for (let i = 0; i < rows.length; i++) {
            rows[i].set('v.mode', 'read');
            rows[i].set('v.showChildTable', false);
            let subChild = rows[i].find('child');
            if (subChild) {
                let subChildRows = subChild.find('row');
                for (let j = 0; j < subChildRows.length; j++) {
                    subChildRows[j].set('v.mode', 'read');
                }
            }
        }
    },
    expandUnfilteredRows: function (cmp) {
        let rows = cmp.find('row');
        const filteredOutString = '_isFilteredOut'
        console.log(rows);
        if(rows){
            for (let i = 0; i < rows.length; i++) {
                if(!rows[i]._isFilteredOut){
                    rows[i].set('v.mode', 'edit');
                    const rowData = rows[i].get('v.rowData');
                    console.log(rowData);
                    const children = rowData._children;
                    if(children){
                        if(children.find(child => child[filteredOutString]!=true)){
                            rows[i].set('v.showChildTable', true);
                        };
                        let subChild = rows[i].find('child');
                        if (subChild) {
                            let subChildRows = subChild.find('row');
                            if(subChildRows){
                                for (let j = 0; j < subChildRows.length; j++) {
                                    subChildRows[j].set('v.mode', 'edit');
                                }
                            }
                            
                        }  
                    } 
                }
            }
        }
    },
    _newToast: function (options) {
        let toastEvent = $A.get('e.force:showToast');
        toastEvent.setParams(options);
        return toastEvent;
    },
    openConfirmMass: function(cmp, event) {
        this.LightningConfirm.open({
            message: 'Are you sure you want to Mark All as Not Deficient?',
            theme: 'default',
            label: 'Please Confirm',
            variant: 'headerless'
        }).then(function(result) {
            if(result){
                var action = cmp.get('c.handleMassAction');
                $A.getCallback(function() {
                    $A.enqueueAction(action);
               })();
            }
        });
    }
})