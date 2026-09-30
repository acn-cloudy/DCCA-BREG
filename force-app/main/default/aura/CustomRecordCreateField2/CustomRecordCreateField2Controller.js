({
    handleSelectChangeEvent: function(component, event, helper) 
    {
        var sObj = component.get('v.sObj');
        var fld = component.get('v.field');
        var selectedValues = '';
        
        for(var i = 0; i < event.getParam("values").length; i++)
        {
            selectedValues += event.getParam("values")[i] + ';';
        }

        // renove the last ';'
        selectedValues = selectedValues.slice(0, -1);

        if(sObj)
        {
            sObj[fld.fieldAPIName] = selectedValues;
            
            component.set('v.sObj', sObj);
        }
    },

	doInit : function(component, event, helper) 
    {
		var fld = component.get('v.field');
        
        if(fld.fieldType == 'ADDRESS' && (fld.fieldAPIName).indexOf("Address") !== -1) 
        {            
            var strStreet = (fld.fieldAPIName).replace("Address", "Street");
            var strCity = (fld.fieldAPIName).replace("Address", "City");
            var strPostalCode = (fld.fieldAPIName).replace("Address", "PostalCode");
            var strState = (fld.fieldAPIName).replace("Address", "State");
            var strStateCode = (fld.fieldAPIName).replace("Address", "StateCode");
        
        	component.set('v.fieldStreet', strStreet);
            component.set('v.fieldCity', strCity);
            component.set('v.fieldPostalCode', strPostalCode);
            component.set('v.fieldState', strState);
            component.set('v.fieldStateCode', strStateCode);
        }
        var fldStreet = component.get('v.fieldStreet');
        var fldCity = component.get('v.fieldCity');
        var fldPostalCode = component.get('v.fieldPostalCode');
        var fldState = component.get('v.fieldState');
        var fldStateCode = component.get('v.fieldStateCode');
		
        if(fld.fieldAPIName == 'Name' && component.get('v.forPersonAccount') == 'true') 
        {            
            var strTitle = "Salutation";
            var strFirstName = "FirstName";
            var strMiddleName = "MiddleName";
            var strLastName = "LastName";
        
        	component.set('v.fieldTitle', strTitle);
            component.set('v.fieldFirstName', strFirstName);
            component.set('v.fieldMiddleName', strMiddleName);
            component.set('v.fieldLastName', strLastName);
        }
        var fldTitle = component.get('v.fieldTitle');
        var fldFirstName = component.get('v.fieldFirstName');
        var fldMiddleName = component.get('v.fieldMiddleName');
        var fldLastName = component.get('v.fieldLastName');
		/*
		address, anytype, base64, Combobox, DataCategoryGroupReference, EncryptedString, ID, MultiPicklist, Reference
		Boolean
		Time
		 */
		
		var cType = 'READONLY';
        
		if (fld.fieldType == 'STRING' || fld.fieldType == 'URL') {
            cType = 'STRING';
        }

        if (fld.fieldType == 'EMAIL') 
        {
            cType = 'EMAIL';
        }

        if (fld.fieldType == 'PHONE') 
        {
            cType = 'PHONE';
        }

        if (fld.fieldType == 'CURRENCY' || fld.fieldType == 'DOUBLE' || fld.fieldType == 'INTEGER' || fld.fieldType == 'PERCENT') {
            cType = 'NUMBER';
        }
        if (fld.fieldType == 'TEXTAREA') {
            cType = 'TEXTAREA';
        }
        if (fld.fieldType == 'PICKLIST') {
            cType = 'PICKLIST';
        }
        if (fld.fieldType == 'MULTIPICKLIST') {
            cType = 'MULTIPICKLIST';
        }
        if (fld.fieldType == 'DATETIME') {
            cType = 'DATETIME';
        }
        if (fld.fieldType == 'DATE') {
            cType = 'DATE';
        }
        if (fld.fieldType == 'BOOLEAN') {
            cType = 'BOOLEAN';
        }
        if (fld.fieldType == 'REFERENCE') {
            cType = 'REFERENCE';
        }
            
        if (fld.fieldType == 'ADDRESS') {
            cType = 'ADDRESS';
        }
        
        if (fld.fieldAPIName == 'Name' && component.get('v.forPersonAccount') == 'true') {
            cType = 'PERSONACCOUNTNAME';
        }
		
		var sObj = component.get('v.sObj');

		component.set('v.ctrlType', cType);

		if (cType == 'ADDRESS')
        {
            if(component.get('v.getDefaultValue') == true)
            { 
                component.set('v.valueStreet', fld.defaultValue.street);
            	component.set('v.valueCity', fld.defaultValue.city);
            	component.set('v.valuePostalCode', fld.defaultValue.postalCode);
            	component.set('v.valueState', fld.defaultValue.state);
                component.set('v.valueStateCode', fld.defaultValue.stateCode);
                
                sObj[fldStreet.fieldAPIName] = fld.defaultValue.street;
                sObj[fldCity.fieldAPIName] = fld.defaultValue.city;
                sObj[fldPostalCode.fieldAPIName] = fld.defaultValue.postalCode;
                sObj[fldState.fieldAPIName] = fld.defaultValue.state;
                sObj[fldStateCode.fieldAPIName] = fld.defaultValue.stateCode;
            }
            else if(sObj)
            {
                // Client Note: "If we search an account and the account is not found, when creating the account pre-populate the account name and street used in the search"
                //component.set('v.valueStreet', sObj[fldStreet.fieldAPIName]);
                component.set('v.valueStreet', component.get("v.streetName"));
            	component.set('v.valueCity', sObj[fldCity.fieldAPIName]);
            	component.set('v.valuePostalCode', sObj[fldPostalCode.fieldAPIName]);
            	component.set('v.valueState', sObj[fldState.fieldAPIName]);
                component.set('v.valueStateCode', sObj[fldStateCode.fieldAPIName]);
            } 
        } 
        else if(cType == 'PERSONACCOUNTNAME') {
            if(component.get('v.getDefaultValue') == true)
            { 
                component.set('v.valueTitle', fld.defaultValue.title);
            	component.set('v.valueFirstName', fld.defaultValue.firstName);
            	component.set('v.valueMiddleName', fld.defaultValue.middleName);
            	component.set('v.valueLastName', fld.defaultValue.lastName);
                
                sObj[fldTitle.fieldAPIName] = fld.defaultValue.title;
                sObj[fldFirstName.fieldAPIName] = fld.defaultValue.firstName;
                sObj[fldMiddleName.fieldAPIName] = fld.defaultValue.middleName;
                sObj[fldLastName.fieldAPIName] = fld.defaultValue.lastName;
            }
            else if(sObj)
            {
            	component.set('v.valueTitle', sObj[fldTitle]);
            	component.set('v.valueFirstName', sObj[fldFirstName]);
            	component.set('v.valueMiddleName', sObj[fldMiddleName]);
                component.set('v.valueLastName', sObj[fldLastName]);
            } 
        }
        else
        {
            if(component.get('v.getDefaultValue') == true && component.get("v.hasMetadataInfo") == false)
            { 
                component.set('v.value', fld.defaultValue);
                sObj[fld.fieldAPIName] = fld.defaultValue;
            }
            else if(component.get("v.hasMetadataInfo") == true)
            {
                // if this property is 'false' we must use the default value, and don't display the field in page
                if(fld.metadataEditable == false)
                {
                    component.set('v.value', fld.metadataDefaultValue);
                	sObj[fld.fieldAPIName] = fld.metadataDefaultValue;
                }
                else
                {
                    component.set('v.value', sObj[fld.fieldAPIName]);
                }
            }
            else if(sObj)
            {
                // Client Note: "If we search an account and the account is not found, when creating the account pre-populate the account name and street used in the search"
                if(fld.fieldAPIName == 'Name')
                {
                    sObj[fld.fieldAPIName] = component.get("v.accountName");
                    component.set('v.sObj', sObj);
                }

                component.set('v.value', sObj[fld.fieldAPIName]);
            }
        }
	},
	
	valueChanged : function(component, event, helper) {
		var sObj = component.get('v.sObj');
        var val = component.get('v.value');
        var fld = component.get('v.field');
		
        var valStreet = component.get('v.valueStreet');
        var valState = component.get('v.valueState');
        var valCity = component.get('v.valueCity');
        var valPostalCode = component.get('v.valuePostalCode');
        var valStateCode = component.get('v.valueStateCode');
        var fldStreet = component.get('v.fieldStreet');
        var fldState = component.get('v.fieldState');
        var fldCity = component.get('v.fieldCity');
        var fldPostalCode = component.get('v.fieldPostalCode');
        var fldStateCode = component.get('v.fieldStateCode');
		
        var valTitle = component.get('v.valueTitle');
        var valFirstName = component.get('v.valueFirstName');
        var valMiddleName = component.get('v.valueMiddleName');
        var valLastName = component.get('v.valueLastName');
        var fldTitle = component.get('v.fieldTitle');
        var fldFirstName = component.get('v.fieldFirstName');
        var fldMiddleName = component.get('v.fieldMiddleName');
        var fldLastName = component.get('v.fieldLastName');

        if(sObj)
		{ 
			if(fld.fieldType == 'ADDRESS' && (fld.fieldAPIName).indexOf("Address") !== -1)
            {
                if(fldStreet !== undefined)
                    sObj[fldStreet] = valStreet;
                if(fldCity !== undefined)
                    sObj[fldCity] = valCity;
                if(fldPostalCode !== undefined)
                    sObj[fldPostalCode] = valPostalCode;
                if(fldState !== undefined)
                    sObj[fldState] = valState;
                if(fldStateCode !== undefined)
                    sObj[fldStateCode] = valStateCode;
            } 
            else if (fld.fieldAPIName == 'Name' && component.get('v.forPersonAccount') == 'true')
            {
                if(fldTitle !== undefined)
                    sObj[fldTitle] = valTitle;
                if(fldFirstName !== undefined)
                    sObj[fldFirstName] = valFirstName;
                if(fldMiddleName !== undefined)
                    sObj[fldMiddleName] = valMiddleName;
                if(fldLastName !== undefined)
                    sObj[fldLastName] = valLastName;
            }
            else 
            {
                var errorFound = false;
                var cType = component.get("v.ctrlType");

                // validate the email and phone input before saving it to the main sObject
                if(cType == 'EMAIL' && helper.emailIsValid(val) == false)
                {
                    var messageType = "error";
                    var messageTitle = "Incorrect email format!";
                    var messageContent = 'Please insert a valid email address.';
                    var mode = "sticky";

                    helper.showToastMessage(messageType, messageTitle, messageContent, mode);

                   errorFound = true;
                }
                else if(cType == 'PHONE' && helper.phoneIsValid(val) == false)
                {
                    var messageType = "error";
                    var messageTitle = "Incorrect phone format!";
                    var messageContent = 'Please insert a valid phone number.';
                    var mode = "sticky";

                    helper.showToastMessage(messageType, messageTitle, messageContent, mode);

                   errorFound = true;
                }

                if(errorFound == false)
                {
                    sObj[fld.fieldAPIName] = val;
                }
                else 
                {
                    sObj[fld.fieldAPIName] = null;
                }                
            }
                
			component.set('v.sObj', sObj);
		}
	},
	
	dateValueChanged : function(component, event, helper) 
    {
		var val = component.get('v.value');
		var sObj = component.get('v.sObj');
		var fld = component.get('v.field');
		
		if(sObj)
		{
			sObj[fld.fieldAPIName] = new Date(val);
			
			component.set('v.sObj', sObj);
		}
	}
})