({
    initiate: function(component) {
        var fields = component.get("v.fields");
        var columnNames = [];
        var headNames = [];
        fields.forEach(field => {
            var label = field.label;
            var size = field.size;
            var apiName = field.apiName;
            var enableSort = field.enableSort;
            headNames.push({label, size, apiName, enableSort});
            columnNames.push(field.apiName);
        });
        component.set("v.headNames", headNames);
        component.set("v.columnNames", columnNames);  
    },
	convertToResults : function(component) {
        var _sefl = this;
		var listViewItems = component.find("listViewItem");
            //listViewItems = [listViewItems];
            
        if (this.checkIsList(listViewItems)) {
            listViewItems = [listViewItems];
        };
        var customRecords = listViewItems.reduce(function(results, listViewItem){
            if(listViewItem.get("v.recordUpdated")) {
               
                results.push(listViewItem.convertToRecord());      
            }
            return results;
        }, []);
      
        return customRecords;
	},
    saveRecords : function(component,event) {
        component.set("v.isSaving", true);
        var _self = this;
       var updaterecords= component.get("v.records"); 
         _self.updateBackToComp(component,updaterecords);
        var customRecords = _self.convertToResults(component);
      
        var action = component.get("c.upsertRecords");
        action.setParams({
            recordStr: JSON.stringify(customRecords) 
        });
        _self.execute(action).then($A.getCallback(function(response){
            var returnValue = response.getReturnValue();
            var responseRecords = JSON.parse(returnValue);
            _self.updateBackToComp(component, responseRecords);
            // check if the 
            if(component.get("v.isChildren")) {
                var turnOffChildrenList = component.getEvent("turnOffChildrenList");
                turnOffChildrenList.setParams({"type":"turnOffChildren"}); 
                turnOffChildrenList.fire(); 
            }
            
        })).catch(function(error) {
            console.log("error", error.getErrors());
            this.showToast("Error", 10000, "Error occurred whilist saving data.", 'error');
        }).finally(function() {
            component.set("v.isSaving", false);
             //event.stopPropagation(); 
        });
    },
    updateBackToComp : function(component, recordResults) {
        var resultMap = recordResults.reduce(function(result, item){
            result[item.index] = item;
            return result;
        }, {});
        var listViewItems = component.find("listViewItem");
        if (this.checkIsList(listViewItems)) {
            listViewItems = [listViewItems];
        };
        var isSucceed = true;
        listViewItems.forEach(function(listViewItem) {
            var index = listViewItem.get("v.index");
            var result = resultMap[index];
            if(result) {
                if(result.isSuccess) {
                    listViewItem.set("v.recordUpdated", false);
                    listViewItem.set('v.originalRecord', result.record);
                } else {
                    isSucceed = false;
                }                
            }
        });
        if(isSucceed) {
            component.set("v.showSave", false);
        	this.switchEditMode(component, false);
            this.showToast("Success", 10000, "Changes saved successfully.", 'success');
        } else {
            throw new Error('Error occurred whilist saving data.');
        }
    },
    
                              
    switchEditMode : function(component, isEditable) {
        var _self = this;
        var readOnly = !isEditable
        component.set("v.editMode", isEditable);
        var listViewItems = component.find("listViewItem");
        if (_self.checkIsList(listViewItems)) {
            listViewItems = [listViewItems];
        };
        listViewItems.forEach(function(listViewItem){
            var fieldInputs = listViewItem.find("fieldInput");
            if (_self.checkIsList(fieldInputs)) {
                fieldInputs = [fieldInputs];
            };
            fieldInputs.forEach(function(field){
                field.set("v.readOnly", readOnly) ;
            });
        });
    },
    showToast: function(title, duration, message, type) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            title: title,
            message: message,
            duration: duration,
            type: type
        });
        toastEvent.fire();
    },
    
})