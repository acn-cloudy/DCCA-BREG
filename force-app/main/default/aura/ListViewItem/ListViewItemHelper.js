({
	convertToRecord : function(component) {
        var record = component.get("v.record");
        var index = component.get("v.index");
        var recordUpdated = component.get("v.recordUpdated");
        
        return {
            index: index,
            record: record,
            updated: recordUpdated
        };
	}
})