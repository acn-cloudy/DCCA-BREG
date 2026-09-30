({
	execute : function(action) {
        return new Promise(function(resolve, reject) {
            action.setCallback(this, function(response) {
                var state = response.getState();
                if (state === "SUCCESS") {
                    resolve(response);
                }else if (state === "ERROR") {
                    reject(response);
                }
            });
            $A.enqueueAction(action);
        });
    },
    getJsonFromUrl : function() {
        var query = location.search.substr(1);
        var result = {};
        var _super = this;
        query.split("&").forEach(function(part) {
            var item = part.split("=");
            if(item && item.length > 1)
	            result[_super.replaceAll(item[0], '+',' ')] 
                	= decodeURIComponent(_super.replaceAll(item[1], '+',' '));
        });
        return result;
    },
    replaceAll : function(str, find, replace) {
    	return str.split(find).join(replace)
	},
    isNumber: function(obj) {
        return typeof obj === "number" && !isNaN(obj);
    },
    customErrorMessage: function(component, message) {
        // Hint is important to make sure the label to be load when initiates
        if(message !== null && message.indexOf("FIELD_CUSTOM_VALIDATION_EXCEPTION") !== -1) {
            var errorMessage = message.split("FIELD_CUSTOM_VALIDATION_EXCEPTION, ")[1];
            errorMessage = errorMessage.split(": []")[0];
            component.set("v.customMessage", $A.getReference("$Label.c." + errorMessage));
            if(!$A.getReference("$Label.c." + errorMessage)) {
                component.set("v.customMessage", errorMessage);
            }
        } else {
            component.set("v.customMessage", message);
        }
    },
    logError: function(component, message, title) {
        if(!title) {
            title = "Error";
        }
        this.logMessage(component, message, title, "error");
        
    },
    logMessage: function(component, message, title, type) {
        try{
            parent.window.name;
            component.set("v.isInSalesforceClassfic", false);
        } catch(err) {
            component.set("v.isInSalesforceClassfic", true);
        }
    
        component.set("v.notificationMessage", message);
        component.set("v.notificationTitle", title);
        component.set("v.notificationType", type);
        component.set("v.showNotificationMessage", true);
        setTimeout(function(){component.set("v.showNotificationMessage", false); }, 3000);
    },
    fireMessage: function(message, type,  payload) {
        message.setParams({"type": type, "payload": payload});
        message.fire();    
    }

})