public without sharing class BREGCaseStatusHandlerNBR extends BREGCaseStatusHandlerBase {
    private static final String R7_DEACTIVATION_NOTE = 'This Name Reservation has been marked as inactive due to linking with the new registration.';
    private static final String ERROR_AGENT_AFFILIATION_REQUIRED = 'Registered Agent is required to complete this Work Item.';
    private static final List<String> EXCLUDED_AGENT_VALIDATION_FORMS = new List<String>{ 'SOLE-1' };

    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        List<Case> casesForCheck = getCasesWithAllFields(cases);
        if (performValidation) {
            // Base validation must run on Trigger.new rows so addError() is allowed; casesForCheck is from SOQL and cannot accept errors.
            super.handleStatusChange(cases, newStatus, true, false);
            performValidation(cases, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(casesForCheck, newStatus, false, true);
            performActions(casesForCheck, newStatus);
        }
    }

    private void performValidation(List<Case> casesForCheck, String newStatus) {
        switch on newStatus {
            when 'Approved' {
                validateGpEntityField(casesForCheck);
            }
            when 'Completed' {
                validateAgentAffiliationExists(casesForCheck);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Received' {
                updateRelatedGPCaseStatus(cases);
                createTransactionsForAccounts(cases);
                createChildCaseForCertCopy(cases);
            }
            when 'Approved' {
                deactivateLinkedR7Records(cases);
            }
            when 'Completed' {
                updateRelatedEntityStatuses(cases);
                BREGCaseStatusHandlerHelper.updateMemberAddressesFromAffiliations(BREGCaseStatusHandlerHelper.getMembersCaseMap(cases), cases);
                updateChildCaseForCertCopy(cases);
                //createAnnualNotificationsForCases(cases); // commented as was decided to move functionality for free email reminder to AnnualReminderJob
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateGpEntityField(List<Case> cases) {
        for (Case currentCase : cases) {
            if (
                (currentCase.breg_Form_Code__c == 'LLP-1' ||
                currentCase.breg_Form_Code__c == 'FLLP-1') &&
                currentCase.breg_GP_Already_Registered__c &&
                currentCase.breg_GP_Entity__c == null
            ) {
                addErrorMessage(currentCase, 'breg_GP_Entity__c', BREGUtils.returnFielLabelByApiName('Case', 'breg_GP_Entity__c') + ': ' + REQUIRED_FIELD_MESSAGE);
            }
        }
    }

    private void validateAgentAffiliationExists(List<Case> cases) {
        Set<Id> caseIds = new Set<Id>();
        for (Case currentCase : cases) {
            if (!EXCLUDED_AGENT_VALIDATION_FORMS.contains(currentCase.breg_Form_Code__c)) {
                caseIds.add(currentCase.Id);
            }
        }

        if (caseIds.isEmpty()) {
            return;
        }

        // Query for Agent affiliations
        List<breg_Account_Affiliation__c> agentAffiliations = [
            SELECT Id, breg_Case__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds AND breg_Role__c = 'Agent'
            LIMIT 10000
        ];

        // Build a set of case IDs that have Agent affiliations
        Set<Id> casesWithAgents = new Set<Id>();
        for (breg_Account_Affiliation__c affiliation : agentAffiliations) {
            casesWithAgents.add(affiliation.breg_Case__c);
        }

        // Add error for cases without Agent affiliations
        for (Case currentCase : cases) {
            if (!EXCLUDED_AGENT_VALIDATION_FORMS.contains(currentCase.breg_Form_Code__c) && !casesWithAgents.contains(currentCase.Id)) {
                addErrorMessage(currentCase, null, ERROR_AGENT_AFFILIATION_REQUIRED);
            }
        }
    }

    private void updateRelatedGPCaseStatus(List<Case> cases) {
        List<Case> gpCases = new List<Case>();
        for (Case currentCase : cases) {
            if (
                (currentCase.breg_Form_Code__c == 'LLP-1' ||
                currentCase.breg_Form_Code__c == 'FLLP-1') &&
                !currentCase.breg_GP_Already_Registered__c &&
                currentCase.breg_GP_Case__c != null
            ) {
                Case gpCaseToUpdate = new Case();
                gpCaseToUpdate.Id = currentCase.breg_GP_Case__c;
                gpCaseToUpdate.Status = 'Received';
                gpCases.add(gpCaseToUpdate);
            }
        }
        if (!gpCases.isEmpty()) {
            update gpCases;
        }
    }

    private void updateRelatedEntityStatuses(List<Case> cases) {
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Set<Id> accountsIds = new Set<Id>();
        for (Case currentCase : cases) {
            if (currentCase.breg_Entity__c != null) {
                accountsIds.add(currentCase.breg_Entity__c);
                entityToCaseMap.put(currentCase.breg_Entity__c, currentCase);
            }
        }
        List<Account> entities = [
            SELECT Id, breg_Entity_Type__c, breg_Entity_Status__c, breg_Expiration_Date__c, breg_File__c, breg_File_Suffix__c, createdById
            FROM Account
            WHERE Id IN :accountsIds
        ];
        Id accountRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : entities) {
            Case relatedCase = entityToCaseMap.get(acc.Id);

            accountUpdatedFieldsMap.put(acc.Id, new Set<String>{ 'breg_Entity_Status__c' });
            if (relatedCase != null) {
                populateAccountFromCase(
                    acc,
                    relatedCase,
                    String.isNotBlank(relatedCase.breg_Name_for_Reservation__c)
                        ? relatedCase.breg_Name_for_Reservation__c
                        : relatedCase.breg_Name_of_the_Entity__c,
                    accountRecordType,
                    acc.CreatedById,
                    null
                );
            }
            acc.breg_Entity_Status__c = ConstantsHelper.ENTITY_STATUS_ACTIVE;
            accountsToUpdate.add(acc);
        }
        update accountsToUpdate;
        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    private void deactivateLinkedR7Records(List<Case> cases) {
        List<Account> accountsToUpdate = getAccountsToDeactivate(cases);
        update accountsToUpdate;
        
    }

    private void createTransactionsForAccounts(List<Case> cases){
         Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        for (Case currentCase : cases) {
            if (currentCase.breg_Entity__c != null) {
                entityToCaseMap.put(currentCase.breg_Entity__c, currentCase);
            }
        }
        List<Account> accountsToUpdate = getAccountsToDeactivate(cases);
        if (!accountsToUpdate.isEmpty()) {
            BREGTransactionUtils.createR7LinkageTransactions(accountsToUpdate, entityToCaseMap, 'R');
        }
    }

    private List<Account> getAccountsToDeactivate(List<Case> cases){
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Set<Id> accountsIds = new Set<Id>();
        for (Case currentCase : cases) {
            if (currentCase.breg_Name_Reservation__c != null) {
                accountsIds.add(currentCase.breg_Name_Reservation__c);
                entityToCaseMap.put(currentCase.breg_Name_Reservation__c, currentCase);
            }
        }
        List<Account> r7Entities = [
            SELECT Id, breg_Entity_Type__c, breg_Entity_Status__c, breg_File__c, breg_File_Suffix__c
            FROM Account
            WHERE Id IN :accountsIds
        ];
        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : r7Entities) {
            acc.breg_Entity_Status__c = ConstantsHelper.ENTITY_STATUS_INACTIVE;
            acc.breg_End_Date__c = entityToCaseMap.get(acc.Id).breg_Effective_Date__c != null
                ? entityToCaseMap.get(acc.Id).breg_Effective_Date__c
                : Date.today();
            acc.breg_Notes__c = R7_DEACTIVATION_NOTE;
            accountUpdatedFieldsMap.put(acc.Id, new Set<String>{ 'breg_Entity_Status__c', 'breg_End_Date__c', 'breg_Notes__c' });
            accountsToUpdate.add(acc);
        }
        return accountsToUpdate;
    }

    private void createChildCaseForCertCopy(List<Case> cases) {
        List<Case> casesWithCertCopy = getCasesWithCertCopyTransactionLine(cases);

        if (casesWithCertCopy.isEmpty()) {
            return;
        }

        Map<Id, Case> existingChildCasesByParentId = getChildCasesByParentCaseId(casesWithCertCopy);
        List<Case> casesWithoutExistingChild = new List<Case>();
        for (Case currentCase : casesWithCertCopy) {
            if (!existingChildCasesByParentId.containsKey(currentCase.Id)) {
                casesWithoutExistingChild.add(currentCase);
            }
        }

        if (casesWithoutExistingChild.isEmpty()) {
            return;
        }

        breg_Form_Configuration__c docdlvrFormConfig = getFormConfigByFormCode('DOCDLVR');
        Id caseRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case'
            LIMIT 1
        ].Id;

        List<Case> casesToInsert = new List<Case>();

        for (Case currentCase : casesWithoutExistingChild) {

            Case newCase = new Case(
                RecordTypeId = caseRecordTypeId,
                Subject = 'Document Certified Copy (Digital) - Public initial filing' + (currentCase.breg_Name_of_the_Entity__c != null ? ' for ' + currentCase.breg_Name_of_the_Entity__c : ''),
                Description = 'Process linked document',
                ContactId = currentCase.ContactId,
                Origin = 'Web',
                Status = 'Pending Submission',
                breg_Delivery_Method__c = 'Email',
                breg_Form_Configuration__c = docdlvrFormConfig?.Id,
                breg_Name_of_the_Entity__c = currentCase.breg_Name_of_the_Entity__c,
                breg_Processing_Speed__c = 'Normal',
                ParentId = currentCase.Id
            );
            
            casesToInsert.add(newCase);
        }

        insertCasesWithCallAssignmentRule(casesToInsert);
    }

    private void updateChildCaseForCertCopy(List<Case> cases) {
        List<Case> casesWithCertCopy = getCasesWithCertCopyTransactionLine(cases);

        if (casesWithCertCopy.isEmpty()) {
            return;
        }

        Map<Id, breg_Document__c> caseIdToLastPublicDocumentMap = getLastPublicDocumentsByCaseId(casesWithCertCopy);
        Map<Id, Case> caseIdToChildCaseMap = getChildCasesByParentCaseId(casesWithCertCopy);
        Map<Id, breg_Document__c> caseIdToNewDocumentMap = new Map<Id, breg_Document__c>();
        Map<Id, Contact> caseIdToContactMap = getContactsByCaseId(casesWithCertCopy);
        Map<Id, TransactionLine__c> caseIdToTransactionLineMap = getCertCopyTransactionLineByCaseId(casesWithCertCopy);

        List<Case> casesToUpdate = new List<Case>();
        List<TransactionLine__c> transactionLinesToUpdate = new List<TransactionLine__c>();
        List<breg_Document__c> documentsToInsert = new List<breg_Document__c>();

        for (Case currentCase : casesWithCertCopy) {
            Case childCase = caseIdToChildCaseMap.get(currentCase.Id);
            breg_Document__c lastPublicDocument = caseIdToLastPublicDocumentMap.get(currentCase.Id);

            breg_Document__c newDocument = new breg_Document__c(
                Name = appendSuffixBeforeExtension(lastPublicDocument.Name, '- Certified Copy'),
                breg_Template_Document__c = lastPublicDocument.Id,
                breg_Availability__c = null,
                breg_Is_Template_Copy__c = true,
                breg_Is_Public__c = false,
                breg_Delivery_Email__c = caseIdToContactMap.get(currentCase.Id)?.Email,
                breg_Annotation__c = caseIdToContactMap.get(currentCase.Id)?.FirstName + ' ' + caseIdToContactMap.get(currentCase.Id)?.LastName,
                breg_Available_To_Certify__c = true,
                breg_Docusign_Document_Id__c = null,
                breg_Case__c = childCase.Id
            );

            caseIdToNewDocumentMap.put(currentCase.Id, newDocument);
            documentsToInsert.add(newDocument);
        }

        insert documentsToInsert;

        for (Case currentCase : casesWithCertCopy) {
            Case childCase = caseIdToChildCaseMap.get(currentCase.Id);
            breg_Document__c lastPublicDocument = caseIdToLastPublicDocumentMap.get(currentCase.Id);
            TransactionLine__c certCopyTransactionLine = caseIdToTransactionLineMap.get(currentCase.Id);

            if (childCase != null && lastPublicDocument != null) {

                childCase.Subject = childCase.Subject.replace(
                    'Public initial filing',
                    lastPublicDocument.Name
                );
                childCase.breg_File__c = currentCase.breg_File__c;
                childCase.breg_Entity__c = currentCase.breg_Entity__c;
                childCase.breg_Document__c = caseIdToNewDocumentMap.get(currentCase.Id).Id;
                childCase.Status = 'Received';
                childCase.breg_Override_Payment__c = true;

                casesToUpdate.add(childCase);
            }

            if (certCopyTransactionLine != null) {
                certCopyTransactionLine.breg_Document__c = caseIdToNewDocumentMap.get(currentCase.Id).Id;
                transactionLinesToUpdate.add(certCopyTransactionLine);
            }
        }

        update casesToUpdate;
        update transactionLinesToUpdate;
    }

    private Map<Id, Case> getChildCasesByParentCaseId(List<Case> cases) {

        Set<Id> parentCaseIds = getCaseIds(cases);

        Map<Id, Case> childCasesMap = new Map<Id, Case>();
        for (Case childCase : [
            SELECT Id, ParentId, Subject
            FROM Case
            WHERE ParentId IN :parentCaseIds
            AND breg_Form_Configuration__r.breg_Form_Code__c = 'DOCDLVR'
        ]) {
            childCasesMap.put(childCase.ParentId, childCase);
        }

        return childCasesMap;
    }

    private Map<Id, breg_Document__c> getLastPublicDocumentsByCaseId(List<Case> cases) {

        Set<Id> caseIds = getCaseIds(cases);

        Map<Id, breg_Document__c> caseIdToDocumentMap = new Map<Id, breg_Document__c>();
        for (breg_Document__c doc : [
            SELECT Id, breg_Case__c, Name
            FROM breg_Document__c
            WHERE breg_Case__c IN :caseIds
            AND breg_Is_Public__c = TRUE
            ORDER BY CreatedDate DESC
        ]) {
            caseIdToDocumentMap.put(doc.breg_Case__c, doc);
        }
        return caseIdToDocumentMap;
    }

    private List<Case> getCasesWithCertCopyTransactionLine(List<Case> cases) {
        
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Case> caseMap = new Map<Id, Case>();

        for (Case c : cases) {
            caseMap.put(c.Id, c);
        }

        List<String> certCopyCashierCodes = new List<String>{'B23', 'L23', 'L38'};
        String certCopyTransactionType = 'NBR Form';

        List<TransactionLine__c> transactionLines = [
            SELECT Id, CashierCode__r.CashierCode__c , breg_Case__c
            FROM TransactionLine__c
            WHERE CashierCode__r.CashierCode__c IN :certCopyCashierCodes
            AND breg_Case__c IN :caseIds
            AND breg_Type__c = :certCopyTransactionType
        ];

        if (transactionLines.isEmpty()) {
            return new List<Case>();
        }

        List<Case> casesWithCertCopyTransactionLine = new List<Case>();
        Set<Id> addedCaseIds = new Set<Id>();
        for (TransactionLine__c transactionLine : transactionLines) {
            if (caseMap.containsKey(transactionLine.breg_Case__c) && !addedCaseIds.contains(transactionLine.breg_Case__c)) {
                casesWithCertCopyTransactionLine.add(caseMap.get(transactionLine.breg_Case__c));
                addedCaseIds.add(transactionLine.breg_Case__c);
            }
        }

        return casesWithCertCopyTransactionLine;
    }

    private Map<Id, TransactionLine__c> getCertCopyTransactionLineByCaseId(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);

        List<String> certCopyCashierCodes = new List<String>{'B23', 'L23', 'L38'};
        String certCopyTransactionType = 'NBR Form';

        Map<Id, TransactionLine__c> caseIdToTransactionLineMap = new Map<Id, TransactionLine__c>();
        for (TransactionLine__c transactionLine : [
            SELECT Id, CashierCode__r.CashierCode__c , breg_Case__c
            FROM TransactionLine__c
            WHERE CashierCode__r.CashierCode__c IN :certCopyCashierCodes
            AND breg_Case__c IN :caseIds
            AND breg_Type__c = :certCopyTransactionType
        ]) {
            caseIdToTransactionLineMap.put(transactionLine.breg_Case__c, transactionLine);
        }
        return caseIdToTransactionLineMap;
    }

    private Map<Id, Contact> getContactsByCaseId(List<Case> cases) {
        Map<Id, Contact> result = new Map<Id, Contact>();

        Set<Id> contactIds = new Set<Id>();
        for (Case c : cases) {
            if (c.ContactId != null) {
                contactIds.add(c.ContactId);
            }
        }

        Map<Id, Contact> contacts = new Map<Id, Contact>([
            SELECT Id, Email, FirstName, LastName
            FROM Contact
            WHERE Id IN :contactIds
        ]);

        for (Case c : cases) {
            if (c.ContactId != null) {
                result.put(c.Id, contacts.get(c.ContactId));
            }
        }

        return result;
    }

    private static breg_Form_Configuration__c getFormConfigByFormCode(String formCode) {
        List<breg_Form_Configuration__c> formConfigs = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Form_Code__c = :formCode
            LIMIT 1
        ];
        if (formConfigs.isEmpty()) {
            return null;
        }
        return formConfigs[0];
    }

    private static String appendSuffixBeforeExtension(String fileName, String suffix) {
        Integer lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex > 0) {
            return fileName.substring(0, lastDotIndex) + ' ' + suffix + fileName.substring(lastDotIndex);
        }
        return fileName + ' ' + suffix;
    }

    private static void insertCasesWithCallAssignmentRule(List<Case> cases) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.AssignmentRuleHeader.useDefaultRule = true;
        List<Case> casesToInsert = new List<Case>();
        for (Case c : cases) {
            c.setOptions(dmlOpts);
            casesToInsert.add(c);
        }

        insert casesToInsert;
    }

    @TestVisible
    private void createAnnualNotificationsForCases(List<Case> cases) {
        List<Case> casesWithAnnualNotification = new List<Case>();
        for (Case currentCase : cases) {
            if (currentCase.breg_Subscribe_Owner_Free_Email_Alerts__c) {
                casesWithAnnualNotification.add(currentCase);
            }
        }
        for (Case currentCase : casesWithAnnualNotification) {
            String notificationData = JSON.serialize(new List<Object>{
                new Map<String, Object>{
                    'recordId' => currentCase.breg_Entity__c,
                    'sourceObject' => 'Account',
                    'notifications' => new List<Object>{
                        new Map<String, Object>{
                            'id' => 'Annual Report Reminder'
                        }
                    }
                }
            });
            BREGNotificationsHandler.createNotifications(notificationData, currentCase.ContactId, true);
        }

    }
}