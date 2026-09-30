({
    retrieveJSONSetting : function(component) {
        var name = component.get("v.cardName");
        var action = component.get("c.getCardJsonByName");
        action.setParams ({'name': name});
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.sections", JSON.parse(response.getReturnValue()));
            }else if (state === "ERROR") {
                var errors = response.getError();
                console.log("Error message: ", errors[0].message);
            }
        });
        $A.enqueueAction(action);
    },
    destroySections : function(component) {
        if(component.find("sections")){
            component.find("sections").destroy();
        }
    },
    refreshBody : function(component, helper) {        
        // Destroy sections;
        // this.destroySections(component);
        // Used to translate error Map into different format 
        // which will be accessble by fieldinput component
        this.convertErrors(component);
        var secComp = component.find("sections");
        helper.fillInParams(component, secComp);
        
    },
    fillInParams : function (component, secComp) {
        if (secComp && secComp.isValid()) {
            var errorMap = component.get("v.errorMap");
            var valueMap = component.get("v.valueMap");
            var fields = secComp.find("fieldInput") || [];
            var cacheData = component.get("v.cacheData");
            secComp = secComp[0] || secComp;
            this.updateDependentValues(component, secComp);
            fields.forEach(function(field) {
                var apiName = field.get("v.apiName");
                if(cacheData && cacheData[apiName]){
                    field.set("v.options", cacheData[apiName]);
                }
                if(apiName !== "" ) {
                    var value = valueMap[apiName];
                    value = value || "";
                    field.set("v.value", value);
                    var fieldCMP = field.find("field");
                    if(fieldCMP){
                        if(errorMap) {
                            var names = apiName.split(".");
                            var pureApiName = names[1];
                            var errorMessages = errorMap[pureApiName];
                            if(errorMessages) {
                                fieldCMP.set("v.errors", errorMessages);
                            } else {
                                fieldCMP.set("v.errors", null);
                            }
                        } else {
                            fieldCMP.set("v.errors", null);
                        }
                    }
                }
            });
            
            //component.set("v.cardBody", secComp); 
        }
    },
    updateValues : function(component, event) {
        var type = event.getParams().type;        
        var valueMap = component.get("v.valueMap");
        valueMap = valueMap || {"dummyValue":"value"};
        if(valueMap === "{}") {
            valueMap = {};
        }
        var isChanged = false;
        if(type === "fieldValueUpdate"){
            var fieldComp = event.getParams().payload.fieldComp;
            var apiName = fieldComp.get("v.apiName");
            var value = fieldComp.get("v.value");
            var fields = component.find("sections").find("field");
            if( Object.prototype.toString.call( fields ) !== '[object Array]' ) {
                fields = [fields];
            }
            fields.forEach( function(field){ 
            
            if(field.get("v.showCondition") && field.get("v.showCondition")[apiName]) {
                
                if(field.get("v.showCondition")[apiName] ===  value) {
                    field.set("v.hidden", false);
                    var fieldInput = field.get("v.body")[0];
                    fieldInput.set("v.hidden", false);
                } else {
                    field.set("v.hidden", true);
                    var fieldInput = field.get("v.body")[0];
                    fieldInput.set("v.hidden", true);
                    fieldInput.set("v.value", null);
                    var dAPIName = fieldInput.get("v.apiName");
                    valueMap[dAPIName] = null ;
                    isChanged = true;
                }
            } 
            
        });
            // No value changes.
            if(valueMap[apiName] !== value || isChanged) {
                valueMap[apiName] = value;
                component.set("v.valueMap", valueMap);
                this.informDataChanges(component, apiName, value);
                var secComps = component.find("sections");
                var secComps = secComps[0] || secComps;
                this.updateDependentValues(component, secComps, apiName);
                this.autoUpdateFields(fieldComp, component);
            }
            event.stopPropagation();
            

        }
    },
    
    autoUpdateFields : function(fieldComp, component){
        if(!fieldComp.get("v.field").autoUpdate){
            return;
        }
        var valueMap = component.get("v.valueMap");
        var record;
        var records = [];
        fieldComp.get("v.options").forEach(function(option) {
            var fieldValueStr = fieldComp.get("v.value");
            if(fieldValueStr) {
                var fieldValues = fieldValueStr.split(";");
                if(fieldValues.length === 1 ){
                    if(option.value === fieldValueStr){
                        record = option.record;
                    }                   
                } else {
                    fieldValues.forEach(function(fieldValue){
                        if(option.value === fieldValue) {
                            records.push(option.record);
                        }
                    });
                }
            }
        });
        var cacheMap = {};

        for(var key in fieldComp.get("v.field").autoUpdate) {
            if(record){
            	valueMap[key] = "" +record[fieldComp.get("v.field").autoUpdate[key]];    
            } else if(records.length > 0){
                valueMap[key] = "";
                records.forEach(function(item){
                    valueMap[key] = item[fieldComp.get("v.field").autoUpdate[key]] 
                    	+ ";" + valueMap[key];
                });
            } else {
                valueMap[key] = "";
            }
            
            cacheMap[key] = valueMap[key];
        }
        component.set("v.valueMap", valueMap);
        var secComp = component.find("sections");
        secComp = secComp[0] || secComp;
        var fields = secComp.find("fieldInput");
        fields.forEach( function(field) {
            var apiName = field.get("v.apiName");
            if(cacheMap[apiName]){
                field.set("v.value", cacheMap[apiName]);
            }
        });
		
	},
    updateDependentValues : function(component, secComp, apiName) {
        var fields = secComp.find("fieldInput") || [];
        fields = Array.isArray(fields)?fields: [fields];
        var valueMap = component.get("v.valueMap");
        var updateValueMap = false;
        fields.forEach(function(field) {
            var dependentField = field.get("v.dependentField");
            if(apiName && dependentField !== apiName ){
                return;
            }
            if(!dependentField){
                return;
            }
            var value = valueMap[dependentField] || "";
            var dependentOptions = field.get("v.dependentOptions");
            var options = dependentOptions[value];
            options = options || [];
            var currentOptions = field.get("v.options");
            var type= field.get("v.type");
            if(apiName){
                updateValueMap = true;
                valueMap[field.get("v.apiName")] = "";
                if(type === "multiPicklist"){
                    field.find("field").set("v.selectedValues", []);
                    field.find("field").set("v.value", "");
                    options.forEach( function(option) {option.selected = false});
                }else {
                    field.set("v.value", "");
                }
            }
            field.set("v.options", options);
        });
        
        if(updateValueMap){
            component.set("v.valueMap", valueMap);
        }
    },
    informDataChanges : function (component, apiName, value) {
        var dataChangedEvent = component.getEvent ("dataChanged");
        var payload = {"apiName": apiName, "value": value};
        dataChangedEvent.setParams({"type": "dataChanged", "payload": payload});
        dataChangedEvent.fire();
    },
    addErrorToEachField : function(fields, errorMessage, errorMap) {
        var context = this;
        if(!fields || fields.length === 0) {
            var field = "generalError";
            errorMap = this.updateErrorMap(field, errorMessage, errorMap);
        }
        fields.forEach((field) => {
            errorMap = context.updateErrorMap(field, errorMessage, errorMap);
        });
        
        return errorMap;
    },
    updateErrorMap : function(field, errorMessage, errorMap) {
        var messages= errorMap[field];
        messages = messages || [];
        messages.push({"message": errorMessage});
        errorMap[field] = messages;
        return errorMap;
    },
    convertErrors : function (component) {
        var context = this;
        var errors = component.get("v.errors");
        var errorMap = {};
        if(errors){
            errors.forEach( function(error) {
                var fields = error.fields;
                var errorMessage = error.message;
                errorMap = context.addErrorToEachField(fields, errorMessage, errorMap);
            });
        }
        component.set("v.errorMap", errorMap);
    },
    convertValueMap : function(valueMap) {
        var formFeed = {};
        for(var apiName in valueMap) {
        	var names = apiName.split(".");
            var objectName = names[0];
            var fieldName = names[1];
            if(fieldName){
                formFeed[objectName] = formFeed[objectName] || {};
                formFeed[objectName][fieldName] = valueMap[apiName];
            }
        }

        return formFeed;
	}
})