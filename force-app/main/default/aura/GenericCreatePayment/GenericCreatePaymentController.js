({
    doInit: function(component, event, helper) {
        component.set("v.isMakingServerCall", true);
        
        //PacPoint-RdG240220 - Updated for Case 6778
        component.set('v.accountColumns', [
            { label: 'Account Name', fieldName: 'Name', type: 'text'},
            { label: 'DBA', fieldName: 'DBA__c', type: 'text'},
            { label: 'Billing Street', fieldName: 'BillingStreet', type: 'text'}
        ]);
        
        // check if we have a recordId in the URL (meaning that we got here by clicking the Upload Button)
        var currentUrl = window.location.href;
        var urlObject = new URL(currentUrl);
        var filingRecordId = urlObject.searchParams.get("recordId");
        
        // if no filingRecordId is found, apply the generic flow
        if (!filingRecordId) {
            helper.getInitialData(component, event, helper);
        }
        // else, apply the upload button flow
        else {
            component.set("v.recordId", filingRecordId);
            helper.getNecessaryInfo(component, event, helper);
        }
    },
    
    goToPaymentSection: function(component, event, helper) {
        component.set("v.isMakingServerCall", true);
        
        if (component.get("v.serverResponse.paymentId")) {
            // Redirect to the Payment URL
            window.location.replace(
                component.get("v.paymentPageURL") +
                "?pid=" +
                component.get("v.serverResponse.paymentId")
            );
        } else {
            var toastType = "error";
            var toastTitle = "Server Error";
            var toastMessage = "No payment found for this filing record.";
            var toastMode = "sticky";
            
            helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
        }
    },
    
    exitFromWizard: function(component, event, helper) {
        // redirect to the design given URL
        var eUrl = $A.get("e.force:navigateToURL");
        
        eUrl.setParams({
            url: component.get("v.redirectUrlAfterExit")
        });
        
        eUrl.fire();
    },
    
    saveAfterUpload: function(component, event, helper) {
        if(component.get("v.disableButton")) return;
        component.set("v.disableButton", true);
        var uploadedFilesWrapperList = component.get(
            "v.serverResponse.uploadedFilesWrapperList"
        );
        var allowToContinue = true;
        var allowGroupsToContinue = true;
        
        var groupMap = {};
        var groupNameToFileDetails = {};
        
        // initialize the 'groupNameToFileDetails' map
        for (var i = 0; i < uploadedFilesWrapperList.length; i++) {
            // if the curent upload is part of an upload group
            if (uploadedFilesWrapperList[i].uploadGroup) {
                groupNameToFileDetails[uploadedFilesWrapperList[i].uploadGroup] = "";
                groupMap[uploadedFilesWrapperList[i].uploadGroup] = false;
            }
        }
        
        // check if all required uploads, were uploaded
        for (var i = 0; i < uploadedFilesWrapperList.length; i++) {
            // if the curent upload is part of an upload group
            if (uploadedFilesWrapperList[i].uploadGroup) {
                // create a string with all the file details for each group
                groupNameToFileDetails[uploadedFilesWrapperList[i].uploadGroup] =
                    groupNameToFileDetails[uploadedFilesWrapperList[i].uploadGroup] +
                    ", " +
                    uploadedFilesWrapperList[i].fileDetails;
                
                // upload found for this current group
                if (
                    uploadedFilesWrapperList[i].contentDocumentId != null &&
                    uploadedFilesWrapperList[i].contentDocumentId !== ""
                ) {
                    groupMap[uploadedFilesWrapperList[i].uploadGroup] = true;
                }
            }
            // if the upload was mandatory
            else if (uploadedFilesWrapperList[i].isRequired === true) {
                // if no upload was found, throw error message and don't let them continue until they uploaded the mandatory file
                if (
                    (uploadedFilesWrapperList[i].fileUrl || uploadedFilesWrapperList[i].contentDocumentId) == null ||
                    (uploadedFilesWrapperList[i].fileUrl || uploadedFilesWrapperList[i].contentDocumentId) === ""
                ) {
                    allowToContinue = false;
                    break;
                }
            }
        }
        
        // check if all groups have at least one upload done
        for (var groupName in groupMap) {
            // if no upload was found for this current group
            if (groupMap[groupName] == false) {
                allowGroupsToContinue = false;
                
                var groupFileDetailList = groupNameToFileDetails[groupName].substr(1);
                
                var toastType = "error";
                var toastTitle = "Upload Required";
                var toastMessage =
                    "The following file details need at least one completed upload: " +
                    groupFileDetailList;
                var toastMode = "sticky";
                
                helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
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
        
        if (!isFileUploadingValid) {
            component.set("v.disableButton", false);
            var toastType = "error";
            var toastTitle = "Required fields missing";
            var toastMessage = "Please wait file upload completes.";
            var toastMode = "sticky";
            
            helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
        } else if (allowToContinue == true && allowGroupsToContinue == true) {
            helper.saveAfterUpload(component, event, helper);
        } else if (allowToContinue == false) {
            component.set("v.disableButton", false);
            var toastType = "error";
            var toastTitle = "Upload Required";
            var toastMessage =
                "Please upload all the required documents identified with an *";
            var toastMode = "sticky";
            
            helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
        }
    },
    
    saveRecords: function(component, event, helper) {
        component.set("v.isMakingServerCall", true);
        
        helper.saveRecords(component, event, helper);
    },
    franchiseAddMoreSuppDocsUpload: function (cmp) {
        var serverResponse = cmp.get('v.serverResponse'),
            uploadFileWrappers = serverResponse.uploadedFilesWrapperList,
            supportingDocsAdditionalCount = cmp.get('v.supportingDocumentsCount');
        if (supportingDocsAdditionalCount < 5) {
            var otherDocumentCategory = cmp.get('v.supportingDocumentCategory');
            var supportingDoc = {
                contentDocumentId: '',
                fileCategory: otherDocumentCategory,
                fileDescription: '',
                fileDetails: 'Other - Supporting Document',
                isRequired: false,
                uploadedFileName: ''
            };
            uploadFileWrappers.push(supportingDoc);
            serverResponse.uploadedFilesWrapperList = uploadFileWrappers;
            cmp.set('v.serverResponse', serverResponse);
            cmp.set('v.supportingDocumentsCount', supportingDocsAdditionalCount+=1);
        }
    },
    
    //Start | PacPoint-RdG240220 - Updated for Case 6778
    selectAccount : function(component, event, helper) {
        var selectedRows = event.getParam('selectedRows');
        var action = component.get("c.getAccountRecord");
        action.setParams({
            accountId: selectedRows[0].Id
        });
        
        action.setCallback(self, function(a) {
            component.set("v.serverResponse.searchedAccount", a.getReturnValue());
            component.set("v.isAccountSelected", true);
        });
        
        // Enqueue the action
        $A.enqueueAction(action);
    },
    next: function (component, event, helper) {
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber+1);
        helper.next(component, event);
    },
    previous: function (component, event, helper) {
        var pageNumber = component.get("v.pageNumber");
        component.set("v.pageNumber", pageNumber-1);
        helper.previous(component, event);
    },
    //End | PacPoint-RdG240220 - Updated for Case 6778
    
    createNewAccount: function(component, event, helper) {
        component.set("v.isMakingServerCall", true);
        
        helper.getAccountLayoutInfo(component, event, helper);
    },
    
    goToNextStep: function(component, event, helper) {
        var currentStep = component.get("v.step");
        component.set("v.isMakingServerCall", true);
        
        if (currentStep == "1") {
            var selectedValue = component.get("v.selectedValue");
            
            // remain at step 1 and throw error message
            if (selectedValue == "None") {
                component.set("v.isMakingServerCall", false);
                
                var toastType = "error";
                var toastTitle = "No value selected";
                var toastMessage = "Please select a value from the existing picklist!";
                var toastMode = "sticky";
                
                helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
            }
            // get metadata info and advance to step 2
            else {
                helper.getMetadataInfo(component, event, helper);
            }
        } else if (currentStep == "2") {
            var foundAccount = component.get("v.serverResponse.foundAccount");
            
            if (foundAccount == false) {
                component.set("v.isMakingServerCall", false);
                
                var toastType = "error";
                var toastTitle = "No account selected";
                var toastMessage = "Please search for an existing account!";
                var toastMode = "sticky";
                
                helper.showToastMessage(toastType, toastTitle, toastMessage, toastMode);
            } else {
                helper.getFilingMetadataInfo(component, event, helper);
            }
        } else if (currentStep == "2b") {
            var manFields = helper.checkRequiredFields(component, event, helper);
            
            if (manFields == true) {
                component.set("v.serverResponse.newAccountCreated", true);
                
                helper.getFilingMetadataInfo(component, event, helper);
            } else {
                component.set("v.isMakingServerCall", false);
            }
        }
    },
    
    searchBusinessAccounts: function(component, event, helper) {
        helper.searchBusinessAccounts(component, event, helper);
    },
    
    searchPersonAccounts: function(component, event, helper) {
        component.set("v.isMakingServerCall", true);
        
        helper.searchPersonAccounts(component, event, helper);
    }
});