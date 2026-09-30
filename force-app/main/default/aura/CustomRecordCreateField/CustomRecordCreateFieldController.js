({
  doInit: function (component, event, helper) {
    var fld = component.get("v.field");

    if (
      fld.fieldType == "ADDRESS" &&
      fld.fieldAPIName.indexOf("Address") !== -1
    ) {
      var strStreet = fld.fieldAPIName.replace("Address", "Street");
      var strCity = fld.fieldAPIName.replace("Address", "City");
      var strPostalCode = fld.fieldAPIName.replace("Address", "PostalCode");
      var strState = fld.fieldAPIName.replace("Address", "State");
      var strStateCode = fld.fieldAPIName.replace("Address", "StateCode");
      var strCountry = fld.fieldAPIName.replace("Address", "Country");

      component.set("v.fieldStreet", strStreet);
      component.set("v.fieldCity", strCity);
      component.set("v.fieldPostalCode", strPostalCode);
      component.set("v.fieldState", strState);
      component.set("v.fieldStateCode", strStateCode);
    }
    var fldStreet = component.get("v.fieldStreet");
    var fldCity = component.get("v.fieldCity");
    var fldPostalCode = component.get("v.fieldPostalCode");
    var fldState = component.get("v.fieldState");
    var fldStateCode = component.get("v.fieldStateCode");
    //var fldCountry = 'USA';

    console.log("fldStateCode ====>" + fldStateCode);
    /*
		address, anytype, base64, Combobox, DataCategoryGroupReference, EncryptedString, ID, MultiPicklist, Reference
		Boolean
		Time
		 */

    var cType = "READONLY";
    component.set("v.fieldType", fld.fieldType);
    if (fld.fieldIsCreatable) {
      if (fld.fieldType == "STRING" || fld.fieldType == "URL") {
        cType = "STRING";
      }

      if (fld.fieldType == "EMAIL") {
        cType = "EMAIL";
      }

      if (fld.fieldType == "PHONE") {
        cType = "PHONE";
      }

      if (
        fld.fieldType == "CURRENCY" ||
        fld.fieldType == "DOUBLE" ||
        fld.fieldType == "INTEGER" ||
        fld.fieldType == "PERCENT"
      ) {
        cType = "NUMBER";
      }
      if (fld.fieldType == "TEXTAREA") {
        cType = "TEXTAREA";
      }
      if (fld.fieldType == "PICKLIST") {
        cType = "PICKLIST";
      }
      if (fld.fieldType == "MULTIPICKLIST") {
        cType = "MULTIPICKLIST";
      }
      if (fld.fieldType == "DATETIME") {
        cType = "DATETIME";
      }
      if (fld.fieldType == "DATE") {
        cType = "DATE";
      }
      if (fld.fieldType == "BOOLEAN") {
        cType = "BOOLEAN";
      }
      if (fld.fieldType == "REFERENCE") {
        cType = "REFERENCE";
      }
    }
    if (fld.fieldType == "ADDRESS") {
      cType = "ADDRESS";
    }

    var sObj = component.get("v.sObj");
    var recordTypeName = component.get("v.recordTypeName");
    component.set("v.ctrlType", cType);
    var sObjectName = component.get("v.sObjectName");
    if (cType == "PICKLIST" && recordTypeName && sObjectName) {
      var action = component.get("c.getPickListValuesIntoList");
      action.setParams({
        objectType: sObjectName,
        selectedField: fld.fieldAPIName,
        recordTypeName: component.get("v.recordTypeName")
      });
      action.setCallback(this, function (response) {
        if (response.getState() === "SUCCESS") {
          var listStr = response.getReturnValue();
          var listOption = JSON.parse(listStr);
          fld.piclistOptions = listOption.values;
          let defaultValue = "";
          component.set("v.picklistValues", listOption.values);
          if (listOption.defaultValue) {
            defaultValue = listOption.defaultValue.value;
          }

          component.set("v.value", defaultValue);
          sObj[fld.fieldAPIName] = defaultValue;
          component.set("v.sObj", sObj);
        }
      });
      $A.enqueueAction(action);
    } else if (cType === "PICKLIST") {
      component.set("v.picklistValues", fld.piclistOptions);
    }
    if (cType != "ADDRESS") {
      var value = sObj[fld.fieldAPIName];
      if (
        (!value || !value.length) &&
        component.get("v.getDefaultValue") == true
      ) {
        component.set("v.value", fld.defaultValue);
        sObj[fld.fieldAPIName] = fld.defaultValue;
        component.set("v.value", sObj[fld.fieldAPIName]);
      } else if (sObj) {
        component.set("v.value", sObj[fld.fieldAPIName]);
      }
    } else {
      console.log("test" + fld.statesOptions);
      if (
        component.get("v.getDefaultValue") == true &&
        fld.defaultValue != null
      ) {
        component.set("v.valueStreet", fld.defaultValue.street);
        component.set("v.valueCity", fld.defaultValue.city);
        component.set("v.valuePostalCode", fld.defaultValue.postalCode);
        component.set("v.valueState", fld.defaultValue.state);
        component.set("v.valueStateCode", fld.defaultValue.stateCode);
        //component.set('v.valueCountry', 'USA');

        sObj[fldStreet.fieldAPIName] = fld.defaultValue.street;
        sObj[fldCity.fieldAPIName] = fld.defaultValue.city;
        sObj[fldPostalCode.fieldAPIName] = fld.defaultValue.postalCode;
        sObj[fldState.fieldAPIName] = fld.defaultValue.state;
        sObj[fldStateCode.fieldAPIName] = fld.defaultValue.stateCode;
      } else if (sObj) {
        component.set("v.valueStreet", sObj[fldStreet]);
        component.set("v.valueCity", sObj[fldCity]);
        component.set("v.valuePostalCode", sObj[fldPostalCode]);
        component.set("v.valueState", sObj[fldState]);
        component.set("v.valueStateCode", sObj[fldStateCode]);
        component.set("v.valueCountry", "USA");
      }
    }
  },

  valueChanged: function (component, event, helper) {
    var sObj = component.get("v.sObj");
    var val = component.get("v.value");
    var fld = component.get("v.field");

    var valStreet = component.get("v.valueStreet");
    var valState = component.get("v.valueState");
    var valCity = component.get("v.valueCity");
    var valPostalCode = component.get("v.valuePostalCode");
    var valStateCode = component.get("v.valueStateCode");
    console.log("1valStreet ====>" + valStreet);
    var fldStreet = component.get("v.fieldStreet");
    var fldState = component.get("v.fieldState");
    var fldCity = component.get("v.fieldCity");
    var fldPostalCode = component.get("v.fieldPostalCode");
    var fldStateCode = component.get("v.fieldStateCode");
    console.log("1fldStreet ====>" + fldStreet);

    if (sObj) {
      if (
        fld.fieldType == "ADDRESS" &&
        fld.fieldAPIName.indexOf("Address") !== -1
      ) {
        if (fldStreet !== undefined) sObj[fldStreet] = valStreet;
        if (fldCity !== undefined) sObj[fldCity] = valCity;
        if (fldPostalCode !== undefined) sObj[fldPostalCode] = valPostalCode;
        if (fldState !== undefined) sObj[fldState] = valState;
        if (fldStateCode !== undefined) sObj[fldStateCode] = valStateCode;

        //sObj[fldCountry] = 'USA';
      } else if (fld.fieldType == "DATE") {
        var inputCmp = event.getSource();
        val = $A.localizationService.formatDate(val, "YYYY-MM-DD");

        sObj[fld.fieldAPIName] = val;
        if (val === "Invalid Date") {
          inputCmp.set("v.errors", [{ message: "The date is invalid" }]);
        } else {
          inputCmp.set("v.errors", null);
        }
      } else {
        var errorFound = false;
        var cType = component.get("v.ctrlType");

        // validate the email and phone input before saving it to the main sObject
        if (cType == "EMAIL" && helper.emailIsValid(val) == false) {
          var messageType = "error";
          var messageTitle = "Incorrect email format!";
          var messageContent = "Please insert a valid email address.";
          var mode = "sticky";

          helper.showToastMessage(
            messageType,
            messageTitle,
            messageContent,
            mode
          );

          errorFound = true;
        } else if (cType == "PHONE" && helper.phoneIsValid(val) == false) {
          var messageType = "error";
          var messageTitle = "Incorrect phone format!";
          var messageContent = "Please insert a valid phone number.";
          var mode = "sticky";

          helper.showToastMessage(
            messageType,
            messageTitle,
            messageContent,
            mode
          );

          errorFound = true;
        }

        if (errorFound == false) {
          component.set("v.isValid", true);
          sObj[fld.fieldAPIName] = val;
        } else {
          component.set("v.isValid", false);
          sObj[fld.fieldAPIName] = null;
        }
      }
      if (component.get("v.runOnCopyAddress")) {
        $A.enqueueAction(component.get("v.runOnCopyAddress"));
      }
      component.set("v.sObj", sObj);
    }
  },

  dateValueChanged: function (component, event, helper) {
    var val = component.get("v.value");
    var sObj = component.get("v.sObj");
    var fld = component.get("v.field");

    if (sObj) {
      sObj[fld.fieldAPIName] = new Date(val);

      component.set("v.sObj", sObj);
    }
  },
  // this function automatic call by aura:waiting event
  showSpinner: function (component, event, helper) {
    // make Spinner attribute true for display loading spinner
    component.set("v.Spinner", true);
  },

  // this function automatic call by aura:doneWaiting event
  hideSpinner: function (component, event, helper) {
    // make Spinner attribute to false for hide loading spinner
    component.set("v.Spinner", false);
  }
});