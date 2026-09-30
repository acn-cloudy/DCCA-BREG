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
    }
})