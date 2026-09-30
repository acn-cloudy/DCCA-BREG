({
	updateValueMap : function(component, event, helper) {
        var type = component.get("v.type");
        if(type === "number" || type === "email" || type === "files" 
           || type === "file" || type === "currency" || type === "richTextarea" 
           || type === "textarea" || type === "text"
           || type === "datetime" || type === "multiPicklist"
           || type === "date" || type === "phone" || type === "longtextarea"  
           || type === "abn" ){
           helper.checkIsRequired(component); 
        }
        var onchange = component.get('v.onchange');
        // Invoke onchange function if it is provided
        if (onchange) {
            onchange(component, event, helper);
        }
        if(component.get("v.type") === "date" && component.get("v.value") === "") {
            component.set("v.value", undefined);
        }
        
		var fieldInfoEvent = component.getEvent ("fieldInfo");
        fieldInfoEvent.setParams({"type": "fieldValueUpdate", "payload": {"fieldComp": component}});
		fieldInfoEvent.fire();
        
	},
    checkIsRequired : function(component, event, helper) {
        helper.checkIsRequired(component);
    },
    captureFileData: function(component, event, helper) {
        console.log("captureFileData");     
        var files = event.getParam("files");
        component.set("v.value", JSON.stringify(files));
        console.log("files: ", JSON.stringify(files));  
        $A.enqueueAction(component.get("c.updateValueMap"));
    },
    updateValueMapForSelect : function(component, event, helper) {
        helper.checkIsRequired(component);
		var fieldInfoEvent = component.getEvent ("fieldInfo");
        fieldInfoEvent.setParams({"type": "fieldValueUpdate", "payload": {"fieldComp": component}});
		fieldInfoEvent.fire();
    },
    addErrors : function(component, event, helper) {
		var params = event.getParam('arguments');
        if(params){
            var message = params.message;
            helper.setErrorMessage(component, message);
            console.log("message", message);
        }
    }
})