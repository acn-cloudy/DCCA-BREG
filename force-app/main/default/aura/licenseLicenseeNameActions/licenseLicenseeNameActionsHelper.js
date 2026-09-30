({
    launchFlow : function(options) {
        const overlay = options.component.find('overlayLib');
        const inputs = [
            {
                name: 'recordId',
                type: 'String',
                value: options.component.get('v.recordId')
            },
            {
                name: 'historyOnly',
                type: 'Boolean',
                value: options.historyOnly
            }
        ];
        $A.createComponent('c:flow', {
            inputs,
            flowName: 'LicenseName_Create_New_Flows'
        }, function(component, status){
            overlay.showCustomModal({
                header: options.header,
                body: component,
                showCloseButton: true
            })
        })
        
    }
})