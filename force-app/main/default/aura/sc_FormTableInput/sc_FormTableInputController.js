({
    doInit: function(component, event, helper) {
        helper.initiateColumns(component);
        helper.initiateSections(component);
    },
	newRow: function(component, event, helper) {
        var rows = component.get("v.rows");
        var timeInMs = Date.now();
        component.set("v.currentIndex", null);
        component.find("card").set("v.valueMap", {});
        component.find("card").refresh();
        component.set("v.modalHidden",false);
    },
    handleSelect: function(component, event, helper ) {
        var selectedMenuItemValue = event.getParam("value");
        console.log("selectedMenuItemValue", selectedMenuItemValue);
        var index = selectedMenuItemValue.split(":")[0];
        var action = selectedMenuItemValue.split(":")[1];
        var rows = component.get("v.rows");
        index = parseInt(index);
        if(action === "Remove" ) {
			rows.splice(index, 1);
            component.set("v.rows", rows);
        } else if (action === "Edit") {
            var record = rows[index];
            var valueMap = Object.keys(record).reduce(function(result, item ) {
				result["record."+ item] = record[item];
                return result;
            }, {});
            component.find("card").set("v.valueMap", valueMap);
            component.find("card").refresh();
            component.set("v.currentIndex", index);
            component.set("v.modalHidden",false);
        }
        helper.updateValue(component);
    },
    addRow: function(component, event, helper) {
        const card = component.find("card");
        const currentIndex = component.get("v.currentIndex");
        const sobjectType = component.get("v.sobjectType");
        if(card.validateFields()){
            const result = card.convertToRecord();
            const value = result.record;
            value["attributes"] = {"type":sobjectType};
            let rows = component.get("v.rows")|| [];
            if(currentIndex !== null) {
                rows[currentIndex] = value;
            } else {
            	rows.push(value);    
            }
            component.set("v.rows", rows);
	        helper.updateValue(component);
            component.set("v.modalHidden",true);
        } 
        
    },
    cancelmodal: function(component, event) {
        component.set("v.modalHidden",true);
        
    }
    
    
})