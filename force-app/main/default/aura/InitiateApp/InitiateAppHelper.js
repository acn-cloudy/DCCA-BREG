({
    confirmNext: function(component) {
        const message = component.getEvent("cmpMessage");
        message.setParams({
            "type" : "continue-with-next"
        });
		message.fire();
        this.destroyCmp(component);
    }
})