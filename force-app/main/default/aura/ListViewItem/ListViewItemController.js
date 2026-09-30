({
	doInit : function(component, event, helper) {
		var fields = component.find('fieldInput');
        var record = component.get('v.record');
        var childrenMap = component.get("v.childrenMap");
        
        fields.forEach(function( field){
            var fieldName = field.get("v.apiName");
            field.set("v.value", record[fieldName]);
            if(childrenMap && childrenMap[record.Id] && childrenMap[record.Id] > 0){
                component.set("v.showViewMore", true); 
            }
        });
        var allFields = component.get("v.fields");
        var totalSize =  allFields.reduce(function(result, item){
            result += item.size;
            return result;
        }, 1);
        component.set("v.totalSize", totalSize);
		component.set("v.originalRecord", JSON.parse(JSON.stringify(record)));
	},
    enableEdit : function(component, event, helper) {
         component.set("v.IsEnabled",true); 
        var fieldInfoEvent = component.getEvent("activateEditMode"); // fieldInfo
        fieldInfoEvent.setParams({"type":"enableEditMode","payload": {"fieldComp": component}}); 
        fieldInfoEvent.fire(); 	
       
    },
    updateRecord: function(component, event, helper) {
        var type = event.getParams().type;        
        var record = component.get("v.record");
        if(type === "fieldValueUpdate"){
            var fieldComp = event.getParams().payload.fieldComp;
            var apiName = fieldComp.get("v.apiName");
            var value = fieldComp.get("v.value");
            record[apiName] = value;
            component.set("v.recordUpdated", true);
            component.set("v.record", record);
            
            
        }
        if(type === "enableEditMode"){
            var fieldComp = event.getParams().payload.fieldComp;
            var apiName = fieldComp.get("v.apiName");
            var value = fieldComp.get("v.value");
            record[apiName] = value;
            component.set("v.recordUpdated", true);
            component.set("v.record", record);
        }
        if(type === "turnOffChildren") {
            component.set("v.showChildren", false);
            event.stopPropagation();
        }
   },
    getRecord: function(component, event, helper) {
        return helper.convertToRecord(component);
    },
    openDrawer : function(component, event, helper) {
        var showChildren = component.get("v.showChildren");
        component.set("v.showChildren", !showChildren);
        var relatedList = component.find("relatedList");
        var fieldInfoEvent = component.getEvent("activateEditMode"); // fieldInfo
        fieldInfoEvent.setParams({"type":"enableEditMode","payload": {"fieldComp": component}}); 
        fieldInfoEvent.fire(); 	
        relatedList.expand();
    },  
    hideDrawer : function(component, event, helper ) {
        component.set("v.showChildren", false);
    },
    cancelRecord: function(component, event, helper ) {
        var fields = component.find('fieldInput');
        var record = component.get('v.originalRecord');

        var currentFields = fields.forEach(function( field){
            var fieldName = field.get("v.apiName");
            field.set("v.value", record[fieldName]);
        });
		component.set("v.record", JSON.parse(JSON.stringify(record)));
    }
})