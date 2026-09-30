({
    clearValue: function(component, event, helper) {
		component.set("v.initiate", false)
        component.set("v.values", "");        
    },
    doInit : function(component, event, helper) {
        var initiateOnce = component.get("v.initiate");
        if(!initiateOnce ){
            var value = component.get("v.value");
            var options = component.get("v.options");
            options.forEach( function(option) {
                if(option.selected ){
                    option.selected = false;
                }
            });
            if(value && value.length > 0){
                var selectedValues =  value.split(";");           
                var valueSet = new Set();
                selectedValues.forEach(function(selectedValue) {
                    valueSet.add(selectedValue);
                });
                options.forEach( function(option) {
                    if(valueSet.has(option.value)){
                        option.selected = true;
                    }else {
                        option.selected = false;
                    }
                });
                component.set("v.selectedValues", selectedValues);               
            }
            component.set("v.options", options);
            component.set("v.initiate", false);
        } 
    },
	toggleSelections : function(component, event, helper) {
		var selections = component.find("selections");
        $A.util.toggleClass(selections, "slds-is-open");
	},
    updateValue :  function(component, event, helper) {
        var selectedValues = component.get("v.selectedValues");
        var value = "";
        selectedValues.forEach( function(option) {
            if(value === ""){
            	value = option;
            } else {
                value =value + ";" + option;                       
            }
        });        
        component.set("v.value", value);
        $A.enqueueAction(component.get("v.change"));
    },
    closeSelections :  function(component, event, helper) {        
        if(!component.get("v.escape")){
        	var selections = component.find("selections");
	        $A.util.removeClass(selections, "slds-is-open");
        } else {
            component.set("v.escape", false);
        }
        
	},
    select :  function(component, event, helper) {
        component.set("v.escape", true);
		var index = event.currentTarget.tabIndex;
        var options = component.get("v.options");
        options[index].selected = !options[index].selected;
        component.set("v.options", options);
        helper.updatSelectedValues(component);
	},
    removeItem : function(component, event, helper) {
        var index = event.currentTarget.tabIndex;
        var options = component.get("v.options");
        var selectedValues = component.get("v.selectedValues");
        var selectedValue = selectedValues[index];
        options.forEach( function(option) {
            if(option.value === selectedValue) {
            	option.selected = false;
        	}
        });
        component.set("v.options", options);
        helper.updatSelectedValues(component);
    }
})