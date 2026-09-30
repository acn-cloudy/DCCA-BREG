({
    "handleNavChange": function(component, event, helper) {
        helper.refreshNavigationBars(component);
    },
    "recalculateDependency": function(component, event, helper) {
        var type = event.getParams().type;
        if(type === "fieldDependentCalculate" ) {
        	helper.save(component);
            const fieldName = event.getParams().payload.fieldName;
            const value = event.getParams().payload.value;
            helper.overrideItems(component, fieldName, value);
        } else if( type === "inputToCheck") {
            const fieldName = event.getParams().payload.fieldName;
            const value = event.getParams().payload.value;
            helper.overrideCurrentItem(component, fieldName, value);
        }
    },
    "getIndexNumber": function(component, event, helper) {
        return component.get("v.currentindex");

    },
    "loadApplication": function (component, event, helper) { 
        helper.initiate(component);
    },
    "loadexisting": function (component, event, helper) {
        helper.loadForm(component);
    },
    "processheaderclick": function (component, event, helper) {

        if (component.get("v.headerclickable")) {
            var cards = component.get("v.cards");
            var scard = -1;
            
            for (var i = 0; i < cards.length; i++) {
                
                if (cards[i] == event.target.id) {
                    scard = i;
                    break;
                }
            }
            helper.save(component);
            
            component.set("v.currentindex", scard);
            helper.loadForm(component);
        }
    },
    "nextBtnPress": function (component, event, helper) {
        helper.nextAction(component,event);
    },
    "checkCardClick": function (component, event, helper) {
        const name = event.getParams().id;
        const cards = component.get("v.cards");
        const depcards = component.get("v.hiddencards");
        const filteredCards = cards.reduce((result, card) => {
            if(!depcards.includes(card.Label__c)) {
                result.push(card);
            }
            return result;
        }, []);
        const index = filteredCards.findIndex(item => item.Name === name);
        const cardCaches = component.get("v.cardCaches");
        let allowVisited = false;
        for(let key in cardCaches) {
            if(key === name)  {
                allowVisited = true;
                break;
            }
        }
        if(allowVisited) {
            let currentIndex = component.get("v.currentindex");
            if(currentIndex) {
                currentIndex = parseInt(currentIndex);
            }
            
            if(currentIndex === 0 && index === 1) {
                helper.nextAction(component, event);
            } else {
                if(currentIndex < index) {
                    helper.nextAction(component,event, index);
                } else if(currentIndex > index) {
                    component.set("v.oldcurrentindex", currentIndex);
                    component.set("v.currentindex", index);
                
                    const totalc = component.get("v.numcards");
                    const tot = Math.round(index / (totalc - 1) * 100);
                    
                    component.set("v.progress", tot);
                    helper.loadForm(component);
                }
            }
            
        }

    },
"prevBtnPress": function (component, event, helper) {
    component.set("v.isLoadingComplete",false);
    var index = component.get("v.currentindex");
    component.set("v.oldcurrentindex", index);
    
    index = index - 1;
    
    if (index < 0)
        index = 0;
    
    component.set("v.currentindex", index);
    
    var totalc = component.get("v.numcards");
    var tot = Math.round(index / (totalc - 1) * 100);
    
    component.set("v.progress", tot);
    helper.loadForm(component);
    
},
"reviewApp": function (component, event, helper) {
    component.set("v.isLoadingComplete",false);
    var isValid = helper.validate(component);
    if (isValid) {
        helper.save(component);
        
        helper.saveData(component, "submit").then($A.getCallback(function(response){
            component.set("v.isnew", false);
            var summaryModal = component.find("summaryModal");
            const appName = component.get("v.applicationcacheid");
            summaryModal.initSummary(appName);
            component.set("v.hidesummarymodal", false);
            component.set("v.isLoadingComplete",true);
        })).catch(function(error){
            component.set("v.isLoadingComplete",true);
        });
    } else {
        $A.get("e.force:showToast").setParams({
            "title": "Failed",
            "message": "One or more required fields are missing.",
            "type": "error"
        }).fire();
        component.set("v.isLoadingComplete",true);
    }
    
},
"cancelprint": function (component, event, helper) {
    component.set("v.hideprintmodal", true);
    component.set("v.hidesummarymodal", false);
},
"cancelApplications": function (component, event, helper) {
    
    $A.get("e.force:navigateToURL").setParams({
        "url": "/?tabset-bee2f=2"
    }).fire();
},
"revertAction": function (component, event, helper) {
    
    
    var page = component.find("cancelMessagepage");
    $A.util.toggleClass(page, "hidemodal");
    
},
"cancelmessage": function (component, event, helper) {
    
    var mesg = component.get("v.message");
    var page = component.find("messagepage");
	$A.util.addClass(page, "slds-hide");
    
},
"redirectpage": function (component, event, helper) {
    
    var page = component.find("messagepage");
    $A.util.addClass(page, "slds-hide");
    var app = component.get("v.application");
    if(app && app.Status__c !== "Submitted"){
        window.location.href = "/s/?recordId="+ app.Id;
    } else if(window.location.href.indexOf('lightning') !== -1) {
        var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
            "recordId": app.Id,
            "slideDevName": "Detail"
            });
            navEvt.fire();
    } else {
        window.location.href = "/s/?tabset-bee2f=2";
    }
},
"cancelApplication": function (component, event, helper) {
    
    var mesg = component.get("v.message");
    mesg = "Are you Sure to exit the Application Submission?";
    component.set("v.message", mesg);
    var page = component.find("cancelMessagepage");
    $A.util.toggleClass(page, "hidemodal");
},
"handleMessage": function (component, event, helper) {
    var type = event.getParam("type");
    if (type === "cancel-summary") {
        component.set("v.hidesummarymodal", true);
    } else if (type === "print-summary") {
        component.set("v.hidesummarymodal", true);
        component.set("v.hideprintmodal", false);
        
    } else if (type === "final-submit") {
        helper.finalSubmitHelper(component);
    } else if(type === "continue-with-next") {

        const valueMap = event.getParam("payload");
        if(valueMap) {
            component.set("v.valueMap", valueMap);
        }
        const cIndex = component.get("v.cIndex");
        helper.saveData(component, event, cIndex);
        component.set("v.isLoading", true);
        component.set("v.isLoadingComplete", false);
    } else if(type === "close-extra-action") {
        const cIndex = component.get("v.cIndex");
        helper.saveData(component, event, cIndex);
        component.set("v.extraActions", []);
        component.set("v.isLoading", false);
    }
},
"handleDependField": function (component, event, helper) {   
    var dependFieldStr = event.getParam("dependfield");
    var valueStr = event.getParam("dvalue");
    var value = event.getParam("value");
    var action = event.getParam("dependaction");
    
    if(!dependFieldStr) {
        return;
    }
    var dependFields = dependFieldStr.split(",");
    var fieldMap = {};
    dependFields.forEach(function(dependField){
        fieldMap[dependField.trim()] = true;
    });

    var fields = component.find("card").get("v.body");
    var fieldsForUpdate = [];
    fields.forEach(function(field){
        var fieldName = field.get("v.fieldName");
        if(fieldMap[fieldName]){
            fieldsForUpdate.push(field);
        }
    });
    var hidden = false;
    if(action === "hide") hidden = true;
    
    fieldsForUpdate.forEach(function(field){
        var originalHidden = field.get("v.originalHidden");
        var dHidden = originalHidden;
        if(value === valueStr) {
            dHidden = hidden;
        }
        if(dHidden) {
            field.set("v.value", "");    
            if(field.get("v.fieldType") === "fileupload"){
                var fileName = field.get("v.fieldName");
                var parentId = field.get("v.parentId");
                field.deleteFiles(fileName, parentId);
            }
            if(field.get("v.fieldType") === "picklist") {
                field.set("v.selectedValue", null);    
            }
            if(field.get("v.fieldType") === "checkbox") {
                field.set("v.value", true);    
            }
        }
        field.set("v.fieldHidden", dHidden);

    });
},
"finalsubmit": function (component, event, helper) {
    this.finalSubmitHelper(component);
},
"sendforvalidation": function (component, event, helper) {
    
    var actionA = component.get("c.validate");
    actionA.setParams({
        
    });
    actionA.setCallback(this, function (response) {
        var state = response.getState();
        
        if (state === "SUCCESS") {
            
            var mesg = component.get("v.message");
            
            var obj = JSON.parse(response.getReturnValue());
            component.set("v.message", mesg);
        }
    });
    $A.enqueueAction(actionA);
    
    
},
"clickcancel": function (component, event, helper) {
    var urlEvent = $A.get("e.force:navigateToURL");
    urlEvent.setParams({
        "url": "/"
    });
    urlEvent.fire();
},
"saveasDraftBtnPress": function (component, event, helper) {
    component.set("v.isLoadingComplete",false);
    helper.save(component);
    helper.saveData(component).then($A.getCallback(function(response){
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "Success!",
            "message": 'Your application ' + component.get("v.applicationcacheid") + ' has been saved as draft.',
            "type": "Success"
        });
        toastEvent.fire();
        component.set("v.isLoadingComplete",true);
    }));
    
}

});