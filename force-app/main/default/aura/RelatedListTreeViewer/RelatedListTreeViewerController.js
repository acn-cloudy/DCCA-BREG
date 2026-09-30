({
    init: function (cmp, event, helper) {
        let getObjectNameAction = cmp.get('c.getIdObjectName');
        getObjectNameAction.setParam('recordId', cmp.get('v.recordId'));

        helper.callServerSideAction(getObjectNameAction).then(function (response) {
            //@See Case 00007690 - limit child records to 20
            let ret = response.getReturnValue(),
                child1RelApiName = cmp.get('v.childRelationship1ApiName'),
                isParentLicenseAndChildLicense = ret === 'License__c' && (child1RelApiName === 'AssociatedEmployee__r' || child1RelApiName === 'AssociatedEntities__r');
            cmp.set('v.isParentLicenseAndChildLicense', isParentLicenseAndChildLicense);
            if (isParentLicenseAndChildLicense) {
                cmp.set('v.child1RecordLimit', 20);
            }
        }).catch(function (response) {
            let error = response.getError();
            console.log(error);
        }).finally(function () {
            helper.initData(cmp);
        });

        let allowNew = cmp.get('v.allowNew');
        if (allowNew) {
            let action = cmp.get('c.getChild1ObjectNameForNewRecord');
            action.setParams({
                parentId: cmp.get('v.recordId'),
                childRel1: cmp.get('v.childRelationship1ApiName')
            });

            helper.callServerSideAction(action).then(function (response) {
                cmp.set('v.createNewDef', response.getReturnValue());
            }).catch(function (response) {
                let error = response.getError();
                console.log(error);
            });
        }
        let filtersEnabled = cmp.get('v.filtersEnabled');
        if(filtersEnabled){
            let filterDef = JSON.parse(cmp.get('v.filtersJSONString'));
            const activeFilterCount = filterDef.filters.filter(filter => filter.active).length;
            filterDef.activeCount = activeFilterCount;
            cmp.set('v.filtersDef', filterDef);
        }
        let massUpdateEnabled = cmp.get('v.massUpdateEnabled');
        if(massUpdateEnabled){
            let massUpdateDef = JSON.parse(cmp.get('v.massUpdateJSONString'));
            cmp.set('v.massUpdateDef', massUpdateDef);
        }
        
    },
    setSubtitleVisibility: function (cmp, event, helper) {
        let recordId = cmp.get('v.recordId');
        if (cmp.get('v.isParentLicenseAndChildLicense')) {
            cmp.set('v.showSubTitleForAllLicensesLink', true);
            cmp.set('v.allLicenseReportFilter', event.getParams()['records'][recordId].fields.Name.value);
        }
    },
    handleCancelClick: function (cmp, event, helper) {
        helper.collapseRows(cmp);
    },
    toggleFiltering: function (cmp, event, helper) {
        cmp.set('v.onlyShowDeficient', !cmp.get('v.onlyShowDeficient'));
        console.log(cmp.get('v.data'));
    },
    // currently only set up to work with single filter
    handleFilterChange: function (cmp, event, helper) {
        const filteredOutString = '_isFilteredOut'
        const filtersDef = cmp.get('v.filtersDef');
        const filters = filtersDef.filters;
        const filterId = event.target.closest('[data-filterid]').dataset.filterid;
        const filterCmp = cmp.find('filter');
        const filter = filters.find(filter => filter.id===filterId);
        const {type:filterType, field:filterField, value:filterValue, filterChildren} = filter;
        if(filterType=='toggle'){
            const currentFilterValue = filterCmp.get('v.checked');
            filter.active=currentFilterValue;
            const data = cmp.get('v.data');
            data.forEach(record => {
                if(record[filterField]!=filterValue && currentFilterValue){
                    record[filteredOutString] = true
                } else {
                    record[filteredOutString] = false
                }
                if(filterChildren){
                    const children = record._children;
                    children && children.forEach(child => {
                        if(child[filterField]!=filterValue && currentFilterValue){
                            child[filteredOutString] = true
                        } else {
                            child[filteredOutString] = false
                        }
                    })
                }
            })
            cmp.set('v.skipAutoSave', true);
            cmp.set('v.data',data);
            cmp.set('v.skipAutoSave', false);
            if(filter.active){
                helper.expandUnfilteredRows(cmp);
            }
        }
        const activeFilterCount = filters.filter(filter => filter.active).length;
        filtersDef.activeCount = activeFilterCount;
        cmp.set('v.filtersDef', filtersDef);
    },
    handleMassAction: function (cmp, event, helper) {
        let action;
        if(event && event.getParam('arguments') && event.getParam('arguments').action){
            action = event.getParam('arguments').action;
        } else {
            const massUpdateDef = cmp.get('v.massUpdateDef');
            const actions = massUpdateDef.actions;
            const actionId = cmp.get('v.massUpdateSelectedId');
            action = actions.find(action => action.id==actionId);
        }
        
        let data = cmp.get('v.data');
        let fields = action.fields;
        if(fields.length>0){
            // updates record
            fields.forEach(field => {
                let {field:fieldApi, value:setValue} = field;
                for(let i=0;i<data.length;i++){
                    let record = data[i];
                    if(record[fieldApi] != setValue){
                        let compVariable = 'v.data['+i+'].' + fieldApi;
                        cmp.set(compVariable, setValue);
                    }
                }
            })
            // updates ui
            let childCmp = cmp.find("row");
            if(childCmp.length>0){
                childCmp.forEach(child => {
                    child.handleMassAction(action);
                })
            }
        }
    },
    openConfirm: function (cmp, event, helper) {
        const actionId = event.target.closest('[data-massactionid]').dataset.massactionid;
        cmp.set('v.massUpdateSelectedId', actionId);
        helper.openConfirmMass(cmp, event);
    },
    autoSaveChild1: function (cmp, event, helper) {
        if(cmp.get('v.skipAutoSave')) return;
        let updatedChild1Rows = cmp.get('v.updatedChild1Rows');

        if (!updatedChild1Rows) return;

        let updatedChild1RowsList = [];
        for (let rowId in updatedChild1Rows) {
            updatedChild1RowsList.push(updatedChild1Rows[rowId]);
        }
        cmp.set('v.updatedChild1Rows', null);
        helper.autoSave(cmp, updatedChild1RowsList);
    },
    autoSaveChild2: function (cmp, event, helper) {
        if(cmp.get('v.skipAutoSave')) return;
        let updatedChild2Rows = cmp.get('v.updatedChild2Rows');

        if (!updatedChild2Rows) return;

        let updatedChild2RowsList = [];

        for (let rowId in updatedChild2Rows) {
            updatedChild2RowsList.push(updatedChild2Rows[rowId]);
        }
        cmp.set('v.updatedChild2Rows', null);
        helper.autoSave(cmp, updatedChild2RowsList);
    },
    handleEscape: function (cmp, event, helper) {
        if ((event.key && event.key === 27) ||
            (event.keyCode && event.keyCode === 27)) {
            helper.collapseRows(cmp);
        }
    },
    handleNewClicked: function (cmp) {
        let fields = cmp.get('v.createNewDefFields');
        let fieldsSplit = fields.split(',');
        let createNewDef = cmp.get('v.createNewDef');
        let cmpToCreate = [
            [
                'lightning:recordEditForm',
                {
                    objectApiName: 'AssociatedLicense__c',
                    onsuccess: cmp.getReference('c.handleNewSuccess')
                }
            ],
            ['lightning:button', {label: 'Save', onclick: cmp.getReference('c.handleNewSave'), variant: 'brand'}],
            ['lightning:button', {label: 'Cancel', onclick: cmp.getReference('c.handleNewCancel')}]
        ];

        for (let i = 0; i < fieldsSplit.length; i++) {
            let fieldCmp = [
                'lightning:inputField', {
                    fieldName: fieldsSplit[i]
                }
            ];

            if (createNewDef.lookupFieldApiName === fieldsSplit[i]) {
                fieldCmp[1].value = cmp.get('v.recordId');
            }

            cmpToCreate.push(fieldCmp);
        }

        cmpToCreate.push();

        $A.createComponents(cmpToCreate, function (cmps, status, errorMessage) {
            if (status === 'SUCCESS') {
                let recordEditForm = cmps[0],
                    recordEditFormBody = [];

                cmp.set('v.createNewCmp', recordEditForm);

                for (let i = 3; i < cmps.length; i++) {
                    recordEditFormBody.push(cmps[i]);
                }

                recordEditForm.set('v.body', recordEditFormBody);
                cmp.find('overlayLib').showCustomModal({
                    header: 'New',
                    body: [recordEditForm],
                    footer: [cmps[1], cmps[2]],
                    showCloseButton: true
                }).then(function (overlayLib) {
                    cmp.set('v.overlayLib', overlayLib);
                });
            }
        });
    },
    handleNewSuccess: function (cmp, event, helper) {
        cmp.find('overlayLib').notifyClose();
        cmp.get('v.overlayLib').close();
        cmp.set('v.data', null);
        helper.getData(cmp);
        /* this logic will not reload the table data, but no sorting can be improve for later use
        let response = event.getParams()['response'],
            fields = response['fields'],
            columns = cmp.get('v.gridColumns'),
            data = cmp.get('v.data'),
            newData = {
                Id: response['id']
            };

        for (let i = 0; i < columns.length; i++) {
            let fieldApiName = columns[i]['fieldApiName'];
            newData[fieldApiName] = fields[fieldApiName].value;
        }

        data.unshift(newData);
        cmp.set('v.data', data);
        */
    },
    handleNewSave: function (cmp) {
        let form = cmp.get('v.createNewCmp');
        let overLayLibInstance = cmp.get('v.overlayLib').instance;
        let overLayLibBody = overLayLibInstance.get('v.body');
        $A.createComponent('lightning:spinner', {}, function (spinner, status) {
            $A.util.toggleClass(spinner, 'slds-spinner_container');
            overLayLibBody.push(spinner);
            overLayLibInstance.set('v.body', overLayLibBody);
            form.submit();
        });

    },
    handleNewCancel: function (cmp) {
        cmp.find('overlayLib').notifyClose();
        cmp.get('v.overlayLib').close();
    },
    handleReplaceEmployeeClicked: function (cmp, event, helper) {
        $A.createComponent(
            "lightning:flow",
            {
                "aura:id": "flowData"
            },
            function(flowCmp, status, errorMessage){
                if (status === "SUCCESS") {
                    cmp.find('overlayLib').showCustomModal({
                        header: 'Replace Employee',
                        body: flowCmp,
                        showCloseButton: true,
                        closeCallback: function(){                            
                            // helper.getData(cmp);
                        }
                    }).then(function (overlayLib) {
                        cmp.set('v.overlayLib', overlayLib);
                        flowCmp.startFlow("Associated_License_Change_Employee", [
                            { 
                                name : "recordId", 
                                type : "SObject", 
                                value: {
                                    "Id" : cmp.get("v.recordId")
                                }
                            }
                        ]);
                    });
                }
            }
        );
    },
    handleReplaceEntityClicked: function (cmp, event, helper) {
        $A.createComponent(
            "lightning:flow",
            {
                "aura:id": "flowData"
            },
            function(flowCmp, status, errorMessage){
                if (status === "SUCCESS") {
                    cmp.find('overlayLib').showCustomModal({
                        header: 'Replace Employer',
                        body: flowCmp,
                        showCloseButton: true,
                        closeCallback: function(){                            
                            // helper.getData(cmp);
                        }
                    }).then(function (overlayLib) {
                        cmp.set('v.overlayLib', overlayLib);
                        flowCmp.startFlow("Associated_License_Change_Employment_Button", [
                            { 
                                name : "recordId", 
                                type : "SObject", 
                                value: {
                                    "Id" : cmp.get("v.recordId")
                                }
                            }
                        ]);
                    });
                }
            }
        );
    }
})