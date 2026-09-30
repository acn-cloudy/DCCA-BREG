({
    initiateColumns: function(component) {
        var value = component.get("v.value");
        var rows = [];
        if(value) {
        	rows = JSON.parse(value);
        }

        var columns = component.get("v.columns");
        columns = columns || '[]';
        columns = JSON.parse(columns);
        const headNames = columns.reduce(function(results, column){
            results.push(column.label);
            return results;
        }, []);
        component.set("v.headNames", headNames);
        const columnNames = columns.reduce(function(results, column){
            results.push(column.apiName);
            return results;
        }, []);
        component.set("v.columnNames", columnNames); 
        component.set("v.rows", rows);
    },
    initiateSections: function(component) {
        var columns = component.get("v.columns");
        columns = JSON.parse(columns);
        var fields = columns.reduce(function(results, item){
            item.apiName = "record."+ item.apiName;
            results.push(item);
            return results;
        }, []);
        var sections = [{
            "name": "",
            "open": true,
            "fields": {
                "end": fields
            }}];
        
        component.set("v.sections", sections);
    },
    updateValue: function(component) {
        var rows = component.get("v.rows");
        if(rows.length) {
            component.set("v.value", JSON.stringify(rows));
        } else {
            component.set("v.value", null);
        }
    }
})