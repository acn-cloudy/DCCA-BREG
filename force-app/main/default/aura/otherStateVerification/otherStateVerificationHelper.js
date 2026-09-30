({
    destroyCmp : function(component) {
        const message = component.getEvent("cmpMessage");
        message.setParams({
            "type" : "close-extra-action"
        });
		message.fire();
    },
    confirmNext: function(component) {
        const message = component.getEvent("cmpMessage");
        message.setParams({
            "type" : "continue-with-next"
        });
		message.fire();
        this.destroyCmp(component);
    }
})