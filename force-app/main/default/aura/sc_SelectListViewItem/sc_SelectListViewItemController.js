({
	doInit : function(component, event, helper) {
		var columnNames = component.get('v.columnNames');
        var record = component.get('v.record');
        var columnObjList = columnNames.reduce(function(newArray, sglColumnName) {
            var sglColumnObj = {};
            sglColumnObj = Object.assign(sglColumnObj, {
                fieldApi: sglColumnName,
                fieldValue: record[sglColumnName] || ''
            });
            newArray.push(sglColumnObj);
            return newArray;
        }, []);
        component.set('v.columnObjList', columnObjList);
        var valueMap = component.get("v.valueMap");
        if (valueMap) {
            var checked = valueMap[record.Id];
        	component.set('v.checked', checked);
        } else {
            component.set('v.checked', false);
        }
	},
    onCheck: function(component, event, helper) {
        var value = event.currentTarget.getAttribute("data-value");
        var valueMap = component.get("v.valueMap") || {};
        var selectOne = component.get("v.selectOne");
        if(event.currentTarget.checked) {
            valueMap[value] = true;
            component.set('v.checked', true);
            if(selectOne) {
                for(var key in valueMap) {
                    if(key !== value) {
                        delete valueMap[key];
                    }
                }
            }
        } else {
            delete valueMap[value];
            component.set('v.checked', false);
        }
        component.set("v.valueMap", valueMap);
    }
})