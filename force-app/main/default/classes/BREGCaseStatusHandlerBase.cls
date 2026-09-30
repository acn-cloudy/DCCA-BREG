public without sharing virtual class BREGCaseStatusHandlerBase {
    private static final String NO_PAYMENT_MESSAGE = 'No payment(s) associated to this work item. Kindly associate this work item to a payment transaction to proceed.';

    public static final String REQUIRED_FIELD_MESSAGE = ' is a required field. Please fill it to proceed.';

    // Cached BREG Account Record Type Id to avoid duplicate queries
    private static Id cachedBREGAccountRecordTypeId;

    private static final String NUMBER_OF_SHARES_COUNT_MESSAGE = 'The number of issued shares can not exceed the number of authorized shares';
    private static final String ERROR_RESUBMISSION_DUE_DATE_PAST = 'Resubmission Due Date cannot be a past date.';
    private static final String ERROR_RESUBMISSION_DUE_DATE_TOO_FAR = 'Resubmission Due Date cannot be more than 40 days in the future  form the day it was rejected.';
    private static final String ERROR_RESUBMISSION_RECIEVED_DATE_FUTURE = 'Resubmission Recieved Date cannot be a future date.';

    public static final String ERROR_LINKED_ENTITY_REQUIRED = 'Approval is not allowed until this work item is linked to a Entity.';
    public static final String ERROR_MERGING_ACC_AFFILIATION_REQUIRED = 'Approval is not allowed until merging account affiliation item exist.';
    public static final String ERROR_LINKED_ENTITY_TO_ACC_AFFILIATION_REQUIRED = 'Approval is not allowed until account affiliation item is linked to a Entity.';
    public static final String ERROR_EFFECTIVE_DATE = 'The Case status cannot be set to Completed before the Effective Date.';
    //Errors: Required words in the Entity Name depending on the Entity Type
    public static final String ERROR_ENTITY_TYPE_DOMESTIC_CORP = 'Domestic Profit corporation, Sustainable business corporation or professional corporation: The name must contain either the words "Corporation" or "Incorporated" or "Limited" or the abbreviation Corp., or Inc., or Ltd.';
    public static final String ERROR_ENTITY_TYPE_LP = 'Domestic limited partnership: The name must contain either the word "Limited Partnership" or the abbreviation "L.P." or "LP"';
    public static final String ERROR_ENTITY_TYPE_LLLP = 'For Limited Liability Limited partnership: The name must contain either the word "Limited Liability Limited Partnership" or the abbreviation "L.L.L.P." or "LLLP"';
    public static final String ERROR_ENTITY_TYPE_LLC = 'Domestic LLC: The name must contain either the words "Limited Liability Company" or "Limited Liability Law Company" or the abbreviation "L.L.C." or "LLC" or "L.L.L.C." or "LLLC"';
    public static final String ERROR_ENTITY_TYPE_LLP = 'Domestic LLP: The name must contain either the words "Registered Limited Liability Partnership", "Limited Liability Law Partnership", "Limited Liability Partnership" or the abbreviation "R.L.L.P.", "L.L.P.", "RLLP", or "LLP"';
    public static final String ERROR_ENTITY_TYPE_COOPERATIVE = 'Consumer Cooperative: The name of the association shall contain the term "cooperative" or "coop.", "co-op"';
    //Errors: Required Applicant fields
    public static final String ERROR_APPLICANT_REQUIRED = 'At least one Applicant is required for this case.';
    public static final String ERROR_APPLICANT_ADDRESS_REQUIRED = 'Applicant address field is required.';
    public static final String ERROR_APPLICANT_ENTITY_NAME_REQUIRED = 'Applicant Entity Name is required.';
    public static final String ERROR_APPLICANT_NAME_REQUIRED = 'Applicant Last and First Name is required.';
    public static final String ERROR_RESERVATION_NAME_DIFFERS_FROM_ENTITY = 'The selected Reservation name does not match the reservation name the applicant has provided.';
    public static final String ERROR_MERGER_CERTIFICATE_NOT_GENERATED = 'Merger Certificate needs to be generated before approval. Please generate the Merger Certificate and try again.';
    public static final String ERROR_ENTITY_STATUS_CLOSED = 'Approval is not allowed until the linked entity is in an active status.';
    public static final String ERROR_CASE_MUST_HAVE_AT_LEAST_TWO_MERGING_ENTITIES = 'The case must have at least two merging entities.';
    // Form codes that should not create transactions in this handler (handled by their own handlers)
    private static final Set<String> FORM_CODES_SKIP_TRANSACTION = new Set<String>{ 'ADD', 'ADD-MEMBER', 'ADD-TNTMSM' };

    // Constants for entity status and TNTMSM status
    private static final String ENTITY_STATUS_NEW = 'New (Y)';
    private static final String TNTMSM_STATUS_ACTIVE = 'A';
    private static final String NOTIFICATION_CATEGORY_TNTMSM_REMINDER = 'Trade Name, Trademark, Service Mark Reminder';
    private static final String NOTIFICATION_CATEGORY_PR_RENEWAL_REMINDER = 'Publicity Rights Name Renewal Reminder';
    private static final String NOTIFICATION_CATEGORY_ANNUAL_REPORT_REMINDER = 'Annual Report Reminder';
    private static final String NOTIFICATION_STATUS_ACTIVE = 'Active';

    private static final List<String> REINST_REVOKE_FORM_CODES = new List<String>{ 'X-4', 'DNP-8', 'DC-12' };

    private static Map<String, Boolean> hasNewRoleVersionMap = null;

    /**
     * Handles the status change for the cases
     * @param cases - list of cases
     * @param newStatus - new status
     * @param performValidation - perform validation
     * @param performActions - perform actions
     */
    public virtual void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        if (performValidation) {
            performValidation(cases, newStatus);
        }

        if (performActions) {
            performActions(cases, newStatus);
        }
    }

    /**
     * Performs the validation for the cases
     * @param cases - list of cases
     * @param newStatus - new status
     */
    private void performValidation(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Pending Submission' {
                sharesCountValidation(cases);
            }
            when 'Approved' {
                validateFormConfigItems(cases, newStatus);
                validatePaymentCompletion(cases);
                validateResubmissionDate(cases);
                validateEffectiveDate(cases);
                validateEntityPopulation(cases);
                validateEntityStatus(cases);
                validateFileNumber(cases);
            }
            when 'Completed' {
                validateFormConfigItems(cases, newStatus);
                validateResubmissionDate(cases);
                validateEffectiveDateNotInTheFuture(cases);
            }
            when 'Rejected' {
                validateFormConfigItems(cases, newStatus);
                validateResubmissionDate(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    /**
     * Performs the actions for the cases
     * @param cases - list of cases
     * @param newStatus - new status
     */
    private void performActions(List<Case> cases, String newStatus) {
        // Sync linked LLP/GP cases to the new status whenever status changes
        syncLinkedLLPGPCasesToStatus(cases, newStatus);
        Map<Id, Case> casesMap = new Map<Id, Case>(cases);
        switch on newStatus {
            when 'Received' {
                createTransactionsForReceivedCases(cases);
            }
            when 'Approved' {
                performApprovedActionsForSpecialForms(cases);
                BREGTransactionUtils.updateTransactionStatusByCases(casesMap, 'A');

            }
            when 'Bounced Check' {
                updateCaseWithAssignmentRules(cases);
                BREGTransactionUtils.updateTransactionStatusByCases(casesMap, 'B');
            }
            when 'Rejected' {
                //AB HOTFIX. Permannent fix neede 13 April 2026. https://aalta.atlassian.net/browse/BREG-4021
                List<id> caseIds = new List<id>();
                for (Case c : cases)
                    caseIds.add(c.Id);
                updateCaseRejectedByUserField(caseIds, UserInfo.getUserId());
                BREGTransactionUtils.updateTransactionStatusByCases(casesMap, 'J');
            }
            when 'Completed' {
                BREGTransactionUtils.updateTransactionStatusByCases(casesMap, 'C');
            }
            when 'Expired' {
                BREGTransactionUtils.updateTransactionStatusByCases(casesMap, 'X');
            }
            when 'Withdrawn' {
                BREGTransactionUtils.updateTransactionStatusByCases(casesMap, 'S');
            }
            when 'Held' {
                BREGTransactionUtils.updateTransactionStatusByCases(casesMap, 'H');
            }
            when else {
                // do nothing
            }
        }
    }

    /**
     * Validates the form configuration items
     * @param cases - list of cases
     * @param newStatus - new status
     */
    private void validateFormConfigItems(List<Case> cases, String newStatus) {
        // get form configuration ids
        Set<String> formConfigCodes = new Set<String>();
        for (Case c : cases) {
            formConfigCodes.add(c.breg_Form_Code__c);
        }
        // get form configuration items
        List<breg_Form_Configuration_Item__c> formConfigItems = [
            SELECT
                Id,
                breg_Required_for_Statuses__c,
                breg_Target_Fields_Mapping__c,
                breg_Apex_Validation_Class_Name__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Form_Code__c,
                breg_Form_Configuration__r.breg_Suffix_Code__c
            FROM breg_Form_Configuration_Item__c
            WHERE breg_Form_Configuration__r.breg_Form_Code__c IN :formConfigCodes
        ];
        // get form configuration item wrappers
        List<FormConfigItemWrapper> formConfigWrappers = getFormConfigItemWrappers(formConfigItems);
        // get trigger cases map for initial cases
        Map<Id, Case> triggerCasesMap = new Map<Id, Case>(cases);
        // requery cases to get the target fields
        List<Case> casesWithTargetFields = getCasesWithTargetFields(cases, formConfigWrappers);
        // get form configuration id to form configuration item map
        Map<String, List<FormConfigItemWrapper>> formCodeToFormConfigItemWrapperMap = getFormCodeToFormConfigItemWrappersMap(formConfigWrappers);
        Map<String, String> jurisdictionLabelMap = BREGUtils.getPicklistLabelMap('Account', 'BillingCountryCode');
        // validate form configuration items
        for (Case c : casesWithTargetFields) {
            List<FormConfigItemWrapper> formConfigItemWrappers = formCodeToFormConfigItemWrapperMap.containsKey(c.breg_Form_Code__c)
                ? formCodeToFormConfigItemWrapperMap.get(c.breg_Form_Code__c)
                : new List<FormConfigItemWrapper>();
            for (FormConfigItemWrapper formConfigItemWrapper : formConfigItemWrappers) {
                if (
                    formConfigItemWrapper.formConfigItem.breg_Form_Configuration__r.breg_Suffix_Code__c
                    != c.breg_Form_Configuration__r.breg_Suffix_Code__c
                ) {
                    continue;
                }
                Map<String, String> fieldNameToErrorMessage = new Map<String, String>();

                // validate required fields
                if (
                    formConfigItemWrapper.formConfigItem.breg_Required_for_Statuses__c != null &&
                    formConfigItemWrapper.formConfigItem.breg_Required_for_Statuses__c.contains(newStatus)
                ) {
                    fieldNameToErrorMessage = validateRequiredFields(formConfigItemWrapper.fieldApiNames, c);
                }
                // validate fields using apex custom validation class
                else if (String.isNotBlank(formConfigItemWrapper.formConfigItem.breg_Apex_Validation_Class_Name__c)) {
                    String handlerClassName = formConfigItemWrapper.formConfigItem.breg_Apex_Validation_Class_Name__c;
                    Object handler = BREGUtils.getHandlerInstance(handlerClassName);

                    // Expect handler to implement a known interface
                    if (handler instanceof BREGIFormFieldValidation) {
                        BREGIFormFieldValidation formFieldValidation = (BREGIFormFieldValidation) handler;
                        fieldNameToErrorMessage = formFieldValidation.validateFields(formConfigItemWrapper.formConfigItem, c);
                    } else {
                        String errorMessage =
                            'Apex Validation class "' +
                            formConfigItemWrapper.formConfigItem.breg_Apex_Validation_Class_Name__c +
                            '" for Form Configuration Item Id "' +
                            formConfigItemWrapper.formConfigItem.Id +
                            '" (Form Code: "' +
                            formConfigItemWrapper.formConfigItem.breg_Form_Configuration__r.breg_Form_Code__c +
                            '") must implement BREGIFormFieldValidation interface.';
                        addErrorMessage(triggerCasesMap.get(c.Id), null, errorMessage);
                    }
                }

                if (
                    formConfigItemWrapper.fieldApiNames.contains('breg_Entity_Jurisdiction__c') &&
                    String.isNotBlank(c.breg_Entity_Jurisdiction__c) &&
                    !jurisdictionLabelMap.containsKey(c.breg_Entity_Jurisdiction__c)
                ) {
                    fieldNameToErrorMessage.put(
                        'breg_Entity_Jurisdiction__c',
                        'The Entity Jurisdiction Country field should contain correct 2-letters Country Code. Please enter a valid value for Entity Jurisdiction Country.'
                    );
                }
                if (
                    formConfigItemWrapper.fieldApiNames.contains('breg_New_Entity_Jurisdiction__c') &&
                    String.isNotBlank(c.breg_New_Entity_Jurisdiction__c) &&
                    !jurisdictionLabelMap.containsKey(c.breg_New_Entity_Jurisdiction__c)
                ) {
                    fieldNameToErrorMessage.put(
                        'breg_New_Entity_Jurisdiction__c',
                        'The New Entity Jurisdiction Country field should contain correct 2-letters Country Code. Please enter a valid value for New Entity Jurisdiction Country.'
                    );
                }

                // add error messages to the case
                for (String fieldName : fieldNameToErrorMessage.keySet()) {
                    String errorMessage = fieldNameToErrorMessage.get(fieldName);
                    if (String.isNotBlank(errorMessage)) {
                        addErrorMessage(triggerCasesMap.get(c.Id), fieldName, errorMessage);
                    }
                }
            }
        }
    }

    /**
     * Returns the cases with target fields
     * @param cases - list of cases
     * @param formConfigWrappers - list of form configuration item wrappers
     * @return List<Case> - list of cases with target fields
     */
    private List<Case> getCasesWithTargetFields(List<Case> cases, List<FormConfigItemWrapper> formConfigWrappers) {
        List<Case> casesWithTargetFields = new List<Case>();
        Set<Id> caseIds = getCaseIds(cases);
        Set<String> fieldApiNames = new Set<String>();
        fieldApiNames.add('breg_Form_Configuration__c');
        fieldApiNames.add('breg_Form_Code__c');
        fieldApiNames.add('breg_Form_Configuration__r.breg_Suffix_Code__c');
        for (FormConfigItemWrapper wrapper : formConfigWrappers) {
            for (String fieldApiName : wrapper.fieldApiNames) {
                fieldApiNames.add(fieldApiName);
            }
        }
        if (fieldApiNames.isEmpty()) {
            return cases;
        }

        // Deduplicate field names case-insensitively to avoid SOQL duplicate field errors
        Set<String> normalizedFields = new Set<String>();
        List<String> uniqueFieldList = new List<String>();
        for (String field : fieldApiNames) {
            String normalized = field.toLowerCase();
            if (!normalizedFields.contains(normalized)) {
                normalizedFields.add(normalized);
                uniqueFieldList.add(field);
            }
        }

        String query = 'SELECT Id, ' + String.join(uniqueFieldList, ', ') + ' FROM Case WHERE Id IN :caseIds';
        casesWithTargetFields = Database.query(query);
        return casesWithTargetFields;
    }

    /**
     * Returns the case ids
     * @param cases - list of cases
     * @return Set<Id> - set of case ids
     */
    protected Set<Id> getCaseIds(List<Case> cases) {
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }
        return caseIds;
    }

    /**
     * @param cases - list of cases
     */
    public void updateCaseWithAssignmentRules(List<Case> cases) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.useDefaultRule = true;

        Group officeServicesQueue = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND Name = 'Office Services'
            LIMIT 1
        ];

        List<Case> casesToUpdate = new List<Case>();

        for (Case c : cases) {
            if (c.OwnerId == officeServicesQueue.Id) {
                continue;
            }
            Case caseToUpdate = new Case(Id = c.Id);
            if (c.breg_Bounced_Check_Due_Date__c == null) {
                Datetime nowUtc = System.now();

                TimeZone tz = UserInfo.getTimeZone();
                Integer offset = tz.getOffset(nowUtc) / 1000;
                Datetime orgNow = nowUtc.addSeconds(offset);
                Date orgDate = orgNow.date();

                caseToUpdate.breg_Bounced_Check_Due_Date__c = orgDate.addDays(15);
            }

            caseToUpdate.setOptions(dmlOpts);
            casesToUpdate.add(caseToUpdate);
        }

        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate, false);
        }
    }

    /**
     * Syncs linked LLP/GP cases to the given status when one of them moves to that status.
     * @param cases - list of cases that are moving to the status
     * @param status - status value to set on the related linked cases
     */
    private void syncLinkedLLPGPCasesToStatus(List<Case> cases, String status) {
        if (cases == null || cases.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (Case receivedCase : cases) {
            caseIds.add(receivedCase.Id);
        }
        List<Case> casesWithFormInfo = [
            SELECT Id, ParentId, breg_Form_Code__c, breg_Is_LLP_Registration__c
            FROM Case
            WHERE Id IN :caseIds
        ];
        Set<Id> llpCaseIds = new Set<Id>();
        Set<Id> parentCaseIdsFromGP = new Set<Id>();
        for (Case caseWithFormInfo : casesWithFormInfo) {
            if (caseWithFormInfo.breg_Form_Code__c == 'LLP-1' || caseWithFormInfo.breg_Form_Code__c == 'FLLP-1') {
                llpCaseIds.add(caseWithFormInfo.Id);
            } else if (
                caseWithFormInfo.breg_Form_Code__c == 'GP-1' &&
                caseWithFormInfo.breg_Is_LLP_Registration__c == true &&
                caseWithFormInfo.ParentId != null
            ) {
                parentCaseIdsFromGP.add(caseWithFormInfo.ParentId);
            }
        }
        Set<Id> relatedCaseIdsToSync = getLinkedGPCaseIdsForLLPCases(llpCaseIds);
        relatedCaseIdsToSync.addAll(parentCaseIdsFromGP);
        relatedCaseIdsToSync.removeAll(caseIds);
        if (relatedCaseIdsToSync.isEmpty()) {
            return;
        }
        List<Case> casesToUpdate = [
            SELECT Id, Status
            FROM Case
            WHERE Id IN :relatedCaseIdsToSync AND Status != :status
        ];
        if (casesToUpdate.isEmpty()) {
            return;
        }
        Integer resubDays = 45;
        if (status == 'Rejected') {
            BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
            if (setting != null && setting.Resubmission_Due_Date_Days__c != null) {
                resubDays = Integer.valueOf(setting.Resubmission_Due_Date_Days__c);
            }
        }
        for (Case caseRecord : casesToUpdate) {
            caseRecord.Status = status;
            if (status == 'Rejected') {
                caseRecord.breg_Resubmission_Due_Date__c = Date.today().addDays(resubDays);
            }
        }
        update casesToUpdate;
    }

    private Set<Id> getLinkedGPCaseIdsForLLPCases(Set<Id> llpCaseIds) {
        Set<Id> gpCaseIds = new Set<Id>();
        if (llpCaseIds == null || llpCaseIds.isEmpty()) {
            return gpCaseIds;
        }
        for (Case gpChildCase : [
            SELECT Id
            FROM Case
            WHERE ParentId IN :llpCaseIds AND breg_Form_Code__c = 'GP-1' AND breg_Is_LLP_Registration__c = TRUE
        ]) {
            gpCaseIds.add(gpChildCase.Id);
        }
        return gpCaseIds;
    }

    /**
     * Returns the form code to form configuration item wrappers map
     * @param formConfigItemWrappers - list of form configuration item wrappers
     * @return Map<String, List<FormConfigItemWrapper>> - map of form code to form configuration item wrappers
     */
    private Map<String, List<FormConfigItemWrapper>> getFormCodeToFormConfigItemWrappersMap(List<FormConfigItemWrapper> formConfigItemWrappers) {
        Map<String, List<FormConfigItemWrapper>> formCodeToFormConfigItemMap = new Map<String, List<FormConfigItemWrapper>>();
        for (FormConfigItemWrapper formConfigItemWrapper : formConfigItemWrappers) {
            if (!formCodeToFormConfigItemMap.containsKey(formConfigItemWrapper.formConfigItem.breg_Form_Configuration__r.breg_Form_Code__c)) {
                formCodeToFormConfigItemMap.put(
                    formConfigItemWrapper.formConfigItem.breg_Form_Configuration__r.breg_Form_Code__c,
                    new List<FormConfigItemWrapper>()
                );
            }
            formCodeToFormConfigItemMap.get(formConfigItemWrapper.formConfigItem.breg_Form_Configuration__r.breg_Form_Code__c).add(formConfigItemWrapper);
        }
        return formCodeToFormConfigItemMap;
    }

    /**
     * Returns the form configuration item wrappers
     * @param formConfigItems - list of form configuration items
     * @return List<FormConfigItemWrapper> - list of form configuration item wrappers
     */
    private List<FormConfigItemWrapper> getFormConfigItemWrappers(List<breg_Form_Configuration_Item__c> formConfigItems) {
        List<FormConfigItemWrapper> wrappers = new List<FormConfigItemWrapper>();
        for (breg_Form_Configuration_Item__c formConfigItem : formConfigItems) {
            FormConfigItemWrapper wrapper = getFormConfigItemWrapper(formConfigItem);
            if (wrapper != null) {
                wrappers.add(wrapper);
            }
        }
        return wrappers;
    }

    /**
     * Returns the form configuration item wrapper
     * @param formConfigItem - form configuration item
     * @return FormConfigItemWrapper - form configuration item wrapper
     */
    private FormConfigItemWrapper getFormConfigItemWrapper(breg_Form_Configuration_Item__c formConfigItem) {
        FormConfigItemWrapper wrapper = new FormConfigItemWrapper();
        try {
            wrapper.formConfigItem = formConfigItem;
            wrapper.fieldApiNames = parseFieldApiNames(formConfigItem.breg_Target_Fields_Mapping__c);
        } catch (Exception e) {
            System.debug(e.getMessage());
            wrapper = null;
        }

        return wrapper;
    }

    /**
     * Parses the field API names from the target fields mapping
     * @param targetFieldsMapping - target fields mapping
     * @return Set<String> - set of field API names
     */
    private Set<String> parseFieldApiNames(String targetFieldsMapping) {
        Set<String> fieldApiNames = new Set<String>();
        if (String.isNotBlank(targetFieldsMapping)) {
            // Parse the JSON into a Map<String, Object>
            Map<String, Object> mapping = (Map<String, Object>) JSON.deserializeUntyped(targetFieldsMapping);
            // Collect all field API names (after "Case.")
            for (Object val : mapping.values()) {
                String fieldRef = (String) val;
                if (fieldRef != null && fieldRef.startsWith('Case.')) {
                    fieldApiNames.add(fieldRef.replace('Case.', ''));
                }
            }
        }
        return fieldApiNames;
    }

    /**
     * Validates if required fields are filled for the case
     * @param fieldApiNames - field API names
     * @param c - case
     * @return Map<String, String> - map of field API name to error message
     */
    private Map<String, String> validateRequiredFields(Set<String> fieldApiNames, Case c) {
        Map<String, String> fieldNameToErrorMessage = new Map<String, String>();
        for (String fieldApiName : fieldApiNames) {
            if (String.isNotBlank(fieldApiName)) {
                Object value = c.get(fieldApiName);
                String fieldLabel = BREGUtils.returnFielLabelByApiName('Case', fieldApiName);
                if (value == null) {
                    // if the value is null, set the error message to the required field message
                    Boolean isFormationStateField = fieldApiName == 'breg_Formation_State__c';
                    Boolean isNewFormationStateField = fieldApiName == 'breg_New_Formation_State__c';

                    Boolean isStateRequired = true;
                    //if the required field is one of the state fields, check if the country has states before setting the error message, if not required
                    if (isFormationStateField) {
                        isStateRequired = BREGUtils.doesCountryHaveStates(c.breg_Entity_Jurisdiction__c);
                    } else if (isNewFormationStateField) {
                        isStateRequired = BREGUtils.doesCountryHaveStates(c.breg_New_Entity_Jurisdiction__c);
                    }

                    if (isStateRequired) {
                        fieldNameToErrorMessage.put(fieldApiName, fieldLabel + REQUIRED_FIELD_MESSAGE);
                    }
                } else {
                    // if the value is not null, set the error message to null
                    fieldNameToErrorMessage.put(fieldApiName, null);
                }
            }
        }
        return fieldNameToErrorMessage;
    }

    /**
     * Validates if payment is done for the cases
     * @param cases - list of cases
     */
    protected void validatePaymentCompletion(List<Case> cases) {
        Map<Id, Boolean> caseIdToPaymentDoneMap = BREGCaseStatusHandlerUtils.isPaymentDoneForCases(cases);
        for (Case c : cases) {
            if (c.breg_Form_Code__c == 'GP-1' && c.breg_Is_LLP_Registration__c && !caseIdToPaymentDoneMap.get(c.parentId)) {
                addErrorMessage(c, null, NO_PAYMENT_MESSAGE);
            } else if (
                (c.breg_Form_Code__c != 'GP-1' || !c.breg_Is_LLP_Registration__c) &&
                !caseIdToPaymentDoneMap.get(c.Id) &&
                c.breg_Form_Code__c != 'DOCDLVR'
            ) {
                addErrorMessage(c, null, NO_PAYMENT_MESSAGE);
            }
        }
    }

    protected void sharesCountValidation(List<Case> cases) {
        for (Case c : cases) {
            if (
                c.breg_Outstanding_Shares_Count__c > 0 &&
                c.breg_Authorized_Shares_Count__c > 0 &&
                c.breg_Outstanding_Shares_Count__c > c.breg_Authorized_Shares_Count__c
            ) {
                addErrorMessage(c, 'breg_Outstanding_Shares_Count__c', NUMBER_OF_SHARES_COUNT_MESSAGE);
            }
        }
    }

    private void validateResubmissionDate(List<Case> cases) {
        for (Case caseRecord : cases) {
            // if (caseRecord.breg_Resubmission_Due_Date__c < Date.today()) { // disabled validation in BREGMO-74
            //     addErrorMessage(caseRecord, 'breg_Resubmission_Due_Date__c', ERROR_RESUBMISSION_DUE_DATE_PAST);
            // }
            // if (caseRecord.breg_Last_Rejection_Date__c != null && caseRecord.breg_Resubmission_Due_Date__c != null) {
            //     if (caseRecord.breg_Resubmission_Due_Date__c > caseRecord.breg_Last_Rejection_Date__c.addDays(40)) {
            //         addErrorMessage(caseRecord, 'breg_Resubmission_Due_Date__c', ERROR_RESUBMISSION_DUE_DATE_TOO_FAR);
            //     }
            // }
            if (caseRecord.breg_Resubmission_Received_Date__c > Date.today()) {
                addErrorMessage(caseRecord, 'breg_Resubmission_Received_Date__c', ERROR_RESUBMISSION_RECIEVED_DATE_FUTURE);
            }
        }
    }

    private void validateEffectiveDateNotInTheFuture(List<Case> cases) {
        Date today = Date.today();
        List<Id> casesIds = new List<Id>();
        for (Case caseRecord : cases) {
            casesIds.add(caseRecord.Id);
        }
        List<Case> casesForCheck = [
            SELECT Id, breg_Effective_Date__c, breg_Form_Configuration__r.breg_Days_After_Submission_Hold_Approval__c
            FROM Case
            WHERE Id IN :casesIds
        ];
        for (Case caseRecord : casesForCheck) {
            if (
                caseRecord.breg_Form_Configuration__r.breg_Days_After_Submission_Hold_Approval__c != null &&
                caseRecord.breg_Effective_Date__c != null &&
                caseRecord.breg_Effective_Date__c > today
            ) {
                addErrorMessage(
                    caseRecord,
                    'breg_Effective_Date__c',
                    BREGUtils.returnFielLabelByApiName('Case', 'breg_Effective_Date__c') + ': ' + ERROR_EFFECTIVE_DATE
                );
            }
        }
    }

    private void validateEffectiveDate(List<Case> cases) {
        for (Case caseRecord : cases) {
            if (caseRecord.breg_Effective_Date__c == null) {
                addErrorMessage(
                    caseRecord,
                    'breg_Effective_Date__c',
                    BREGUtils.returnFielLabelByApiName('Case', 'breg_Effective_Date__c') + ': ' + REQUIRED_FIELD_MESSAGE
                );
            }
        }
    }

    private void validateEntityPopulation(List<Case> cases) {
        for (Case caseRecord : cases) {
            String formCode = caseRecord.breg_Form_Code__c;
            if (
                !BREGUtils.isNBRForm(formCode) &&
                !BREGUtils.isTNTMSMForm(formCode) &&
                !BREGUtils.isNameReservationForm(formCode) &&
                !BREGUtils.isCRARegistrationForm(formCode) &&
                !BREGUtils.isWithdrawalForm(formCode) &&
                caseRecord.breg_Entity__c == null
            ) {
                addErrorMessage(
                    caseRecord,
                    'breg_Entity__c',
                    BREGUtils.returnFielLabelByApiName('Case', 'breg_Entity__c') + ': ' + REQUIRED_FIELD_MESSAGE
                );
            }
        }
    }

    private void validateEntityStatus(List<Case> cases) {
        List<Id> notReinstEntitiesIds = new List<Id>();
        for (Case caseRecord : cases) {
            String formCode = String.isBlank(caseRecord.breg_Form_Code__c) ? null : caseRecord.breg_Form_Code__c.trim();
            Boolean isAnnualForm = BREGUtils.isAnnualForm(formCode) || (String.isNotBlank(formCode) && formCode.startsWith('ANN-'));
            if ( formCode != null &&
                !REINST_REVOKE_FORM_CODES.contains(formCode) &&
                formCode != 'DOCDLVR' &&
                !isAnnualForm &&
                caseRecord.breg_Entity__c != null
            ) {
                notReinstEntitiesIds.add(caseRecord.breg_Entity__c);
            }
        }
        Set<String> closedStatuses = BREGAdditionalEntityStatesUtils.CLOSED_STATUSES;
        Map<Id, Account> notReinstClosedEntities = new Map<Id, Account>(
            [SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Id IN :notReinstEntitiesIds AND breg_Entity_Status__c IN :closedStatuses]
        );
        if (notReinstClosedEntities.isEmpty()) {
            return;
        }
        for (Case caseRecord : cases) {
            if (notReinstClosedEntities.containsKey(caseRecord.breg_Entity__c)) {
                addErrorMessage(
                    caseRecord,
                    'breg_Entity__c',
                    BREGUtils.returnFielLabelByApiName('Case', 'breg_Entity__c') + ': ' + ERROR_ENTITY_STATUS_CLOSED
                );
            }
        }

    }

    private void validateFileNumber(List<Case> cases) {
        for (Case caseRecord : cases) {
            String formCode = caseRecord.breg_Form_Code__c;
            if (
                !BREGUtils.isNBRForm(formCode) &&
                !BREGUtils.isTNTMSMForm(formCode) &&
                !BREGUtils.isNameReservationForm(formCode) &&
                formCode != 'GP-4' &&
                !BREGUtils.isWithdrawalForm(formCode) &&
                !BREGUtils.isMergerForm(formCode) &&
                !BREGUtils.isAnnualForm(formCode) &&
                !(BREGUtils.isCRARegistrationForm(formCode) && caseRecord.breg_Reg_Agent_Type__c == 'Individual') &&
                caseRecord.breg_File__c == null
            ) {
                addErrorMessage(caseRecord, 'breg_File__c', BREGUtils.returnFielLabelByApiName('Case', 'breg_File__c') + ': ' + REQUIRED_FIELD_MESSAGE);
            }
        }
    }

    /**
     * Adds an error message to the case
     * @param c - case
     * @param fieldApiName - field API name
     * @param errorMessage - error message
     */
    protected void addErrorMessage(Case c, String fieldApiName, String errorMessage) {
        System.debug('addErrorMessage: ' + errorMessage);
        if (Trigger.isExecuting) {
            if (String.isNotBlank(fieldApiName)) {
                c.addError(fieldApiName, errorMessage);
            } else {
                c.addError(errorMessage);
            }
        } else {
            BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException ex = new BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException(errorMessage);
            ex.errorMessage = errorMessage;
            throw ex;
        }
    }

    protected List<breg_Transaction__c> upsertTransactions(Map<Id, Case> casesMap, String status) {
        // Overload for when transaction code is determined solely by Case's Form Configuration
        if (casesMap.isEmpty()) {
            return null;
        }
        Map<Id, Id> caseToEntityMap = new Map<Id, Id>();
        for (Case c : casesMap.values()) {
            caseToEntityMap.put(c.Id, c.breg_Entity__c);
        }
        List<breg_Transaction__c> transactions = BREGTransactionUtils.upsertTransactionRecords(casesMap, caseToEntityMap, status);
        if (!transactions.IsEmpty()) {
            BREGSObjectUpdaterWithoutSharing.upsertRecords(transactions);
        }
        return transactions;
    }

    protected List<breg_Transaction_Address__c> createTransactionAdresses(
        Map<Id, Case> casesMap,
        List<breg_Transaction__c> transactions,
        Map<Id, Id> caseToAffiliationMap
    ) {
        if (casesMap.isEmpty()) {
            return null;
        }

        List<breg_Transaction_Address__c> transAdresses = BREGTransactionUtils.createTransactionAdresses(casesMap, transactions, caseToAffiliationMap);
        if (!transactions.IsEmpty()) {
            insert transAdresses;
        }
        return transAdresses;
    }

    protected void updateEndDateInLastTransAddressRecords(List<Account> accounts, Map<Id, Case> entityToCaseMap, Map<Id, Id> caseIdToAffiliationId) {
        BREGTransactionUtils.updateEndDateInLastTransAddressRecords(accounts, entityToCaseMap, caseIdToAffiliationId);
    }

    protected void validateEntityNameEqualAccName(Map<Id, Case> casesForCheck, List<Case> cases) {
        for (Case triggerCase : cases) {
            Case caseRecord = casesForCheck.isEmpty() ? triggerCase : casesForCheck.get(triggerCase.Id);
            String errorMessage;
            if (caseRecord.breg_Form_Code__c != 'X-1' && caseRecord.breg_Form_Code__c != 'X-2' && caseRecord.breg_Entity__c == null) {
                errorMessage = REQUIRED_FIELD_MESSAGE;
                addErrorMessage(triggerCase, 'breg_Entity__c', BREGUtils.returnFielLabelByApiName('Case', 'breg_Entity__c') + ': ' + errorMessage);
            } else if ((caseRecord.breg_Form_Code__c == 'X-1' || caseRecord.breg_Form_Code__c == 'X-2') && caseRecord.breg_Name_Reservation__c == null) {
                errorMessage = REQUIRED_FIELD_MESSAGE;
                addErrorMessage(
                    triggerCase,
                    'breg_Name_Reservation__c',
                    BREGUtils.returnFielLabelByApiName('Case', 'breg_Name_Reservation__c') + ': ' + errorMessage
                );
            } else if (
                (caseRecord.breg_Form_Code__c == 'X-1' || caseRecord.breg_Form_Code__c == 'X-2') &&
                caseRecord.breg_Name_Reservation__r.Name != caseRecord.breg_Name_for_Reservation__c
            ) {
                errorMessage = ERROR_RESERVATION_NAME_DIFFERS_FROM_ENTITY;
                addErrorMessage(
                    triggerCase,
                    'breg_Name_for_Reservation__c',
                    BREGUtils.returnFielLabelByApiName('Case', 'breg_Name_for_Reservation__c') + ': ' + errorMessage
                );
            }
        }
    }

    public class FormConfigItemWrapper {
        // form configuration item
        public breg_Form_Configuration_Item__c formConfigItem;
        // field API names to validate
        public Set<String> fieldApiNames;
    }

    /**
     * Performs the approved status actions for NBR, TNTMSM, and Name Reservation forms
     * Migrated from BREG_Case_Status_Approved flow
     * @param cases - list of cases
     */
    protected void performApprovedActionsForSpecialForms(List<Case> cases) {
        // Filter cases that are NBR, TNTMSM, or Name Reservation forms
        List<Case> specialFormCases = filterSpecialFormCases(cases);
        if (specialFormCases.isEmpty()) {
            return;
        }

        // Requery cases with all required fields for processing
        List<Case> casesWithDetails = queryCasesForApprovalProcessing(specialFormCases);

        // Get Account Affiliations for cases (for applicant lookup)
        Map<Id, breg_Account_Affiliation__c> caseIdToApplicantMap = getApplicantAffiliationsByCaseId(casesWithDetails);

        // Get current user for creator field
        Id currentUserId = UserInfo.getUserId();

        // Get BREG Account Record Type (cached)
        Id bregAccountRtId = getBREGAccountRecordTypeId();

        // BULKIFIED: Pre-query all existing Accounts by entity name
        Map<String, Account> existingAccountsByName = getExistingAccountsByName(casesWithDetails, caseIdToApplicantMap);

        // Process each case
        Map<Id, Account> caseIdToAccountMap = new Map<Id, Account>();
        Map<Id, Case> accIdToCaseMap = new Map<Id, Case>();
        Map<String, Case> accNameToCaseMap = new Map<String, Case>();
        Map<Id, breg_TN_TM_SM__c> caseIdToTNTMSMMap = new Map<Id, breg_TN_TM_SM__c>();
        List<Case> casesToUpdate = new List<Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        Map<Id, Case> entityIdToCaseMap = new Map<Id, Case>();
        List<String> fieldsToTrack = BREGCaseStatusHandlerHelper.getFieldsFromFieldSet('Account', 'BREG_TBI_Fields_Set');

        Set<Id> entitiesIds = new Set<Id>();
        List<Case> caseWithoutFileNumbers = new List<Case>();
        for (Case c : casesWithDetails) {
            if (c.breg_Name_Reservation__c != null) {
                entitiesIds.add(c.breg_Name_Reservation__c);
            } else if (c.breg_Entity__c != null) {
                entitiesIds.add(c.breg_Entity__c);
            }
        }        
        Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, breg_Entity_Type__c FROM Account WHERE Id IN :entitiesIds]);
        for (Case c : casesWithDetails) {
            // Lookup or create Account using pre-queried map
            Account acc = lookupOrCreateAccount(c, caseIdToApplicantMap.get(c.Id), bregAccountRtId, c.CreatedById, existingAccountsByName, accountMap);
            if (acc != null) {
                entityIdToCaseMap.put(acc.Id, c);
                caseIdToAccountMap.put(c.Id, acc);
                if (acc.Id == null) {
                    Id relatedAccountId = c.breg_Name_Reservation__c != null ? c.breg_Name_Reservation__c : c.breg_Entity__c;
                    accNameToCaseMap.put(relatedAccountId, c);
                }
            }
        }

        // Insert new accounts
        List<Account> accountsToInsert = new List<Account>();
        List<Account> accountsToUpdate = new List<Account>();

        for (Account acc : caseIdToAccountMap.values()) {
            if (acc.Id == null) {
                accountsToInsert.add(acc);
            } /*else {
                Set<String> updatedFields = BREGCaseStatusHandlerHelper.getChangedFields(null, acc, fieldsToTrack);
                accountUpdatedFieldsMap.put(acc.Id, updatedFields);
                accountsToUpdate.add(acc);
            }*/
        }
        if (!accountsToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityIdToCaseMap);
        }
        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
            for (Account acc : accountsToInsert) {
                accIdToCaseMap.put(acc.Id, accNameToCaseMap.get(acc.Name));
            }
            BREGTransactionUtils.updateEndDateInLastTransAddressRecords(accountsToInsert, accIdToCaseMap, null);
        }

        // BULKIFIED: Pre-query all existing TNTMSM records
        Map<String, breg_TN_TM_SM__c> existingTNTMSMByKey = getExistingTNTMSMRecords(casesWithDetails, caseIdToAccountMap);

        // Process TNTMSM forms - lookup or create TNTMSM records using pre-queried map
        for (Case c : casesWithDetails) {
            if (BREGUtils.isTNTMSMForm(c.breg_Form_Code__c)) {
                Account acc = caseIdToAccountMap.get(c.Id);
                breg_TN_TM_SM__c tntmsm = lookupOrCreateTNTMSM(c, acc, existingTNTMSMByKey);
                if (tntmsm != null) {
                    caseIdToTNTMSMMap.put(c.Id, tntmsm);
                }
            }
        }

        // Insert new TNTMSM records
        List<breg_TN_TM_SM__c> tntmsmsToInsert = new List<breg_TN_TM_SM__c>();
        for (breg_TN_TM_SM__c tntmsm : caseIdToTNTMSMMap.values()) {
            if (tntmsm.Id == null) {
                tntmsmsToInsert.add(tntmsm);
            }
        }
        if (!tntmsmsToInsert.isEmpty()) {
            insert tntmsmsToInsert;
        }
        // Update cases with Entity and TNTMSM lookups
        for (Case c : casesWithDetails) {
            Account acc = caseIdToAccountMap.get(c.Id);
            breg_TN_TM_SM__c tntmsm = caseIdToTNTMSMMap.get(c.Id);

            Case caseToUpdate = new Case(Id = c.Id);
            Boolean needsUpdate = false;

            if (acc != null && ((c.breg_Form_Code__c != 'X-1' && c.breg_Form_Code__c != 'X-2' && c.breg_Entity__c != acc.Id))) {
                caseToUpdate.breg_Entity__c = acc.Id;
                c.breg_Entity__c = acc.Id;
                needsUpdate = true;
            } else if ((c.breg_Form_Code__c == 'X-1' || c.breg_Form_Code__c == 'X-2') && c.breg_Name_Reservation__c != acc.Id) {
                caseToUpdate.breg_Name_Reservation__c = acc.Id;
                c.breg_Name_Reservation__c = acc.Id;
                needsUpdate = true;
            }
            if (tntmsm != null && c.breg_TN_TM_SM__c != tntmsm.Id) {
                caseToUpdate.breg_TN_TM_SM__c = tntmsm.Id;
                c.breg_TN_TM_SM__c = tntmsm.Id;
                needsUpdate = true;
            }

            if (needsUpdate) {
                casesToUpdate.add(caseToUpdate);
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }

        // Handle LLP-1, FLLP-1 parent entity updates 
        handleLLP1ParentEntity(casesWithDetails);

        // Update Name Reservation accounts with Case fields (breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_Consent__c, breg_Similar_Name__c)
        updateNameReservationAccountFields(casesWithDetails, caseIdToAccountMap);

        // Create free email notifications for TNTMSM forms
        createFreeEmailNotifications(casesWithDetails, caseIdToTNTMSMMap);

        // Update Account Affiliations with Entity and TNTMSM lookups
        updateAccountAffiliationsLookups(casesWithDetails, caseIdToAccountMap, caseIdToTNTMSMMap);

        // Create stocks for NBR forms with stock
        createStocksForNBRFormsWithStock(casesWithDetails, caseIdToAccountMap);

    }

    /**
     * Updates Name Reservation (X-1, X-2) Account records with Case fields when approved.
     * Copies breg_Xref_Name_1__c, breg_Xref_Name_2__c, breg_Consent__c, breg_Similar_Name__c from Case to Account.
     * @param cases - list of cases with details
     * @param caseIdToAccountMap - map of case Id to Account
     */
    private void updateNameReservationAccountFields(List<Case> cases, Map<Id, Account> caseIdToAccountMap) {
        List<Account> accountsToUpdate = new List<Account>();
        for (Case c : cases) {
            if (!BREGUtils.isNameReservationForm(c.breg_Form_Code__c)) {
                continue;
            }
            Account acc = caseIdToAccountMap.get(c.Id);
            if (acc == null || acc.Id == null) {
                continue;
            }
            accountsToUpdate.add(
                new Account(
                    Id = acc.Id,
                    breg_Xref_Name_1__c = c.breg_Xref_Name_1__c,
                    breg_Xref_Name_2__c = c.breg_Xref_Name_2__c,
                    breg_Consent__c = c.breg_Consent__c,
                    breg_Similar_Name__c = c.breg_Similar_Name__c,
                    breg_Reserved_for_Entity_Type__c = c.breg_New_Entity_Type__c
                )
            );
        }
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    /**
     * Creates stocks for NBR forms with stock
     * @param cases - list of cases
     * @param caseIdToAccountMap - map of case Id to Account
     */
    private void createStocksForNBRFormsWithStock(List<Case> cases, Map<Id, Account> caseIdToAccountMap) {
        List<breg_Stock__c> stocksToInsert = new List<breg_Stock__c>();
        for (Case c : cases) {
            if (
                BREGUtils.isNBRFormWithStock(c.breg_Form_Code__c) && // form code is NBR form with stock
                c.breg_Number_of_common_shares__c != null // if number of common shares is null, then it's a NBR form without stock
            ) {
                breg_Stock__c stock = new breg_Stock__c();
                stock.breg_Case__c = c.Id;
                stock.breg_Account__c = caseIdToAccountMap.get(c.Id).Id;
                stock.breg_Stock_Class__c = 'Common';
                stock.breg_Start_Date__c = c.breg_Effective_Date__c;
                // user input fields, per value is not populated on all forms
                stock.breg_Number_of_Issued_Shares__c = c.breg_Number_of_common_shares__c != null
                    ? String.valueOf(c.breg_Number_of_common_shares__c)
                    : null;
                stock.breg_Per_Value__c = c.breg_Par_Value_Of_Each_Share__c != null ? String.valueOf(c.breg_Par_Value_Of_Each_Share__c) : null;

                stocksToInsert.add(stock);
            }
        }
        if (!stocksToInsert.isEmpty()) {
            insert stocksToInsert;
        }
    }

    /**
     * BULKIFIED: Pre-queries all existing Accounts by entity name
     * TNTMSM New filings never reuse an Account by name.
     * TNTMSM Renewal filings reuse an Account only when it has a related breg_TN_TM_SM__c
     * whose Name matches Case.breg_TNTMSM_Description__c. Those matches are keyed by
     * entity name + TNTMSM name so bulk approve does not cross-match cases.
     * @param cases - list of cases
     * @param caseIdToApplicantMap - map of case Id to applicant affiliation
     * @return Map<String, Account> - map of lookup key to existing Account
     */
    private Map<String, Account> getExistingAccountsByName(List<Case> cases, Map<Id, breg_Account_Affiliation__c> caseIdToApplicantMap) {
        Map<String, Account> result = new Map<String, Account>();
        Set<String> entityNames = new Set<String>();
        Set<String> tntmsmDescriptions = new Set<String>();
        Boolean hasNonTntmsmLookup = false;

        // Collect entity names for cases that may legitimately reuse an existing Account (NBR cases never do)
        for (Case c : cases) {
            if (
                c.breg_Entity__c != null ||
                c.breg_Name_Reservation__c != null ||
                BREGUtils.isNBRForm(c.breg_Form_Code__c) ||
                BREGUtils.isNameReservationForm(c.breg_Form_Code__c)
            ) {
                continue;
            }

            String entityName = calculateEntityName(c, caseIdToApplicantMap.get(c.Id));
            if (String.isBlank(entityName)) {
                continue;
            }

            if (BREGUtils.isTNTMSMForm(c.breg_Form_Code__c)) {
                // New TNTMSM filings skip Account name lookup entirely
                if (c.breg_TNTMSM_Registration_Type__c != 'Renewal') {
                    continue;
                }
                String tntmsmName = toTntmsmRecordName(c.breg_TNTMSM_Description__c);
                if (String.isBlank(tntmsmName)) {
                    continue;
                }
                entityNames.add(entityName);
                tntmsmDescriptions.add(tntmsmName);
            } else {
                entityNames.add(entityName);
                hasNonTntmsmLookup = true;
            }
        }

        if (entityNames.isEmpty()) {
            return result;
        }

        // Query all existing accounts in one SOQL

        Id bregRtId = getBREGAccountRecordTypeId();
        Set<String> closedStatuses = BREGAdditionalEntityStatesUtils.CLOSED_STATUSES;

        List<Account> existingAccounts = [
            SELECT
                Id,
                Name,
                breg_Entity_Type__c,
                breg_Formation_Country__c,
                breg_Formation_State__c,
                breg_Formation_State_Label__c,
                breg_Formation_Country_Label__c,
                breg_Entity_Type_Description__c,
                breg_File_Suffix__c,
                breg_File__c,
                breg_Authorized_Shares_Count__c,
                RecordTypeId
            FROM Account
            WHERE Name IN :entityNames AND RecordTypeId = :bregRtId AND breg_Entity_Status__c NOT IN :closedStatuses
        ];

        if (hasNonTntmsmLookup) {
            for (Account acc : existingAccounts) {
                result.put(acc.Name, acc);
            }
        }

        putTntmsmRenewalAccountsByCompositeKey(result, existingAccounts, tntmsmDescriptions);

        return result;
    }

    /**
     * Adds TNTMSM Renewal Account matches keyed by entity name + TNTMSM name.
     * @param result - lookup map to populate
     * @param accounts - candidate accounts found by name
     * @param tntmsmDescriptions - TNTMSM Names to match (truncated to the Name field length)
     */
    private void putTntmsmRenewalAccountsByCompositeKey(
        Map<String, Account> result,
        List<Account> accounts,
        Set<String> tntmsmDescriptions
    ) {
        if (result == null || accounts == null || accounts.isEmpty() || tntmsmDescriptions == null || tntmsmDescriptions.isEmpty()) {
            return;
        }

        Map<Id, Account> accountsById = new Map<Id, Account>(accounts);
        for (breg_TN_TM_SM__c tntmsm : [
            SELECT Name, breg_Account__c
            FROM breg_TN_TM_SM__c
            WHERE breg_Account__c IN :accountsById.keySet() AND Name IN :tntmsmDescriptions
        ]) {
            Account acc = accountsById.get(tntmsm.breg_Account__c);
            if (acc == null || String.isBlank(tntmsm.Name)) {
                continue;
            }
            result.put(buildTntmsmAccountLookupKey(acc.Name, tntmsm.Name), acc);
        }
    }

    /**
     * Builds the Account lookup key for a TNTMSM Renewal case.
     * @param entityName - calculated entity name
     * @param tntmsmName - truncated TNTMSM description / related TNTMSM Name
     * @return String - composite lookup key
     */
    private String buildTntmsmAccountLookupKey(String entityName, String tntmsmName) {
        return entityName + '|' + tntmsmName;
    }

    /**
     * Truncates a TNTMSM description to the breg_TN_TM_SM__c.Name field length.
     * @param tntmsmName - Case TNTMSM description
     * @return String - Name value used on breg_TN_TM_SM__c
     */
    private String toTntmsmRecordName(String tntmsmName) {
        if (String.isBlank(tntmsmName)) {
            return tntmsmName;
        }
        return tntmsmName.length() > 80 ? tntmsmName.substring(0, 80) : tntmsmName;
    }

    /**
     * BULKIFIED: Pre-queries all existing TNTMSM records
     * @param cases - list of cases
     * @param caseIdToAccountMap - map of case Id to Account
     * @return Map<String, breg_TN_TM_SM__c> - map of composite key (name + accountId) to TNTMSM
     */
    private Map<String, breg_TN_TM_SM__c> getExistingTNTMSMRecords(List<Case> cases, Map<Id, Account> caseIdToAccountMap) {
        Map<String, breg_TN_TM_SM__c> result = new Map<String, breg_TN_TM_SM__c>();
        Set<String> tntmsmNames = new Set<String>();
        Set<Id> accountIds = new Set<Id>();

        // Collect all TNTMSM names and Account IDs that need lookup
        for (Case c : cases) {
            if (BREGUtils.isTNTMSMForm(c.breg_Form_Code__c) && c.breg_TN_TM_SM__c == null) {
                Account acc = caseIdToAccountMap.get(c.Id);
                if (acc != null && acc.Id != null && String.isNotBlank(c.breg_TNTMSM_Description__c)) {
                    String tntmsmName = c.breg_TNTMSM_Description__c;
                    String tntmsmName80 = tntmsmName.length() > 80 ? tntmsmName.substring(0, 80) : tntmsmName;
                    tntmsmNames.add(tntmsmName80);
                    accountIds.add(acc.Id);
                }
            }
        }

        if (tntmsmNames.isEmpty() || accountIds.isEmpty()) {
            return result;
        }

        Date today = Date.today();
        // Query all existing TNTMSM records in one SOQL
        List<breg_TN_TM_SM__c> existingRecords = [
            SELECT Id, Name, breg_Account__c
            FROM breg_TN_TM_SM__c
            WHERE Name IN :tntmsmNames 
            AND breg_Account__c IN :accountIds
            AND breg_Status__c = 'A'
            AND breg_End_Date__c = NULL
            AND breg_Expiration_Date__c > :today
        ];

        for (breg_TN_TM_SM__c rec : existingRecords) {
            // Create composite key: name + accountId
            String key = rec.Name + '|' + rec.breg_Account__c;
            result.put(key, rec);
        }

        return result;
    }

    /**
     * Filters cases that are NBR, TNTMSM, or Name Reservation forms
     * @param cases - list of cases
     * @return List<Case> - filtered list of special form cases
     */
    private List<Case> filterSpecialFormCases(List<Case> cases) {
        List<Case> specialFormCases = new List<Case>();
        for (Case c : cases) {
            String formCode = c.breg_Form_Code__c;
            if (BREGUtils.isNBRForm(formCode) || BREGUtils.isTNTMSMForm(formCode) || BREGUtils.isNameReservationForm(formCode)) {
                specialFormCases.add(c);
            }
        }
        return specialFormCases;
    }

    /**
     * Queries cases with all fields required for approval processing
     * @param cases - list of cases
     * @return List<Case> - cases with all required fields
     */
    protected List<Case> queryCasesForApprovalProcessing(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        return [
            SELECT
                Id,
                breg_Form_Code__c,
                breg_Entity__c,
                breg_TN_TM_SM__c,
                breg_Entity_Type__c,
                breg_Name_of_the_Entity__c,
                breg_TNTMSM_Description__c,
                breg_TNTMSM_Certificate__c,
                breg_TNTMSM_Registration_Type__c,
                breg_Company_Address__City__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__PostalCode__s,
                breg_Company_Address_State__c,
                breg_Company_Address__StateCode__s,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address_State__c,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Delivery_Address__City__s,
                breg_Delivery_Address__CountryCode__s,
                breg_Delivery_Address__PostalCode__s,
                breg_Delivery_Address__Street__s,
                breg_Delivery_Address__StateCode__s,
                breg_Delivery_Address_State_Text__c,
                breg_Delivery_Address_Street2__c,
                breg_BRIM_FILE_NO__c,
                breg_Workitem_Number__c,
                breg_ESWM_WFWORKITEM_ID__c,
                Origin,
                CaseNumber,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Effective_Date__c,
                breg_Expiration_Date__c,
                breg_Partnership_Begin_Business_Date__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Purposes__c,
                breg_Subscribe_Owner_Free_Email_Alerts__c,
                breg_Applicant_Is_Entity__c,
                breg_Applicant_Name__c,
                breg_Applicant_First_Name__c,
                breg_Entity_Jurisdiction__c,
                breg_Formation_State__c,
                breg_Applicant_Last_Name__c,
                breg_Reg_Agent_Type__c,
                breg_TNTMSM_Classification__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Entity_Type__c,
                breg_Form_Configuration__r.breg_Business_Location__c,
                breg_Form_Configuration__r.breg_Business_Structure__c,
                breg_Form_Configuration__r.breg_Registration_Type__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                ContactId,
                breg_Transaction_Code__c,
                Contact.Email,
                ParentId,
                breg_GP_Already_Registered__c,
                breg_GP_Entity__c,
                breg_GP_Case__r.breg_Entity__c,
                breg_Is_LLP_Registration__c,
                breg_Number_of_common_shares__c,
                breg_Par_Value_Of_Each_Share__c,
                CreatedById,
                breg_Xref_Name_1__c,
                breg_Xref_Name_2__c,
                breg_Consent__c,
                breg_Similar_Name__c,
                breg_Duration_Period__c,
                breg_Entity_Term_To_Expire__c,
                breg_Name_Reservation__c,
                breg_Name_for_Reservation__c,
                breg_Is_Manager_Managed__c,
                breg_Number_of_Initial_Members__c,
                breg_New_Entity_Type__c,
                OwnerId,
                breg_Received_Date_Formula__c,
                breg_Annual__r.breg_Filing_Date__c
            FROM Case
            WHERE Id IN :caseIds
        ];
    }

    /**
     * Gets applicant account affiliations for cases
     * @param cases - list of cases
     * @return Map<Id, breg_Account_Affiliation__c> - map of case Id to applicant affiliation
     */
    private Map<Id, breg_Account_Affiliation__c> getApplicantAffiliationsByCaseId(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, breg_Account_Affiliation__c> result = new Map<Id, breg_Account_Affiliation__c>();

        List<breg_Account_Affiliation__c> affiliations = [
            SELECT
                Id,
                breg_Case__c,
                breg_Account__c,
                breg_Type__c,
                breg_Status__c,
                breg_Entity_Name__c,
                breg_Entity_Type__c,
                breg_Entity_Type_Description__c,
                breg_Suffix__c,
                breg_File__c,
                breg_Number_of_shares__c,
                breg_Entity_Location__c,
                breg_Entity_Location_Country__c,
                breg_First_Name__c,
                breg_Last_Name__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds AND breg_Role__c = 'Applicant'
        ];

        for (breg_Account_Affiliation__c aff : affiliations) {
            result.put(aff.breg_Case__c, aff);
        }

        return result;
    }

    /**
     * Gets the BREG Account Record Type Id (cached to avoid duplicate queries)
     * @return Id - BREG Account Record Type Id
     */
    private Id getBREGAccountRecordTypeId() {
        if (cachedBREGAccountRecordTypeId == null) {
            List<RecordType> rtList = [SELECT Id FROM RecordType WHERE Name = 'BREG Account' AND SObjectType = 'Account' LIMIT 1];
            cachedBREGAccountRecordTypeId = rtList.isEmpty() ? null : rtList[0].Id;
        }
        return cachedBREGAccountRecordTypeId;
    }

    /**
     * Looks up or creates an Account based on case data
     * BULKIFIED: Uses pre-queried existingAccountsByName map instead of querying per case
     * @param c - case record
     * @param applicant - applicant account affiliation
     * @param recordTypeId - BREG Account Record Type Id
     * @param creatorId - user Id for creator field
     * @param existingAccountsByName - pre-queried map of entity name to existing Account
     * @return Account - existing or new account
     */
    private Account lookupOrCreateAccount(
        Case c,
        breg_Account_Affiliation__c applicant,
        Id recordTypeId,
        Id creatorId,
        Map<String, Account> existingAccountsByName,
        Map<Id, Account> accountMap
    ) {
        // Calculate entity name based on form type and applicant data
        String entityName = calculateEntityName(c, applicant);
        if (String.isBlank(entityName)) {
            return null;
        }
        Id relatedEntityId = c.breg_Name_Reservation__c != null ? c.breg_Name_Reservation__c : c.breg_Entity__c;
        // If entity is already linked, use that account
        if (
            relatedEntityId != null &&
            accountMap.get(relatedEntityId).breg_Entity_Type__c != ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE &&
            !BREGUtils.isNameReservationForm(c.breg_Form_Code__c)
        ) {
            return new Account(Id = relatedEntityId);
        }
        // Try to find existing account from pre-queried map (BULKIFIED - no SOQL here)
        Account existingAccount = lookupExistingAccount(c, entityName, existingAccountsByName);
        List<breg_Account_Affiliation__c> affiliationsToUpdate = new List<breg_Account_Affiliation__c>();
        Boolean foundByApplicantName = BREGUtils.isTNTMSMForm(c.breg_Form_Code__c) && applicant != null && applicant.breg_Type__c == 'Entity';
        if (existingAccount != null && foundByApplicantName) {
            applicant.breg_Account__c = existingAccount.Id;
            BREGCaseStatusHandlerHelper.populateAffiliationEntityFieldsFromEntity(applicant, existingAccount);
            affiliationsToUpdate.add(applicant);
        }
        if (!affiliationsToUpdate.isEmpty()) {
            update affiliationsToUpdate;
        }
        if (existingAccount != null) {
            return existingAccount;
        }

        // Create new account
        Account newAccount = new Account();
        populateAccountFromCase(newAccount, c, entityName, recordTypeId, creatorId, applicant);
        return newAccount;
    }

    /**
     * Looks up an existing account candidate that can be reused for the given case.
     * @param c - case record
     * @param entityName - calculated entity name
     * @param existingAccountsByName - pre-queried map of entity name to existing Account
     * @return Account - reusable existing account or null
     */
    private Account lookupExistingAccount(Case c, String entityName, Map<String, Account> existingAccountsByName) {
        if (String.isBlank(entityName)) {
            return null;
        }

        String lookupKey = entityName;
        if (BREGUtils.isTNTMSMForm(c.breg_Form_Code__c)) {
            if (c.breg_TNTMSM_Registration_Type__c != 'Renewal') {
                return null;
            }
            lookupKey = buildTntmsmAccountLookupKey(entityName, toTntmsmRecordName(c.breg_TNTMSM_Description__c));
        }

        if (!existingAccountsByName.containsKey(lookupKey)) {
            return null;
        }

        Account existingAccount = existingAccountsByName.get(lookupKey);
        if (
            existingAccount.Id == c.breg_Entity__c ||
            existingAccount.breg_Entity_Type__c == ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE ||
            BREGUtils.isNBRForm(c.breg_Form_Code__c) ||
            BREGUtils.isNameReservationForm(c.breg_Form_Code__c)
        ) {
            return null;
        }

        return existingAccount;
    }

    /**
     * Populates an Account with data from a Case
     * @param acc - account to populate
     * @param c - case record
     * @param entityName - calculated entity name
     * @param recordTypeId - BREG Account Record Type Id
     * @param creatorId - user Id for creator field
     */
    protected void populateAccountFromCase(Account acc, Case c, String entityName, Id recordTypeId, Id creatorId, breg_Account_Affiliation__c applicant) {
        acc.Name = entityName;
        acc.RecordTypeId = recordTypeId;
        acc.breg_Creator__c = creatorId;
        acc.breg_Entity_Status__c = ENTITY_STATUS_NEW;
        acc.breg_Good_Standing__c = true;

        // Billing address
        acc.BillingCity = c.breg_Company_Address__City__s;
        acc.BillingCountryCode = c.breg_Company_Address__CountryCode__s;
        acc.BillingPostalCode = c.breg_Company_Address__PostalCode__s;
        acc.BillingStreet = c.breg_Company_Address__Street__s;
        acc.breg_Billing_Address_Street_2__c = c.breg_Company_Address_Street2__c;

        // Billing state - only set StateCode if country is US
        if (c.breg_Company_Address__CountryCode__s == 'US') {
            acc.BillingStateCode = c.breg_Company_Address__StateCode__s;
        } else {
            acc.breg_Billing_Address_State_Text__c = c.breg_Company_Address_State__c;
        }

        // Mailing address
        acc.breg_Mailing_Address__City__s = c.breg_Mailing_Address__City__s;
        acc.breg_Mailing_Address__CountryCode__s = c.breg_Mailing_Address__CountryCode__s;
        acc.breg_Mailing_Address__PostalCode__s = c.breg_Mailing_Address__PostalCode__s;
        acc.breg_Mailing_Address__Street__s = c.breg_Mailing_Address__Street__s;
        acc.breg_Mailing_Address_Street_2__c = c.breg_Mailing_Address_Number_and_Street_2__c;

        // Mailing state - only set StateCode if country is US
        if (c.breg_Mailing_Address__CountryCode__s == 'US') {
            acc.breg_Mailing_Address__StateCode__s = c.breg_Mailing_Address__StateCode__s;
        } else {
            acc.breg_Mailing_Address_State_Text__c = c.breg_Mailing_Address_State__c;
        }

        // Shipping address
        acc.ShippingCity = c.breg_Delivery_Address__City__s;
        acc.ShippingCountryCode = c.breg_Delivery_Address__CountryCode__s;
        acc.ShippingPostalCode = c.breg_Delivery_Address__PostalCode__s;
        acc.ShippingStreet = c.breg_Delivery_Address__Street__s;
        acc.breg_Shipping_Street2__c = c.breg_Delivery_Address_Street2__c;

        // Shipping state - only set StateCode if country is US
        if (c.breg_Delivery_Address__CountryCode__s == 'US') {
            acc.ShippingStateCode = c.breg_Delivery_Address__StateCode__s;
        } else {
            acc.ShippingState = c.breg_Delivery_Address_State_Text__c;
        }
        if(New List<String>{'T-1', 'T-2', 'T-3', 'T-7'}.contains(c.breg_Form_Code__c)) {
            if(applicant != null) {
                acc.breg_Registrant_Type__c = applicant.breg_Type__c;
            } else if (c.breg_Applicant_Is_Entity__c == true) {
                acc.breg_Registrant_Type__c = 'Entity';
            } else {
                acc.breg_Registrant_Type__c = 'Individual';
            }
        }

       

        //Formation fields
        if (applicant != null){
            acc.breg_Formation_Country__c = applicant.breg_Entity_Location_Country__c;
            acc.breg_Formation_State__c = applicant.breg_Entity_Location__c;
        } else {
            acc.breg_Formation_Country__c = c.breg_Entity_Jurisdiction__c;
            acc.breg_Formation_State__c = c.breg_Formation_State__c;
        }

        //XREF fields
        acc.breg_Xref_Name_1__c = c.breg_Xref_Name_1__c;
        acc.breg_Xref_Name_2__c = c.breg_Xref_Name_2__c;
        acc.breg_Consent__c = c.breg_Consent__c;
        acc.breg_Similar_Name__c = c.breg_Similar_Name__c;

        // Additional fields
        acc.breg_BRIM_FILE_NO__c = c.breg_BRIM_FILE_NO__c;
        acc.breg_File__c = c.breg_File__c;
        acc.breg_File_Suffix__c = c.breg_File_Suffix__c;
        acc.breg_Incorporation_Date__c = c.breg_Effective_Date__c;
        acc.breg_Expiration_Date__c = c.breg_Expiration_Date__c;
        acc.breg_Purpose__c = c.breg_Entity_Nature_Of_Business__c != null
            ? c.breg_Entity_Nature_Of_Business__c
            : c.breg_Purposes__c;
        acc.breg_Subscribe_Owner_Free_Email_Alerts__c = c.breg_Subscribe_Owner_Free_Email_Alerts__c;
        acc.breg_Is_Manager_Managed__c = c.breg_Is_Manager_Managed__c;
        acc.breg_Number_of_Initial_Members__c = c.breg_Number_of_Initial_Members__c;
        acc.breg_Commence_Date__c = c.breg_Partnership_Begin_Business_Date__c;

        // Entity type and business structure from form configuration
        acc.breg_Entity_Type__c = calculateEntityType(c);
        acc.breg_Business_Structure__c = calculateBusinessStructure(c);
        acc.breg_Location_Type__c = c.breg_Form_Configuration__r?.breg_Business_Location__c;

        // Term / Partner Term, derived from Duration Period (+ expiration date when specified)
        String termValue = calculateTermValue(c);
        if (acc.breg_Business_Structure__c == 'Partnership' || acc.breg_Business_Structure__c == 'Limited Liability Partnership') {
            acc.breg_Partner_Term__c = termValue;
        } else {
            acc.breg_Term__c = termValue;
        }
    }

    private String calculateTermValue(Case caseRecord) {
        if (String.isBlank(caseRecord.breg_Duration_Period__c)) {
            return null;
        }
        if (caseRecord.breg_Duration_Period__c == 'For a specified term to expire on' && caseRecord.breg_Entity_Term_To_Expire__c != null) {
            DateTime expireDt = DateTime.newInstance(
                caseRecord.breg_Entity_Term_To_Expire__c.year(),
                caseRecord.breg_Entity_Term_To_Expire__c.month(),
                caseRecord.breg_Entity_Term_To_Expire__c.day()
            );
            return 'TO EXPIRE ON ' + expireDt.format('MMMM d, yyyy').toUpperCase();
        }
        return caseRecord.breg_Duration_Period__c.toUpperCase();
    }

    /**
     * Calculates the entity name based on case and applicant data
     * @param c - case record
     * @param applicant - applicant account affiliation
     * @return String - entity name
     */
    private String calculateEntityName(Case c, breg_Account_Affiliation__c applicant) {
        String formCode = c.breg_Form_Code__c;
        if (c.breg_Name_of_the_Entity__c != null || c.breg_Name_for_Reservation__c != null) {
            // For NBR and Name Reservation forms, use breg_Name_of_the_Entity__c
            return String.isNotBlank(c.breg_Name_for_Reservation__c) ? c.breg_Name_for_Reservation__c : c.breg_Name_of_the_Entity__c;
        }

        // For TNTMSM forms, use applicant name
        if (BREGUtils.isTNTMSMForm(formCode)) {
            if(applicant != null) {
                if (applicant.breg_Type__c == 'Entity') {
                    return applicant.breg_Entity_Name__c;
                } else if (applicant.breg_Type__c == 'Individual') {
                    return applicant.breg_First_Name__c + ' ' + applicant.breg_Last_Name__c;
                }
            } else {
                // If no applicant affiliation, fallback to case fields
                if (String.isNotBlank(c.breg_Applicant_Name__c)) {
                    return c.breg_Applicant_Name__c;
                } else if (String.isNotBlank(c.breg_Applicant_First_Name__c) || String.isNotBlank(c.breg_Applicant_Last_Name__c)) {
                    return (String.isNotBlank(c.breg_Applicant_First_Name__c) ? c.breg_Applicant_First_Name__c : '') +
                        ' ' +
                        (String.isNotBlank(c.breg_Applicant_Last_Name__c) ? c.breg_Applicant_Last_Name__c : '');
                }
            }
        }

        return null;
    }

    /**
     * Calculates the entity type from case or form configuration
     * @param c - case record
     * @return String - entity type
     */
    private String calculateEntityType(Case c) {
        String formCode = c.breg_Form_Code__c;
        if (BREGUtils.isNameReservationForm(formCode)) {
            return ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE;
        } else if (BREGUtils.isNBRForm(formCode) || BREGUtils.isTNTMSMForm(formCode)) {
            String formConfigEntityType = c.breg_Form_Configuration__r?.breg_Entity_Type__c;
            if (String.isNotBlank(formConfigEntityType)) {
                return formConfigEntityType;
            }
            return c.breg_Entity_Type__c;
        }
        return null;
    }

    /**
     * Calculates the business structure based on form configuration
     * @param c - case record
     * @return String - business structure
     */
    private String calculateBusinessStructure(Case c) {
        String businessStructure = c.breg_Form_Configuration__r?.breg_Business_Structure__c;
        if (String.isBlank(businessStructure)) {
            return null;
        }

        // Map business structure values
        if (
            businessStructure == 'Cooperative' ||
            (c.breg_Entity_Type__c != null && c.breg_Entity_Type__c.contains('Cooperative')) ||
            (c.breg_Entity_Type__c != null &&
            c.breg_Form_Code__c == 'X-1' &&
            c.breg_New_Entity_Type__c.contains('Cooperative'))
        ) {
            return 'Cooperative';
        } else if (
            businessStructure == 'Corporation' ||
            (c.breg_Entity_Type__c != null && c.breg_Entity_Type__c.contains('Corporation')) ||
            (c.breg_Entity_Type__c != null &&
            c.breg_Form_Code__c == 'X-1' &&
            c.breg_New_Entity_Type__c.contains('Corporation'))
        ) {
            return 'Corporation';
        } else if (
            businessStructure == 'General Partnership' ||
            businessStructure == 'Limited Partnership' ||
            businessStructure == 'Limited Liability Partnership' ||
            (c.breg_Entity_Type__c != null && c.breg_Entity_Type__c.contains('Partnership')) ||
            (c.breg_Entity_Type__c != null &&
            c.breg_Form_Code__c == 'X-1' &&
            c.breg_New_Entity_Type__c.contains('Partnership'))
        ) {
            return 'Partnership';
        } else if (
            businessStructure == 'Limited Liability Company' ||
            c.breg_Entity_Type__c == 'Limited Liability Company' ||
            (c.breg_Form_Code__c == 'X-1' &&
            c.breg_New_Entity_Type__c == 'Limited Liability Company')
        ) {
            return 'Limited Liability Company';
        }
        return null;
    }

    /**
     * Looks up or creates a TNTMSM record based on case data
     * BULKIFIED: Uses pre-queried existingTNTMSMByKey map instead of querying per case
     * @param c - case record
     * @param account - associated account
     * @param existingTNTMSMByKey - pre-queried map of composite key to existing TNTMSM
     * @return breg_TN_TM_SM__c - existing or new TNTMSM record
     */
    private breg_TN_TM_SM__c lookupOrCreateTNTMSM(Case c, Account account, Map<String, breg_TN_TM_SM__c> existingTNTMSMByKey) {
        // If TNTMSM is already linked, use that
        if (c.breg_TN_TM_SM__c != null) {
            return new breg_TN_TM_SM__c(Id = c.breg_TN_TM_SM__c);
        }

        if (account == null || account.Id == null) {
            return null;
        }

        String tntmsmName = c.breg_TNTMSM_Description__c;
        if (String.isBlank(tntmsmName)) {
            return null;
        }

        // Truncate to 80 characters for Name field
        String tntmsmName80 = tntmsmName.length() > 80 ? tntmsmName.substring(0, 80) : tntmsmName;

        // Try to find existing TNTMSM from pre-queried map (BULKIFIED - no SOQL here)
        String lookupKey = tntmsmName80 + '|' + account.Id;
        if (existingTNTMSMByKey.containsKey(lookupKey)) {
            return existingTNTMSMByKey.get(lookupKey);
        }

        // Calculate applicant name
        String applicantName;
        if (c.breg_Applicant_Is_Entity__c) {
            applicantName = c.breg_Applicant_Name__c;
        } else {
            applicantName =
                (String.isNotBlank(c.breg_Applicant_First_Name__c) ? c.breg_Applicant_First_Name__c : '') +
                ' ' +
                (String.isNotBlank(c.breg_Applicant_Last_Name__c) ? c.breg_Applicant_Last_Name__c : '');
            applicantName = applicantName.trim();
        }

        // Create new TNTMSM
        breg_TN_TM_SM__c newTntmsm = new breg_TN_TM_SM__c();
        newTntmsm.Name = tntmsmName80;
        newTntmsm.breg_Account__c = account.Id;
        newTntmsm.breg_Applicant_Name__c = applicantName;
        newTntmsm.breg_Cert_Number__c = c.breg_TNTMSM_Certificate__c;
        newTntmsm.breg_Entity_Nature_Of_Business__c = c.breg_Entity_Nature_Of_Business__c;
        newTntmsm.breg_File_Suffix__c = c.breg_File_Suffix__c;
        newTntmsm.breg_File__c = c.breg_File__c;
        newTntmsm.breg_Registrant_Type__c = c.breg_Reg_Agent_Type__c;
        newTntmsm.breg_Status__c = TNTMSM_STATUS_ACTIVE;
        newTntmsm.breg_Subscribe_Owner_Free_Email_Alerts__c = c.breg_Subscribe_Owner_Free_Email_Alerts__c;
        newTntmsm.breg_Trade_Name__c = c.breg_TNTMSM_Description__c;
        newTntmsm.breg_Type__c = c.breg_Form_Configuration__r?.breg_Registration_Type__c;
        newTntmsm.breg_TM_SM_Category__c = c.breg_TNTMSM_Classification__c;
        newTntmsm.breg_XREF_Name1__c = c.breg_Xref_Name_1__c;
        newTntmsm.breg_XREF_Name2__c = c.breg_Xref_Name_2__c;
        newTntmsm.breg_Consent__c = c.breg_Consent__c;
        newTntmsm.breg_Similar_Name__c = c.breg_Similar_Name__c;
        newTntmsm.breg_Registration_Date__c = c.breg_Effective_Date__c;
        newTntmsm.breg_Start_Date__c = c.breg_Effective_Date__c;

        return newTntmsm;
    }

    /**
     * Creates free email notification records for TNTMSM forms
     * @param cases - list of cases
     * @param caseIdToTNTMSMMap - map of case Id to TNTMSM records
     */
    private void createFreeEmailNotifications(List<Case> cases, Map<Id, breg_TN_TM_SM__c> caseIdToTNTMSMMap) {
        List<breg_Notification__c> notificationsToInsert = new List<breg_Notification__c>();
        Date today = Date.today();

        for (Case c : cases) {
            // Only for TNTMSM, NBR and Annuals forms with subscription flag
            if (
                (!BREGUtils.isTNTMSMForm(c.breg_Form_Code__c) &&
                !BREGUtils.isNBRForm(c.breg_Form_Code__c) &&
                !BREGUtils.isAnnualForm(c.breg_Form_Code__c)) || c.breg_Subscribe_Owner_Free_Email_Alerts__c != true
            ) {
                continue;
            }

            breg_TN_TM_SM__c tntmsm = caseIdToTNTMSMMap.get(c.Id);
            if (tntmsm == null || tntmsm.Id == null) {
                continue;
            }
            String notifCategory = '';
            if (BREGUtils.isTNTMSMForm(c.breg_Form_Code__c)) {
                notifCategory = NOTIFICATION_CATEGORY_TNTMSM_REMINDER;
            } else if (BREGUtils.isNBRForm(c.breg_Form_Code__c)) {
                notifCategory = NOTIFICATION_CATEGORY_ANNUAL_REPORT_REMINDER;
            } else if (BREGUtils.isAnnualForm(c.breg_Form_Code__c)) {
                notifCategory = NOTIFICATION_CATEGORY_ANNUAL_REPORT_REMINDER;
            }

            breg_Notification__c notification = new breg_Notification__c();
            notification.breg_Contact__c = c.ContactId;
            notification.breg_Free_Of_Charge__c = true;
            notification.breg_Is_Email__c = true;
            notification.breg_Notification_Category__c = notifCategory;
            notification.breg_Recipient_Email__c = c.Contact?.Email;
            notification.breg_Start_Date__c = today;
            notification.breg_Status__c = NOTIFICATION_STATUS_ACTIVE;
            notification.breg_TN_TM_SM__c = tntmsm.Id;

            notificationsToInsert.add(notification);
        }

        if (!notificationsToInsert.isEmpty()) {
            insert notificationsToInsert;
        }
    }
    @future //a.b. urgent hotfix 13 April 2026. https://aalta.atlassian.net/browse/BREG-4021
    static void updateCaseRejectedByUserField(List<Id> caseIds, Id currentUserId) {
        List<Case> casesToUpdate = new List<Case>();
        for (Id cid : caseIds) {
            Case c = new Case(Id = cid, breg_Rejected_By_User__c = currentUserId);
            casesToUpdate.add(c);
        }
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    /**
     * Updates Account Affiliations with Entity, TNTMSM lookup values, Start Date,
     * and creates Contact/Account records for Individual/Entity types if not linked.
     * @param cases - list of cases
     * @param caseIdToAccountMap - map of case Id to Account
     * @param caseIdToTNTMSMMap - map of case Id to TNTMSM
     */
    private void updateAccountAffiliationsLookups(List<Case> cases, Map<Id, Account> caseIdToAccountMap, Map<Id, breg_TN_TM_SM__c> caseIdToTNTMSMMap) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, String> caseIdToFormCodeMap = new Map<Id, String>();

        // Build map of Case Id to Effective Date
        Map<Id, Date> caseIdToEffectiveDateMap = new Map<Id, Date>();
        for (Case c : cases) {
            caseIdToEffectiveDateMap.put(c.Id, c.breg_Effective_Date__c);
            caseIdToFormCodeMap.put(c.Id, c.breg_Form_Code__c);
        }

        // Query affiliations with all required fields
        List<breg_Account_Affiliation__c> affiliations = [
            SELECT
                Id,
                breg_Case__c,
                breg_Entity__c,
                breg_TN_TM_SM__c,
                breg_Start_Date__c,
                breg_Type__c,
                breg_Contact__c,
                breg_Account__c,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Entity_Name__c,
                breg_Address__City__s,
                breg_Address__CountryCode__s,
                breg_Address__PostalCode__s,
                breg_Address__StateCode__s,
                breg_Address__Street__s,
                breg_Status__c,
                breg_Role__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds
        ];

        // Collect affiliations that need new Contact or Account records
        List<breg_Account_Affiliation__c> affiliationsNeedingContact = new List<breg_Account_Affiliation__c>();
        List<breg_Account_Affiliation__c> affiliationsNeedingAccount = new List<breg_Account_Affiliation__c>();

        for (breg_Account_Affiliation__c aff : affiliations) {
            if (caseIdToFormCodeMap.get(aff.breg_Case__c) == 'T-4' && aff.breg_Role__c == 'Assignor') {
                continue;
            }
            // Individual type without Contact - need to create Contact
            if (aff.breg_Type__c == 'Individual' && aff.breg_Contact__c == null) {
                affiliationsNeedingContact.add(aff);
            }
            // Entity type without Account - need to create Account
            if (aff.breg_Type__c == 'Entity' && aff.breg_Account__c == null) {
                affiliationsNeedingAccount.add(aff);
            }
        }

        // Create Contacts for Individual affiliations
        Map<Id, Contact> affiliationIdToContactMap = createContactsForAffiliations(affiliationsNeedingContact);

        // Create Accounts for Entity affiliations
        Map<Id, Account> affiliationIdToAccountMap = createAccountsForAffiliations(affiliationsNeedingAccount);

        // Build map of role names to check if "New " prefixed versions exist
        if (hasNewRoleVersionMap == null) {
            hasNewRoleVersionMap = buildHasNewRoleVersionMap(affiliations);
        }

        // Now update all affiliations
        List<breg_Account_Affiliation__c> affiliationsToUpdate = new List<breg_Account_Affiliation__c>();

        for (breg_Account_Affiliation__c aff : affiliations) {
            String formCode = caseIdToFormCodeMap.get(aff.breg_Case__c);
            if (formCode == 'T-4' && aff.breg_Role__c == 'Assignor') {
                continue;
            }

            Account entityAcc = caseIdToAccountMap.get(aff.breg_Case__c);
            breg_TN_TM_SM__c tntmsm = caseIdToTNTMSMMap.get(aff.breg_Case__c);
            Date effectiveDate = caseIdToEffectiveDateMap.get(aff.breg_Case__c);

            // Check if there's a "New " prefixed version of this affiliation's role
            Boolean isT4Assignee = formCode == 'T-4' && aff.breg_Role__c == 'Assignee';
            Boolean hasNewVersionOfRole = hasNewRoleVersionMap.get(isT4Assignee ? 'Applicant' : aff.breg_Role__c) == true;

            Boolean needsUpdate = false;
            if (isT4Assignee) {
                aff.breg_Role__c = 'Applicant';
                needsUpdate = true;
            }
            // Set Entity lookup (skip if a "New " version of this role exists)
            if (!hasNewVersionOfRole && entityAcc != null && entityAcc.Id != null && aff.breg_Entity__c != entityAcc.Id) {
                aff.breg_Entity__c = entityAcc.Id;
                aff.breg_Role__c = aff.breg_Role__c.replace('New ', '').trim();
                needsUpdate = true;
            }

            // Set TNTMSM lookup (skip if a "New " version of this role exists)
            if (!hasNewVersionOfRole && tntmsm != null && tntmsm.Id != null && aff.breg_TN_TM_SM__c != tntmsm.Id) {
                aff.breg_TN_TM_SM__c = tntmsm.Id;
                aff.breg_Role__c = aff.breg_Role__c.replace('New ', '').trim();
                needsUpdate = true;
            }

            // Set Start Date from Case Effective Date
            if (effectiveDate != null && aff.breg_Start_Date__c != effectiveDate) {
                aff.breg_Start_Date__c = effectiveDate;
                needsUpdate = true;
            }

            // Set Contact if created for Individual
            Contact newContact = affiliationIdToContactMap.get(aff.Id);
            if (newContact != null && newContact.Id != null) {
                aff.breg_Contact__c = newContact.Id;
                needsUpdate = true;
                // Set status to Active for new affiliations
                if (aff.breg_Status__c != 'A') {
                    aff.breg_Status__c = 'A';
                }
            }

            // Set Account if created for Entity
            Account newAccount = affiliationIdToAccountMap.get(aff.Id);
            if (newAccount != null && newAccount.Id != null) {
                aff.breg_Account__c = newAccount.Id;
                needsUpdate = true;
                // Set status to Active for new affiliations
                if (aff.breg_Status__c != 'A') {
                    aff.breg_Status__c = 'A';
                }
            }

            aff.breg_Bypass_Validation_Token__c = Datetime.now();

            if (needsUpdate) {
                affiliationsToUpdate.add(aff);
            }
        }

        if (!affiliationsToUpdate.isEmpty()) {
            update affiliationsToUpdate;
        }
    }

    /**
     * Creates Contact records for Individual type Account Affiliations that don't have a Contact linked
     * @param affiliations - list of account affiliations needing contacts
     * @return Map<Id, Contact> - map of affiliation Id to created Contact
     */
    private Map<Id, Contact> createContactsForAffiliations(List<breg_Account_Affiliation__c> affiliations) {
        Map<Id, Contact> affiliationIdToContactMap = new Map<Id, Contact>();

        if (affiliations.isEmpty()) {
            return affiliationIdToContactMap;
        }

        List<Contact> contactsToInsert = new List<Contact>();
        Id bregContactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('BREG_Contact').getRecordTypeId();

        for (breg_Account_Affiliation__c aff : affiliations) {
            Contact newContact = new Contact();
            newContact.FirstName = aff.breg_First_Name__c;
            newContact.LastName = String.isNotBlank(aff.breg_Last_Name__c) ? aff.breg_Last_Name__c : 'Unknown';
            newContact.MailingCity = aff.breg_Address__City__s;
            newContact.MailingCountryCode = aff.breg_Address__CountryCode__s;
            newContact.MailingPostalCode = aff.breg_Address__PostalCode__s;
            newContact.MailingStateCode = aff.breg_Address__StateCode__s;
            newContact.MailingStreet = aff.breg_Address__Street__s;
            newContact.RecordTypeId = bregContactRecordTypeId;

            contactsToInsert.add(newContact);
            affiliationIdToContactMap.put(aff.Id, newContact);
        }

        if (!contactsToInsert.isEmpty()) {
            insert contactsToInsert;
        }

        return affiliationIdToContactMap;
    }

    /**
     * Creates Account records for Entity type Account Affiliations that don't have an Account linked
     * @param affiliations - list of account affiliations needing accounts
     * @return Map<Id, Account> - map of affiliation Id to created Account
     */
    private Map<Id, Account> createAccountsForAffiliations(List<breg_Account_Affiliation__c> affiliations) {
        Map<Id, Account> affiliationIdToAccountMap = new Map<Id, Account>();

        if (affiliations.isEmpty()) {
            return affiliationIdToAccountMap;
        }

        // Get BREG Account Record Type Id
        Id bregAccountRtId = getBREGAccountRecordTypeId();

        List<Account> accountsToInsert = new List<Account>();

        for (breg_Account_Affiliation__c aff : affiliations) {
            Account newAccount = new Account();
            newAccount.Name = String.isNotBlank(aff.breg_Entity_Name__c) ? aff.breg_Entity_Name__c : 'Unknown Entity';
            newAccount.RecordTypeId = bregAccountRtId;
            newAccount.BillingCity = aff.breg_Address__City__s;
            newAccount.BillingCountryCode = aff.breg_Address__CountryCode__s;
            newAccount.BillingPostalCode = aff.breg_Address__PostalCode__s;
            newAccount.BillingStateCode = aff.breg_Address__StateCode__s;
            newAccount.BillingStreet = aff.breg_Address__Street__s;

            accountsToInsert.add(newAccount);
            affiliationIdToAccountMap.put(aff.Id, newAccount);
        }

        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
        }

        return affiliationIdToAccountMap;
    }

    /**
     * Handles LLP-1, FLLP-1 specific parent entity update for child GP-1 cases
     * @param cases - list of cases
     */
    private void handleLLP1ParentEntity(List<Case> cases) {
        List<Account> accountsToUpdate = new List<Account>();

        for (Case c : cases) {
            if (c.breg_Form_Code__c != 'LLP-1' && c.breg_Form_Code__c != 'FLLP-1') {
                continue;
            }
            if (c.breg_GP_Already_Registered__c && c.breg_GP_Entity__c != null && c.breg_Entity__c != null) {
                accountsToUpdate.add(new Account(Id = c.breg_GP_Entity__c, ParentId = c.breg_Entity__c));
            } else if (!c.breg_GP_Already_Registered__c && c.breg_GP_Case__c != null && c.breg_Entity__c != null) {
                accountsToUpdate.add(new Account(Id = c.breg_GP_Case__r.breg_Entity__c, ParentId = c.breg_Entity__c));
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    /**
     * Creates transaction records for approved cases
     * Skips ADD, ADD-MEMBER, ADD-TNTMSM forms (handled by their own handlers)
     * @param cases - list of cases
     */
    private void createTransactionsForReceivedCases(List<Case> cases) {
        // Filter cases that are NBR, TNTMSM, or Name Reservation forms
        List<Case> specialFormCases = filterSpecialFormCases(cases);
        if (specialFormCases.isEmpty()) {
            return;
        }

        // Requery cases with all required fields for processing
        List<Case> casesWithDetails = queryCasesForApprovalProcessing(specialFormCases);
         // Create transactions (except for ADD, ADD-MEMBER, ADD-TNTMSM forms)
        System.debug('@@ Creating transactions for approved cases: ' + casesWithDetails);
        List<breg_Transaction__c> transactionsToInsert = new List<breg_Transaction__c>();
        Map<Id, Case> casesMap = new Map<Id, Case>();
        for (Case c : casesWithDetails) {
            // Skip forms that create their own transactions
            if (FORM_CODES_SKIP_TRANSACTION.contains(c.breg_Form_Code__c)) {
                continue;
            }
            casesMap.put(c.Id, c);
        }

        upsertTransactions(casesMap, 'R');
    }

    @TestVisible
    protected List<Case> getCasesWithAllFields(List<Case> cases) {
        Set<Id> casesIds = getCaseIds(cases);
        List<Case> result = [
            SELECT
                Id,
                breg_Organizing_Articles_Changes__c,
                breg_Resubmission_Due_Date__c,
                breg_Last_Rejection_Date__c,
                breg_Effective_Date__c,
                breg_Name_of_the_Entity__c,
                breg_Entity_Type__c,
                breg_Company_Address__City__s,
                breg_Formation_State__c,
                breg_Form_Code__c,
                breg_Entity__c,
                breg_Entity__r.Name,
                breg_Remaining_Shares_Class_Series__c,
                breg_Remaining_Shares_Count__c,
                breg_Cancelled_Shares_Class_Series__c,
                breg_Cancelled_Shares_Count__c,
                breg_Resubmission_Received_Date__c,
                breg_Form_Configuration__c,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Reg_Agent_Last_Name__c,
                breg_Reg_Agent_First_Name__c,
                breg_Reg_Agent_Entity_Name__c,
                breg_Reg_Agent_Type__c,
                breg_Reg_Agent_Has_Changed__c,
                breg_Reg_Agent_Address_Has_Changed__c,
                breg_Registered_Agent_Address__CountryCode__s,
                breg_Registered_Agent_Address__Street__s,
                breg_Reg_Agent_Address_Street2__c,
                breg_Reg_Agent_Address_State__c,
                breg_Registered_Agent_Address__StateCode__s,
                breg_Registered_Agent_Address__City__s,
                breg_Registered_Agent_Address__PostalCode__s,
                breg_Entity_Type_Has_Changed__c,
                breg_Entity_Jurisdiction_Has_Changed__c,
                breg_Entity_Jurisdiction__c,
                breg_Update_Child_Entity__c,
                breg_Entity__r.breg_Entity_Type__c,
                breg_TNTMSM_Classification__c,
                breg_Entity__r.breg_Certified_Register_Agent__c,
                breg_Is_Allowed_Generate_Reinstatem_Cert__c,
                ParentId,
                breg_Outstanding_Shares_Count__c,
                breg_Transaction_Code__c,
                breg_Name_Reservation__c,
                breg_Name_Reservation__r.Name,
                breg_Name_for_Reservation__c,
                breg_GP_Already_Registered__c,
                breg_GP_Entity__c,
                breg_GP_Case__r.breg_Entity__c,
                breg_Is_LLP_Registration__c,
                Parent.breg_Form_Configuration__c,
                Parent.breg_Form_Configuration__r.breg_Form_Name__c,
                Parent.breg_Name_of_the_Entity__c,
                breg_Publication_Date_1__c,
                breg_Publication_Date_2__c,
                breg_Publication_Date_3__c,
                breg_Publication_Date_4__c,
                breg_Is_Manager_Managed__c,
                breg_Number_of_Initial_Members__c,
                breg_GP_Case__c,
                breg_Override_Payment__c,
                OwnerId,
                CaseNumber,
                breg_Bounced_Check_Due_Date__c,
                breg_TN_TM_SM__c,
                breg_TNTMSM_Description__c,
                breg_TNTMSM_Certificate__c,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__PostalCode__s,
                breg_Company_Address__StateCode__s,
                breg_Company_Address_State__c,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address_State__c,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Delivery_Address__City__s,
                breg_Delivery_Address__CountryCode__s,
                breg_Delivery_Address__PostalCode__s,
                breg_Delivery_Address__Street__s,
                breg_Delivery_Address__StateCode__s,
                breg_Delivery_Address_State_Text__c,
                breg_Delivery_Address_Street2__c,
                breg_BRIM_FILE_NO__c,
                breg_Expiration_Date__c,
                breg_Partnership_Begin_Business_Date__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Purposes__c,
                breg_Subscribe_Owner_Free_Email_Alerts__c,
                breg_Applicant_Is_Entity__c,
                breg_Applicant_Name__c,
                breg_Applicant_First_Name__c,
                breg_Applicant_Last_Name__c,
                breg_Form_Configuration__r.breg_Entity_Type__c,
                breg_Form_Configuration__r.breg_Business_Location__c,
                breg_Form_Configuration__r.breg_Business_Structure__c,
                breg_Form_Configuration__r.breg_Registration_Type__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                ContactId,
                Contact.Email,
                breg_Number_of_common_shares__c,
                breg_Par_Value_Of_Each_Share__c,
                CreatedById,
                breg_Xref_Name_1__c,
                breg_Xref_Name_2__c,
                breg_Consent__c,
                breg_Similar_Name__c,
                breg_Duration_Period__c,
                breg_Entity_Term_To_Expire__c,
                breg_New_Entity_Type__c,
                breg_Received_Date_Formula__c,
                breg_Annual__r.breg_Filing_Date__c,
                breg_No_Changes__c,
                breg_Workitem_Number__c,
                Status,
                (
                    SELECT
                        Id,
                        breg_Account__c,
                        breg_Address_State_Text__c,
                        breg_Address_Street_2__c,
                        breg_Address__c,
                        breg_Address__CountryCode__s,
                        breg_Address__Street__s,
                        breg_Address__StateCode__s,
                        breg_Address__City__s,
                        breg_Address__PostalCode__s,
                        breg_As_of_Date__c,
                        breg_Case__c,
                        breg_Contact__c,
                        breg_End_Date__c,
                        breg_Entity_Location__c,
                        breg_Entity_Location_Country__c,
                        breg_Entity_Name__c,
                        breg_Entity_Type_Description__c,
                        breg_Entity_Type__c,
                        breg_Entity__c,
                        breg_File__c,
                        breg_First_Name__c,
                        breg_Last_Name__c,
                        breg_Number_of_shares__c,
                        breg_Officer_Director_Titles__c,
                        breg_Officer_Director_Other_Title__c,
                        breg_Titles_Are_Vacant__c,
                        breg_Role__c,
                        breg_Start_Date__c,
                        breg_TN_TM_SM__c,
                        breg_Transaction__c,
                        breg_Type__c,
                        breg_Title__c,
                        breg_Officer_Director_Titles_Formula__c,
                        breg_Title_Text__c,
                        breg_Signed_By_First_Name__c,
                        breg_Signed_By_Last_Name__c,
                        breg_Signature__c
                    FROM Account_Affiliations__r
                )
            FROM Case
            WHERE Id IN :casesIds
        ];
        return result;
    }

    /**
     * Builds a map to check if affiliations have "New " prefixed role versions
     * For example, if an affiliation has role "Applicant", this checks if any affiliation has role "New Applicant"
     * @param affiliations - list of account affiliations
     * @return Map<String, Boolean> - map of role to boolean indicating if "New " version exists
     */
    private Map<String, Boolean> buildHasNewRoleVersionMap(List<breg_Account_Affiliation__c> affiliations) {
        Set<String> allRoles = new Set<String>();

        // Collect all roles from affiliations
        for (breg_Account_Affiliation__c aff : affiliations) {
            if (String.isNotBlank(aff.breg_Role__c)) {
                allRoles.add(aff.breg_Role__c);
            }
        }

        // Build map to check if "New " versions exist
        Map<String, Boolean> hasNewRoleVersionMap = new Map<String, Boolean>();
        for (String role : allRoles) {
            String newRole = 'New ' + role;
            hasNewRoleVersionMap.put(role, allRoles.contains(newRole));
        }

        return hasNewRoleVersionMap;
    }

    @InvocableMethod(label='Get Filing Withdrawn Text')
    public static List<String> getFilingWithdrawnText(List<String> input) {
        TimeZone tz = UserInfo.getTimeZone();

        return new List<String>{
            'Withdrawal request submitted ' + System.now().format('MM/dd/yyyy hh:mm a', tz.getID())
        };
    }
}