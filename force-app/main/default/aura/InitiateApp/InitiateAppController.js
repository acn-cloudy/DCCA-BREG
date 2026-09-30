({
    doInit: function(component, event, helper) {
        const appId = component.get("v.appId");
        const action = component.get("c.createApplication");
        action.setParams({ appId });
        action.setBackground();
        helper.execute(action);
        helper.confirmNext(component);
    }
})