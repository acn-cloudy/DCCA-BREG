({
	validatePhone : function(phoneVal) {
        if(!phoneVal) {
            return true;
        }
        var trimedPhoneVal = phoneVal.replace(/ /g,'');
		var phoneno = /^\({0,1}((0|\+61)(2|4|3|7|8)){0,1}\){0,1}(\ |-){0,1}[0-9]{2}(\ |-){0,1}[0-9]{2}(\ |-){0,1}[0-9]{1}(\ |-){0,1}[0-9]{3}$/;
        return trimedPhoneVal.match(phoneno);
	},
    addErrorMessage: function(message) {
        var messages = [];
        messages.push({"message": message});
        return messages;
    }
})