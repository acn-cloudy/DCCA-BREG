({
	doInit : function(component, event, helper) {
        helper.decodeParam(component);

    },
    back: function(component, event, helper) {
        const app = component.find("app");
        const indexNumber = app.getIndex();
        if(indexNumber === 0) {
            const formData = JSON.parse(component.get("v.formData"));
            window.location.href = formData.cancel_url;
        } else {
            app.previous();
        }
    }
})