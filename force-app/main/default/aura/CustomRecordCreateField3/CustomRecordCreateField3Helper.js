({
	emailIsValid : function(email) 
	{
        var re = new RegExp('^(([^<>()[\\]\\\\.,;:\\s@\\"]+(\\.[^<>()[\\]\\\\.,;:\\s@\\"]+)*)|(\\".+\\"))@((\\[[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\])|(([a-zA-Z\\-0-9]+\\.)+[a-zA-Z]{2,}))$');
        return re.test(email);
    },

    phoneIsValid : function(phone) 
    {
        var re = new RegExp('^([\\(]{1}[0-9]{3}[\\)]{1}[\\.| |\\-]{0,1}|^[0-9]{3}[\\.|\\-| ]?)?[0-9]{3}(\\.|\\-| )?[0-9]{4}$');
        return re.test(phone);
    },

    showToastMessage : function(type, title, message, mode) 
    {
    	var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "type": type,
            "title": title,
            "message": message,
            "mode": mode
        });
        toastEvent.fire();
    },

    showContent : function(component, event, helper) 
    {
        var sObj = component.get('v.sObj');
        var fld = component.get('v.field');

        // if this field is dependent on another field
        if(fld.dependentOnFieldApiName != null)
        {
            if(sObj[fld.dependentOnFieldApiName] == true || sObj[fld.dependentOnFieldApiName] == 'Yes')
            {
                component.set("v.displayFieldInfo", fld.displayIfTrue);
            }
            else
            {
                component.set("v.displayFieldInfo", !fld.displayIfTrue);
            }
        }
    },
    
    filterDependentPicklists : function(component, event, helper)
    {
    	var sObj = component.get('v.sObj');
        var fld = component.get('v.field');
        var ctrlType = component.get('v.ctrlType');
        if (ctrlType == 'PICKLIST') {
            var piclistOptionsAv = [];
            for (var i = 0; i < fld.piclistOptions.length; i++) {
                if (fld.piclistOptions[i].dependentOnField != null && fld.piclistOptions[i].dependentOnField != '') {
                    if (sObj[fld.piclistOptions[i].dependentOnField] == fld.piclistOptions[i].dependentOnValue) {
                        piclistOptionsAv.push(fld.piclistOptions[i]);
                    }
                } else {
                    piclistOptionsAv.push(fld.piclistOptions[i]);
                }
            }
            component.set('v.availableOptions', piclistOptionsAv);
        }
	}
})