({
  getLicenseTypes: function (component) {
    const _self = this;
    var accountId = component.get("v.accountId");
    var action = component.get("c.getLicenseTypes");
    action.setParams({ accountId: accountId });
    this.execute(action).then(
      $A.getCallback(function (response) {
        var responseStr = response.getReturnValue();
        _self.convertLicenseTypes(component, JSON.parse(responseStr));
      })
    );
  },

  cacheClassifications: function (component) {
    var classifications = component.get("v.classifications");
    var selectedClassifications =
      component.get("v.chosenClassifications") || {};
    var selectedRecords = classifications.reduce(function (newList, record) {
      if (selectedClassifications[record.Id]) {
        newList.push(record);
      }
      return newList;
    }, []);
    component.set("v.selectedClassifications", selectedRecords);
  },
  gotoSearchAccount: function (component) {
    var originalAccountType = component.get("v.accountType");
    var accountType = component.get("v.accountType");
    var selectedLicenseType = component.get("v.selectedLicenseType");
    var fieldSetName = "PVLAccountSearchresults";
    if (selectedLicenseType) {
      var accountType = selectedLicenseType.AccountType__c;
      if (!accountType) {
        accountType = "Person Account";
      }
      if (accountType === "Person Account") {
        fieldSetName = "PVLPersonAccountSearchresults";
      }
    }
    if (originalAccountType !== accountType) {
      // To remove the selected account.
      component.set("v.accountValueMap", {});
      component.set("v.accounts", []);
    }
    component.set("v.accountType", accountType);
    component.find("accountSearch").getAccountFields(fieldSetName);
  },
  convertLicenseTypes: function (component, licenseTypes) {
    const licenseTypeOptions = licenseTypes.reduce(function (
      newList,
      licenseType
    ) {
      newList.push({ label: licenseType.Name, value: licenseType.Id });
      return newList;
    },
    []);
    component.set("v.licenseTypeOptions", licenseTypeOptions);
    component.set("v.licenseTypes", licenseTypes);
  },
  getClassifications: function (component, licenseTypeId) {
    var action = component.get("c.getClassifications");
    action.setParams({ licenseTypeId: licenseTypeId });
    return this.execute(action).then(
      $A.getCallback(function (response) {
        var valueStr = response.getReturnValue();
        var classifications = JSON.parse(valueStr);
        return classifications;
      })
    );
  },
  getSelectedAccount: function (component) {
    var selectedAccount = {};
    var accountValueMap = component.get("v.accountValueMap");
    if (accountValueMap) {
      var accountIds = Object.keys(accountValueMap);
      accountIds.forEach(function (sglAccountId) {
        if (accountValueMap[sglAccountId]) {
          selectedAccount.Id = sglAccountId;
        }
      });
      component.set("v.selectedAccount", selectedAccount);
    }
  },
  keyCheck: function (component, key, helper) {
    if (key == 13) {
      this.next(component);
      var licenseTypeId = component.get("v.licenseTypeId");
      this.getClassifications(component, licenseTypeId);
    }
  },
  next: function (component) {
    var _self = this;
    var step = component.get("v.step");
    if (step === 0) {
      var licenseTypeId = component.get("v.licenseTypeId");
      component.set("v.selectedClassifications", []);
      var selectedLicenseTypes = component
        .get("v.licenseTypes")
        .filter(function (item) {
          return item.Id === licenseTypeId;
        });
        let businessLayout, personLayout;
        component.get("v.licenseTypes").forEach(licenseType => {
          if(licenseType.AccountPageLayout__c && licenseType.AccountPageLayout__c.indexOf('Person') !== -1) {
            personLayout = licenseType.AccountPageLayout__c;
          } else if(licenseType.AccountPageLayout__c && licenseType.AccountPageLayout__c.indexOf('Business') !== -1) {
            businessLayout = licenseType.AccountPageLayout__c;
          }
        });
      const typeValue = component.get("v.typeValue");
      if (selectedLicenseTypes && selectedLicenseTypes.length) {
        
        // var accountLayout = selectedLicenseTypes[0].AccountPageLayout__c;
        if(selectedLicenseTypes[0].AccountType__c && selectedLicenseTypes[0].AccountType__c.indexOf('Business') !== -1) {
          component.set("v.selectedAccountPageLayout", businessLayout);
        } else {
          component.set("v.selectedAccountPageLayout", personLayout);
        }
        
      }
      if(typeValue === "ADDP - Additional Special Privilege") {
        selectedLicenseTypes[0].ApplicationRecordType__c = 'PVL - ADDP';
      } else if (typeValue === "ADDC - Additional Class") { 
        selectedLicenseTypes[0].ApplicationRecordType__c = 'PVL - ADDC';
      }

      if (licenseTypeId && typeValue) {
        if(typeValue === "ADDP - Additional Special Privilege") {
          component.set("v.classifications", []);
          component.set("v.step", 2);
          _self.gotoSearchAccount(component);
        } else {
          _self
          .getClassifications(component, licenseTypeId)
          .then(function (classifications) {
            if (classifications && classifications.length) {
              component.set("v.classifications", classifications);
              component.set("v.step", 1);
            } else {
              component.set("v.classifications", []);
              component.set("v.step", 2);
              _self.gotoSearchAccount(component);
            }
          });
        }
        
      } else {
        _self.logError(component, "Please select a valid license type.");
      }
    } else if (step === 1) {
      _self.cacheClassifications(component);
      component.set("v.step", 2);
      _self.gotoSearchAccount(component);
    } else if (step === 2) {
      component.find("accountSearch").submit();

      //_self.getSelectedAccount(component);
      //var selectedAccount = component.get("v.selectedAccount");
      //if(selectedAccount && selectedAccount.Id) {
      //    component.set("v.step", 3);
      // } else {
      //    _self.logError(component, "Please select a valid Account.");
      // }
    }
  },
  extractAttributesFromURL: function (component) {
    var pageReference = component.get("v.pageReference");
    console.log("PageReference : " + JSON.stringify(pageReference));
    if (
      pageReference &&
      pageReference.state &&
      pageReference.state.c__accountId
    ) {
      // Component opened from the Hyperlink formula field in the details page....
      // so setting the required attributes from the url query parameters which is passed.
      component.set("v.accountId", pageReference.state.c__accountId);
      component.set("v.fromAccount", true);
    }
  }
});