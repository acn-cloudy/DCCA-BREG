({
  initiateRecordType: function(component, licenseType) {
    var _self = this;
    var action = component.get("c.getApplicationRecordTypes");
    action.setParams({ recordTypeName: licenseType.ApplicationRecordType__c });
    return _self.execute(action).then(
      $A.getCallback(function(response) {
        var recordTypes = JSON.parse(response.getReturnValue());
        if (recordTypes && recordTypes.length) {
          component.set("v.selectedRecordType", recordTypes[0]);
        }
        return "";
      })
    );
  },
  getType: function(component) {
    var _self = this;
    console.log("before get  licenseApplicationType :::   ");
    var action = component.get("c.licenseApplicationType");
    return _self.execute(action).then(
      $A.getCallback(function(response) {
        var licApplicationType = response.getReturnValue();
        console.log("licApplicationType :::   " + licApplicationType);
        if (licApplicationType && licApplicationType.length) {
          component.set("v.typeField", licApplicationType);
        }
        return "";
      })
    );
  },
  initiate: function(component) {
    var selectedLicenseType = component.get("v.selectedLicenseType");
    this.initiateRecordType(component, selectedLicenseType).then(function(res) {
      var selectedLicenseType = component.get("v.selectedLicenseType");
      var selectedRecordType = component.get("v.selectedRecordType");
      var selectedAccount = component.get("v.selectedAccount");
      //var defaultType = component.get("v.typeField");

      var sObj = component.get("v.sObj") || {};
      if (
        selectedLicenseType.ApplicationPageLayout__c &&
        selectedLicenseType.ApplicationPageLayout__c.length
      ) {
        component.set(
          "v.layoutName",
          selectedLicenseType.ApplicationPageLayout__c
        );
      }
      sObj["LicenseType__c"] = selectedLicenseType.Id;
      sObj["Type__c"] = component.get("v.typeField");
      //typeField
      sObj["Applicant__c"] = selectedAccount.Id;
      if (selectedRecordType) {
        sObj["RecordTypeId"] = selectedRecordType.Id;
      }
      component.set("v.recordTypeName", selectedRecordType.Name);
      component.set("v.sObj", sObj);
    });
  },
  checkDuplicateLicense: function(component, record) {
    var _self = this;
    var action = component.get("c.checkDuplicateLicense");
    component.set("v.record", record);
    action.setParams({
      record: JSON.stringify(record),
      fieldSetName: "WizardMatchingRecords"
    });
    this.execute(action).then(
      $A.getCallback(function(response) {
        let result = JSON.parse(response.getReturnValue());
        console.log("result", result);
        if (result.length) {
          component.set("v.existingLicenses", result);
        } else {
          _self.createApplication(component, record);
        }
      })
    );
  },
  getContactRecord: function(component) {
    var action = component.get("c.getContactRecord");
    action.setParams({ accountId: component.get("v.selectedAccount").Id });
    this.execute(action).then(
      $A.getCallback(function(response) {
        const contacts = JSON.parse(response.getReturnValue());
        if (contacts && contacts.length) {
          component.set("v.contact", contacts[0]);
        }
      })
    );
  },
  getDisplayFields: function(component) {
    var action = component.get("c.getFieldSetByName");
    action.setParams({ fieldSetName: "WizardMatchingRecords" });
    this.execute(action).then(
      $A.getCallback(function(response) {
        let options = JSON.parse(response.getReturnValue());
        const apiNames = options.reduce((li, option) => {
          li.push(option.name);
          return li;
        }, []);
        const apiLabels = options.reduce((li, option) => {
          li.push(option.label);
          return li;
        }, []);
        component.set("v.licenseHeaderNames", apiLabels);
        component.set("v.licenseFieldNames", apiNames);
      })
    );
  },
  createApplication: function(component, record) {
    var selectedClassifications = component.get("v.selectedClassifications");
    var action = component.get("c.createApplicationRecord");
    action.setParams({
      record: JSON.stringify(record),
      classificationsStr: JSON.stringify(selectedClassifications)
    });
    this.execute(action).then(
      $A.getCallback(function(response) {
        var result = JSON.parse(response.getReturnValue());
        if (result.status == "OK") {
          var navEvt = $A.get("e.force:navigateToSObject");
          navEvt.setParams({
            recordId: result.id
          });
          navEvt.fire();
          window.location.href =
            "/lightning/r/Application/" + result.id + "/view";
        }
      })
    );
  }
});