({
	initComp : function(component, event, helper) {
        
		let fieldInfo = component.get("v.fieldInfo");
        let picklistValues = fieldInfo.PicklistValues__c ;
        
        if(picklistValues) {
            
            let options = [];
            
            picklistValues.split(";").forEach( function(value) {
                
                options.push(value.trim());
                
            });
            
        	component.set("v.options", options);
            
        }
        
                
        var value = component.get("v.value");
        if(value === undefined){
                return;
            }
        var valueItems = value.split(";");
        var valueObj = {};
        valueItems.forEach(function(item){
            valueObj[item] = true;
        });
        var multiCheckboxes = component.find("multiCheck");
        if(!multiCheckboxes.length ){
            multiCheckboxes = [component.find("multiCheck")];
        }

		multiCheckboxes.forEach(function(multiCheck){
            if(valueObj[multiCheck.get("v.text")] === true){
                multiCheck.set("v.value", true);
            }
        });
                
        console.log("fieldInfo", fieldInfo);
	},
 	handleChange: function (component, event) {
        var changeValue = event.getParam("value");
        var multiCheckboxes = component.find("multiCheck");
        var values = "";
        if(!multiCheckboxes.length ){
            multiCheckboxes = [component.find("multiCheck")];
        }
        multiCheckboxes.forEach(function(multiCheck){
            if(multiCheck.get("v.value")){
                values= multiCheck.get("v.text") + ";" + values;
            }
        });
        component.set("v.value", values);
    	console.log(changeValue);
        console.log(component.get("v.value"));
    }
})