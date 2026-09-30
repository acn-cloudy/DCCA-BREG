public without sharing class BREGRegistrationFormController {
    private static final String INITIAL_UPLOAD_NAME_PREFIX = 'For Initial: ';
    private static final String RESUBMIT_UPLOAD_NAME_PREFIX = 'For Resubmittal: ';
    private static final String GENERIC_UPLOAD_TARGET = 'generic';
    private static final Map<String, String> roleToTitleMap = new Map<String, String>{
        'Partner' => 'G',
        'General Partner' => 'G',
        'Member'         => 'MEM',
        'Manager'        => 'MGR'
    };

    @AuraEnabled
    public static String saveFormData(String formConfigurationId, String jsonData) {
        System.debug('*** BREGRegistrationFormController.saveFormData');
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jsonData);

            Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
            Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
            BREGPortalUtils.FormConfiguration formConfig = BREGPortalUtils.getFormConfiguration(formConfigurationId);

            Case newCase;
            List<breg_Account_Affiliation__c> newAffiliations = new List<breg_Account_Affiliation__c>();
            List<Map<String, Object>> memberDataList = new List<Map<String, Object>>();
            List<breg_Stock__c> stocksToUpsert = new List<breg_Stock__c>();
            List<Map<String, Object>> stockDataList = new List<Map<String, Object>>();
            Id currentUserContactId = BREGUtils.getCommunityUserContactId();
            Datetime nowUtc = System.now();

            // Get Org/User timezone (see note below)
            TimeZone tz = UserInfo.getTimeZone();
            // Convert UTC → Org TZ
            Integer offset = tz.getOffset(nowUtc) / 1000;
            Datetime orgNow = nowUtc.addSeconds(offset);
            // Extract Date
            Date orgDate = orgNow.date();

            for (String key : data.keySet()) {
                if (key.startsWith('members') || key.startsWith('deletedMembers')) {
                    List<Object> members = (List<Object>) data.get(key);
                    System.debug('members: ' + members);
                    for (Object member : members) {
                        System.debug('member: ' + member);
                        Map<String, Object> castMember = (Map<String, Object>) member;
                        breg_Account_Affiliation__c newAffiliation = new breg_Account_Affiliation__c();
                        // Set default Type for the Account Affiliation if not specified
                        if (castMember.get('breg_Account_Affiliation__c.breg_Type__c') == null) {
                            castMember.put('breg_Account_Affiliation__c.breg_Type__c', 'Individual');
                        }

                        for (String memberKey : castMember.keySet()) {
                            Object value = castMember.get(memberKey);
                            if (memberKey.startsWith('breg_Account_Affiliation__c.')) {
                                newAffiliation.put(memberKey.removeStart('breg_Account_Affiliation__c.'), value);
                            }
                        }

                        String role = newAffiliation.breg_Role__c;
                        if (roleToTitleMap.containsKey(role)) {
                            newAffiliation.breg_Officer_Director_Titles__c = roleToTitleMap.get(role);
                        }

                        System.debug('New Affiliation: ' + newAffiliation);
                        if (key.startsWith('deletedMembers')) {
                            newAffiliation.breg_To_Remove__c = true;
                        }
                        if (newAffiliation != new breg_Account_Affiliation__c()) {
                            newAffiliations.add(newAffiliation);
                            // Store the original member data for mapping back
                            memberDataList.add(castMember);
                        }
                    }
                } else if (key.startsWith('stocksAnnuals') || key.startsWith('stocksPaidIn')) {
                    List<Object> stocks = (List<Object>) data.get(key);
                    System.debug('stocks: ' + stocks);
                    for (Object stock : stocks) {
                        System.debug('stock: ' + stock);
                        Map<String, Object> castStock = (Map<String, Object>) stock;
                        breg_Stock__c newStock = new breg_Stock__c();

                        for (String stockKey : castStock.keySet()) {
                            Object value = castStock.get(stockKey);
                            System.debug('stockKey: ' + stockKey);
                            if (stockKey.startsWith('breg_Stock__c.')) {
                                String fieldName = stockKey.removeStart('breg_Stock__c.');
                                // Skip setting the Id field directly - it will be handled by upsert
                                if (fieldName != 'Id') {
                                    newStock.put(fieldName, value);
                                } else if (value != null) {
                                    newStock.Id = (Id) value;
                                }
                            }
                        }
                        System.debug('New Stock: ' + newStock);

                        if (newStock != new breg_Stock__c()) {
                            stocksToUpsert.add(newStock);
                            // Store the original stock data for mapping back
                            stockDataList.add(castStock);
                        }
                    }
                } else if (key.startsWith('Case')) {
                    List<Case> casesToUpsert = new List<Case>();
                    newCase = (Case) JSON.deserialize(JSON.serialize(data.get(key)), Case.class);
                    String caseSubject = newCase.breg_TNTMSM_Description__c ?? newCase.breg_Name_of_the_Entity__c ?? newCase.Subject;
                    if (newCase.breg_Name_for_Reservation__c != null) {
                        caseSubject = newCase.breg_Name_for_Reservation__c;
                    }
                    newCase.Subject = caseSubject.left(80);
                    newCase.RecordTypeId = bregCaseRecordTypeId;
                    newCase.Origin = currentUserContactId != null || UserInfo.getUserType() == 'Guest' ? 'Web' : 'In Person';
                    newCase.breg_Processing_Speed__c = 'Normal';
                    newCase.ContactId = currentUserContactId;
                    newCase.breg_Signed_Date__c = Date.today();
                    newCase.breg_Form_Configuration__c = formConfigurationId;
                    newCase.breg_Form_Code__c = formConfig.formCode;

                    // Set default values
                    if (newCase.breg_Entity_Type__c == null && formConfig.entityType != null) {
                        newCase.breg_Entity_Type__c = formConfig.entityType;
                    }
                    if (newCase.breg_Effective_Date__c == null) {
                        if (formConfig.daysAfterSubmissionHoldApproval != null) {
                            newCase.breg_Effective_Date__c = orgDate.addDays(formConfig.daysAfterSubmissionHoldApproval);
                        } else {
                            newCase.breg_Effective_Date__c = orgDate;
                        }
                    }
                    if (newCase.breg_Effective_Date_Time__c == null) {
                        newCase.breg_Effective_Date_Time__c = Datetime.newInstance(newCase.breg_Effective_Date__c, Time.newInstance(16, 0, 0, 0));
                    }
                    if (newCase.breg_Number_of_common_shares__c != null && newCase.breg_Stock_Type__c == null) {
                        newCase.breg_Stock_Type__c = 'With Stock';
                    }
                    if (newCase.breg_Stock_Type__c == null && formConfig.stockType != null) {
                        newCase.breg_Stock_Type__c = formConfig.stockType;
                    }

                    // Clean default values
                    if (String.isNotBlank(newCase.breg_File__c) && newCase.Id == null && newCase.breg_Entity__c == null) {
                        newCase.breg_File__c = null; 
                    }

                    System.debug('Case to upsert: ' + newCase);

                    if (newCase.breg_Form_Action__c == 'Resubmit') {
                        newCase.Status = 'Rejected';
                    }
                    if (newCase.breg_Form_Action__c == 'Reopen') {
                        newCase.Status = 'Pending Submission';
                        newCase.breg_Reopened_Date__c = Datetime.now();
                    }

                    // Skip assignment rules for Manual filings
                    if (newCase.Origin != 'In Person') {
                        Database.DMLOptions dmo = new Database.DMLOptions();
                        dmo.assignmentRuleHeader.useDefaultRule = true;
                        newCase.setOptions(dmo);
                    }

                    if (String.isBlank(newCase.Status) || newCase.Status == 'New' || newCase.Status == 'Pending Submission') {
                        Database.DMLOptions dmo = new Database.DMLOptions();
                        dmo.assignmentRuleHeader.useDefaultRule = false;
                        newCase.setOptions(dmo);
                    }

                    casesToUpsert.add(newCase);

                    upsert casesToUpsert;
                    // Database.UpsertResult result = Database.upsert(newCase, false);
                    // if (!result.isSuccess()) {
                    //     String errorMessage = 'Case upsert failed: ';
                    //     for (Database.Error error : result.getErrors()) {
                    //         errorMessage += error.getStatusCode() + ': ' + error.getMessage() + ' (Fields: ' + error.getFields() + ') ';
                    //     }
                    //     System.debug(errorMessage);
                    //     throw new AuraHandledException(errorMessage);
                    // }

                    // Populate ParentId for GP case if LLP-1 or FLLP-1 form
                    if ((formConfig.formCode == 'LLP-1' || formConfig.formCode == 'FLLP-1') && newCase.breg_GP_Case__c != null) {
                        Case gpCase = new Case(Id = newCase.breg_GP_Case__c, ParentId = newCase.Id);
                        update gpCase;
                    }
                }
            }

            if (!newAffiliations.isEmpty()) {
                // Remove duplicates based on Id
                Map<Id, breg_Account_Affiliation__c> uniqueAffiliations = new Map<Id, breg_Account_Affiliation__c>();
                List<breg_Account_Affiliation__c> affiliationsToUpsert = new List<breg_Account_Affiliation__c>();
                for (breg_Account_Affiliation__c affiliation : newAffiliations) {
                    affiliation.breg_Case__c = newCase.Id;
                    if (affiliation.Id != null) {
                        uniqueAffiliations.put(affiliation.Id, affiliation);
                    } else {
                        affiliationsToUpsert.add(affiliation);
                    }
                }
                affiliationsToUpsert.addAll(uniqueAffiliations.values());

                System.debug('Affiliations to upsert: ' + JSON.serialize(affiliationsToUpsert));
                upsert affiliationsToUpsert;

                // Add affiliation IDs to memberDataList
                for (Integer i = 0; i < newAffiliations.size(); i++) {
                    memberDataList[i].put('affiliationId', newAffiliations[i].Id);
                }
            }

            if (!stocksToUpsert.isEmpty()) {
                Id selectedAccountId =
                    newCase.breg_Portal_User_Entity_Selected__c;

                Boolean isAnnualForm =
                    BREGUtils.isAnnualForm(formConfig.formCode);

                for (breg_Stock__c stock : stocksToUpsert) {
                    stock.breg_Case__c = newCase.Id;

                    if (stock.Id == null) {
                        stock.breg_Account__c = isAnnualForm
                            ? null
                            : selectedAccountId;
                    }
                }
                System.debug('Stocks to upsert: ' + stocksToUpsert);
                upsert stocksToUpsert;

                // Add stock IDs to stockDataList
                for (Integer i = 0; i < stocksToUpsert.size(); i++) {
                    stockDataList[i].put(
                        'stockId',
                        stocksToUpsert[i].Id
                    );
                }
            }

            System.debug('New Case: ' + newCase);
            System.debug('New Affiliations: ' + newAffiliations);
            System.debug('New Stocks: ' + stocksToUpsert);

            // It means that case is not draft and update the status to the submitted state.
            if (!newCase.breg_Bypass_Validation__c && newCase.breg_Form_Action__c != 'Resubmit') {
                String submittedStatus = BREGUtils.isWithdrawalForm(formConfig.formCode) ? 'Received' : 'Pending Submission';
                if (newCase.Status != submittedStatus) {
                    newCase.Status = submittedStatus;
                    TriggerUtils.disableTrigger = false; // Enable triggers to next DML
                    update newCase;
                }
            }

            // Build response with Case ID, Account Affiliation data, and Stock data
            Map<String, Object> response = new Map<String, Object>();
            response.put('caseId', newCase.Id);
            response.put('affiliations', memberDataList);
            response.put('stocks', stockDataList);

            return JSON.serialize(response);
        } catch (Exception ex) {
            System.debug('*** BREGRegistrationFormController.saveFormData' + ex.getMessage() + '\n' + ex.getStackTraceString());

            String userMsg;
            if (ex instanceof DmlException) {
                DmlException dmlex = (DmlException) ex;
                if (dmlex.getNumDml() > 0) {
                    userMsg = dmlex.getDmlMessage(0);
                } else {
                    userMsg = dmlex.getMessage();
                }
            } else {
                userMsg = ex.getMessage();
            }

            throw new AuraHandledException(userMsg);
        }
    }

    @AuraEnabled
    public static void saveRelatedFiles(String recordId, String jsonData, Boolean isResubmit) {
        if (String.isBlank(recordId) || String.isBlank(jsonData)) {
            throw new AuraHandledException('Record ID and JSON data cannot be blank.');
        }
        try {
            List<breg_Document__c> documentsToInsert = new List<breg_Document__c>();
            Set<Id> existingDocumentIds = new Set<Id>();
            List<FileWrapper> files = (List<FileWrapper>) JSON.deserialize(jsonData, List<FileWrapper>.class);

            for (FileWrapper file : files) {
                if (file.id != null) {
                    existingDocumentIds.add((Id) file.id);
                    continue;
                }
                file.href = DocuSignAPI.uploadFile(recordId, file.fileName, file.base64Data);
                breg_Document__c newDocument = new breg_Document__c();
                //newDocument.Name = 'For Initial: ' + file.fileName;
                newDocument.Name = buildUploadedDocumentName(file, isResubmit);
                newDocument.breg_Availability__c = 'Available Now';
                newDocument.breg_Docusign_Document_Id__c = file.href;
                newDocument.breg_Type__c = 'Digital';
                newDocument.breg_Case__c = recordId;
                newDocument.breg_Form_Configuration_Item__c = file.configId;
                newDocument.breg_Is_Uploaded_Attachment__c = true;
                newDocument.breg_Is_Irrelevant__c = false;
                documentsToInsert.add(newDocument);
            }

            if (isResubmit == true && !existingDocumentIds.isEmpty()) {
                List<breg_Document__c> documentsToReactivate = [
                    SELECT Id, breg_Is_Irrelevant__c
                    FROM breg_Document__c
                    WHERE
                        Id IN :existingDocumentIds
                        AND breg_Case__c = :recordId
                        AND breg_Form_Configuration_Item__c != NULL
                        AND breg_Is_Uploaded_Attachment__c = TRUE
                ];

                List<breg_Document__c> documentsToUpdate = new List<breg_Document__c>();
                for (breg_Document__c documentRecord : documentsToReactivate) {
                    if (documentRecord.breg_Is_Irrelevant__c == true) {
                        documentRecord.breg_Is_Irrelevant__c = false;
                        documentsToUpdate.add(documentRecord);
                    }
                }

                if (!documentsToUpdate.isEmpty()) {
                    update documentsToUpdate;
                }
            }

            List<breg_Document__c> documentsToDelete = [
                SELECT Id
                FROM breg_Document__c
                WHERE
                    breg_Case__c = :recordId
                    AND Id NOT IN :existingDocumentIds
                    AND breg_Form_Configuration_Item__c != NULL
                    AND breg_Is_Uploaded_Attachment__c = TRUE
            ];
            if (!documentsToDelete.isEmpty()) {
                delete documentsToDelete;
            }

            if (!documentsToInsert.isEmpty()) {
                insert documentsToInsert;
            }
        } catch (Exception ex) {
            System.debug('*** BREGRegistrationFormController.saveRelatedFiles' + ex.getMessage() + '\n' + ex.getStackTraceString());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static String buildUploadedDocumentName(FileWrapper file, Boolean isResubmit) {
        String namePrefix = isResubmit ? RESUBMIT_UPLOAD_NAME_PREFIX : INITIAL_UPLOAD_NAME_PREFIX;
        if (String.isBlank(file.uploadTarget) || file.uploadTarget == GENERIC_UPLOAD_TARGET) {
            return namePrefix + file.fileName;
        }

        return namePrefix + '[' + file.uploadTarget + '] ' + file.fileName;
    }

    @AuraEnabled
    public static Boolean isNBRForm(String formCode) {
        try {
            return BREGUtils.isNBRForm(formCode);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String checkFormCategory(String formCode) {
        try {
            return BREGUtils.checkFormCategory(formCode);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class FileWrapper {
        public String id { get; set; }
        public String fileName { get; set; }
        public String fileType { get; set; }
        public String base64Data { get; set; }
        public String uploadTarget { get; set; }
        public String configId { get; set; }
        public String href { get; set; }
    }
}