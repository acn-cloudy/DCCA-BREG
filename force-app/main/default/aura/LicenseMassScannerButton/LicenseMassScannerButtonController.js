({
    navigateToUrl: function (component, event, helper) {
        let urlEvent = $A.get('e.force:navigateToURL');
        urlEvent.setParams({
            url: component.get('v.url')
        });
        urlEvent.fire();
    }
})