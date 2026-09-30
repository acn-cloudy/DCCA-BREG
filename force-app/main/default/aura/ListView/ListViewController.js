({
    doInit : function(component, event, helper) {
        helper.initiate(component);
        var listViewItems = component.find("listViewItem");
        if(listViewItems) {
            if(helper.checkIsList(listViewItems)) {
                listViewItems = [listViewItems];
            }
            
            listViewItems.forEach(function(listViewItem) {
                listViewItem.initiateRecord();
            });
        }
        if(component.get("v.isChildren")) {
            helper.switchEditMode(component, true);
        }
    },
    openEditMode : function(component, event, helper) {
        var type = event.getParams().type;        
        var editMode = component.get("v.editMode");
        if(type === "enableEditMode" && !editMode) {
            component.set("v.recordUpdated", true);
            helper.switchEditMode(component, true);
            
        } 
        
    },
    markAsUpdated: function(component, event, helper) {
        var type = event.getParams().type;        
        
        if(type === "fieldValueUpdate"){
            component.set("v.showSave", true); 
            event.stopPropagation();
           
        }
    },
    comitSave: function(component, event, helper) {
        //helper.updaterecord(component,event); 
        helper.saveRecords(component);  
        
    },
    sort : function(component, event, helper) {
        var message = event.getParam("type");
        var payload = event.getParam("payload");
        if(message === "clear-sorts"){
            var sortBy = payload.apiName;
            var sortSeq = payload.sortSeq;
            console.log(sortBy, sortSeq);
            var listViewHeaders = component.find("listViewHeader");
            listViewHeaders.forEach(cmp => { 
                if(cmp.get("v.title") !== sortBy) {
                $A.util.addClass(cmp.find("arrowUp"), "hiddenIcon");
                $A.util.addClass(cmp.find("arrowDown"), "hiddenIcon");
            }});
            var records = component.get("v.records");
            const recordIds = records.reduce((result, item) => {
                result.push(item.Id);
                return result;
            }, []);
            const columnNames = component.get("v.columnNames");
            const relatedSObject = component.get("v.relatedSObject");
            var action = component.get("c.sortRecords");
            action.setParams({relatedSObject, sortBy, sortSeq, recordIds, columnNames});
            helper.execute(action).then($A.getCallback(function(response){
                var sortRecords = response.getReturnValue();
                component.set("v.records", JSON.parse(sortRecords));
                component.set("v.showSave", false);
            }) );
            event.stopPropagation();
        }
    },
    cancelChanges : function(component, event, helper) {
        var listViewItems = component.find("listViewItem");
        if(listViewItems) {
            if(helper.checkIsList(listViewItems)) {
                listViewItems = [listViewItems];
            }
            listViewItems.forEach(function(listViewItem) {
                listViewItem.revertRecord();
            });
            helper.switchEditMode(component, false);
            component.set("v.showSave", false);
            
        }
        if(component.get("v.isChildren")) {
            var turnOffChildrenList = component.getEvent("turnOffChildrenList");
            turnOffChildrenList.setParams({"type":"turnOffChildren"}); 
            turnOffChildrenList.fire(); 
        }
        
    }
})