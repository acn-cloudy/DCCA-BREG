({
    validateABN : function (value) {

        var weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19],
            abn = value.replace(/[^\d]/, ''),
            result = false;

        // check length is 11 digits
        if (abn.length === 11) {

            // apply ato check method
            var sum = 0,
                weight;

            for (var index = 0; index <= weights.length - 1; index++) {
                weight = weights[index];
                digit = abn[index] - (index ? 0 : 1);
                sum += weight * digit;
            }

            result = sum % 89 === 0;
        }

        return result;
    },
    validateInput: function(component, inputCmp) {
       var value    = inputCmp.get("v.value") || component.get("v.value"); 
       var fieldminlength = component.get("v.fieldminlength");
        var fieldLabel = component.get("v.fieldLabel");
        var numonly = component.get("v.numericonly");
		var req = component.get("v.required");
 		var length = component.get("v.fieldlength");
        var specialchars = component.get("v.specialcharacters");
        var emailonly = component.get("v.emailonly");
        var Phoneonly = component.get("v.Phoneonly");
        var NoSpace = component.get("v.NoSpace");
        var NonZeroNumeric = component.get("v.NonZeroNumeric");
              
       	value = value || '';
		let fieldInfo = component.get("v.fieldInfo");
       
        if (req && (!value || value.trim()==''))
        {    var str = fieldLabel;
             str = str.endsWith(":") ? str.substring(0, str.length - 1) :str;
             component.set("v.errors", [{message: str + " is required"}]); // Set Error
        }
        else  if (length && value.length > length  && value.length)
        {
            component.set("v.errors", [{message:"Input maximum length is: " + length}]);
        }
         else  if (fieldminlength && length && value.length < fieldminlength && value.length)
        {
            component.set("v.errors", [{message:"Input minimum length is: " + fieldminlength}]);
        }
        else  if (isNaN(value) && numonly)
        {
            if(value) {
                component.set("v.errors", [{message:"Input not a number: " + value}]);
            }
        }
        else if((/[^a-zA-Z0-9]/.test(value) && specialchars)) {
            component.set("v.errors", [{message:"No Special Characters allowed"}]);
		}
        else if (value && value.length && emailonly && !/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/.test(value))
        {
            component.set("v.errors", [{message:"Not a valid email address"}]);
        }
        else if (Phoneonly && !/^(?:\+?(61))? ?(?:\((?=.*\)))?(0?[2-57-8])\)? ?(\d\d(?:[- ](?=\d{3})|(?!\d\d[- ]?\d[- ]))\d\d[- ]?\d[- ]?\d{3})$/.test(value) )
        {
            component.set("v.errors", [{message:"Not a valid Contact number."}]);
        }
       	else if (NoSpace && /\s/.test(value) )
        {
            component.set("v.errors", [{message:"Space not allowed."}]);
        }
        else if (NonZeroNumeric && !/^(?!0+$)[0-9]{0,10}$/.test(value) )
        {
            component.set("v.errors", [{message:"Should be greater than zero and decimal values not allowed. "}]);
        } else if (fieldInfo.Validation_ABN_Number__c && !this.validateABN(value)){
            component.set("v.errors", [{message:"ABN is invalid"}]);

        }else{ 
            component.set("v.errors", null);  
        }
        return component.get("v.errors") === null;
    }
})