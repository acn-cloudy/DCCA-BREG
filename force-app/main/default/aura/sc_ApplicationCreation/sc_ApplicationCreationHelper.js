({
    findGetParameter : function(parameterName) {
        var result = null,
            tmp = [];
        location.search
            .substring(1)
            .split("&")
            .forEach(function (item) {
                tmp = item.split("=");
                if (tmp[0] === parameterName) result = decodeURIComponent(tmp[1]);
            });
        return result;
    },
    getAppData: function(component, formData) {
        const { user_id: userId} = formData;
        let name = formData.app_no;
        if(sessionStorage && sessionStorage.getItem("sc_Application_ExistingForm_app_no")) {
            name = sessionStorage.getItem("sc_Application_ExistingForm_app_no");
            const currentIndex = sessionStorage.getItem("sc_Application_ExistingForm_index");
            component.set("v.currentindex", currentIndex);
        }
        if(name ) {
            this.showApplicationDetail(component, name, userId);
        } else {
            
            this.initiateApplicationCreation(component, formData);
        }
    },
    showApplicationDetail: function(component, name, userId) {
        const action = component.get("c.getDraftApp");
        action.setParams({ name, userId });
        this.execute(action).then(res => {
            const app = JSON.parse(res.getReturnValue())[0];
            component.set("v.name", app.Application_Meta_Data__r.Name);
            component.set("v.label", app.Application_Meta_Data__r.Label__c);
            component.set("v.applicationcacheId", app.Name);
            component.set("v.appId", app.Id);
            component.set("v.formData", app.FormData__c);
            component.set("v.showApplicationUpdate", true);
        }).catch(ex => {
            console.log("ex", ex);
        });
    },
    initiateApplicationCreation: function(component, formData) {
        const _self = this;
        const {app_name: name, user_id: recordId } = formData;
        const action = component.get("c.getApplicationMetaData");
        action.setParams({name});
        
        const getUserInfo = component.get("c.getUserInfo");
        getUserInfo.setParams({recordId});
        Promise.all([this.execute(action), this.execute(getUserInfo)]
                   ).then($A.getCallback(function(responses) {
            const response1 = responses[0];
            const response2 = responses[1];
            const appMeta = JSON.parse(response1.getReturnValue());
            const userInfoJSON = response2.getReturnValue();
            const userInfo = JSON.parse(userInfoJSON);
            _self.setApp(component, appMeta, userInfo.Email__c, formData);
        })).catch(function(errors){
            console.log("errors", errors);
        });
    },
    setApp: function(component, appMeta, email, formData) {
        const {license_type, board_program} = formData;
        const label = appMeta.Label__c;
        const name = appMeta.Name;
        const cardCaches = {"Select License Type":
        { "cachedValue":{"BoardProgram": board_program, "SelectLicenseType": license_type}
            }, "Person Info": {"cachedValue": {"email": email}}};
        component.set("v.cardCaches", cardCaches);
        component.set("v.label", label);
        component.set("v.name", name);
        component.set("v.formData", JSON.stringify(formData));
        component.set("v.showApplicationCreation", true);    
    },
    decodeParam: function(component) {
        const data = this.replaceAll(decodeURI(this.findGetParameter("data")), " ", "+");
        const action = component.get("c.decode");
        action.setParams({data});
        this.execute(action).then($A.getCallback(
            (response) => {
                const formData = JSON.parse(response.getReturnValue());
                this.getAppData(component, formData);
            }
        ));
    }
})