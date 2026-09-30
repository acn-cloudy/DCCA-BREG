({
    doInit : function(component, event, helper) {
        component.find('flowData').startFlow(component.get('v.flowName'), component.get('v.inputs'));
    },
    statusChange : function(component, event, helper) {
        if(event.getParam('status') === 'FINISHED'){
            $A.get("e.force:refreshView").fire();
            component.find('overlayLib').notifyClose();
        }
    }
})