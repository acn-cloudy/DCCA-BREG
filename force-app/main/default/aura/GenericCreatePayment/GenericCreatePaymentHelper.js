({
  getNecessaryInfo: function(component, event, helper) {
    var filingId = component.get("v.recordId");

    var action = component.get("c.getNecessaryInfoFromServer");

    action.setParams({
      filingId: filingId
    });

    action.setCallback(self, function(a) {
      if (a.getReturnValue().errorMessage == "") {
        component.set("v.serverResponse", a.getReturnValue());
        component.set(
          "v.FilingRecordType",
          a.getReturnValue().filingRecordType
        );

        // set the selected Application
        component.set(
          "v.selectedValue",
          component.get("v.serverResponse.applicationType")
        );

        helper.getUploadedFilesperRecordType(component, event, helper);
      } else {
        component.set("v.isMakingServerCall", false);

        var toastType = "error";
        var toastTitle = "Server Error";
        var toastMessage = a.getReturnValue().errorMessage;
        var toastMode = "sticky";

        helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      }
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  getInitialData: function(component, event, helper) {
    var filingRecordType = component.get("v.FilingRecordType");

    var action = component.get("c.getInitialDataFromServer");

    action.setParams({
      filingRecordType: filingRecordType
    });

    action.setCallback(self, function(a) {
      if (a.getReturnValue().errorMessage == "") {
        component.set("v.serverResponse", a.getReturnValue());
        component.set("v.isMakingServerCall", false);
      } else {
        component.set("v.isMakingServerCall", false);

        var toastType = "error";
        var toastTitle = "Server Error";
        var toastMessage = a.getReturnValue().errorMessage;
        var toastMode = "sticky";

        helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      }
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  getUploadedFilesperRecordType: function(component, event, helper) {
    var selectedValue = component.get("v.selectedValue");
    var filingRecordType = component.get("v.FilingRecordType");

    var action = component.get("c.getUploadedFilesperRecordTypeFromServer");

    action.setParams({
      applicationType: selectedValue,
      filingRecordType: filingRecordType
    });

    action.setCallback(self, function(a) {
      if (a.getReturnValue().errorMessage == "") {
        component.set("v.serverResponse.uploadedFilesWrapperList", a.getReturnValue().uploadedFilesWrapperList);

        var serverResponse = component.get('v.serverResponse'),
            otherDocumentCount = component.get('v.supportingDocumentsCount'),
        recordType = component.get('v.FilingRecordType');
        if (serverResponse['uploadedFilesWrapperList'] &&
            (
                recordType === 'Franchise' ||
                    recordType === 'By Qualification' ||
                    recordType === 'Issuer Dealer' ||
                    recordType === 'Mutual Fund' ||
                    recordType === 'Regulation A' ||
                    recordType === 'Regulation D' ||
                    recordType === 'Small Company Offering Registration (SCOR)' ||
                    recordType === 'Model Accredited Investor' ||
                    recordType === 'Issuer Dealer Agent'

            )) {

          var otherDocumentCategory;
          for(var i =0; i < serverResponse['uploadedFilesWrapperList'].length; i++){
            if(serverResponse['uploadedFilesWrapperList'][i].fileDetails.toLowerCase() === 'other - supporting document'){
              otherDocumentCount += 1;
              otherDocumentCategory = serverResponse['uploadedFilesWrapperList'][i].fileCategory;
            }
          }

          component.set('v.supportingDocumentsCount', otherDocumentCount);
          component.set('v.supportingDocumentCategory', otherDocumentCategory);
        }
        component.set("v.step", "3b");
        component.set("v.isMakingServerCall", false);
      } else {
        component.set("v.isMakingServerCall", false);

        var toastType = "error";
        var toastTitle = "Server Error";
        var toastMessage = a.getReturnValue().errorMessage;
        var toastMode = "sticky";

        helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      }
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  saveAfterUpload: function(component, event, helper) {
    var serverResponse = component.get("v.serverResponse");
    // don't send this list as we don't need them
    serverResponse.layoutWrapper = null;
    serverResponse.filingFieldsWrapperList = null;

    var action = component.get("c.saveAfterUploadOnServer");

    action.setParams({
      serverResponseString: JSON.stringify(serverResponse)
    });

    action.setCallback(self, function(a) {
      if (a.getReturnValue().errorMessage == "") {
        if (serverResponse.displayPayment == true) {
          if (component.get("v.serverResponse.paymentId")) {
            // Redirect to the Payment URL
            window.open(
              component.get("v.paymentPageURL") +
                "?pid=" +
                component.get("v.serverResponse.paymentId"),
              "Payment",
              "height=670,width=670"
            );

            // redirect to the newly created payment record
            var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
              recordId: component.get("v.serverResponse.filingId"), //paymentId
              slideDevName: "Detail"
            });
            navEvt.fire();
          } else {
            var toastType = "error";
            var toastTitle = "Server Error";
            var toastMessage = "No payment found for this filing record.";
            var toastMode = "sticky";

            helper.showToastMessage(
              toastType,
              toastTitle,
              toastMessage,
              toastMode
            );
          }
        } else {
          // redirect to the newly created payment record
          var navEvt = $A.get("e.force:navigateToSObject");
          navEvt.setParams({
            recordId: component.get("v.serverResponse.filingId"), //paymentId
            slideDevName: "Detail"
          });
          navEvt.fire();
        }
      } else {
        var toastType = "error";
        var toastTitle = "Server Error";
        var toastMessage = a.getReturnValue().errorMessage;
        var toastMode = "sticky";

        helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      }
      component.set("v.disableButton", false);
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  saveRecords: function(component, event, helper) {
    var filingRecordType = component.get("v.FilingRecordType");
    var serverResponse = component.get("v.serverResponse");
    var filingFieldsWrapperList = serverResponse.filingFieldsWrapperList;
    var newFiling = component.get("v.serverResponse.newFiling");
    var manFields = "";

    // check if all required fields, have value
    for (var i = 0; i < filingFieldsWrapperList.length; i++) {
      // if the field was mandatory
      if (
        filingFieldsWrapperList[i].fieldIsMandatory == true ||
        filingFieldsWrapperList[i].metadataRequired == true
      ) {
        // if no value was found
        if (
          newFiling[filingFieldsWrapperList[i].fieldAPIName] == null ||
          newFiling[filingFieldsWrapperList[i].fieldAPIName] == ""
        ) {
          if (manFields != "") {
            manFields += ", ";
          }

          manFields += filingFieldsWrapperList[i].metadataLabel;
        }
      }
    }
    let isFileUploadingValid = true;
    const fileUploaders = component.find("fileDetailUploader");
    const uploaders = fileUploaders ? (Array.isArray(fileUploaders) ? fileUploaders : [fileUploaders]) : [];
    if(uploaders.length) {
      isFileUploadingValid = uploaders.reduce((result, item) => 
        result && item.checkValid() 
      , true);
    }

    if (manFields != "") {
      component.set("v.isMakingServerCall", false);

      var toastType = "error";
      var toastTitle = "Required fields missing";
      var toastMessage = "The following fields are required: " + manFields;
      var toastMode = "sticky";

      helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);

      return false;
    } else if(!isFileUploadingValid) {
      var toastType = "error";
      var toastTitle = "Required fields missing";
      var toastMessage = "Please wait file upload completes.";
      var toastMode = "sticky";
      
      helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
    } else {
      // don't send this list as we don't need them
      serverResponse.layoutWrapper = null;
      serverResponse.filingFieldsWrapperList = null;
      var applicationType = component.get("v.selectedValue");

      var action = component.get("c.saveRecordsOnServer");

      action.setParams({
        serverResponseString: JSON.stringify(serverResponse),
        filingRecordType: filingRecordType,
        applicationType: applicationType
      });

      action.setCallback(self, function(a) {
        if (a.getReturnValue().errorMessage == "") {
          component.set(
            "v.serverResponse.filingId",
            a.getReturnValue().filingId
          );
          component.set(
            "v.serverResponse.filingAccountId",
            a.getReturnValue().filingAccountId
          );
          component.set(
            "v.serverResponse.paymentId",
            a.getReturnValue().paymentId
          );

          if (serverResponse.displayFiles == true) {
            // if u got here from step 3, it means that you have the 'displayFile' = true, thus advance to step 3b (Display File to Upload)
            helper.getUploadedFilesperRecordType(component, event, helper);
          } else if (serverResponse.displayPayment == true) {
            // Redirect to the Payment URL
            window.open(
              component.get("v.paymentPageURL") +
                "?pid=" +
                component.get("v.serverResponse.paymentId"),
              "Payment",
              "height=670,width=760"
            );

            // redirect to the newly created payment record
            var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
              recordId: component.get("v.serverResponse.filingId"),
              slideDevName: "Detail"
            });
            navEvt.fire();
          } else {
            // redirect to the newly created payment record
            var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
              recordId: component.get("v.serverResponse.filingId"),
              slideDevName: "Detail"
            });
            navEvt.fire();
          }
        } else {
          var toastType = "error";
          var toastTitle = "Server Error";
          var toastMessage = a.getReturnValue().errorMessage;
          var toastMode = "sticky";

          helper.showToastMessage(
            toastType,
            toastTitle,
            toastMessage,
            toastMode
          );
        }
      });

      // Enqueue the action
      $A.enqueueAction(action);
    }
  },

  getFilingMetadataInfo: function(component, event, helper) {
    var flowperRecordTypeId = component.get(
      "v.serverResponse.flowperRecordTypeId"
    );

    var action = component.get("c.getFilingMetadataInfoFromServer");

    action.setParams({
      flowperRecordTypeId: flowperRecordTypeId
    });

    action.setCallback(self, function(a) {
      if (a.getReturnValue().errorMessage == "") {
        var filingFieldsWrapperList = a.getReturnValue()
          .filingFieldsWrapperList;
        component.set(
          "v.serverResponse.filingFieldsWrapperList",
          a.getReturnValue().filingFieldsWrapperList
        );
        var skip = true;
        var newFiling = component.get("v.serverResponse.newFiling");
        for (var i = 0; i < filingFieldsWrapperList.length; i++) {
          if (filingFieldsWrapperList[i].metadataEditable) skip = false;
          else {
            newFiling[filingFieldsWrapperList[i].fieldAPIName] =
              filingFieldsWrapperList[i].metadataDefaultValue;
          }
        }
        component.set("v.serverResponse.newFiling", newFiling);

        if (skip) {
          component.set("v.isMakingServerCall", true);
          helper.saveRecords(component, event, helper);
        } else {
          component.set("v.step", "3");
          component.set("v.isMakingServerCall", false);
        }
      } else {
        component.set("v.isMakingServerCall", false);

        var toastType = "error";
        var toastTitle = "Server Error";
        var toastMessage = a.getReturnValue().errorMessage;
        var toastMode = "sticky";

        helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      }
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  getAccountLayoutInfo: function(component, event, helper) {
    var isPersonAccount = component.get("v.serverResponse.isPersonAccount");
    var isBusinessAccount = component.get("v.serverResponse.isBusinessAccount");

    var action = component.get("c.getAccountLayoutInfoFromServer");

    action.setParams({
      isPersonAccount: isPersonAccount,
      isBusinessAccount: isBusinessAccount
    });

    action.setCallback(self, function(a) {
      var serverResponse = component.get("v.serverResponse");
      serverResponse.layoutWrapper = a.getReturnValue().layoutWrapper;
      serverResponse.layoutWrapper.sections.forEach(section => {
        section.fields.forEach(field => {
          if (field.field1) {
            if (field.field1.fieldAPIName === "Name") {
              field.field1.fieldLabel =
                serverResponse.accountNameLabel || field.field1.fieldLabel;
            }
          }
          if (field.field2) {
            if (field.field2.fieldAPIName === "Name") {
              field.field2.fieldLabel =
                serverResponse.accountNameLabel || field.field2.fieldLabel;
            }
          }
        });
      });
      serverResponse.createdAccount.FirstName = component.get("v.firstName");
      serverResponse.createdAccount.LastName = component.get("v.lastName");
      serverResponse.createdAccount.PersonEmail = component.get("v.email");
      serverResponse.createdAccount.BillingStreet = component.get(
        "v.streetName"
      );
      component.set("v.serverResponse", serverResponse);

      component.set("v.step", "2b");
      component.set("v.isMakingServerCall", false);
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  // return 'true' if all the required fields are completed, else 'false' and an error message to notify the end-user
  checkRequiredFields: function(component, event, helper) {
    var serverResponse = component.get("v.serverResponse");
    var sections = serverResponse.layoutWrapper.sections;
    var createdAccount = serverResponse.createdAccount;

    var isPersonAccount = component.get("v.serverResponse.isPersonAccount");

    var manFields = "";

    for (var i = 0; i < sections.length; i++) {
      var fields = sections[i].fields;

      for (var j = 0; j < fields.length; j++) {
        // if the current section has two collumns
        if (sections[i].columns == 2) {
          // check field1
          if (
            fields[j].field1 != null &&
            fields[j].field1 !== undefined &&
            fields[j].field1.fieldAPIName == "Name" &&
            isPersonAccount
          ) {
            if (
              createdAccount["LastName"] == null ||
              createdAccount["LastName"] === "" ||
              createdAccount["LastName"] === undefined
            ) {
              if (manFields != "") {
                manFields += ", ";
              }

              manFields += "Contact Name";
            }
          } else if (
            fields[j].field1 != null &&
            fields[j].field1 !== undefined &&
            (createdAccount[fields[j].field1.fieldAPIName] == null ||
              createdAccount[fields[j].field1.fieldAPIName] === "" ||
              createdAccount[fields[j].field1.fieldAPIName] === undefined) &&
            fields[j].field1.fieldIsMandatory
          ) {
            if (manFields != "") {
              manFields += ", ";
            }

            manFields += fields[j].field1.fieldLabel;
          }

          // check field2
          if (
            fields[j].field2 != null &&
            fields[j].field2 !== undefined &&
            fields[j].field2.fieldAPIName == "Name" &&
            isPersonAccount
          ) {
            if (
              createdAccount["LastName"] == null ||
              createdAccount["LastName"] === "" ||
              createdAccount["LastName"] === undefined
            ) {
              if (manFields != "") {
                manFields += ", ";
              }

              manFields += "Contact Name";
            }
          } else if (
            fields[j].field2 != null &&
            fields[j].field2 !== undefined &&
            (createdAccount[fields[j].field2.fieldAPIName] == null ||
              createdAccount[fields[j].field2.fieldAPIName] === "" ||
              createdAccount[fields[j].field2.fieldAPIName] === undefined) &&
            fields[j].field2.fieldIsMandatory
          ) {
            if (manFields != "") {
              manFields += ", ";
            }

            manFields += fields[j].field2.fieldLabel;
          }
        }
        // if it has only one
        else {
          // check only field1
          if (
            fields[j].field1 != null &&
            fields[j].field1 !== undefined &&
            fields[j].field1.fieldAPIName == "Name" &&
            isPersonAccount
          ) {
            if (
              createdAccount["LastName"] == null ||
              createdAccount["LastName"] === "" ||
              createdAccount["LastName"] === undefined
            ) {
              if (manFields != "") {
                manFields += ", ";
              }

              manFields += "Contact Name";
            }
          } else if (
            fields[j].field1 != null &&
            fields[j].field1 !== undefined &&
            (createdAccount[fields[j].field1.fieldAPIName] == null ||
              createdAccount[fields[j].field1.fieldAPIName] === "" ||
              createdAccount[fields[j].field1.fieldAPIName] === undefined) &&
            fields[j].field1.fieldIsMandatory
          ) {
            if (manFields != "") {
              manFields += ", ";
            }

            manFields += fields[j].field1.fieldLabel;
          }
        }
      }
    }

    if (manFields != "") {
      var toastType = "error";
      var toastTitle = "Required fields missing";
      var toastMessage = "The following fields are required: " + manFields;
      var toastMode = "sticky";

      helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);

      return false;
    } else {
      return true;
    }
  },

  searchPersonAccounts: function(component, event, helper) {
    var firstName = component.get("v.firstName");
    var lastName = component.get("v.lastName");
    var email = component.get("v.email");

    var action = component.get("c.searchPersonAccountsFromServer");

    action.setParams({
      firstName: firstName,
      lastName: lastName,
      email: email
    });

    action.setCallback(self, function(a) {
      component.set(
        "v.serverResponse.foundAccount",
        a.getReturnValue().foundAccount
      );
      component.set(
        "v.serverResponse.searchedAccount",
        a.getReturnValue().searchedAccount
      );
      component.set("v.searchAccount", true);
      component.set("v.isMakingServerCall", false);
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  searchBusinessAccounts: function(component, event, helper) {
    var accountName = component.get("v.accountName");
    var accountCRD = component.get("v.accountCRD");
    var accountDBA = component.get("v.accountDBA");
    var streetName = component.get("v.streetName");

    if (!accountName) {
      var toastType = "error";
      var toastTitle = "Missing fields";
      var toastMessage = "Please fill in the name of the firm to continue";
      var toastMode = "sticky";

      helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      return;
    }
      //Updated by Rumina
    /*  
    if (!streetName && !accountCRD && !accountDBA) {
      var toastType = "error";
      var toastTitle = "Missing fields";
      var toastMessage = "Please fill in either the CRD# or DBA or Street";
      var toastMode = "sticky";

      helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      return;
    }
    */
    component.set("v.isMakingServerCall", true);

    var action = component.get("c.searchBusinessAccountsFromServer");

    action.setParams({
      accountName: accountName,
      accountCRD: accountCRD,
      accountDBA: accountDBA,
      streetName: streetName
    });

    action.setCallback(self, function(a) {
      component.set(
        "v.serverResponse.foundAccount",
        a.getReturnValue().foundAccount
      );
		/*        
      component.set(
        "v.serverResponse.searchedAccount",
        a.getReturnValue().searchedAccount
      );
      */
        var accountList = a.getReturnValue().searchedAccounts;
        component.set("v.serverResponse.searchedAccounts", accountList);
        var pageSize = component.get("v.pageSize");
        component.set("v.totalRecords", accountList.length);
        component.set("v.startPage",0);
        component.set("v.endPage",pageSize-1);
                
        var PaginationList = [];
        for(var i=0; i< pageSize; i++){
            if(accountList.length> i){
                PaginationList.push(accountList[i]);
            }
        }
		component.set("v.serverResponse.accountList", PaginationList);
        
      component.set("v.searchAccount", true);
      component.set("v.isMakingServerCall", false);
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },
          
  //PacPoint-RdG240220 - Updated for Case 6778
  next : function(component, event){
        var accountList = component.get("v.serverResponse.searchedAccounts");
        var end = component.get("v.endPage");
        var start = component.get("v.startPage");
        var pageSize = component.get("v.pageSize");
        var Paginationlist = [];
        var counter = 0;
        for(var i=end+1; i<end+pageSize+1; i++){
            if(accountList.length > i){
                Paginationlist.push(accountList[i]);
            }
            counter ++ ;
        }
        start = start + counter;
        end = end + counter;
        component.set("v.startPage",start);
        component.set("v.endPage",end);
        component.set("v.serverResponse.accountList", Paginationlist);
    },
          
    previous : function(component, event){
        var accountList = component.get("v.serverResponse.searchedAccounts");
        var end = component.get("v.endPage");
        var start = component.get("v.startPage");
        var pageSize = component.get("v.pageSize");
        var Paginationlist = [];
        var counter = 0;
        for(var i= start-pageSize; i < start ; i++){
            if(i > -1){
                Paginationlist.push(accountList[i]);
                counter ++;
            }else{
                start++;
            }
        }
        start = start - counter;
        end = end - counter;
        component.set("v.startPage",start);
        component.set("v.endPage",end);
        component.set('v.serverResponse.accountList', Paginationlist);
    },
  //PacPoint-RdG240220 - Updated for Case 6778    
  getMetadataInfo: function(component, event, helper) {
    var selectedValue = component.get("v.selectedValue");
    var filingRecordType = component.get("v.FilingRecordType");

    var action = component.get("c.getMetadataInfoFromServer");

    action.setParams({
      applicationType: selectedValue,
      filingRecordType: filingRecordType
    });

    action.setCallback(self, function(a) {
      if (a.getReturnValue().errorMessage == "") {
        component.set("v.serverResponse", a.getReturnValue());
        component.set("v.step", "2");
        component.set("v.isMakingServerCall", false);
      } else {
        component.set("v.isMakingServerCall", false);

        var toastType = "error";
        var toastTitle = "Server Error";
        var toastMessage = a.getReturnValue().errorMessage;
        var toastMode = "sticky";

        helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
      }
    });

    // Enqueue the action
    $A.enqueueAction(action);
  },

  showToastMessage: function(type, title, message, mode) {
    var toastEvent = $A.get("e.force:showToast");
    toastEvent.setParams({
      type: type,
      title: title,
      message: message,
      mode: mode
    });
    toastEvent.fire();
  }
});