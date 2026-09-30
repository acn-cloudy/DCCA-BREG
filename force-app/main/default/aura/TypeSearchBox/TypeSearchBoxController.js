({
    doInit: function(component, event, helper) {
        var options = component.get("v.defaultOptions");
        if(options) {
            component.set("v.options", options);
        } else {
            component.set("v.options", []);
        }
    },
    showBox : function(component, event, helper) {
        component.set("v.show", true);
        component.set("v.options", component.get("v.defaultOptions"));
    },
    handleBlur : function(component, event, helper) {
        var value = event.currentTarget.value || "";
        value = value.toLowerCase();
        value = value.trim();
        var defaultOptions = component.get("v.defaultOptions");
        var options = defaultOptions.filter(option => option.label.toLowerCase().includes(value));
        if(options && options.length === 1 && options[0].label.toLowerCase() === value.toLowerCase() ) {
            component.set("v.value", options[0].value);
            component.set("v.show", false);
            component.set("v.options", component.get("v.defaultOptions"));
        } else {
            component.set("v.show", true);
            component.set("v.value", "");
            component.set("v.options", options);
        }
    },
    closeBox : function(component, event, helper) {
        if(component.get("v.noClose")) {
            component.set("v.noClose", false);
        } else {
            component.set("v.show", false);
            component.set("v.options", component.get("v.defaultOptions"));
        }
        
    }, 
    handleChange: function(component, event, helper) {
        component.set("v.value", event.currentTarget.getAttribute("data-option-value"));
        component.set("v.label", event.currentTarget.getAttribute("data-option-label"));
        component.set("v.show", false);
        component.set("v.options", component.get("v.defaultOptions"));
        component.set("v.noClose", false);
    },
    markNotForClose : function(component, event) {
        if(event.target.id === "listbox-id-1" ) {
            component.set("v.noClose", true);
        }
        
    }
})