public without sharing class BREGBusinessDetailsController {
    // constants
    private static final String ACCOUNT_SOBJECT_TYPE = 'Account';
    private static final String TN_TM_SM_SOBJECT_TYPE = 'breg_TN_TM_SM__c';
    private static final String TRANSACTION_SOBJECT_TYPE = 'breg_Transaction__c';
    private static final String CASE_SOBJECT_TYPE = 'Case';
    private static final String FILING_CASE_STATUS_VALUE = 'Filing';
    private static final String APPROVED_CASE_STATUS_VALUE = 'Approved';
    private static final String COMPLETED_TRANSACTION_STATUS_VALUE = 'C';
    private static final String PUBLICITY_RIGHTS_NAME_TYPE = 'Publicity Rights Name';
    private static final String D1_ENTITY_TYPE = 'D1';
    private static final String P1_ENTITY_TYPE = 'P1';
    private static final String S1_ENTITY_TYPE = 'S1';
    private static final String A1_ENTITY_TYPE = 'A1';
    private static final String C1_ENTITY_TYPE = 'C1';
    private static final String G5_ENTITY_TYPE = 'G5';
    private static final String G6_ENTITY_TYPE = 'G6';
    private static final String L6_ENTITY_TYPE = 'L6';
    private static final String K5_ENTITY_TYPE = 'K5';
    private static final String K6_ENTITY_TYPE = 'K6';
    private static final String L5_ENTITY_TYPE = 'L5';
    private static final String Q5_ENTITY_TYPE = 'Q5';
    private static final String Q6_ENTITY_TYPE = 'Q6';
    private static final String C5_ENTITY_TYPE = 'C5';
    private static final String C6_ENTITY_TYPE = 'C6';
    private static final String F1_ENTITY_TYPE = 'F1';
    private static final String F2_ENTITY_TYPE = 'F2';
    private static final String D2_ENTITY_TYPE = 'D2';
    private static final String ZZ_ENTITY_TYPE = 'ZZ';
    private static final Set<String> INVALID_ACCOUNT_ENTITY_TYPES = new Set<String>{ 'r7', 'other' };
    private static final List<String> ENTITY_TYPE_WITH_PARTNER = new List<String>{'K5', 'K6', 'L5', 'L6', 'G5', 'G6', 'Q5', 'Q6'};
    private static final String ADD_MEMBER_FORM = 'ADD-MEMBER';
    private static final String NO = 'No';
    private static final String YES = 'Yes';
    private static final String COMMERCIAL_REGISTERED_AGENT_HELP_TEXT = System.Label.BREG_CommercialRegisteredAgentHelpText;
    // form error messages
    private static final String NOT_ACTIVE_ERROR_MESSAGE = System.Label.BREG_Forms_NotActiveErrorMessage;
    private static final String BUSINESS_NOT_IN_GOOD_STANDING_ERROR_MESSAGE = System.Label.BREG_Forms_BusinessNotInGoodStandingErrorMessage;
    private static final String PENDING_ODC_REQUEST_ERROR_MESSAGE = System.Label.BREG_Forms_PendingODCRequestErrorMessage;
    private static final String PENDING_ADD_REQUEST_ERROR_MESSAGE = System.Label.BREG_Forms_PendingADDRequestErrorMessage;
    private static final String PENDING_ADD_ODMMP_REQUEST_ERROR_MESSAGE = System.Label.BREG_Forms_PendingADDODMMPRequestErrorMessage;
    private static final String CURRENT_DATE_NOT_WITHIN_LAST_180_DAYS_OF_ACTIVE_TERM_ERROR_MESSAGE = System.Label.BREG_Forms_CurrentDateNotWithinLast180DaysErrorMessage;
    private static final String NAME_RESERVATION_MORE_THAN_14_DAYS_PRIOR_TO_EXPIRATION_DATE_ERROR_MESSAGE = System.Label.BREG_Forms_NameReservationMoreThan14DaysErrorMessage;
    private static final String BOUNCE_CHECK_IN_PROGRESS_ERROR_MESSAGE = System.Label.BREG_Forms_BounceCheckInProgressErrorMessage;
    private static final String TWO_YEARS_AFTER_DISSOLUTION_ERROR_MESSAGE = System.Label.BREG_Forms_TwoYearsAfterDissolutionErrorMessage;
    private static final String NO_ACTIVE_AGENT_ASSOCIATED_ERROR_MESSAGE = System.Label.BREG_Forms_NoActiveAgentAssociatedErrorMessage;
    private static final String RESTATED_ARTICLES_ERROR_MESSAGE = System.Label.BREG_Forms_RestatedArticlesErrorMessage;
    private static final String REGISTERED_CRA_ERROR_MESSAGE = System.Label.BREG_Forms_RegisteredCRAErrorMessage;
    private static final String ACCOUNT_DETAILS_NOT_IN_GOOD_STANDING_ERROR_MESSAGE = System.Label.BREG_AccountDetails_NotInGoodStanding;
    private static final Integer DEFAULT_RDPMS_ADHOC_REQUEST_TIMEOUT_MINUTES = 3;
    private static Boolean isDisabledTransactions = false;
    private static Boolean hideMailingAddress = false;
    private static Boolean hideBillingAddress = false;
    private static Boolean hideAgentAddress = false;

    private static final Set<String> STATUSES_WITH_CUSTOM_GOOD_STANDING_MESSAGE = new Set<String>{
        'Adm. Terminated (V)',
        'Terminated (T)',
        'Cancelled (C)',
        'Dissolved (D)',
        'Inv. Cancelled (X)',
        'Inv. Dissolved (7)'
    };

    @AuraEnabled(cacheable=true)
    public static BusinessDetailsWrapper getBusinessDetailsWrapper(Id entityId) {
        BusinessDetailsWrapper wrapper = new BusinessDetailsWrapper();
        wrapper.companyInfo.fields = new List<CompanyInfoFieldWrapper>();
        try {
            // Determine the entity type from the ID
            String entityType = getEntityType(entityId);

            if (entityType == ACCOUNT_SOBJECT_TYPE) {
                // Handle Account entity
                wrapper = getAccountBusinessDetails(entityId);
            } else if (entityType == TN_TM_SM_SOBJECT_TYPE) {
                // Handle breg_TN_TM_SM__c entity
                wrapper = getTnTmSmBusinessDetails(entityId);
            } else if (entityType == TRANSACTION_SOBJECT_TYPE) {
                // Handle breg_Transaction__c entity
                wrapper = getTransactionBusinessDetails(entityId);
            } else if (entityType == CASE_SOBJECT_TYPE) {
                // Handle Case entity
                wrapper = getCaseBusinessDetails(entityId);
            } else {
                throw new AuraHandledException('Unsupported entity type: ' + entityType);
            }
        } catch (Exception e) {
            System.debug('** exception: ' + e.getMessage() + ' | stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage() + '|' + e.getStackTraceString());
        }
        return wrapper;
    }

    @AuraEnabled
    public static void createRDPMSAdhocRequests(Id recordId) {
        String entityId = recordId;
        String entityType = getEntityType(entityId);
        if (entityType == ACCOUNT_SOBJECT_TYPE) {
            entityId = recordId;
        } else if (entityType == TN_TM_SM_SOBJECT_TYPE) {
            breg_TN_TM_SM__c tnTmSmRecord = getTnTmSmRecord(entityId);
            if (tnTmSmRecord != null) {
                entityId = tnTmSmRecord.breg_Account__c;
            }
        }

        List<Case> cases = [
            SELECT Id, breg_Entity__c, (SELECT Id, breg_Case__c FROM RDPMS_Adhoc_Requests__r)
            FROM Case
            WHERE breg_Entity__c = :entityId AND breg_ESWM_WFWORKITEM_ID__c != NULL
        ];

        List<breg_RDPMS_Adhoc_Request__c> rdpmsAdhocRequestsToInsert = new List<breg_RDPMS_Adhoc_Request__c>();
        for (Case c : cases) {
            if (c.RDPMS_Adhoc_Requests__r.isEmpty()) {
                rdpmsAdhocRequestsToInsert.add(new breg_RDPMS_Adhoc_Request__c(breg_Case__c = c.Id, breg_Status__c = 'Requested'));
            }
        }

        insert rdpmsAdhocRequestsToInsert;
    }

    /**
     * Determines the SObject type from the given ID
     * @param recordId The record ID to analyze
     * @return String representing the SObject type
     */
    private static String getEntityType(Id recordId) {
        return recordId.getSObjectType().getDescribe().getName();
    }

    /**
     * Retrieves business details for Account entity
     * @param accountId The Account ID
     * @return BusinessDetailsWrapper with Account-based data
     */
    private static BusinessDetailsWrapper getAccountBusinessDetails(Id accountId) {
        BusinessDetailsWrapper wrapper = new BusinessDetailsWrapper();

        // Get Account record
        Account accountRecord = getAccountRecord(accountId);

        // Get Field Mappings
        List<breg_Company_Info_Field_Mapping__mdt> mappings = getFieldMappingsFromMetadata(ACCOUNT_SOBJECT_TYPE);

        // Get Field Values
        List<CompanyInfoFieldWrapper> fields = getFieldValues(accountRecord, mappings);

        // Get Annual Filings
        List<breg_Annual__c> annualFilings = getAnnualFilingData(accountId);

        // Get TN/TM/SM
        List<breg_TN_TM_SM__c> tnTmSms = getTnTmSmDataForAccount(accountId);

        // Get Account Affiliations
        List<breg_Account_Affiliation__c> accountAffiliations = getAccountAffiliationData(accountId, accountRecord.breg_Entity_Type__c);

        for (breg_Account_Affiliation__c aff : accountAffiliations) {
            String name = BREGAddressProtectionUtils.buildAffiliationName(aff);
            BREGAddressProtectionUtils.AddressWrapper addr = BREGAddressProtectionUtils.buildAddressFromAffiliation(aff);
            if (String.isNotBlank(name) && BREGAddressProtectionUtils.isAddressProtected(name, addr)) {
                BREGAddressProtectionUtils.clearAffiliationAddressFields(aff);
                aff.breg_Address__CountryCode__s = null; // Clear country code for address protection
                isDisabledTransactions = true;
            }
        }

        // Get Other Filings
        List<breg_Transaction__c> otherFilings = isDisabledTransactions ? new List<breg_Transaction__c>() : getOtherFilingData(accountId);

        

        // Get Stocks
        List<breg_Stock__c> stocks = new List<breg_Stock__c>();
        if (
            D1_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c) ||
            P1_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c) ||
            S1_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c) ||
            A1_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c) ||
            C1_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c)
        ) {
            stocks = getStockData(accountId);
        }

        // Get Form Configuration wrappers
        List<FormConfigurationWrapper> formConfigurationsWrappers = new List<FormConfigurationWrapper>();
        if (!ZZ_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c)) {
            formConfigurationsWrappers = getFormConfigurationWrappers(accountRecord);
        }

        // Get Buy Available Doc Wrappers
        List<BuyAvailableDocumentWrapper> buyAvailableDocWrappers = isDisabledTransactions ? new List<BuyAvailableDocumentWrapper>() : getBuyAvailableDocWrappers(accountRecord);

        // Populate company info fields based on metadata configuration and related data
        wrapper.companyInfo.fields = fields;
        wrapper.companyInfo.annualFilingData = annualFilings;
        wrapper.companyInfo.otherFilingData = otherFilings;
        wrapper.companyInfo.accountAffiliationData = accountAffiliations;
        wrapper.companyInfo.stockData = stocks;
        wrapper.companyInfo.tnTmSmData = tnTmSms;
        wrapper.entityTypeValue = accountRecord?.breg_Entity_Type__c;
        wrapper.entityTypeLabel = BREGUtils.getPicklistLabel(ACCOUNT_SOBJECT_TYPE, 'breg_Entity_Type__c', accountRecord?.breg_Entity_Type__c);
        wrapper.entityName = accountRecord?.Name;
        wrapper.objectType = ACCOUNT_SOBJECT_TYPE;
        wrapper.formConfigurationsData = formConfigurationsWrappers;
        wrapper.buyAvailableDocsData = buyAvailableDocWrappers;
        wrapper.isInGoodStanding = accountRecord?.breg_Good_Standing__c;
        wrapper.goodStandingMessage = getGoodStandingMessage(accountRecord);

        return wrapper;
    }

    /**
     * Retrieves business details for breg_TN_TM_SM__c entity
     * @param tnTmSmId The breg_TN_TM_SM__c ID
     * @return BusinessDetailsWrapper with TN/TM/SM-based data
     */
    private static BusinessDetailsWrapper getTnTmSmBusinessDetails(Id tnTmSmId) {
        BusinessDetailsWrapper wrapper = new BusinessDetailsWrapper();

        // Get TN/TM/SM record with related Account data
        breg_TN_TM_SM__c tnTmSmRecord = getTnTmSmRecord(tnTmSmId);

        // Get Field Mappings
        List<breg_Company_Info_Field_Mapping__mdt> mappings = getFieldMappingsFromMetadata(TN_TM_SM_SOBJECT_TYPE);

        // Get Field Values
        List<CompanyInfoFieldWrapper> fields = getFieldValues(tnTmSmRecord, mappings);

        // Get Other Filings
        List<breg_Transaction__c> otherFilingData = new List<breg_Transaction__c>();
        if (tnTmSmRecord?.breg_Type__c != PUBLICITY_RIGHTS_NAME_TYPE && !isDisabledTransactions) {
            otherFilingData = getOtherFilingDataForTnTmSm(tnTmSmId);
        }

        // Get Form Configuration wrappers
        List<FormConfigurationWrapper> formConfigurationsWrappers = getFormConfigurationWrappers(tnTmSmRecord);

        // Get Buy Available Doc Wrappers
        List<BuyAvailableDocumentWrapper> buyAvailableDocWrappers = isDisabledTransactions ? new List<BuyAvailableDocumentWrapper>() : getBuyAvailableDocWrappers(tnTmSmRecord);

        // Populate company info fields based on metadata configuration and related data for TN/TM/SM
        wrapper.companyInfo.fields = fields;
        wrapper.companyInfo.otherFilingData = otherFilingData;
        wrapper.entityTypeValue = tnTmSmRecord?.breg_Type__c;
        wrapper.entityTypeLabel = BREGUtils.getPicklistLabel(TN_TM_SM_SOBJECT_TYPE, 'breg_Type__c', tnTmSmRecord?.breg_Type__c);
        wrapper.entityName = tnTmSmRecord?.breg_Trade_Name__c != null ? tnTmSmRecord?.breg_Trade_Name__c : tnTmSmRecord?.Name;
        wrapper.objectType = TN_TM_SM_SOBJECT_TYPE;
        wrapper.formConfigurationsData = formConfigurationsWrappers;
        wrapper.buyAvailableDocsData = buyAvailableDocWrappers;

        return wrapper;
    }

    private static String getCasePortalDisplayStatus(String caseStatus) {
        return caseStatus == FILING_CASE_STATUS_VALUE ? APPROVED_CASE_STATUS_VALUE : caseStatus;
    }

    private static BusinessDetailsWrapper getCaseBusinessDetails(Id caseId) {
        BusinessDetailsWrapper wrapper = new BusinessDetailsWrapper();

        Case caseRecord = getCaseRecord(caseId);

        String entityName = String.isNotBlank(caseRecord?.breg_TNTMSM_Description__c)
            ? caseRecord.breg_TNTMSM_Description__c
            : (String.isNotBlank(caseRecord?.breg_New_Entity_Name__c)
                ? caseRecord.breg_New_Entity_Name__c
                : (String.isNotBlank(caseRecord?.breg_Name_of_the_Entity__c)
                    ? caseRecord.breg_Name_of_the_Entity__c
                    : caseRecord?.Subject));

        List<CompanyInfoFieldWrapper> fields = new List<CompanyInfoFieldWrapper>();
        fields.add(new CompanyInfoFieldWrapper('Entity Name', entityName, null, null));
        fields.add(new CompanyInfoFieldWrapper('Work Item #', caseRecord?.breg_Workitem_Number__c, null, null));
        fields.add(new CompanyInfoFieldWrapper('Form Name / Type', caseRecord?.breg_Form_Configuration__r?.breg_Form_Name__c, null, null));
        fields.add(new CompanyInfoFieldWrapper('Status of the Filing', getCasePortalDisplayStatus(caseRecord?.Status), null, null));
        fields.add(new CompanyInfoFieldWrapper('Received Date', formatDate(caseRecord?.breg_Received_Date__c?.date()), null, null));

        wrapper.companyInfo.fields = fields;
        wrapper.entityName = entityName;
        wrapper.entityTypeValue = caseRecord?.breg_Form_Configuration__r?.breg_Form_Name__c;
        wrapper.objectType = CASE_SOBJECT_TYPE;

        return wrapper;
    }

    private static Case getCaseRecord(Id caseId) {
        List<Case> cases = [
            SELECT
                Id,
                Subject,
                CaseNumber,
                breg_Workitem_Number__c,
                Status,
                breg_Received_Date__c,
                CreatedDate,
                breg_TNTMSM_Description__c,
                breg_New_Entity_Name__c,
                breg_Name_of_the_Entity__c,
                breg_Form_Configuration__r.breg_Form_Name__c,
                breg_Form_Configuration__r.breg_Form_Code__c
            FROM Case
            WHERE Id = :caseId
            AND RecordType.DeveloperName = 'BREG_Case'
            LIMIT 1
        ];
        return !cases.isEmpty() ? cases[0] : null;
    }

    private static BusinessDetailsWrapper getTransactionBusinessDetails(Id transactionId) {
        BusinessDetailsWrapper wrapper = new BusinessDetailsWrapper();

        // Get Transaction record with related Account data
        breg_Transaction__c transactionRecord = getTransactionRecord(transactionId);

        // Get Field Mappings
        List<breg_Company_Info_Field_Mapping__mdt> mappings = getFieldMappingsFromMetadata(TRANSACTION_SOBJECT_TYPE);

        // Get Field Values
        List<CompanyInfoFieldWrapper> fields = getFieldValues(transactionRecord, mappings);

        // Populate company info fields based on metadata configuration and related data for TN/TM/SM
        wrapper.companyInfo.fields = fields;
        wrapper.entityTypeValue = transactionRecord?.breg_Type__c;
        wrapper.entityName = transactionRecord?.breg_Business_Name__c;
        wrapper.objectType = TRANSACTION_SOBJECT_TYPE;

        return wrapper;
    }

    /**
     * @description get form configuration wrappers for Account
     * @param  accountRecord
     * @return list of form configuration wrappers
     */
    private static List<FormConfigurationWrapper> getFormConfigurationWrappers(Account accountRecord) {
        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult statesResult = BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForRecord(
            accountRecord?.Id
        );
        String additionalStates = statesResult?.valueString;

        List<breg_Form_Configuration__c> formConfigurations = getFormConfigurations(
            'Entity',
            accountRecord?.breg_Entity_Type__c,
            accountRecord?.breg_Entity_Status__c,
            additionalStates
        );

        List<FormConfigurationWrapper> formConfigurationWrappers = constructFormConfigurationWrappers(formConfigurations, accountRecord, additionalStates);

        return formConfigurationWrappers;
    }

    /**
     * @description get form configuration wrappers for TN/TM/SM
     * @param  tnTmSmRecord
     * @return list of form configuration wrappers
     */
    private static List<FormConfigurationWrapper> getFormConfigurationWrappers(breg_TN_TM_SM__c tnTmSmRecord) {
        BREGAdditionalEntityStatesUtils.AdditionalEntityStatesResult statesResult = BREGAdditionalEntityStatesUtils.getAdditionalEntityStatesForRecord(
            tnTmSmRecord?.Id
        );
        String additionalStates = statesResult?.valueString;

        List<breg_Form_Configuration__c> formConfigurations = getFormConfigurations(
            tnTmSmRecord?.breg_Type__c,
            null,
            tnTmSmRecord?.breg_Status__c == 'A' ? 'Active (A)' : 'Inactive',
            additionalStates
        );

        List<FormConfigurationWrapper> formConfigurationWrappers = constructFormConfigurationWrappers(formConfigurations, tnTmSmRecord, additionalStates);

        return formConfigurationWrappers;
    }

    /**
     * @description get form configurations
     * @param  tradeType
     * @param  entityType
     * @param  entityStatus
     * @return list of form configurations
     */
    private static List<breg_Form_Configuration__c> getFormConfigurations(
        String tradeType,
        String entityType,
        String entityStatus,
        String additionalStates
    ) {
        List<breg_Form_Configuration__c> formConfigs = [
            SELECT
                Id,
                Name,
                breg_Heading__c,
                breg_Trade_Type__c,
                breg_Form_Available_Message__c,
                breg_Available_only_for_Entity_Types__c,
                breg_Available_only_for_Entity_Statuses__c,
                breg_Show_Error_For_Additional_States__c,
                breg_Change_Type__c,
                breg_Not_Available_for_Additional_States__c,
                breg_Form_Name__c,
                breg_Form_Code__c,
                breg_Order__c
            FROM breg_Form_Configuration__c
            WHERE
                (breg_Business_Process__c = 'Change'
                OR breg_Form_Code__c = 'T-1'
                OR breg_Form_Code__c = 'T-2'
                OR breg_Form_Code__c = 'T-3'
                OR breg_Form_Code__c = 'X-1')
                AND breg_Trade_Type__c INCLUDES (:tradeType)
                AND (breg_Available_only_for_Entity_Types__c = NULL
                OR breg_Available_only_for_Entity_Types__c INCLUDES (:entityType))
                AND (breg_Available_only_for_Entity_Statuses__c = NULL
                OR breg_Available_only_for_Entity_Statuses__c INCLUDES (:entityStatus))
            ORDER BY breg_Order__c ASC NULLS LAST, breg_Heading__c ASC NULLS LAST
        ];

        formConfigs = filterFormConfigurations(formConfigs, additionalStates);

        return formConfigs;
    }

    private static List<breg_Form_Configuration__c> filterFormConfigurations(List<breg_Form_Configuration__c> formConfigs, String additionalStates) {
        List<breg_Form_Configuration__c> filteredFormConfigs = new List<breg_Form_Configuration__c>();
        Set<String> additionalStatesSet = new Set<String>();
        if (String.isNotBlank(additionalStates)) {
            additionalStatesSet = new Set<String>(additionalStates.split(';'));
        }

        for (breg_Form_Configuration__c config : formConfigs) {
            Boolean shouldInclude = true;

            if (String.isNotBlank(config.breg_Not_Available_for_Additional_States__c)) {
                Set<String> notAvailableStates = new Set<String>(config.breg_Not_Available_for_Additional_States__c.split(';'));

                for (String notAvailableState : notAvailableStates) {
                    if (additionalStatesSet.contains(notAvailableState)) {
                        shouldInclude = false;
                        break;
                    }
                }
            }

            if (shouldInclude) {
                filteredFormConfigs.add(config);
            }
        }

        return filteredFormConfigs;
    }

    /**
     * @description filter form configurations for Account
     * @param  formConfigurations
     * @param  accountRecord
     */
    private static List<FormConfigurationWrapper> constructFormConfigurationWrappers(
        List<breg_Form_Configuration__c> formConfigs,
        Account accountRecord,
        String additionalStates
    ) {
        List<FormConfigurationWrapper> formConfigWrappers = new List<FormConfigurationWrapper>();
        String safeAdditionalStates = additionalStates ?? '';

        if (
            accountRecord.breg_Entity_Type__c == G5_ENTITY_TYPE ||
            accountRecord.breg_Entity_Type__c == G6_ENTITY_TYPE ||
            accountRecord.breg_Entity_Type__c == K5_ENTITY_TYPE ||
            accountRecord.breg_Entity_Type__c == K6_ENTITY_TYPE
        ) {
            formConfigWrappers.add(new FormConfigurationWrapper(null, 'Restated Articles', null, RESTATED_ARTICLES_ERROR_MESSAGE, true, false));
        }

        for (breg_Form_Configuration__c formConfig : formConfigs) {
            String heading = String.isNotBlank(formConfig.breg_Heading__c) ? formConfig.breg_Heading__c : formConfig.breg_Form_Name__c;
            if (formConfig.breg_Form_Code__c == ADD_MEMBER_FORM && ENTITY_TYPE_WITH_PARTNER.contains(accountRecord.breg_Entity_Type__c)) {
                heading = heading.replace('Member', 'Partner');
            }
            String formAvailableMessage = formConfig.breg_Form_Available_Message__c ?? '';
            String formConfigShowErrorForAdditionalStates = formConfig.breg_Show_Error_For_Additional_States__c ?? '';
            String errorMessage = getErrorMessage(formConfigShowErrorForAdditionalStates, safeAdditionalStates, accountRecord.Name);
            Boolean isError = String.isNotBlank(errorMessage);

            if (String.isNotBlank(formConfig.breg_Change_Type__c) && formConfig.breg_Change_Type__c.contains('Name Change for Entity')) {
                String entityTypeLabel = BREGUtils.getPicklistLabel(ACCOUNT_SOBJECT_TYPE, 'breg_Entity_Type__c', accountRecord?.breg_Entity_Type__c);
                formAvailableMessage = String.format(formAvailableMessage, new List<String>{ entityTypeLabel });
            }

            formConfigWrappers.add(new FormConfigurationWrapper(formConfig, heading, formAvailableMessage, errorMessage, isError, false));
        }

        return formConfigWrappers;
    }

    /**
     * @description filter form configurations for TN/TM/SM
     * @param  formConfigurations
     * @param  tnTmSmRecord
     */
    private static List<FormConfigurationWrapper> constructFormConfigurationWrappers(
        List<breg_Form_Configuration__c> formConfigs,
        breg_TN_TM_SM__c tnTmSmRecord,
        String additionalStates
    ) {
        List<FormConfigurationWrapper> formConfigurationWrappers = new List<FormConfigurationWrapper>();
        String safeAdditionalStates = additionalStates ?? '';

        for (breg_Form_Configuration__c formConfig : formConfigs) {
            String heading = String.isNotBlank(formConfig.breg_Heading__c) ? formConfig.breg_Heading__c : formConfig.breg_Form_Name__c;
            String formAvailableMessage = formConfig.breg_Form_Available_Message__c ?? '';
            String formConfigShowErrorForAdditionalStates = formConfig.breg_Show_Error_For_Additional_States__c ?? '';
            String errorMessage = getErrorMessage(formConfigShowErrorForAdditionalStates, safeAdditionalStates, tnTmSmRecord?.Name);
            Boolean isError = String.isNotBlank(errorMessage);
            Boolean isRenewal =
                formConfig.breg_Form_Code__c == 'T-1' ||
                formConfig.breg_Form_Code__c == 'T-2' ||
                formConfig.breg_Form_Code__c == 'T-3' ||
                formConfig.breg_Form_Code__c == 'T-7';

            formConfigurationWrappers.add(new FormConfigurationWrapper(formConfig, heading, formAvailableMessage, errorMessage, isError, isRenewal));
        }

        return formConfigurationWrappers;
    }

    /**
     * @description get error message for form configuration
     * @param  formConfigShowErrorForAdditionalStates formConfigShowErrorForAdditionalStates description
     * @param  additionalStates                       additionalStates description
     * @param  entityName                             entityName description
     * @return                                        error message
     */
    private static String getErrorMessage(String formConfigShowErrorForAdditionalStates, String additionalStates, String entityName) {
        String errorMessage = null;

        if (formConfigShowErrorForAdditionalStates?.contains('Not active') && additionalStates?.contains('Not active')) {
            errorMessage = String.format(NOT_ACTIVE_ERROR_MESSAGE, new List<String>{ entityName });
        }

        if (formConfigShowErrorForAdditionalStates?.contains('Not in good standing') && additionalStates?.contains('Not in good standing')) {
            errorMessage = BUSINESS_NOT_IN_GOOD_STANDING_ERROR_MESSAGE;
        }
        if (formConfigShowErrorForAdditionalStates?.contains('Registered CRA') && additionalStates?.contains('Registered CRA')) {
            errorMessage = REGISTERED_CRA_ERROR_MESSAGE;
        }

        if (formConfigShowErrorForAdditionalStates?.contains('Pending ODC request') && additionalStates?.contains('Pending ODC request')) {
            errorMessage = PENDING_ODC_REQUEST_ERROR_MESSAGE;
        }

        if (formConfigShowErrorForAdditionalStates?.contains('Pending ADD request') && additionalStates?.contains('Pending ADD request')) {
            errorMessage = PENDING_ADD_REQUEST_ERROR_MESSAGE;
        }

        if (
            formConfigShowErrorForAdditionalStates?.contains('Pending O/D/M/M/P ADD request') &&
            additionalStates?.contains('Pending O/D/M/M/P ADD request')
        ) {
            errorMessage = PENDING_ADD_ODMMP_REQUEST_ERROR_MESSAGE;
        }

        if (
            formConfigShowErrorForAdditionalStates?.contains('Current date is not within the last 180 days of active term') &&
            additionalStates?.contains('Current date is not within the last 180 days of active term')
        ) {
            errorMessage = CURRENT_DATE_NOT_WITHIN_LAST_180_DAYS_OF_ACTIVE_TERM_ERROR_MESSAGE;
        }

        if (
            formConfigShowErrorForAdditionalStates?.contains('More than 14 days prior to the expiration date') &&
            additionalStates?.contains('More than 14 days prior to the expiration date')
        ) {
            errorMessage = NAME_RESERVATION_MORE_THAN_14_DAYS_PRIOR_TO_EXPIRATION_DATE_ERROR_MESSAGE;
        }

        if (formConfigShowErrorForAdditionalStates?.contains('Bounce check in progress') && additionalStates?.contains('Bounce check in progress')) {
            errorMessage = BOUNCE_CHECK_IN_PROGRESS_ERROR_MESSAGE;
        }

        if (formConfigShowErrorForAdditionalStates?.contains('2 years after dissolution') && additionalStates?.contains('2 years after dissolution')) {
            errorMessage = TWO_YEARS_AFTER_DISSOLUTION_ERROR_MESSAGE;
        }

        if (
            formConfigShowErrorForAdditionalStates?.contains('No active agent associated who is not a CRA') &&
            additionalStates?.contains('No active agent associated who is not a CRA')
        ) {
            errorMessage = NO_ACTIVE_AGENT_ASSOCIATED_ERROR_MESSAGE;
        }

        return errorMessage;
    }

    /**
     * @description get field values for TN/TM/SM
     * @param  tnTmSmRecord
     * @param  mappings     field mappings
     * @return              list of company info field wrappers
     */
    private static List<CompanyInfoFieldWrapper> getFieldValues(breg_TN_TM_SM__c tnTmSmRecord, List<breg_Company_Info_Field_Mapping__mdt> mappings) {
        List<CompanyInfoFieldWrapper> fields = new List<CompanyInfoFieldWrapper>();
        breg_Account_Affiliation__c agent = getActiveAgent(tnTmSmRecord?.breg_Account__c);
        breg_Account_Affiliation__c applicant = getApplicantAffiliation(tnTmSmRecord?.Id);

        String agentName = BREGAddressProtectionUtils.buildAffiliationName(agent);
        BREGAddressProtectionUtils.AddressWrapper addr = BREGAddressProtectionUtils.buildAddressFromAffiliation(agent);
        if (String.isNotBlank(agentName) && BREGAddressProtectionUtils.isAddressProtected(agentName, addr)) {
            BREGAddressProtectionUtils.clearAffiliationAddressFields(agent);
            isDisabledTransactions = true;
            hideAgentAddress = true;
        }

        String entityName = agent != null ? BREGAddressProtectionUtils.buildAffiliationName(agent) : tnTmSmRecord?.breg_Trade_Name__c != null ? tnTmSmRecord?.breg_Trade_Name__c : tnTmSmRecord?.Name;
        if(String.isNotBlank(entityName)) {
            if (BREGAddressProtectionUtils.isAddressProtected(
                entityName,
                new BREGAddressProtectionUtils.AddressWrapper(
                    tnTmSmRecord.breg_Mailing_Address__Street__s,
                    null,
                    null,
                    tnTmSmRecord.breg_Mailing_Address__City__s,
                    tnTmSmRecord.breg_Mailing_Address__StateCode__s,
                    tnTmSmRecord.breg_Mailing_Address__CountryCode__s,
                    tnTmSmRecord.breg_Mailing_Address__PostalCode__s
                )
            )) {
                tnTmSmRecord.breg_Mailing_Address__Street__s = null;
                tnTmSmRecord.breg_Mailing_Address__City__s = null;
                tnTmSmRecord.breg_Mailing_Address__StateCode__s = null;
                tnTmSmRecord.breg_Mailing_Address__CountryCode__s = null;
                tnTmSmRecord.breg_Mailing_Address__PostalCode__s = null;
                isDisabledTransactions = true;
                hideMailingAddress = true;
            }
        }

        for (breg_Company_Info_Field_Mapping__mdt mapping : mappings) {
            // Skip if the entity type is not allowed
            Boolean isEntityTypeAllowed = isEntityTypeAllowed(mapping.breg_Allowed_Entity_Types__c, tnTmSmRecord?.breg_Type__c);
            if (!isEntityTypeAllowed) {
                continue;
            }

            String fieldMappingLabel = mapping.breg_Field_Label__c;
            String fieldMappingApiName = mapping.breg_Field_API_Name__c;
            if (String.isBlank(fieldMappingLabel) && String.isBlank(fieldMappingApiName)) {
                continue;
            }
            if (
                'Agent Name'.equalsIgnoreCase(fieldMappingLabel) ||
                'Agent Address'.equalsIgnoreCase(fieldMappingLabel)
            ) {
                continue;
            }
            String fieldWrapperLabel = fieldMappingLabel;
            String fieldWrapperValue = '';
            String fieldWrapperHelpText = null;
            String fieldWrapperValueUrl = null;

            if ('Trade Type'.equalsIgnoreCase(fieldMappingLabel)) {
                // Trade Type label should be taken from the TN/TM/SM Type field
                // Trade Type value should be taken from the TN/TM/SM Name field
                fieldWrapperLabel = tnTmSmRecord?.breg_Type__c;
                fieldWrapperValue = tnTmSmRecord?.breg_Trade_Name__c != null ? tnTmSmRecord?.breg_Trade_Name__c : tnTmSmRecord?.Name;
            } else if ('Status'.equalsIgnoreCase(fieldMappingLabel)) {
                fieldWrapperValue = BREGUtils.getPicklistLabel('breg_TN_TM_SM__c', 'breg_Status__c', tnTmSmRecord?.breg_Status__c);
            } else if ('File Number'.equalsIgnoreCase(fieldMappingLabel)) {
                // File Number and File Suffix should be combined
                fieldWrapperValue = getFileNumber(tnTmSmRecord?.breg_Account__r?.breg_File__c, tnTmSmRecord?.breg_Account__r?.breg_File_Suffix__c);
            } else if ('Registration Date'.equalsIgnoreCase(fieldMappingLabel)) {
                // Registration Date should be formatted
                fieldWrapperValue = formatDate(tnTmSmRecord?.breg_Registration_Date__c);
            } else if ('Expiration Date'.equalsIgnoreCase(fieldMappingLabel)) {
                // Expiration Date should be formatted
                fieldWrapperValue = formatDate(tnTmSmRecord?.breg_Expiration_Date__c);
            } else if ('Mailing Address'.equalsIgnoreCase(fieldMappingLabel) && !hideMailingAddress) {
                // Mailing Address should be formatted
                fieldWrapperValue = formatAddress(tnTmSmRecord?.breg_Mailing_Address__c, null);
            } else if ('Registrant'.equalsIgnoreCase(fieldMappingLabel)) {
                if (applicant?.breg_Type__c == 'Individual') {
                    fieldWrapperValue = String.join(
                        new List<String>{
                            applicant.breg_First_Name__c,
                            applicant.breg_Last_Name__c
                        },
                        ' '
                    ).trim();
                } else {
                    fieldWrapperValue = tnTmSmRecord?.breg_Account__r?.Name;

                    fieldWrapperValueUrl = '/search-and-buy?entityId=' + tnTmSmRecord?.breg_Account__c;
                }
            } else if ('Agent Name'.equalsIgnoreCase(fieldMappingLabel)) {
                // Agent Name should be taken from the Account's Account Affiliation record
                fieldWrapperValue = agent?.breg_Affiliation_Name__c;
            } else if ('Agent Address'.equalsIgnoreCase(fieldMappingLabel) && !hideAgentAddress) {
                // Agent Address should be taken from the Account Affiliation record
                fieldWrapperValue = formatAddress(agent?.breg_Address__c, null);
            } else if ('Cross Reference Name'.equalsIgnoreCase(fieldMappingLabel)) {
                // Cross Reference Name should be taken from the TN/TM/SM record
                fieldWrapperValue = getCrossReferenceName(tnTmSmRecord?.breg_XREF_Name1__c, tnTmSmRecord?.breg_XREF_Name2__c);
            } else if (String.isNotBlank(fieldMappingApiName)) {
                // Get the field value from the TN/TM/SM record
                fieldWrapperValue = String.valueOf(tnTmSmRecord?.get(fieldMappingApiName));
            }

            if (mapping.breg_Hide_If_Blank__c && String.isBlank(fieldWrapperValue)) {
                continue;
            }

            if(hideBillingAddress && 'Principal Address'.equalsIgnoreCase(fieldMappingLabel)) {
                continue;
            }

            if(hideMailingAddress && 'Mailing Address'.equalsIgnoreCase(fieldMappingLabel)) {
                continue;
            }

            if(hideAgentAddress && 'Agent Address'.equalsIgnoreCase(fieldMappingLabel)) {
                continue;
            }
            fields.add(new CompanyInfoFieldWrapper(fieldWrapperLabel, fieldWrapperValue, fieldWrapperHelpText, fieldWrapperValueUrl));
        }

        return fields;
    }

    public static breg_Account_Affiliation__c getActiveAgent(Id accountId) {
        List<breg_Account_Affiliation__c> agents = [
            SELECT  Id, breg_Affiliation_Name__c, breg_Address__c, breg_Entity_Name__c, breg_First_Name__c, breg_Last_Name__c, breg_Role__c, breg_Type__c,
                    breg_Address__Street__s,
                    breg_Address__City__s,
                    breg_Address__StateCode__s,
                    breg_Address__PostalCode__s,
                    breg_Address__CountryCode__s,
                    breg_Address_Street_2__c,
                    breg_Affiliation_Formula_Street__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c = :accountId AND breg_Role__c = 'Agent' AND breg_Status__c = 'A' AND breg_End_Date__c = NULL
            LIMIT 1
        ];
        if (agents.isEmpty()) {
            return null;
        }
        return agents[0];
    }

    private static breg_Account_Affiliation__c getApplicantAffiliation(Id tnTmSmId) {
        List<breg_Account_Affiliation__c> applicants = [
            SELECT Id, breg_Type__c, breg_Entity_Name__c, breg_First_Name__c, breg_Last_Name__c, breg_Address__c, breg_Role__c,
                    breg_Address__Street__s,
                    breg_Address__City__s,
                    breg_Address__StateCode__s,
                    breg_Address__PostalCode__s,
                    breg_Address__CountryCode__s,
                    breg_Address_Street_2__c,
                    breg_Affiliation_Formula_Street__c
            FROM breg_Account_Affiliation__c
            WHERE breg_TN_TM_SM__c = :tnTmSmId
                AND breg_Role__c = 'Applicant'
                AND breg_Status__c = 'A'
                AND breg_End_Date__c = NULL
            LIMIT 1
        ];

        return applicants.isEmpty() ? null : applicants[0];
    }

    /**
     * @description get field values for Account
     * @param  accountRecord
     * @param  mappings     field mappings
     * @return              list of company info field wrappers
     */
    private static List<CompanyInfoFieldWrapper> getFieldValues(Account accountRecord, List<breg_Company_Info_Field_Mapping__mdt> mappings) {
        List<CompanyInfoFieldWrapper> fields = new List<CompanyInfoFieldWrapper>();
        breg_Account_Affiliation__c agent = getActiveAgent(accountRecord?.Id);
        
        String agentName = agent != null ? BREGAddressProtectionUtils.buildAffiliationName(agent) : '';
        BREGAddressProtectionUtils.AddressWrapper addr = BREGAddressProtectionUtils.buildAddressFromAffiliation(agent);
        if (String.isNotBlank(agentName) && BREGAddressProtectionUtils.isAddressProtected(agentName, addr)) {
            BREGAddressProtectionUtils.clearAffiliationAddressFields(agent);
            isDisabledTransactions = true;
            hideAgentAddress = true;
        }

        String entityName = agent != null ? BREGAddressProtectionUtils.buildAffiliationName(agent) : accountRecord?.Name;
        if(String.isNotBlank(entityName)) {
            if (BREGAddressProtectionUtils.isAddressProtected(
                entityName,
                new BREGAddressProtectionUtils.AddressWrapper(
                    accountRecord.BillingStreet,
                    accountRecord.breg_Billing_Address_Street_2__c,
                    null,
                    accountRecord.BillingCity,
                    accountRecord.BillingStateCode,
                    accountRecord.BillingCountryCode,
                    accountRecord.BillingPostalCode
                )
            )) {
                accountRecord.BillingStreet = null;
                accountRecord.breg_Billing_Address_Street_2__c = null;
                accountRecord.BillingCity = null;
                accountRecord.BillingStateCode = null;
                accountRecord.BillingCountryCode = null;
                accountRecord.BillingPostalCode = null;
                isDisabledTransactions = true;
                hideBillingAddress = true;
            }

            if (BREGAddressProtectionUtils.isAddressProtected(
                entityName,
                new BREGAddressProtectionUtils.AddressWrapper(
                    accountRecord.breg_Mailing_Address__Street__s,
                    accountRecord.breg_Mailing_Address_Street_2__c,
                    null,
                    accountRecord.breg_Mailing_Address__City__s,
                    accountRecord.breg_Mailing_Address__StateCode__s,
                    accountRecord.breg_Mailing_Address__CountryCode__s,
                    accountRecord.breg_Mailing_Address__PostalCode__s
                )
            )) {
                accountRecord.breg_Mailing_Address__Street__s = null;
                accountRecord.breg_Mailing_Address_Street_2__c = null;
                accountRecord.breg_Mailing_Address__City__s = null;
                accountRecord.breg_Mailing_Address__StateCode__s = null;
                accountRecord.breg_Mailing_Address__CountryCode__s = null;
                accountRecord.breg_Mailing_Address__PostalCode__s = null;
                isDisabledTransactions = true;
                hideMailingAddress = true;
            }
        }
        for (breg_Company_Info_Field_Mapping__mdt mapping : mappings) {
            // Skip if the entity type is not allowed
            Boolean isEntityTypeAllowed = isEntityTypeAllowed(mapping.breg_Allowed_Entity_Types__c, accountRecord?.breg_Entity_Type__c);
            if (!isEntityTypeAllowed) {
                continue;
            }

            // Get the field mapping label, API name, and wrapper label
            String fieldMappingLabel = mapping.breg_Field_Label__c;
            String fieldMappingApiName = mapping.breg_Field_API_Name__c;
            if (String.isBlank(fieldMappingLabel) && String.isBlank(fieldMappingApiName)) {
                continue;
            }
            String fieldWrapperLabel = fieldMappingLabel;
            String fieldWrapperValue = '';
            String fieldWrapperHelpText = null;
            String fieldWrapperValueUrl = null;

            if ('Entity Name'.equalsIgnoreCase(fieldMappingLabel)) {
                // Entity Name should be taken from the Account record
                fieldWrapperValue = accountRecord?.Name;
            }
            if ('Business Type'.equalsIgnoreCase(fieldMappingLabel)) {
                // Entity Type label should be taken from the picklist
                fieldWrapperValue = BREGUtils.getPicklistLabel(ACCOUNT_SOBJECT_TYPE, 'breg_Entity_Type__c', accountRecord?.breg_Entity_Type__c);
            } else if ('Status'.equalsIgnoreCase(fieldMappingLabel)) {
                fieldWrapperValue = BREGUtils.getPicklistLabel('Account', 'breg_Entity_Status__c', accountRecord?.breg_Entity_Status__c);
            } else if ('File Number'.equalsIgnoreCase(fieldMappingLabel)) {
                // File Number and File Suffix should be combined
                fieldWrapperValue = getFileNumber(accountRecord?.breg_File__c, accountRecord?.breg_File_Suffix__c);
            } else if ('Organized In'.equalsIgnoreCase(fieldMappingLabel)) {
                // Place of Incorporation or Organization should be formatted
                fieldWrapperValue = formatOrganizedIn(accountRecord?.breg_Formation_State_Label__c, accountRecord?.breg_Formation_Country_Label__c);
            } else if ('Organization Date'.equalsIgnoreCase(fieldMappingLabel)) {
                // If Entity Type is G5, use Formation Date
                // If Entity Type is L6 or G6, use Commence Date
                if (G5_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c)) {
                    fieldWrapperValue = formatDate(accountRecord?.breg_Incorporation_Date__c);
                } else if (
                    G6_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c) ||
                    L6_ENTITY_TYPE.equalsIgnoreCase(accountRecord?.breg_Entity_Type__c)
                ) {
                    fieldWrapperValue = formatDate(accountRecord?.breg_Commence_Date__c);
                }
            } else if ('Registration Date'.equalsIgnoreCase(fieldMappingLabel)) {
                // Registration Date should be formatted
                fieldWrapperValue = formatDate(accountRecord?.breg_Incorporation_Date__c);
            } else if ('Mailing Address'.equalsIgnoreCase(fieldMappingLabel) && !hideMailingAddress) {
                // Mailing Address should be formatted
                fieldWrapperValue = formatAddress(accountRecord?.breg_Mailing_Address__c, accountRecord?.breg_Mailing_Formula_Street__c);
            } else if ('Principal Address'.equalsIgnoreCase(fieldMappingLabel) && !hideBillingAddress) {
                // Principal Address should be formatted
                fieldWrapperValue = formatAddress(accountRecord?.BillingAddress, accountRecord?.breg_Principal_Formula_Street__c);
            } else if ('Agent Name'.equalsIgnoreCase(fieldMappingLabel)) {
                // Agent Name should be taken from the Account Affiliation record
                fieldWrapperValue = agent?.breg_Affiliation_Name__c;
            } else if ('Agent Address'.equalsIgnoreCase(fieldMappingLabel) && !hideAgentAddress) {
                // Agent Address should be taken from the Account Affiliation record
                fieldWrapperValue = formatAddress(agent?.breg_Address__c, agent?.breg_Affiliation_Formula_Street__c);
            } else if ('Commercial Registered Agent?'.equalsIgnoreCase(fieldMappingLabel)) {
                // Check if the Account is a CRA
                fieldWrapperValue = accountRecord?.breg_BRIM_CRA_FL__c ? YES : NO;
                fieldWrapperHelpText = COMMERCIAL_REGISTERED_AGENT_HELP_TEXT;
            } else if ('Cross Reference Name'.equalsIgnoreCase(fieldMappingLabel)) {
                // Cross Reference Name should be taken from the Account record
                fieldWrapperValue = getCrossReferenceName(accountRecord?.breg_XREF_Name_1__c, accountRecord?.breg_XREF_Name_2__c);
            } else if (String.isNotBlank(fieldMappingApiName)) {
                // Get the field value from the Account record
                fieldWrapperValue = String.valueOf(accountRecord.get(fieldMappingApiName));
            }

            if (mapping.breg_Hide_If_Blank__c && String.isBlank(fieldWrapperValue)) {
                continue;
            }

            if(hideBillingAddress && 'Principal Address'.equalsIgnoreCase(fieldMappingLabel)) {
                continue;
            }

            if(hideMailingAddress && 'Mailing Address'.equalsIgnoreCase(fieldMappingLabel)) {
                continue;
            }

            if(hideAgentAddress && 'Agent Address'.equalsIgnoreCase(fieldMappingLabel)) {
                continue;
            }

            fields.add(new CompanyInfoFieldWrapper(fieldWrapperLabel, fieldWrapperValue, fieldWrapperHelpText, fieldWrapperValueUrl));
        }

        return fields;
    }

    private static List<CompanyInfoFieldWrapper> getFieldValues(
        breg_Transaction__c transactionRecord,
        List<breg_Company_Info_Field_Mapping__mdt> mappings
    ) {
        List<CompanyInfoFieldWrapper> fields = new List<CompanyInfoFieldWrapper>();
        Map<String, String> statusPicklistLabelsMap = BREGUtils.getPicklistLabelMap(TRANSACTION_SOBJECT_TYPE, 'breg_Status__c');
        Map<String, String> transCodePicklistLabelsMap = BREGUtils.getPicklistLabelMap(TRANSACTION_SOBJECT_TYPE, 'breg_Transaction_Code__c');
        for (breg_Company_Info_Field_Mapping__mdt mapping : mappings) {
            // Get the field mapping label, API name, and wrapper label
            String fieldMappingLabel = mapping.breg_Field_Label__c;
            String fieldMappingApiName = mapping.breg_Field_API_Name__c;
            if (String.isBlank(fieldMappingLabel) && String.isBlank(fieldMappingApiName)) {
                continue;
            }
            String fieldWrapperLabel = fieldMappingLabel;
            String fieldWrapperValue = '';
            String fieldWrapperHelpText = null;
            String fieldWrapperValueUrl = null;
            if ('Transaction Code'.equalsIgnoreCase(fieldMappingLabel)) {
                // Transaction Number should be taken from the Account record
                fieldWrapperValue = transCodePicklistLabelsMap.get(transactionRecord.breg_Transaction_Code__c);
            } else if ('Transaction Name'.equalsIgnoreCase(fieldMappingLabel)) {
                // Transaction Name should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_Business_Name__c;
            } else if ('Transaction New Name'.equalsIgnoreCase(fieldMappingLabel)) {
                // Transaction New Name should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_BRIM_New_Name__c;
            } else if ('File Number'.equalsIgnoreCase(fieldMappingLabel)) {
                // File Number should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_BRIM_TRANS_ID__c;
            } else if ('Status'.equalsIgnoreCase(fieldMappingLabel)) {
                // Status should be taken from the Account record
                fieldWrapperValue = statusPicklistLabelsMap.get(transactionRecord.breg_Status__c);
            } else if ('Received Date'.equalsIgnoreCase(fieldMappingLabel)) {
                // Date should be taken from the Account record
                fieldWrapperValue = formatDate(transactionRecord.breg_Received_Date__c);
            } else if ('Trade Type'.equalsIgnoreCase(fieldMappingLabel)) {
                // Trade Type should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_Trade_Type__c;
            } else if ('Category'.equalsIgnoreCase(fieldMappingLabel)) {
                // Category should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_Category__c;
            } else if ('Remarks'.equalsIgnoreCase(fieldMappingLabel)) {
                // Remarks should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_Remarks__c;
            } else if ('Work Item Number'.equalsIgnoreCase(fieldMappingLabel)) {
                // Work Item Number should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_Case__r.breg_Workitem_Number__c;
            } else if ('Form Code'.equalsIgnoreCase(fieldMappingLabel)) {
                // Form Code should be taken from the Account record
                fieldWrapperValue = transactionRecord.breg_Case__r.breg_Form_Code__c;
            } else if ('Effective Date'.equalsIgnoreCase(fieldMappingLabel)) {
                // Date should be taken from the Account record
                fieldWrapperValue = formatDate(transactionRecord.breg_Effective_Date__c);
            }

            if (mapping.breg_Hide_If_Blank__c && String.isBlank(fieldWrapperValue)) {
                continue;
            }

            fields.add(new CompanyInfoFieldWrapper(fieldWrapperLabel, fieldWrapperValue, fieldWrapperHelpText, fieldWrapperValueUrl));
        }

        return fields;
    }

    /**
     * Returns the concatenation of cross reference names, separated by a semicolon,
     * if both are not blank. Otherwise, returns whichever is not blank.
     * @param xrefName1 First cross reference name
     * @param xrefName2 Second cross reference name
     * @return Concatenated string or single value if only one is non-blank
     */
    private static String getCrossReferenceName(String xrefName1, String xrefName2) {
        if (String.isNotBlank(xrefName1) && String.isNotBlank(xrefName2)) {
            return '1. ' + xrefName1 + '\n2. ' + xrefName2;
        } else if (String.isNotBlank(xrefName1)) {
            return xrefName1;
        } else {
            return xrefName2;
        }
    }

    /**
     * Retrieves field mappings from custom metadata for the specified object type
     * @param objectType The SObject type to get mappings for
     * @return List of field mapping custom metadata records
     */
    private static List<breg_Company_Info_Field_Mapping__mdt> getFieldMappingsFromMetadata(String objectType) {
        return [
            SELECT breg_Field_API_Name__c, breg_Field_Label__c, breg_Display_Order__c, breg_Allowed_Entity_Types__c, breg_Hide_If_Blank__c
            FROM breg_Company_Info_Field_Mapping__mdt
            WHERE breg_Object_Type__c = :objectType AND breg_Active__c = TRUE
            ORDER BY breg_Display_Order__c ASC
        ];
    }

    /**
     * Formats a date into a string in the format of MMM d, yyyy
     * @param date The date to format
     * @return Formatted date string
     */
    private static String formatDate(Date dateToFormat) {
        if (dateToFormat == null) {
            return '';
        }
        // Convert Date to DateTime to use the .format() method
        DateTime dt = DateTime.newInstance(dateToFormat.year(), dateToFormat.month(), dateToFormat.day());
        return dt.format('MMM d, yyyy');
    }

    /**
     * @description get file number and file suffix combined
     * @param  fileNumber
     * @param  fileSuffix
     * @return file number and file suffix combined
     */
    private static String getFileNumber(String fileNumber, String fileSuffix) {
        String result = '';
        if (String.isNotBlank(fileNumber)) {
            result = getFormattedFileNumber(fileNumber);
        } else if (String.isNotBlank(fileSuffix)) {
            result = fileSuffix;
        }
        return result;
    }

    private static String getFormattedFileNumber(String fileNumber) {
        if (String.isBlank(fileNumber)) {
            return fileNumber;
        }

        // Use regex to find where the numeric part ends and the alphanumeric suffix begins
        // Pattern: one or more digits, followed by one or more letters/digits
        Pattern pattern = Pattern.compile('(\\d+)([A-Za-z]\\d*)');
        Matcher matcher = pattern.matcher(fileNumber);

        if (matcher.matches()) {
            // Group 1 is the numeric part, Group 2 is the suffix (letter + optional digit)
            return matcher.group(1) + ' ' + matcher.group(2);
        }

        // If pattern doesn't match, return as-is
        return fileNumber;
    }

    /**
     * Formats a Salesforce Address field into a multi-line address string
     * @param address The Address field to format
     * @return Formatted address string with line breaks
     */
    private static String formatAddress(Address address, String formulaStreet) {
        if (address == null) {
            return '';
        }

        List<String> addressLines = new List<String>();

        // First line: Street address
        if (formulaStreet != null) {
            addressLines.add(formulaStreet);
        } else if (String.isNotBlank(address.getStreet())) {
            addressLines.add(address.getStreet());
        }

        // Second line: City, State ZIP
        List<String> cityStateZip = new List<String>();
        if (String.isNotBlank(address.getCity())) {
            cityStateZip.add(address.getCity());
        }
        if (String.isNotBlank(address.getState())) {
            cityStateZip.add(address.getState());
        }
        if (String.isNotBlank(address.getPostalCode())) {
            cityStateZip.add(address.getPostalCode());
        }

        if (!cityStateZip.isEmpty()) {
            addressLines.add(String.join(cityStateZip, ' '));
        }

        // Third line: Country
        if (String.isNotBlank(address.getCountry())) {
            addressLines.add(address.getCountry());
        }

        return String.join(addressLines, '\n');
    }

    /**
     * Checks if the entity type is allowed for the field mapping
     * @param allowedTypes Comma-separated list of allowed entity types
     * @param entityType The current entity type
     * @return true if allowed, false otherwise
     */
    private static Boolean isEntityTypeAllowed(String allowedTypes, String entityType) {
        if (String.isBlank(allowedTypes)) {
            return true;
        }
        if (String.isBlank(entityType)) {
            return false;
        }

        List<String> allowedList = allowedTypes.split(',');
        for (String allowed : allowedList) {
            if (allowed.trim().equalsIgnoreCase(entityType)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Formats the Organized In field
     * @param place The place of incorporation or organization
     * @param state The state of incorporation or organization
     * @param country The country of incorporation or organization
     * @return Formatted Organized In string
     */
    private static String formatOrganizedIn(String state, String country) {
        if (String.isNotBlank(state) && String.isNotBlank(country)) {
            return state + ', ' + country;
        } else if (String.isNotBlank(state)) {
            return state + ', UNITED STATES';
        } else if (String.isNotBlank(country)) {
            return country;
        } else {
            return 'Hawaii, UNITED STATES';
        }
    }

    /**
     * Retrieves breg_TN_TM_SM__c data for the given ID
     * @param tnTmSmId The breg_TN_TM_SM__c ID to query
     * @return breg_TN_TM_SM__c record or null if not found
     */
    private static breg_TN_TM_SM__c getTnTmSmRecord(Id tnTmSmId) {
        List<breg_TN_TM_SM__c> records = [
            SELECT
                Id,
                Name,
                breg_Trade_Name__c,
                breg_Type__c,
                breg_Status__c,
                breg_Registration_Date__c,
                breg_Expiration_Date__c,
                breg_Cert_Number__c,
                breg_Cert_Date__c,
                breg_TM_SM_Category__c,
                breg_Details__c,
                breg_Trade_Type__c,
                breg_Descriptors__c,
                breg_XREF_Name1__c,
                breg_XREF_Name2__c,
                breg_Similar_Name__c,
                breg_Notes__c,
                breg_Account__c,
                breg_Certificate__c,
                breg_DocuSign_Envelope_Document__c,
                breg_Registrant_Name__c,
                breg_Account__r.breg_File__c,
                breg_Account__r.breg_File_Suffix__c,
                breg_Mailing_Address__c,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__CountryCode__s,
                breg_Registrant_Type__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Applicant_Name__c,
                breg_Purpose__c,
                breg_Account__r.Name,
                breg_Account__r.breg_BRIM_MASTER_NAME__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :tnTmSmId
            LIMIT 1
        ];

        return !records.isEmpty() ? records[0] : null;
    }

    /**
     * Retrieves Account data for the given Account Id
     * @param accountId The Account Id to query
     * @return Account record or null if not found
     */
    private static Account getAccountRecord(Id accountId) {
        List<Account> accounts = [
            SELECT
                Id,
                Name,
                breg_BRIM_MASTER_NAME__c,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Entity_Type__c,
                breg_Reserved_for_Entity_Type__c,
                breg_Entity_Status__c,
                breg_Registration_Date__c,
                breg_Term__c,
                breg_Management_Type__c,
                breg_Number_of_initial_members__c,
                breg_Is_Manager_Managed__c,
                breg_Formation_State__c,
                breg_Formation_Country__c,
                Contact__c,
                breg_Record_Type__c,
                breg_Purpose__c,
                breg_Consent__c,
                breg_Similar_Name__c,
                breg_Commence_Date__c,
                breg_Formation_Date__c,
                breg_Formation_Country_Label__c,
                breg_Formation_State_Label__c,
                breg_Partner_Term__c,
                breg_Mailing_Address__c,
                breg_Registrant_Type__c,
                breg_Registrant_Name__c,
                breg_Registrant_First_Name__c,
                breg_Registrant_Last_Name__c,
                breg_Registrant_Address__c,
                breg_Good_Standing__c,
                breg_Incorporation_Date__c,
                BillingAddress,
                breg_XREF_Name_1__c,
                breg_XREF_Name_2__c,
                breg_BRIM_CRA_FL__c,
                breg_Principal_Formula_Street__c,
                breg_Mailing_Formula_Street__c,
                BillingStreet,
                BillingCity,
                BillingStateCode,
                BillingPostalCode,
                BillingCountryCode,
                breg_Billing_Address_Street_2__c,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address_Street_2__c
            FROM Account
            WHERE Id = :accountId
            AND RecordType.DeveloperName = 'BREG_Account'
            LIMIT 1
        ];

        return !accounts.isEmpty() ? accounts[0] : null;
    }

    private static breg_Transaction__c getTransactionRecord(Id transactionId) {
        List<breg_Transaction__c> transactions = [
            SELECT
                Id,
                breg_Case__c,
                breg_Case__r.breg_Workitem_Number__c,
                breg_Case__r.breg_Form_Code__c,
                breg_Received_Date__c,
                breg_Effective_Date__c,
                breg_Category__c,
                breg_Remarks__c,
                breg_Description__c,
                breg_BRIM_TRANS_ID__c,
                breg_Transaction_Code__c,
                breg_Trade_Type__c,
                breg_Status__c,
                breg_Business_Name__c,
                breg_BRIM_New_Name__c,
                breg_Type__c
            FROM breg_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        return !transactions.isEmpty() ? transactions[0] : null;
    }

    /**
     * Retrieves Account Affiliation data for the given Account Id
     * @param accountId The Account Id to query
     * @return List of Account Affiliation records
     */
    private static List<breg_Account_Affiliation__c> getAccountAffiliationData(Id accountId, String entityType) {
        List<String> roles = getAccountAffiliationRole(entityType);

        return [
            SELECT
                Id,
                Name,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Entity_Name__c,
                breg_Officer_Director_Titles__c,
                breg_Officer_Director_TitlesText_Formula__c,
                breg_As_of_Date__c,
                breg_Address__c,
                breg_Address_Street_2__c,
                breg_Type__c,
                breg_Role__c,
                breg_Entity__c,
                breg_Start_Date__c,
                breg_Affiliation_Name__c,
                breg_Address__Street__s,
                breg_Address__City__s,
                breg_Address__StateCode__s,
                breg_Address__PostalCode__s,
                breg_Address__CountryCode__s,
                breg_Affiliation_Formula_Street__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c = :accountId AND breg_Role__c IN :roles AND breg_End_Date__c = NULL AND breg_Status__c = 'A'
            ORDER BY breg_Start_Date__c DESC
        ];
    }

    /**
     * Gets the role for the Account Affiliation
     * @param entityType The entity type to get the role for
     * @return The role for the Account Affiliation
     */
    private static List<String> getAccountAffiliationRole(String entityType) {
        List<String> roles = new List<String>();
        //DC, DNP, SBC, FC-1
        if (
            entityType == D1_ENTITY_TYPE ||
            entityType == D2_ENTITY_TYPE ||
            entityType == S1_ENTITY_TYPE ||
            entityType == F1_ENTITY_TYPE ||
            entityType == F2_ENTITY_TYPE
        ) {
            //Officers
            roles.add('Officer');
            // roles.add('Director');
            roles.add('Officer/Director');
            roles.add('Director');
        }
        // GP, LLP, LLLP, LP
        else if (
            entityType == G5_ENTITY_TYPE ||
            entityType == G6_ENTITY_TYPE ||
            entityType == K5_ENTITY_TYPE ||
            entityType == K6_ENTITY_TYPE ||
            entityType == L5_ENTITY_TYPE ||
            entityType == Q5_ENTITY_TYPE ||
            entityType == Q6_ENTITY_TYPE
        ) {
            //Partners
            roles.add('General Partner');
            roles.add('Partner');
        }
        // LLC, FLLC
        else if (entityType == C5_ENTITY_TYPE || entityType == C6_ENTITY_TYPE) {
            //Managers/Members
            roles.add('Member');
            roles.add('Manager');
        }

        return roles;
    }

    /**
     * Retrieves Stock data for the given Account Id
     * @param accountId The Account Id to query
     * @return List of breg_Stock__c records
     */
    private static List<breg_Stock__c> getStockData(Id accountId) {
        return [
            SELECT
                Id,
                CreatedDate,
                breg_Class_Detail__c,
                breg_Number_of_Issued_Shares__c,
                breg_Start_Date__c,
                breg_Paid_Shares__c,
                breg_Per_Value__c,
                breg_Stock_Amount__c
            FROM breg_Stock__c
            WHERE breg_Account__c = :accountId AND breg_End_Date__c = NULL AND breg_Start_Date__c != NULL
            ORDER BY breg_Start_Date__c DESC
        ];
    }

    /**
     * Retrieves TN/TM/SM data related to the given Account Id
     * @param accountId The Account Id to query
     * @return List of breg_TN_TM_SM__c records
     */
    private static List<breg_TN_TM_SM__c> getTnTmSmDataForAccount(Id accountId) {
        return [
            SELECT
                Id,
                Name,
                breg_Trade_Name__c,
                breg_Type__c,
                breg_TM_SM_Category__c,
                breg_Cert_Number__c,
                breg_Status__c,
                breg_Registration_Date__c,
                breg_Expiration_Date__c
            FROM breg_TN_TM_SM__c
            WHERE
                breg_Account__c = :accountId
                AND breg_Type__c != :PUBLICITY_RIGHTS_NAME_TYPE
                AND breg_End_Date__c = NULL
                AND Id IN (
                    SELECT breg_TN_TM_SM__c
                    FROM breg_Transaction__c
                    WHERE breg_TN_TM_SM__c != NULL
                    AND breg_Status__c = 'C' // Only include TN/TM/SM with completed transactions
                )
            ORDER BY Name ASC
        ];
    }

    /**
     * Retrieves Annual Filings data for the given Account Id
     * @param accountId The Account Id to query
     * @return List of breg_Annual__c records
     */
    private static List<breg_Annual__c> getAnnualFilingData(Id accountId) {
        List<breg_Annual__c> annuals = [
            SELECT Id, breg_Filing_Year__c, breg_Received_Date__c, breg_Status__c, breg_Account__r.breg_Good_Standing__c
            FROM breg_Annual__c
            WHERE breg_Account__c = :accountId
            ORDER BY breg_Filing_Year__c DESC
        ];

        setAnnualStatus(annuals);

        return annuals;
    }

    private static void setAnnualStatus(List<breg_Annual__c> annuals) {
        Map<String, String> statusLabels = BREGUtils.getPicklistLabelMap('breg_Annual__c', 'breg_Status__c');
        for (breg_Annual__c annual : annuals) {
            if (String.isNotBlank(annual.breg_Status__c)) {
                annual.breg_Status__c = statusLabels.get(annual.breg_Status__c);
            }
        }
    }

    /**
     * Retrieves Other Filings (Transactions) for the given Account Id
     * @param accountId The Account Id to query
     * @return List of Transaction records
     */
    private static List<breg_Transaction__c> getOtherFilingData(Id accountId) {
        // Get all transactions related to the account
        List<breg_Transaction__c> transactions = [
            SELECT
                Id,
                breg_Date__c,
                breg_Effective_Date__c,
                breg_Description__c,
                breg_Remarks__c,
                breg_Account__c,
                breg_TN_TM_SM__c,
                breg_Case__r.breg_Form_Code__c,
                breg_Case__r.breg_Portal_User_Entity_Selected__c,
                breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE (breg_Account__c = :accountId OR (breg_Case__r.breg_Portal_User_Entity_Selected__c = :accountId AND breg_Account__c = NULL))
                AND breg_Case__c != NULL
                AND breg_Status__c = :COMPLETED_TRANSACTION_STATUS_VALUE
            ORDER BY breg_Effective_Date__c DESC
        ];

        // Filter out annual and TNTMSM transactions
        List<breg_Transaction__c> transactionsToReturn = new List<breg_Transaction__c>();
        for (breg_Transaction__c trans : transactions) {
            if (BREGUtils.isAnnualForm(trans.breg_Case__r?.breg_Form_Code__c) || BREGUtils.isTNTMSMForm(trans.breg_Case__r?.breg_Form_Code__c)) {
                continue;
            }
            transactionsToReturn.add(trans);
        }

        setTransactionDescription(transactionsToReturn);

        return transactionsToReturn;
    }

    /**
     * Retrieves Other Filings (Transactions) for the given TN/TM/SM Id
     * @param tnTmSmId The TN/TM/SM Id to query
     * @return List of Transaction records
     */
    private static List<breg_Transaction__c> getOtherFilingDataForTnTmSm(Id tnTmSmId) {
        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Date__c, breg_Effective_Date__c, breg_Description__c, breg_Remarks__c, breg_Transaction_Code__c
            FROM breg_Transaction__c
            WHERE breg_TN_TM_SM__c = :tnTmSmId
                AND breg_Status__c = :COMPLETED_TRANSACTION_STATUS_VALUE
            ORDER BY breg_Effective_Date__c DESC
        ];

        setTransactionDescription(transactions);

        return transactions;
    }

    private static void setTransactionDescription(List<breg_Transaction__c> transactions) {
        for (breg_Transaction__c trans : transactions) {
            if (String.isNotBlank(trans.breg_Transaction_Code__c)) {
                String transactionCodeLabel = BREGTransactionUtils.getTransactionCodeLabel(trans.breg_Transaction_Code__c);
                trans.breg_Description__c = transactionCodeLabel;
            } else {
                trans.breg_Description__c = '';
            }
            if (trans.breg_Remarks__c == null) {
                trans.breg_Remarks__c = trans.breg_Description__c;
            }
        }
    }

    private static List<BuyAvailableDocumentWrapper> getBuyAvailableDocWrappers(Account accountRecord) {
        String entityType = resolveAccountEntityType(accountRecord);
        Boolean isInGoodStanding = accountRecord?.breg_Good_Standing__c == true;
        Map<Id, breg_Transaction__c> transactionMap = getTransactionMap(accountRecord.Id);
        Map<Id, breg_Document__c> transactionIdToDocumentMap = getTransactionIdToDocumentMap(transactionMap.values());
        Map<Id, Map<String, breg_Fee__c>> transactionIdToFeeMap = getTransactionIdToFeeMap(transactionMap.values(), entityType);
        List<BuyAvailableDocumentWrapper> buyAvailableDocWrappers = constructBuyAvailableDocWrappers(
            transactionIdToDocumentMap,
            transactionMap,
            transactionIdToFeeMap,
            isInGoodStanding,
            entityType,
            accountRecord.breg_Entity_Status__c
        );
        return buyAvailableDocWrappers;
    }

    private static List<BuyAvailableDocumentWrapper> constructBuyAvailableDocWrappers(
        Map<Id, breg_Document__c> transactionIdToDocumentMap,
        Map<Id, breg_Transaction__c> transactionMap,
        Map<Id, Map<String, breg_Fee__c>> transactionIdToFeeMap,
        Boolean isInGoodStanding,
        String entityType,
        String entityStatus
    ) {
        Integer adhocRequestTimeoutMinutes = getRDPMSAdhocRequestTimeoutMinutes();
        List<BuyAvailableDocumentWrapper> buyAvailableDocWrappers = new List<BuyAvailableDocumentWrapper>();
        List<Id> caseIds = new List<Id>();
        List<Id> caseIdsToRdpmsRequest = new List<Id>();
        // Map<Id, breg_Fee__c> caseIdToFeeMap = getCaseIdToFeeMap(transactionMap.values());

        // Derive termination date from transactions with termination codes:
        // ADMT (Administrative Termination), RVKD (Involuntary Revoked),
        // INCN (Involuntary Cancellation), INDS (Involuntary Dissolution)
        Set<String> terminationCodes = new Set<String>{ 'ADMT', 'RVKD', 'INCN', 'INDS' };
        Date terminationDate = null;
        for (breg_Transaction__c t : transactionMap.values()) {
            if (terminationCodes.contains(t.breg_Transaction_Code__c) && t.breg_Effective_Date__c != null) {
                if (terminationDate == null || t.breg_Effective_Date__c > terminationDate) {
                    terminationDate = t.breg_Effective_Date__c;
                }
            }
        }

        for (Id transactionId : transactionMap.keySet()) {
            caseIds.add(transactionMap.get(transactionId).breg_Case__c);
        }

        Map<Id, breg_RDPMS_Adhoc_Request__c> caseIdToAdhocRequestByCaseMap = getRDPMSAdhocByCaseMap(caseIds);
        if (isInGoodStanding) {
            Map<String, breg_Fee__c> certFeeEntityTypeToFeeMap = getCertFeesByEntityType();
            List<breg_Document__c> cogsDocuments = [
                SELECT Id, Name, breg_Type__c, breg_Price__c, breg_Availability__c, breg_Available_To_Certify__c
                FROM breg_Document__c
                WHERE breg_Is_Certificate_Of_Good_Standing__c = TRUE AND breg_Template_Document__c = NULL
                LIMIT 2
            ];

            for (breg_Document__c cogsDocument : cogsDocuments) {
                BuyAvailableDocumentWrapper cogsWrapper = new BuyAvailableDocumentWrapper();
                cogsWrapper.id = cogsDocument.Id;
                cogsWrapper.documentId = cogsDocument.Id;
                cogsWrapper.type = cogsDocument.breg_Type__c;
                cogsWrapper.feeId = certFeeEntityTypeToFeeMap != null ? certFeeEntityTypeToFeeMap.get(entityType)?.Id : null;
                cogsWrapper.bregTransactionId = null;
                cogsWrapper.effectiveDate = Date.today();
                cogsWrapper.documentAndTradeName = 'Certificate of Good Standing (COGS)';
                cogsWrapper.availability = cogsWrapper.type == 'Printed' ? 'Available by Mail or Pickup' : 'Available Now';
                Decimal purchasePrice = cogsDocument?.breg_Price__c != null
                    ? cogsDocument.breg_Price__c
                    : certFeeEntityTypeToFeeMap != null ? certFeeEntityTypeToFeeMap.get(entityType)?.breg_Fee_Amount__c : 5.0;
                cogsWrapper.purchasePrice = purchasePrice;
                cogsWrapper.isAvailableToCertify = false;
                buyAvailableDocWrappers.add(cogsWrapper);
            }
        }

        for (Id transactionId : transactionMap.keySet()) {
            breg_Document__c doc = transactionIdToDocumentMap.get(transactionId);
            breg_Transaction__c trans = transactionMap.get(transactionId);
            breg_RDPMS_Adhoc_Request__c rdpmsAdhocRequest = caseIdToAdhocRequestByCaseMap.get(trans.breg_Case__c);
            Map<String, breg_Fee__c> feeTypeToFeeMap = transactionIdToFeeMap.get(transactionId);
            BuyAvailableDocumentWrapper wrapper = new BuyAvailableDocumentWrapper();
            wrapper.id = doc != null ? doc.Id : trans.Id;
            wrapper.documentId = doc?.Id;
            wrapper.type = doc != null ? doc.breg_Type__c : 'Digital';
            wrapper.feeId = feeTypeToFeeMap != null ? feeTypeToFeeMap.get('Document')?.Id : null;
            wrapper.bregTransactionId = trans?.Id;
            if (trans.breg_Transaction_Code__c != null && trans.breg_Transaction_Code__c.equalsIgnoreCase('ANN')) {
                wrapper.documentAndTradeName = 'Annual Filing for ' + trans.breg_Effective_Date__c?.year();
            } else if (trans.breg_Transaction_Code__c != null) {
                String transactionCodeLabel = BREGUtils.getPicklistLabel(
                    'breg_Transaction__c',
                    'breg_Transaction_Code__c',
                    trans.breg_Transaction_Code__c
                );
                wrapper.documentAndTradeName = transactionCodeLabel;
                if (String.isNotBlank(trans.breg_BRIM_New_Name__c)) {
                    wrapper.documentAndTradeName += '\n' + trans.breg_BRIM_New_Name__c;
                    if (trans.breg_Trade_Type__c != null) {
                        String tradeTypeLabel = BREGUtils.getPicklistLabel('breg_Transaction__c', 'breg_Trade_Type__c', trans.breg_Trade_Type__c);
                        wrapper.documentAndTradeName += ' (' + tradeTypeLabel + ')';
                    }
                }
            } else {
                wrapper.documentAndTradeName = 'Unknown Transaction Code';
            }
            wrapper.effectiveDate = trans?.breg_Effective_Date__c;
            wrapper.availability = getDocumentAvailability(
                doc,
                trans,
                rdpmsAdhocRequest,
                adhocRequestTimeoutMinutes,
                entityType,
                entityStatus,
                terminationDate
            );
            Decimal purchasePrice = doc?.breg_Price__c != null
                ? doc.breg_Price__c
                : feeTypeToFeeMap != null ? feeTypeToFeeMap.get('Document')?.breg_Fee_Amount__c : 3.0;
            wrapper.purchasePrice = purchasePrice;
            wrapper.isAvailableToCertify = feeTypeToFeeMap != null ? feeTypeToFeeMap.get('Document')?.breg_Is_Able_to_Certify_Online__c == true : false;
            wrapper.certifyPrice = feeTypeToFeeMap != null ? feeTypeToFeeMap.get('Certify')?.breg_Fee_Amount__c : 10.0;
            wrapper.certifyFeeId = feeTypeToFeeMap != null ? feeTypeToFeeMap.get('Certify')?.Id : null;
            buyAvailableDocWrappers.add(wrapper);
        }

        return buyAvailableDocWrappers;
    }

    private static String getDocumentAvailability(
        breg_Document__c doc,
        breg_Transaction__c trans,
        breg_RDPMS_Adhoc_Request__c rdpmsAdhocRequest,
        Integer adhocRequestTimeoutMinutes,
        String entityType,
        String entityStatus,
        Date terminationDate
    ) {
        // Condition 1: Hawaii corporations dissolved or involuntary dissolved before 1994
        // Entity type: D1, D2, D9, P1, A2 | Status: D, I | Termination date before 1994
        if (
            new Set<String>{ 'D1', 'D2', 'D9', 'P1', 'A2' }.contains(entityType) &&
            entityStatus == 'Inv. Dissolved (7)' &&
            terminationDate != null &&
            terminationDate.year() < 1994
        ) {
            return 'Not Available';
        }

        // Condition 2: GP registration, change of name and dissolution statements dated before 1993
        // Transaction code: PRS, FPRS, PNC, PDS, NC | Entity type: G5, G6 | Document date before 1993
        if (
            new Set<String>{ 'PRS', 'FPRS', 'PNC', 'PDS', 'NC' }.contains(trans.breg_Transaction_Code__c) &&
            new Set<String>{ 'G5', 'G6' }.contains(entityType) &&
            trans.breg_Effective_Date__c != null &&
            trans.breg_Effective_Date__c.year() < 1993
        ) {
            return 'Not Available';
        }

        // Condition 3: LP expired, cancelled or involuntary cancelled before 1994
        // Entity type: L5, L6 | Status: E, C, X | Termination date before 1994
        if (
            new Set<String>{ 'L5', 'L6' }.contains(entityType) &&
            entityStatus == 'Inv. Cancelled (X)' &&
            terminationDate != null &&
            terminationDate.year() < 1994
        ) {
            return 'Not Available';
        }

        // Condition 4: Trade mark/name docs with certificate number < 94001 are already
        // excluded by the SOQL filter in getTransactionMap and will not appear here.

        // Condition 5: Foreign corporations withdrawn, cancelled or involuntary cancelled over 10 years ago
        // Entity type: F1, F2 | Status: W, C, X | Termination date more than 10 years ago
        if (
            new Set<String>{ 'F1', 'F2' }.contains(entityType) &&
            entityStatus == 'Inv. Revoked (R)' &&
            terminationDate != null &&
            terminationDate < Date.today().addYears(-10)
        ) {
            return 'Not Available';
        }

        // Condition 6: Annual reports dated before 2001
        if ('ANN'.equalsIgnoreCase(trans.breg_Transaction_Code__c) && trans.breg_Effective_Date__c != null && trans.breg_Effective_Date__c.year() < 2001) {
            return 'Not Available';
        }

        // Condition 7: Address protection (Act 187 name/address combinations)
        // TODO: Implement when ADDRESS_PROTECTION object structure is confirmed

        // Document not yet retrieved from BRIMS
        if (doc == null) {
            if (String.isNotBlank(trans.breg_Case__r?.breg_ESWM_WFWORKITEM_ID__c)) {
                if (
                    rdpmsAdhocRequest != null &&
                    rdpmsAdhocRequest.breg_Status__c != 'Completed' &&
                    rdpmsAdhocRequest.createdDate < DateTime.now().addMinutes(-adhocRequestTimeoutMinutes)
                ) {
                    return System.Label.BREG_Archive_Search_Unsuccessful;
                }
                return System.Label.BREG_Archive_Search_Started;
            }
            return 'Not Available';
        }

        return 'Available Now';
    }

    private static Integer getRDPMSAdhocRequestTimeoutMinutes() {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        if (setting?.RDPMS_Adhoc_Request_Timeout_Minutes__c != null && setting.RDPMS_Adhoc_Request_Timeout_Minutes__c > 0) {
            return Integer.valueOf(setting.RDPMS_Adhoc_Request_Timeout_Minutes__c);
        }
        return DEFAULT_RDPMS_ADHOC_REQUEST_TIMEOUT_MINUTES;
    }

    private static Map<Id, breg_Transaction__c> getTransactionMap(Id accountOrTnTmSmId) {
        Date clsfExcludeDate = Date.newInstance(2003, 7, 1);

        List<breg_Transaction__c> transactions = [
            SELECT
                Id,
                breg_Date__c,
                breg_Effective_Date__c,
                breg_Description__c,
                breg_Remarks__c,
                breg_Account__c,
                breg_TN_TM_SM__c,
                breg_Case__c,
                breg_Case__r.breg_Form_Code__c,
                breg_Case__r.breg_ESWM_WFWORKITEM_ID__c,
                breg_Transaction_Code__c,
                breg_BRIM_New_Name__c,
                breg_Trade_Type__c,
                breg_BRIM_IMAGE_AAILABLE_DT__c,
                breg_Case__r.breg_Form_Configuration__r.breg_Form_Code__c
            FROM breg_Transaction__c
            WHERE
                (breg_Account__c = :accountOrTnTmSmId
                OR breg_TN_TM_SM__c = :accountOrTnTmSmId)
                AND breg_Status__c = 'C'
                AND (breg_Certificate__c = NULL
                OR breg_Certificate__r.breg_Current_Certificate_Number__c > 94000)
                AND (breg_Transaction_Code__c IN :ConstantsHelper.VALID_TRANSACTION_CODES
                OR (breg_Transaction_Code__c = 'TNTR'
                AND breg_Case__r.breg_Form_Code__c IN ('T-3', 'T-4'))
                OR (breg_Transaction_Code__c = 'CLSF'
                AND (breg_Case__r.breg_ESWM_WFWORKITEM_ID__c = 'B0521201010002'
                OR breg_Effective_Date__c != :clsfExcludeDate))
                OR breg_Transaction_Code__c = 'MGBY')
            ORDER BY breg_Effective_Date__c DESC
        ];

        // MGBY transactions require remarks to contain '-ZZ'; breg_Remarks__c is a TextArea
        // and cannot be filtered in SOQL, so the check is applied here after the query
        List<breg_Transaction__c> filteredTransactions = new List<breg_Transaction__c>();
        for (breg_Transaction__c trans : transactions) {
            if (trans.breg_Transaction_Code__c == 'MGBY' && (trans.breg_Remarks__c == null || !trans.breg_Remarks__c.contains('-ZZ'))) {
                continue;
            }
            filteredTransactions.add(trans);
        }

        return new Map<Id, breg_Transaction__c>(filteredTransactions);
    }

    private static Map<Id, breg_RDPMS_Adhoc_Request__c> getRDPMSAdhocByCaseMap(List<Id> caseIds) {
        List<breg_RDPMS_Adhoc_Request__c> rdpmsAdhocRequests = [
            SELECT Id, breg_Case__c, CreatedDate, breg_Status__c
            FROM breg_RDPMS_Adhoc_Request__c
            WHERE breg_Case__c IN :caseIds
            ORDER BY CreatedDate DESC
        ];

        Map<Id, breg_RDPMS_Adhoc_Request__c> caseIdToRdpmsAdhocMap = new Map<Id, breg_RDPMS_Adhoc_Request__c>();
        for (breg_RDPMS_Adhoc_Request__c request : rdpmsAdhocRequests) {
            if (!caseIdToRdpmsAdhocMap.containsKey(request.breg_Case__c)) {
                caseIdToRdpmsAdhocMap.put(request.breg_Case__c, request);
            }
        }

        return caseIdToRdpmsAdhocMap;
    }

    private static Map<Id, breg_Document__c> getTransactionIdToDocumentMap(List<breg_Transaction__c> transactions) {
        Map<Id, breg_Document__c> transactionIdToDocumentMap = new Map<Id, breg_Document__c>();

        // Get case ID to transaction map, and transaction IDs
        Map<Id, breg_Transaction__c> caseIdToTransactionMap = new Map<Id, breg_Transaction__c>();
        Set<Id> transactionIds = new Set<Id>();
        for (breg_Transaction__c trans : transactions) {
            if (trans.breg_Case__c != null) {
                caseIdToTransactionMap.put(trans.breg_Case__c, trans);
            }
            transactionIds.add(trans.Id);
        }

        // form a map of transaction ID to public document
        List<breg_Document__c> publicDocuments = getPublicDocuments(caseIdToTransactionMap.keyset(), transactionIds);
        for (breg_Document__c doc : publicDocuments) {
            if (doc.breg_Case__c != null) {
                breg_Transaction__c trans = caseIdToTransactionMap.get(doc.breg_Case__c);
                if (trans != null) {
                    transactionIdToDocumentMap.put(trans.Id, doc);
                }
            } else if (doc.breg_Transaction__c != null) {
                transactionIdToDocumentMap.put(doc.breg_Transaction__c, doc);
            }
        }

        // add null documents for transactions that are not in the public documents map
        for (breg_Transaction__c trans : transactions) {
            if (!transactionIdToDocumentMap.containsKey(trans.Id)) {
                transactionIdToDocumentMap.put(trans.Id, null);
            }
        }

        return transactionIdToDocumentMap;
    }

    private static List<breg_Document__c> getPublicDocuments(Set<Id> caseRecordIds, Set<Id> transactionIds) {
        return [
            SELECT Id, Name, breg_Case__c, breg_Transaction__c, breg_Type__c, breg_Price__c
            FROM breg_Document__c
            WHERE (breg_Case__c IN :caseRecordIds OR breg_Transaction__c IN :transactionIds) AND breg_Is_Public__c = TRUE
        ];
    }

    private static List<BuyAvailableDocumentWrapper> getBuyAvailableDocWrappers(breg_TN_TM_SM__c tnTmSmRecord) {
        Map<Id, breg_Transaction__c> transactionMap = getTransactionMap(tnTmSmRecord.Id);
        Map<Id, breg_Document__c> transactionIdToDocumentMap = getTransactionIdToDocumentMap(transactionMap.values());
        Map<Id, Map<String, breg_Fee__c>> transactionIdToFeeMap = getTransactionIdToFeeMap(transactionMap.values(), null);
        List<BuyAvailableDocumentWrapper> buyAvailableDocWrappers = constructBuyAvailableDocWrappers(
            transactionIdToDocumentMap,
            transactionMap,
            transactionIdToFeeMap,
            false,
            null,
            null
        );
        return buyAvailableDocWrappers;
    }

    private static Map<String, breg_Fee__c> getCertFeesByEntityType() {
        List<breg_Fee__c> certFees = BREGGetFeeForService.getFeesComplexFilter(
            new List<String>{
                'breg_Purchase_Type_Fee_type__c',
                'breg_Entity_Type__c',
                'breg_Fee_Amount__c',
                'breg_Form_Code__c',
                'breg_Registration_Type__c',
                'breg_Is_Able_to_Certify_Online__c',
                'Id'
            },
            new List<Map<String, Object>>{ new Map<String, Object>{ 'breg_Purchase_Type_Fee_type__c' => 'Certificate' } },
            null,
            ''
        );

        Map<String, breg_Fee__c> certFeeMap = new Map<String, breg_Fee__c>();
        for (breg_Fee__c fee : certFees) {
            certFeeMap.put(fee.breg_Entity_Type__c, fee);
        }
        return certFeeMap;
    }

    private static Map<Id, Map<String, breg_Fee__c>> getTransactionIdToFeeMap(List<breg_Transaction__c> transactions, String entityType) {
        Map<Id, Map<String, breg_Fee__c>> transactionIdToFeeMap = new Map<Id, Map<String, breg_Fee__c>>();
        Set<String> formCodes = new Set<String>();
        Map<Id, String> transactionIdToFormCodeMap = new Map<Id, String>();
        for (breg_Transaction__c trans : transactions) {
            String formCode = trans.breg_Case__r?.breg_Form_Configuration__r?.breg_Form_Code__c;
            if (formCode != null) {
                formCodes.add(formCode);
                transactionIdToFormCodeMap.put(trans.Id, formCode);
            }
        }

        // Get all feed for trancastion forms
        List<breg_Fee__c> fees = BREGGetFeeForService.getFeesComplexFilter(
            new List<String>{
                'breg_Purchase_Type_Fee_type__c',
                'breg_Fee_Amount__c',
                'breg_Form_Code__c',
                'breg_Entity_Type__c',
                'breg_Registration_Type__c',
                'breg_Is_Able_to_Certify_Online__c',
                'Id'
            },
            new List<Map<String, Object>>{
                new Map<String, Object>{ 'breg_Form_Code__c' => String.join(formCodes, ',') },
                new Map<String, Object>{ 'breg_Purchase_Type_Fee_type__c' => 'Document' },
                new Map<String, Object>{ 'breg_Purchase_Type_Fee_type__c' => 'Certify' }
            },
            null,
            '1 AND (2 OR 3)'
        );

        // Group fees by form code
        Map<String, List<breg_Fee__c>> formCodeToFeesMap = new Map<String, List<breg_Fee__c>>();
        for (breg_Fee__c fee : fees) {
            String formCode = fee.breg_Form_Code__c;
            if (!formCodeToFeesMap.containsKey(formCode)) {
                formCodeToFeesMap.put(formCode, new List<breg_Fee__c>());
            }
            formCodeToFeesMap.get(formCode).add(fee);
        }

        // Map transaction ID to fee based on form code
        for (Id transactionId : transactionIdToFormCodeMap.keySet()) {
            String formCode = transactionIdToFormCodeMap.get(transactionId);
            List<breg_Fee__c> feesForForm = formCodeToFeesMap.get(formCode);
            if (feesForForm != null && !feesForForm.isEmpty()) {
                Map<String, breg_Fee__c> feeTypeToFeeMap = new Map<String, breg_Fee__c>();
                for (String purchaseType : new List<String>{ 'Document', 'Certify' }) {
                    breg_Fee__c matchingFee = getBestFeeForEntityType(feesForForm, purchaseType, entityType);
                    if (matchingFee != null) {
                        feeTypeToFeeMap.put(purchaseType, matchingFee);
                    }
                }
                if (!feeTypeToFeeMap.isEmpty()) {
                    transactionIdToFeeMap.put(transactionId, feeTypeToFeeMap);
                }
            }
        }

        return transactionIdToFeeMap;
    }

    private static breg_Fee__c getBestFeeForEntityType(List<breg_Fee__c> fees, String purchaseType, String entityType) {
        breg_Fee__c blankEntityTypeFee;
        breg_Fee__c firstMatchingPurchaseTypeFee;
        for (breg_Fee__c fee : fees) {
            if (fee.breg_Purchase_Type_Fee_type__c != purchaseType) {
                continue;
            }

            if (firstMatchingPurchaseTypeFee == null) {
                firstMatchingPurchaseTypeFee = fee;
            }

            if (String.isBlank(fee.breg_Entity_Type__c)) {
                blankEntityTypeFee = fee;
            }

            if (String.isNotBlank(entityType) && fee.breg_Entity_Type__c == entityType) {
                return fee;
            }
        }

        return blankEntityTypeFee != null ? blankEntityTypeFee : firstMatchingPurchaseTypeFee;
    }

    private static String resolveAccountEntityType(Account accountRecord) {
        String entityType = getValidAccountEntityType(accountRecord?.breg_Entity_Type__c);
        if (entityType != null) {
            return entityType;
        }

        return getValidAccountEntityType(accountRecord?.breg_Reserved_for_Entity_Type__c);
    }

    private static String getValidAccountEntityType(String entityType) {
        if (String.isBlank(entityType)) {
            return null;
        }

        String normalizedEntityType = entityType.trim();
        if (String.isBlank(normalizedEntityType)) {
            return null;
        }

        return INVALID_ACCOUNT_ENTITY_TYPES.contains(normalizedEntityType.toLowerCase()) ? null : normalizedEntityType;
    }

    private static String getGoodStandingMessage(Account accountRecord) {
        if (accountRecord == null || accountRecord.breg_Good_Standing__c != false) {
            return null;
        }

        String status = accountRecord.breg_Entity_Status__c;

        if (!STATUSES_WITH_CUSTOM_GOOD_STANDING_MESSAGE.contains(status)) {
            return ACCOUNT_DETAILS_NOT_IN_GOOD_STANDING_ERROR_MESSAGE;
        }

        String statusLabel = BREGUtils.getPicklistLabel(ACCOUNT_SOBJECT_TYPE, 'breg_Entity_Status__c', status);
        if (String.isBlank(statusLabel)) {
            return ACCOUNT_DETAILS_NOT_IN_GOOD_STANDING_ERROR_MESSAGE;
        }

        Integer parenIndex = statusLabel.indexOf('(');
        String cleanStatus = parenIndex > -1 ? statusLabel.substring(0, parenIndex).trim() : statusLabel.trim();

        return 'Entity ' + cleanStatus + '.';
    }

    /**
     * Updates document prices based on Fee records by matching suffix codes
     * @param documents List of document records to update
     */
    // private static void updateDocumentPrices(List<breg_Document__c> documents) {
    //     if (documents == null || documents.isEmpty()) {
    //         return;
    //     }

    //     // Collect all suffix codes from documents that have Case -> Form Configuration relationships
    //     Set<String> suffixCodes = new Set<String>();
    //     for (breg_Document__c doc : documents) {
    //         if (doc.breg_Case__r?.breg_Form_Configuration__r?.breg_Suffix_Code__c != null) {
    //             suffixCodes.add(doc.breg_Case__r.breg_Form_Configuration__r.breg_Suffix_Code__c);
    //         }
    //     }

    //     if (suffixCodes.isEmpty()) {
    //         return;
    //     }

    //     // Query Fee records that match the suffix codes through Form Configuration
    //     Map<String, Decimal> suffixToDocumentFeeMap = new Map<String, Decimal>();
    //     Map<String, Decimal> suffixToCertificateFeeMap = new Map<String, Decimal>();
    //     List<breg_Fee__c> fees = getFees(suffixCodes);

    //     // Build separate mappings for Document and Certificate fees
    //     for (breg_Fee__c fee : fees) {
    //         String suffixCode = fee.breg_Form_Configuration__r.breg_Suffix_Code__c;
    //         if (fee.breg_Purchase_Type_Fee_type__c == 'Document') {
    //             suffixToDocumentFeeMap.put(suffixCode, fee.breg_Fee_Amount__c);
    //         } else if (fee.breg_Purchase_Type_Fee_type__c == 'Certificate') {
    //             suffixToCertificateFeeMap.put(suffixCode, fee.breg_Fee_Amount__c);
    //         }
    //     }

    //     // Update document prices based on suffix code matching and document type
    //     for (breg_Document__c doc : documents) {
    //         String suffixCode = doc.breg_Case__r?.breg_Form_Configuration__r?.breg_Suffix_Code__c;
    //         if (suffixCode != null) {
    //             if (doc.breg_Is_Certificate_Of_Good_Standing__c && suffixToCertificateFeeMap.containsKey(suffixCode)) {
    //                 // Apply Certificate fee for Certificate of Good Standing documents
    //                 doc.breg_Price__c = suffixToCertificateFeeMap.get(suffixCode);
    //             } else if (!doc.breg_Is_Certificate_Of_Good_Standing__c && suffixToDocumentFeeMap.containsKey(suffixCode)) {
    //                 // Apply Document fee for regular documents
    //                 doc.breg_Price__c = suffixToDocumentFeeMap.get(suffixCode);
    //             }
    //         }
    //     }
    // }

    /**
     * Retrieves Fee records with Document and Certificate type for the given suffix codes
     * @param suffixCodes The suffix codes to query
     * @return List of breg_Fee__c records
     */
    // private static List<breg_Fee__c> getFees(Set<String> suffixCodes) {
    //     List<String> suffixCodesList = new List<String>(suffixCodes);
    //     return BREGGetFeeForService.getFees(
    //         new List<String>{ 'breg_Fee_Amount__c', 'breg_Form_Configuration__r.breg_Suffix_Code__c', 'breg_Purchase_Type_Fee_type__c' },
    //         new Map<String, Object>{
    //             'breg_Form_Configuration__r.breg_Suffix_Code__c' => String.join(suffixCodesList, ','),
    //             'breg_Purchase_Type_Fee_type__c' => 'Document,Certificate',
    //             'breg_Fee_Amount__c' => null
    //         },
    //         null,
    //         '1 AND 2 AND NOT 3'
    //     );
    // }

    // Main wrapper class for all entity details (Account or TN/TM/SM)
    public class BusinessDetailsWrapper {
        @AuraEnabled
        public CompanyInfoWrapper companyInfo { get; set; }
        @AuraEnabled
        public List<BuyAvailableDocumentWrapper> buyAvailableDocsData { get; set; }
        @AuraEnabled
        public List<FormConfigurationWrapper> formConfigurationsData { get; set; }
        @AuraEnabled
        public String objectType { get; set; }
        @AuraEnabled
        public String entityTypeValue { get; set; }
        @AuraEnabled
        public String entityTypeLabel { get; set; }
        @AuraEnabled
        public String entityName { get; set; }
        @AuraEnabled
        public Boolean isInGoodStanding { get; set; }
        @AuraEnabled 
        public String goodStandingMessage { get; set; }

        public BusinessDetailsWrapper() {
            this.companyInfo = new CompanyInfoWrapper();
        }
    }

    public class CompanyInfoWrapper {
        @AuraEnabled
        public List<CompanyInfoFieldWrapper> fields { get; set; }
        @AuraEnabled
        public List<breg_Annual__c> annualFilingData { get; set; }
        @AuraEnabled
        public List<breg_Transaction__c> otherFilingData { get; set; }
        @AuraEnabled
        public List<breg_Account_Affiliation__c> accountAffiliationData { get; set; } // Officers, Partners, Managers/Members
        @AuraEnabled
        public List<breg_Stock__c> stockData { get; set; }
        @AuraEnabled
        public List<breg_TN_TM_SM__c> tnTmSmData { get; set; }

        public CompanyInfoWrapper() {
            this.fields = new List<CompanyInfoFieldWrapper>();
            this.annualFilingData = new List<breg_Annual__c>();
            this.otherFilingData = new List<breg_Transaction__c>();
            this.accountAffiliationData = new List<breg_Account_Affiliation__c>();
            this.stockData = new List<breg_Stock__c>();
            this.tnTmSmData = new List<breg_TN_TM_SM__c>();
        }
    }

    public class CompanyInfoFieldWrapper {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
        @AuraEnabled
        public String helpText { get; set; }
        @AuraEnabled
        public String valueUrl { get; set; }

        public CompanyInfoFieldWrapper(String label, String value, String helpText, String valueUrl) {
            this.label = label;
            this.value = value;
            this.helpText = helpText;
            this.valueUrl = valueUrl;
        }
    }

    public class FormConfigurationWrapper {
        @AuraEnabled
        public String formConfigurationId { get; set; }
        @AuraEnabled
        public String formCode { get; set; }
        @AuraEnabled
        public String heading { get; set; }
        @AuraEnabled
        public String formAvailableMessage { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public Boolean isError { get; set; }
        @AuraEnabled
        public Boolean isRenewal { get; set; }

        public FormConfigurationWrapper(
            breg_Form_Configuration__c formConfig,
            String heading,
            String formAvailableMessage,
            String errorMessage,
            Boolean isError,
            Boolean isRenewal
        ) {
            this.formConfigurationId = formConfig?.Id;
            this.formCode = formConfig?.breg_Form_Code__c;
            this.heading = heading;
            this.formAvailableMessage = formAvailableMessage;
            this.errorMessage = errorMessage;
            this.isError = isError;
            this.isRenewal = isRenewal;
        }
    }

    public class BuyAvailableDocumentWrapper {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public Id documentId { get; set; }
        @AuraEnabled
        public Id feeId { get; set; }
        @AuraEnabled
        public Id certifyFeeId { get; set; }
        @AuraEnabled
        public Id bregTransactionId { get; set; }
        @AuraEnabled
        public Date effectiveDate { get; set; }
        @AuraEnabled
        public String documentAndTradeName { get; set; }
        @AuraEnabled
        public String availability { get; set; }
        @AuraEnabled
        public Decimal purchasePrice { get; set; }
        @AuraEnabled
        public Boolean isAvailableToCertify { get; set; }
        @AuraEnabled
        public Decimal certifyPrice { get; set; }
        @AuraEnabled
        public String type { get; set; }
    }

    @AuraEnabled
    public static String generateCompanyInfoPdf(Id entityId) {
        try {
            if (entityId == null) {
                throw new AuraHandledException('PDF generation failed: Missing entity id.');
            }

            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf(BREGBusinessDetailsPdfHtmlBuilder.build(entityId));
            } else {
                PageReference pdfPage = Page.BREG_CompanyInfoPdf;
                pdfPage.getParameters().put('entityId', String.valueOf(entityId));
                pdfBlob = pdfPage.getContentAsPDF();
            }

            return EncodingUtil.base64Encode(pdfBlob);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'generateCompanyInfoPdf failed: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            throw new AuraHandledException('PDF generation failed: ' + e.getMessage());
        }
    }
}