({
  doInit: function (component, event, helper) {
    // helper.getType(component);
    helper.initiate(component);
    helper.getDisplayFields(component);
    helper.getContactRecord(component);
  },
  submitToSave: function (component, event, helper) {
    component.find("application").save();
  },
  updateOnFiledValueChange: function (component, event, helper) {
    let sobj = component.get("v.sObj");
    if (sobj.CopyResidenceAddress__c) {
      const contact = component.get("v.contact").PersonContact;

      component
        .find("application")
        .find("field")
        .forEach(function (item) {
          if (
            item.get("v.field").fieldAPIName === "MailingStreet__c" &&
            contact.MailingStreet &&
            contact.MailingStreet.length
          ) {
            sobj.MailingStreet__c = contact.MailingStreet;
            item.set("v.value", contact.MailingStreet);
          }
          if (
            item.get("v.field").fieldAPIName === "MailingCity__c" &&
            contact.MailingCity &&
            contact.MailingCity.length
          ) {
            sobj.MailingCity__c = contact.MailingCity;
            item.set("v.value", contact.MailingCity);
          }
          if (
            item.get("v.field").fieldAPIName === "MailingState__c" &&
            contact.MailingStateCode &&
            contact.MailingStateCode.length
          ) {
            sobj.MailingState__c = contact.MailingStateCode;
            item.set("v.value", contact.MailingStateCode);
          }
          if (
            item.get("v.field").fieldAPIName === "MailingZipCode__c" &&
            contact.MailingPostalCode &&
            contact.MailingPostalCode.length
          ) {
            sobj.MailingZipCode__c = contact.MailingPostalCode;
            item.set("v.value", contact.MailingPostalCode);
          }
          if (
            item.get("v.field").fieldAPIName === "MailingCountry__c" &&
            contact.MailingCountry &&
            contact.MailingCountry.length
          ) {
            sobj.MailingCountry__c = contact.MailingCountry;

            item.set("v.value", contact.MailingCountry);
          }
        });
      component.set("v.sObj", sobj);
    }
  },
  saveRecord: function (component, event, helper) {
    if (component.get("v.executeOnce")) {
      return;
    }
    var type = event.getParams().type;
    if (type === "saveRecord") {
      var record = event.getParams().payload.record;
      // console.log("recordId", recordId);
      // Check if there is duplicate license.
      // call web service to check.
      helper.checkDuplicateLicense(component, record);

      // helper.createApplication(component, record);
      event.stopPropagation();
    }
  },
  proceedToCreate: function (component, event, helper) {
    var record = component.get("v.record");
    helper.createApplication(component, record);
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