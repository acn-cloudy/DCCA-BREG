({
  execute: function (action) {
    return new Promise(function (resolve, reject) {
      action.setCallback(this, function (response) {
        var state = response.getState();
        if (state === "SUCCESS") {
          resolve(response);
        } else if (state === "ERROR") {
          reject(response);
        }
      });
      $A.enqueueAction(action);
    });
  },
  initiateData: function (component) {
    this.initiateContact(component);
    this.initiateCashier(component);
    let sObj = component.get("v.sObj");
    sObj = sObj || {};
    sObj.Event__c = "DFI Registration";
    component.set("v.sObj", sObj);
  },
  initiateContact: function (component) {
    var action = component.get("c.loadGenericContact");
    var contactId = component.get("v.contactId");
    action.setParams({ contactId: contactId });
    action.setCallback(this, function (response) {
      if (response.getState() === "SUCCESS") {
        component.set("v.contactRecord", response.getReturnValue());
      }
    });
    $A.enqueueAction(action);
  },
  initiateCashier: function (component) {
    var action = component.get("c.loadCashierCode");
    var codeId = component.get("v.cashierCodeId");
    action.setParams({ cashierCodeId: codeId });
    action.setCallback(this, function (response) {
      if (response.getState() === "SUCCESS") {
        component.set("v.cachierRecord", response.getReturnValue());
      }
    });
    $A.enqueueAction(action);
  },
  createSObj: function (component, sObj) {
    let _self = this,
      action = component.get("c.createSObject"),
      contactRecord = component.get("v.contactRecord"),
      cachierRecord = component.get("v.cachierRecord"),
      parentLookUpField = component.get("v.parentFieldApiName");

    component.set("v.executeOnce", true);
    action.setParams({
      sObj: sObj,
      contactStr: contactRecord,
      cashierStr: cachierRecord,
      parentLookUpField: parentLookUpField,
      division: component.get("v.division"),
      currencyCode: component.get("v.currencyCode")
    });

    _self
      .execute(action)
      .then(
        $A.getCallback(function (response) {
          console.log("response", response);
          component.set("v.paymentId", response.getReturnValue());
          _self.openPaymentPage(component);
          _self.checkPaymentStatus(component);
          component.set("v.executeOnce", false);
        })
      )
      .catch(function (response) {
        let errorMessage = response.getError()[0].message;
        _self.customErrorMessage(component, errorMessage);
        component.set("v.executeOnce", false);
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
          type: "error",
          title: "Error saving!",
          message: component.get("v.customMessage")
        });
        toastEvent.fire();
      });
  },
  createScript: function (component, transcript) {
    let _self = this;
    let action = component.get("c.createTranscript");
    let contactRecord = component.get("v.contactRecord");
    let cachierRecord = component.get("v.cachierRecord");
    component.set("v.executeOnce", true);
    action.setParams({
      transcriptStr: JSON.stringify(transcript),
      contactStr: contactRecord,
      cashierStr: cachierRecord,
      division: component.get("v.division"),
      currencyCode: component.get("v.currencyCode")
    });
    _self
      .execute(action)
      .then(
        $A.getCallback(function (response) {
          console.log("response", response);
          component.set("v.paymentId", response.getReturnValue());
          _self.openPaymentPage(component);
          _self.checkPaymentStatus(component);
          component.set("v.executeOnce", false);
        })
      )
      .catch(function (response) {
        let errorMessage = response.getError()[0].message;
        _self.customErrorMessage(component, errorMessage);
        component.set("v.executeOnce", false);
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
          type: "error",
          title: "Error saving!",
          message: component.get("v.customMessage")
        });
        toastEvent.fire();
      });
  },
  openPaymentPage: function (component) {
    component.set("v.showPayment", true);
    let paymentURL =
      component.get("v.paymentPageURL") +
      "?pid=" +
      component.get("v.paymentId");
    component.set("v.paymentURL", paymentURL);
    //Object.assign(document.createElement('a'), { target: '_blank', href: paymentURL}).click();
    window.open(paymentURL, "_blank");
  },
  showThanksLabel: function (component) {
    component.set("v.showThanks", true);
  },
  checkPaymentStatus: function (component) {
    let _self = this;
    let action = component.get("c.checkPaymentStatus");
    action.setParams({ paymentId: component.get("v.paymentId") });
    action.setCallback(this, function (response) {
      if (response.getState() === "SUCCESS") {
        _self.showThanksLabel(component);
      } else {
        _self.checkPaymentStatus(component);
      }
    });
    $A.enqueueAction(action);
  },
  customErrorMessage: function (component, message) {
    let errorMessage = message,
      toastEvent = $A.get("e.force:showToast");
    if (
      message !== null &&
      message.indexOf("FIELD_CUSTOM_VALIDATION_EXCEPTION") !== -1
    ) {
      errorMessage = message.split("FIELD_CUSTOM_VALIDATION_EXCEPTION, ")[1];
      errorMessage = errorMessage.split(": []")[0];
    }

    toastEvent.setParams({
      type: "error",
      title: "Failed!",
      message: errorMessage
    });
    toastEvent.fire();
  }
});