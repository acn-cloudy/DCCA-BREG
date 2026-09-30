({
    doHistoryNameOnly : function(component, event, helper) {
        helper.launchFlow(
            {
                component, 
                historyOnly: true,
                header: 'History Trade/Professional Name Only'
            });
    },

    doNew : function(component, event, helper) {
        helper.launchFlow(
            {
                component, 
                historyOnly: false,
                header: 'New'
            });
    },
})