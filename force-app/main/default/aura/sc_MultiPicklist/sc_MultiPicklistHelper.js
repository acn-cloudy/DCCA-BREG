({
	updatSelectedValues : function(component) {
        var options = component.get("v.options");
        var selectedValues = [];
        options.forEach(function(option) {
            if(option.selected) {
	            selectedValues.push(option.value);
        	}
        });
        component.set("v.selectedValues", selectedValues);
	}
})