({
  doInit: function(component, event, helper) {
    var sObj = component.get("v.sObj") || {};
    component.set("v.sObj", sObj);
    helper.loadLayout(component, event, helper);
  },

  saveRecord: function(component, event, helper) {
    var sObj = component.get("v.sObj");
    var layout = component.get("v.layout");
    var allIn = true;
    var hideNameField = component.get("v.hideNameField");
    var manFields = "";
    for (var i = 0; i < layout.sections.length; i++) {
      for (var j = 0; j < layout.sections[i].fields.length; j++) {
        if (
          layout.sections[i].fields[j].field1 != null &&
          layout.sections[i].fields[j].field1.fieldIsMandatory &&
          layout.sections[i].fields[j].field1.fieldIsCreatable
        ) {
          if (
            layout.sections[i].fields[j].field1.fieldAPIName === "Name" &&
            hideNameField
          ) {
            continue;
          }
          if (
            sObj[layout.sections[i].fields[j].field1.fieldAPIName] == null ||
            sObj[layout.sections[i].fields[j].field1.fieldAPIName] == ""
          ) {
            if (manFields != "") manFields += ", ";
            manFields += layout.sections[i].fields[j].field1.fieldLabel;
            allIn = false;
          }
        }
        if (
          layout.sections[i].fields[j].field2 != null &&
          layout.sections[i].fields[j].field2.fieldIsMandatory &&
          layout.sections[i].fields[j].field2.fieldIsCreatable
        ) {
          if (
            layout.sections[i].fields[j].field2.fieldAPIName === "Name" &&
            hideNameField
          ) {
            continue;
          }
          if (
            sObj[layout.sections[i].fields[j].field2.fieldAPIName] == null ||
            sObj[layout.sections[i].fields[j].field2.fieldAPIName] == ""
          ) {
            if (manFields != "") manFields += ", ";
            manFields += layout.sections[i].fields[j].field2.fieldLabel;
            allIn = false;
          }
        }
      }
    }

    if (manFields != "") {
      // var toastEvent = $A.get("e.force:showToast");
      // toastEvent.setParams({
      // 	"type": "error",
      //     "title": "Required fields missing",
      //     "message": "The following fields are required: " + manFields
      // });
      // toastEvent.fire();
      helper.logError(
        component,
        "The following fields are required: " + manFields,
        "Required fields missing"
      );
    } else {
      var fields = component.find("field");
      var isValid = fields.reduce(function(isValid, item) {
        return isValid && item.get("v.isValid");
      }, true);
      if (isValid) {
        helper.saveRecord(component, event, helper);
      }
    }
  },
  saveStep2: function(component, event, helper) {
    const fileList = helper.createFileDetails(component);
        // Save files
        var action = component.get("c.saveFileDetails");
        action.setParams({fileDetails: JSON.stringify(fileList), recordTypeName: "SEB"});
        action.setCallback(this, function(res) {
            var state = res.getState();
            if (state === "SUCCESS") {
				var navEvt = $A.get("e.force:navigateToSObject");
                navEvt.setParams({
                    "recordId": component.get("v.recordId"),
                    "slideDevName": "details"
                });
                navEvt.fire();
            } 
        });
      $A.enqueueAction(action);
  },

  // this function automatic call by aura:waiting event
  showSpinner: function(component, event, helper) {
    // make Spinner attribute true for display loading spinner
    component.set("v.Spinner", true);
  },

  // this function automatic call by aura:doneWaiting event
  hideSpinner: function(component, event, helper) {
    // make Spinner attribute to false for hide loading spinner
    component.set("v.Spinner", false);
  }
});