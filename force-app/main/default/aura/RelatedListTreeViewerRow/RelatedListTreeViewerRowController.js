({
    init: function (cmp) {
        let data = cmp.get('v.rowData'),
            fields = cmp.get('v.fields'),
            cells = cmp.get('v.cells') || [];

        cmp.set('v.childColspanSize', fields.length);

        for (let i = 0; i < fields.length; i++) {
            let fieldApiName = fields[i]['fieldApiName'];
            let cell = {
                value: data[fieldApiName],
                fieldDef: fields[i]
            };
            cells.push(cell);
        }

        cmp.set('v.cells', cells);
    },
    toggleChildrenVisibility: function (cmp) {
        cmp.set('v.showChildTable', !cmp.get('v.showChildTable'));
    },
    handleRowDataChange: function (cmp) {
        let updatedRows = cmp.get('v.updatedRows') || {},
            rowData = cmp.get('v.rowData');
        if (!rowData || !rowData['Id']) {
            return;
        }
        updatedRows[rowData['Id']] = rowData;
        cmp.set('v.updatedRows', updatedRows);
    },
    handleModeChange: function (cmp) {
        let mode = cmp.get('v.mode');
        cmp.set('v.isInEditMode', mode === 'edit');
    },
    handleMassAction: function (cmp, event, helper) {
        let params = event.getParam('arguments');
        if (params) {
            let {action} = params;
            var childCmp = cmp.find("cRelatedListTreeViewerCell");
            childCmp.forEach(child => {
                child.handleMassAction(action);
            })
            let childTable = cmp.find("child");
            if(childTable){
                childTable.handleMassAction(action);
            }
        }

    }
})