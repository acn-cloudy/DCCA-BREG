({
	itemSelected : function(component, event, helper) {
		helper.itemSelected(component, event, helper);
        helper.updateValue(component);
	}, 
    serverCall :  function(component, event, helper) {
		helper.serverCall(component, event, helper);
	},
    clearSelection : function(component, event, helper){
        helper.clearSelection(component, event, helper);
        helper.updateValue(component);
    } 
})