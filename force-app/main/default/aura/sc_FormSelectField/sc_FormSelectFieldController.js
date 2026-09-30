({
    loadOptions: function (component, event, helper) {
 
        const fieldValues = component.get('v.fieldvalues');
        let options = [{label: "-None-", value: ""}];
        try{
            options =[...options, ...JSON.parse(fieldValues)] ;
        } catch(ex) {
            if(fieldValues) {
                options = [...options, ...fieldValues.split(",").reduce((result, item) => 
                [...result, {label:item, value: item}], [])];
            }
        }
        
       component.set("v.options", options);
       var defaultValue = component.get("v.selectedValue");
        
        if (defaultValue==null || defaultValue.trim()=="")
            defaultValue="-None-";
        
        component.set('v.value', defaultValue.trim());
        component.set('v.selectedValue', defaultValue.trim());

        if(component.get("v.value")) {
            helper.broadcastValue(component, event);
        }
    },
    onChange: function (component, event, helper) {
        helper.validate(component);
        helper.broadcastValue(component, event);
    }, 
    checkValidity: function(component, event, helper) {
        return helper.validate(component)
    }
 
})