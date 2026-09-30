({
    getAllRecords: function(component) {
        var _self =this;
        Promise.all([_self.getChildren(component), _self.getSubChildren(component)]
                   ).then($A.getCallback(function(responses) {
            var response1 = responses[0];
            var response2 = responses[1];
            var returnValue = response1.getReturnValue();
            var results = JSON.parse(returnValue);
            component.set("v.relatedRecords", results)
            
            console.log("response2", response2.getReturnValue());
            component.set("v.childrenMap", JSON.parse(response2.getReturnValue()));
            _self.refreshListView(component);
        })).catch(function(errors){
            console.log("errors", errors);
        });
    },
    getChildren : function(component) {
        var _self = this;
        var action = component.get("c.getRelatedRecords");
        var fields = component.get("v.fields");
        var sortBy = component.get("v.sortBy");
        var fieldNames = fields.reduce(function(results, field){
            results.push(field.apiName);
            return results;
        }, []);
        action.setParams({
            fields: JSON.stringify(fieldNames),
            sobjectName: component.get("v.relatedSObject"),
            parentField: component.get("v.parentField"),
            parentId: component.get("v.recordId"),
            otherConditions: component.get("v.otherConditions"),
            sortBy: sortBy
        });
        return _self.execute(action);
    },
    getSubChildren: function(component) {
        var _self = this;
        var action = component.get("c.getSubChildren");
        var fields = component.get("v.fields");
        var fieldNames = fields.reduce(function(results, field){
            results.push(field.apiName);
            return results;
        }, []);
        var exploreFields = component.get("v.exploreFields");
        var exploreFieldNames = exploreFields.reduce(function(results, field){
            results.push(field.apiName);
            return results;
        }, []);
        
        action.setParams({
            fields: JSON.stringify(fieldNames),
            sobjectName: component.get("v.relatedSObject"),
            parentField: component.get("v.parentField"),
            parentId: component.get("v.recordId"),
            otherConditions: component.get("v.otherConditions"),
            exploreFields: JSON.stringify(exploreFieldNames),
            exploreSobjectName: component.get("v.exploreRelatedSObject"),
            exploreParentField: component.get("v.exploreParentField")
        });
        return _self.execute(action);
    },
    refreshListView: function(component) {
      var listView = component.find("relatedListView");
        if(listView) {
            listView.refresh();    
        }  
    },
    initiateJSONValues: function(component) {
        var exploreFieldJSON = component.get("v.exploreFieldJSON");
        var fieldJSON = component.get("v.fieldJSON");
        if(fieldJSON && fieldJSON.length) {
            component.set("v.fields", JSON.parse(fieldJSON));
        }
        if(exploreFieldJSON && exploreFieldJSON.length) {
            component.set("v.exploreFields", JSON.parse(exploreFieldJSON));
        }
    }
})