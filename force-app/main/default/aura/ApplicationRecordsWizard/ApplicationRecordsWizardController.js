({
  doInit: function (component, event, helper) {
    helper.extractAttributesFromURL(component);
    var key;
    helper.getLicenseTypes(component);
    window.addEventListener(
      "keydown",
      function (e) {
        key = e.which || e.keyCode;
        if (key === 13) {
          if (component.get("v.Spinner")) {
            return;
          }
          if (component.get("v.step") === 3) {
            var applicationCreationCmp = component.find(
              "applicationRecordCreation"
            );
            applicationCreationCmp.submit();
          } else {
            //var cmp =component.find("div1").getElement();
            var cmpEvent = component.getEvent("Screen");
            if (cmpEvent) {
              cmpEvent.setParams({
                nextScreen: "A component event fired me. "
              });
              cmpEvent.fire();
            }
          }
        }
      },
      true
    );
  },

  findLicenseType: function (component, event, helper) {
    var licenseTypeId = component.get("v.licenseTypeId");
    if (!licenseTypeId) {
      component.set("v.selectedLicenseType", null);
      return;
    }
    var licenseTypes = component.get("v.licenseTypes");
    const selectedLicenseTypes = licenseTypes.filter(function (licenseType) {
      return licenseType.Id === licenseTypeId;
    });
    if (selectedLicenseTypes.length) {
      component.set("v.selectedLicenseType", selectedLicenseTypes[0]);
    } else {
      component.set("v.selectedLicenseType", null);
    }
  },
  notifySaveComplete: function (component, event, helper) {
    var type = event.getParams().type;
    if (type === "Account Saved") {
      var record = event.getParams().payload.record;
      helper.getSelectedAccount(component);
      component.set("v.selectedAccount", record);
      var selectedAccount = component.get("v.selectedAccount");
      if (selectedAccount && selectedAccount.Id) {
        helper.getLicenseTypes(component);
        component.set("v.step", 3);
      } else {
        helper.logError(component, "Please select a valid Account.");
      }
    }
  },
  cancel: function (component, event, helper) {
    const accountId = component.get("v.accountId");
    component.set("v.step", 0);
    component.set("v.selectedLicenseType", null);
    component.set("v.selectedClassifications", null);
    component.set("v.accountId", null);
    component.set("v.licenseTypeOptions", null);
    component.set("v.licenseTypes", null);

    if (component.get("v.fromAccount")) {
      window.location.href = "/lightning/r/Account/" + accountId + "/view";
    } else {
      window.location.href =
        "/lightning/o/Application__c/list?filterName=Recent";
    }
  },
  previous: function (component, event, helper) {
    var step = component.get("v.step");
    if (step === 1) {
      component.set("v.step", 0);
    } else if (step === 2) {
      var classifications = component.get("v.classifications");
      if (classifications && classifications.length > 0) {
        component.set("v.step", 1);
      } else {
        component.set("v.step", 0);
      }
    } else if (step === 3) {
      component.set("v.step", 2);
    }
  },
  next: function (component, event, helper) {
    helper.next(component);
  },
  submit: function (component, event, helper) {
    var applicationCreationCmp = component.find("applicationRecordCreation");
    applicationCreationCmp.submit();
  },

  noenter: function (event) {
    if (window.event) {
      key = window.event.keyCode; //IE
    } else {
      key = e.which; //firefox
    }
    if (key == 13) {
      var ele = document.getElementById(
        "contactMergePage:searchForm:searchButton"
      );
      ele.click();
      return false;
    } else {
      return true;
    }
  },

  // this function automatic call by aura:waiting event  <!--psy-->
  showSpinner: function (component, event, helper) {
    // make Spinner attribute true for display loading spinner
    component.set("v.Spinner", true);
  },

  // this function automatic call by aura:doneWaiting event   <!--psy-->
  hideSpinner: function (component, event, helper) {
    // make Spinner attribute to false for hide loading spinner
    component.set("v.Spinner", false);
  }
});