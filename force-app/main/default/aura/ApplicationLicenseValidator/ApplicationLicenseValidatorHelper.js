({
    checkLicense : function(component) {
        const _self = this;
        const valueMap = component.get("v.valueMap");
        if(valueMap.hadTypeOfNursingLicense === "Yes") {
            const licenseType = valueMap.SelectLicenseType;
            const licenseNumber = valueMap.previousLicenseNumber;
            const action = component.get("c.validateLicense");
            action.setParams({licenseNumber, licenseType});
            this.execute(action).then($A.getCallback(function(res){
                const message = res.getReturnValue();
                if(!message || !message.length) {
                    _self.confirmNext(component);
                } else {
                    component.set("v.displayItem", true);
                    component.set("v.message", message);
                }
            }));
        } else {
            _self.confirmNext(component);
        }
    },
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