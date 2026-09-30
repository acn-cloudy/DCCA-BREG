public without sharing class BREGCaseTriggerHandler extends BREGBaseTriggerHandler {
    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String STATUS_RECEIVED = 'Received';
    private static final String STATUS_REJECTED = 'Rejected';
    private static final String STATUS_PROCESSED = 'Processed';
    private static final String STATUS_WITHDRAWN = 'Withdrawn';
    private static final String STATUS_BOUNCED_CHECK = 'Bounced Check';
    private static final String APPROVAL_WORKFLOW = 'BREG Approval Process';
    private static final String REJECTION_WORKFLOW = 'BREG Rejection Process';
    private static final String INITIAL_FILING_WORKFLOW = 'BREG Initial Filing Generation by Form';
    private static final String CHANGE_STATUS_WORKFLOW = 'BREG Send Email by Case Status Change';
    private static final String CREATE_CERTIFICATE_WORKFLOW = 'BREG Create Certificate for Case';
    private static final String CREATE_DOCUMENT_WORKFLOW = 'BREG Create Document for Case';
    private static final String CREATE_PATCH_SHEET_WORKFLOW = 'BREG Create Patch Sheet for Case';
    private static final String CREATE_DOC_FOR_PAYMENT_WORKFLOW = 'BREG Create Document For Payment';
    private static final String BOUNCED_CHECK_TEMPLATE = 'Bounced Check Notice';
    private static final String NAME_RESERVATION_FORMCODE = 'X-1';
    private static final Set<String> FORM_CODES_TO_SKIP_ASSIGNMENT_RULES = new Set<String>{
        'ADD',
        'ADD-MEMBER',
        'ADD-TNTMSM',
        'ODC'
    };
    private static final String TRANSACTION_CODE_VALUE_SEPARATOR = ' - ';
    private static Boolean ReinstCertificateCreated = false;
    private static Boolean InitialFilingCreated = false;
    private static Id refundRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Refund_Request_Case').getRecordTypeId();
    private static Id bregRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
    private static breg_Docusign_Settings__c docusignSettings;

    private Map<Id, Case> queriedCasesMap;
    private List<Case> bregNewList;

    public BREGCaseTriggerHandler(Boolean allowRecursion) {
        super(allowRecursion);
    }

    private Map<Id, Case> getQueriedCasesMap() {
        if (queriedCasesMap == null) {
            Set<Id> allCaseIds = new Set<Id>();
            List<Case> bregNewList = getBregNewList();
            for (Case c : bregNewList) {
                allCaseIds.add(c.Id);
            }
            queriedCasesMap = new Map<Id, Case>(
                [
                    SELECT
                        Id,
                        breg_Form_Configuration__r.breg_Suffix_Code__c,
                        breg_Form_Configuration__r.breg_Business_Process__c,
                        breg_Form_Code__c,
                        breg_Entity__c,
                        breg_Entity__r.breg_File_Suffix__c,
                        breg_Entity__r.breg_File__c,
                        breg_Number_of_Delinquent_Annual_Reports__c,
                        breg_Annual_Report_Filing_Year__c,
                        breg_Refund_Payment__c,
                        breg_Approved_Automatically__c,
                        breg_Effective_Date__c,
                        breg_Expiration_Date__c,
                        breg_Entity_Jurisdiction__c,
                        breg_Formation_State__c,
                        breg_Entity_Type__c,
                        breg_Resubmission_Due_Date__c,
                        breg_TNTMSM_Classification__c,
                        breg_Reg_Agent_Type__c,
                        Status,
                        RecordTypeId,
                        breg_Payment_Type__c,
                        Origin,
                        breg_Form_Configuration__c,
                        breg_Form_Action__c,
                        breg_Name_of_the_Entity_Previous__c,
                        breg_New_Entity_Name__c,
                        breg_Name_of_the_Entity__c,
                        ParentId,
                        breg_File__c,
                        breg_Rejected_By_User__c,
                        breg_TNTMSM_Certificate__c,
                        breg_TN_TM_SM__c,
                        breg_TN_TM_SM__r.breg_Cert_Number__c
                    FROM Case
                    WHERE Id IN :allCaseIds AND (breg_Form_Configuration__c != NULL OR RecordTypeId = :refundRtId)
                ]
            );
        }
        return queriedCasesMap;
    }

    private List<Case> getCasesFromMap(Set<Id> caseIds) {
        Map<Id, Case> allCases = getQueriedCasesMap();
        List<Case> result = new List<Case>();
        for (Id caseId : caseIds) {
            if (allCases.containsKey(caseId)) {
                result.add(allCases.get(caseId));
            }
        }
        return result;
    }

    private List<Case> filterBregCases(List<Case> cases) {
        List<Case> bregCases = new List<Case>();
        for (Case c : cases) {
            if (c.RecordTypeId == refundRtId || c.RecordTypeId == bregRtId) {
                bregCases.add(c);
            }
        }
        return bregCases;
    }

    private List<Case> getBregNewList() {
        if (bregNewList == null) {
            bregNewList = filterBregCases((List<Case>) this.newList);
        }
        return bregNewList;
    }

    public override void beforeUpdate() {
        List<Case> bregNewList = getBregNewList();
        BREGCaseValidator.validateCases(bregNewList);
        
        populateFilingContactDetails(
            bregNewList,
            (Map<Id, Case>) this.oldMap
        );
        
        updateAnnualLookupAfterEntityOrFilingYearWasUpdated();

        updateJurisdictionLabelsAfterJurisdictionWasChanged(bregNewList);
        
        for (Case currentCase : bregNewList) {
            Case oldCase = (Case) this.oldMap.get(currentCase.Id);
            if (oldCase == null) {
                continue;
            }
            if(currentCase.breg_TNTMSM_Description__c != null) {
                if (currentCase.breg_TNTMSM_Description__c != oldCase.breg_TNTMSM_Description__c) {
                    currentCase.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_TNTMSM_Description__c);
                }
            } else if(currentCase.breg_New_Entity_Name__c != null) {
                 if (currentCase.breg_New_Entity_Name__c != oldCase.breg_New_Entity_Name__c) {
                    currentCase.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_New_Entity_Name__c);
                }
            } else if(currentCase.breg_Name_of_the_Entity__c != null) {
                 if (currentCase.breg_Name_of_the_Entity__c != oldCase.breg_Name_of_the_Entity__c) {
                    currentCase.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_Name_of_the_Entity__c);
                }
            }
            if (currentCase.breg_Xref_Name_1__c != oldCase.breg_Xref_Name_1__c) {
                currentCase.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_Xref_Name_1__c);
            }
            if (currentCase.breg_Xref_Name_2__c != oldCase.breg_Xref_Name_2__c) {
                currentCase.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_Xref_Name_2__c);
            }
            if (
                currentCase.breg_Rejection_Reason_Description__c != oldCase.breg_Rejection_Reason_Description__c ||
                currentCase.Origin != oldCase.Origin
            ) {
                currentCase.breg_Need_to_Add_Page_Break__c = shouldAddPageBreakAfterRejectionReason(
                    currentCase.breg_Rejection_Reason_Description__c,
                    currentCase.Origin
                );
            }
        }

        populateTransactionCodeValue(bregNewList, (Map<Id, Case>) this.oldMap);

        // Handle status changes - perform validation only
        handleStatusChange(bregNewList, (Map<Id, Case>) this.oldMap, true, false);

        List<Case> approvedCases = getCasesWithChangedStatus(STATUS_APPROVED, null);

        // BULKIFIED: Pre-query all Annual reports for entities with Annual Report business process
        Map<Id, List<breg_Annual__c>> entityIdToAnnualsMap = getAnnualReportsForApprovedCases(approvedCases);

        for (Case theCase : approvedCases) {
            Case originalCaseRecord = (Case) this.newMap.get(theCase.Id);
            // Check number of delinquents using pre-queried map (BULKIFIED - no SOQL in loop)
            if (theCase.breg_Form_Configuration__r.breg_Business_Process__c == 'Annual Report') {
                List<breg_Annual__c> relatedAnnuals = entityIdToAnnualsMap.get(theCase.breg_Entity__c);
                Integer numberOfDelinquents = checkNumberOfDelinquents(theCase, relatedAnnuals);
                theCase.breg_Number_of_Delinquent_Annual_Reports__c = numberOfDelinquents;
            }
            // Assign file number - use theCase for relationship fields, but set values on originalCaseRecord
            assignFileNumber(theCase, originalCaseRecord);
        }

        List<Case> updatedSubmissionDateCases = getCasesWithChangedFields('breg_Submission_Date__c', null);
        Map<Id, Case> updatedSubmissionDateCasesMap = getCasesWithRelatedFieldsMap(updatedSubmissionDateCases);
        for (Case c : updatedSubmissionDateCasesMap.values()) {
            Case originalCaseRecord = (Case) this.newMap.get(c.Id);
            if (originalCaseRecord.breg_Form_Configuration__r.breg_Business_Process__c != 'Annual Report' && originalCaseRecord.breg_Form_Configuration__r.breg_Days_After_Submission_hold_Approval__c == null) {
                Datetime submissionDateTime = originalCaseRecord.breg_Submission_Date__c;
                if (submissionDateTime != null) {
                    originalCaseRecord.breg_Effective_Date__c = Date.newInstance(submissionDateTime.year(), submissionDateTime.month(), submissionDateTime.day());
                }
            }
        }

        List<Case> updatedEffectiveDateCases = getCasesWithChangedFields('breg_Effective_Date__c', null);
        for (Case c : updatedEffectiveDateCases) {
            Case originalCaseRecord = (Case) this.newMap.get(c.Id);
            if (originalCaseRecord.breg_Form_Code__c == NAME_RESERVATION_FORMCODE) {
                originalCaseRecord.breg_Expiration_Date__c = calculateExpirationDate(originalCaseRecord.breg_Effective_Date__c, 120);
            }
        }
        List<Case> resubmittedCases = getCasesWithChangedStatus(STATUS_RECEIVED, STATUS_REJECTED);
        for (Case c : resubmittedCases) {
            c.breg_Reopened_Date__c = Date.today();
        }

        for (Case currentCase : bregNewList) {
            updateStatusForAmendedCase(currentCase, false);
        }
    }

    private void updateAnnualLookupAfterEntityOrFilingYearWasUpdated(){
        List<Case> casesChosenEntity = getCasesWithChangedFields('breg_Entity__c', null);
        List<Case> casesChangedAnnualReportFilingYear = getCasesWithChangedFields('breg_Annual_Report_Filing_Year__c', null);
        Map<Id, Case> chosenEntityCasesMap = new Map<Id, Case>();
        for (Case theCase : casesChosenEntity) {
            Case originalCaseRecord = (Case) this.newMap.get(theCase.Id);
            chosenEntityCasesMap.put(originalCaseRecord.breg_Entity__c, theCase);
        }
        Map<Id, Account> chosenAccountsMap = new Map<Id, Account>(
            [SELECT Id, breg_File__c, breg_File_Suffix__c FROM Account WHERE Id IN :chosenEntityCasesMap.keyset()]
        );
        for (Case c : chosenEntityCasesMap.values()) {
            Case originalCaseRecord = (Case) this.newMap.get(c.Id);
            Account relatedEntity = chosenAccountsMap.get(originalCaseRecord.breg_Entity__c);
            if (relatedEntity != null) {
                originalCaseRecord.breg_File__c = relatedEntity?.breg_File__c;
                originalCaseRecord.breg_File_Suffix__c = relatedEntity?.breg_File_Suffix__c;
            }
        }
    }

    private void updateJurisdictionLabelsAfterJurisdictionWasChanged(List<Case> bregNewList){
        Boolean hasJurisdictionChanges = false;
        List<SObject> recordsWithJurisdictionOrStateChanges = new List<SObject>();
        for (Case currentCase : bregNewList) {
            Case oldCase = (Case) this.oldMap.get(currentCase.Id);
            if (oldCase == null) {
                continue;
            }
            Boolean jurisdictionChanged =
                currentCase.breg_Entity_Jurisdiction__c != oldCase.breg_Entity_Jurisdiction__c ||
                currentCase.breg_New_Entity_Jurisdiction__c != oldCase.breg_New_Entity_Jurisdiction__c;
            Boolean stateChanged =
                currentCase.breg_Formation_State__c != oldCase.breg_Formation_State__c ||
                currentCase.breg_New_Formation_State__c != oldCase.breg_New_Formation_State__c;
            if (jurisdictionChanged) {
                hasJurisdictionChanges = true;
            }
            if (jurisdictionChanged || stateChanged) {
                recordsWithJurisdictionOrStateChanges.add(currentCase);
            }
        }

        Map<String, String> jurisdictionLabelMap = hasJurisdictionChanges ? BREGUtils.getPicklistLabelMap('Account', 'BillingCountryCode') : null;
        Map<String, String> dependentStateLabelMap = null;
        if (!recordsWithJurisdictionOrStateChanges.isEmpty()) {
            Set<String> jurisdictionCodes = BREGUtils.extractFieldValuesAsSet(recordsWithJurisdictionOrStateChanges, 'breg_Entity_Jurisdiction__c');
            jurisdictionCodes.addAll(BREGUtils.extractFieldValuesAsSet(recordsWithJurisdictionOrStateChanges, 'breg_New_Entity_Jurisdiction__c'));
            dependentStateLabelMap = BREGUtils.getStateLabelMapByCountrySet(jurisdictionCodes);
        }

        BREGUtils.LabelFieldConfig entityJurisdictionConfig = new BREGUtils.LabelFieldConfig(
            'breg_Entity_Jurisdiction__c',
            'breg_Entity_Jurisdiction_Label__c',
            null,
            jurisdictionLabelMap
        );
        BREGUtils.LabelFieldConfig formationStateConfig = new BREGUtils.LabelFieldConfig(
            'breg_Formation_State__c',
            'breg_Formation_State_Label__c',
            'breg_Entity_Jurisdiction__c',
            dependentStateLabelMap
        );
        BREGUtils.LabelFieldConfig newEntityJurisdictionConfig = new BREGUtils.LabelFieldConfig(
            'breg_New_Entity_Jurisdiction__c',
            'breg_New_Entity_Jurisdiction_Label__c',
            null,
            jurisdictionLabelMap
        );
        BREGUtils.LabelFieldConfig newFormationStateConfig = new BREGUtils.LabelFieldConfig(
            'breg_New_Formation_State__c',
            'breg_New_Formation_State_Label__c',
            'breg_New_Entity_Jurisdiction__c',
            dependentStateLabelMap
        );
        for (Case currentCase : bregNewList) {
            Case oldCase = (Case) this.oldMap.get(currentCase.Id);
            if (oldCase == null) {
                continue;
            }
            updateLabelField(oldCase, currentCase, entityJurisdictionConfig);
            updateLabelField(oldCase, currentCase, formationStateConfig);
            updateLabelField(oldCase, currentCase, newEntityJurisdictionConfig);
            updateLabelField(oldCase, currentCase, newFormationStateConfig);
        }
    }

    private void assignFileNumber(Case caseWithRelationships, Case originalCaseRecord) {
        // Use caseWithRelationships for reading relationship fields (has breg_Entity__r, breg_Form_Configuration__r)
        // Set values on originalCaseRecord (trigger context record)
        BREGFileNumberAssignmentController.FileNumberAssignmentResult result = BREGFileNumberAssignmentController.generateFileNumber(
            caseWithRelationships,
            null
        );
        Map<Id,Case> caseWithFieldsMap =getQueriedCasesMap();
        if (originalCaseRecord.breg_File__c == null) {
            originalCaseRecord.breg_File__c = result.fileNumber != null ? result.fileNumber : originalCaseRecord.breg_File__c;
            originalCaseRecord.breg_File_Suffix__c = result.fileSuffix != null ? result.fileSuffix : originalCaseRecord.breg_File_Suffix__c;
            originalCaseRecord.breg_BRIM_FILE_NO__c = result.brimFileNumber != null ? result.brimFileNumber : originalCaseRecord.breg_BRIM_FILE_NO__c;
        }
        if (BREGUtils.isTNTMSMForm(caseWithRelationships.breg_Form_Code__c) && originalCaseRecord.breg_TNTMSM_Certificate__c == null) {
            Case caseWithFields = caseWithFieldsMap.get(originalCaseRecord.Id);
            if (caseWithFields.breg_TN_TM_SM__c != null){
                originalCaseRecord.breg_TNTMSM_Certificate__c = caseWithFields.breg_TN_TM_SM__r.breg_Cert_Number__c;
            } else {
                originalCaseRecord.breg_TNTMSM_Certificate__c = result.tntmsmCertificate != null
                    ? result.tntmsmCertificate
                    : originalCaseRecord.breg_TNTMSM_Certificate__c;
            }
        }
    }

    private void populateFilingContactDetails(
        List<Case> newCases,
        Map<Id, Case> oldCases
    ) {
        Set<Id> contactIds = new Set<Id>();
        List<Case> casesToPopulate = new List<Case>();

        for (Case caseRecord : newCases) {
            Boolean isFirstContactAssignment;

            if (oldCases == null) {
                isFirstContactAssignment = caseRecord.ContactId != null;
            } else {
                Case oldCase = oldCases.get(caseRecord.Id);

                isFirstContactAssignment =
                    oldCase != null &&
                    oldCase.ContactId == null &&
                    caseRecord.ContactId != null;
            }

            if (isFirstContactAssignment) {
                contactIds.add(caseRecord.ContactId);
                casesToPopulate.add(caseRecord);
            }
        }

        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>([
            SELECT Id, Name, Email, Phone, MobilePhone
            FROM Contact
            WHERE Id IN :contactIds
        ]);

        for (Case caseRecord : casesToPopulate) {
            Contact contactRecord = contactsById.get(caseRecord.ContactId);

            if (contactRecord == null) {
                continue;
            }

            caseRecord.breg_Filing_Contact_Name__c =
                contactRecord.Name;
            caseRecord.breg_Filing_Contact_Email__c =
                contactRecord.Email;
            caseRecord.breg_Filing_Contact_Phone__c =
                contactRecord.Phone;
            caseRecord.breg_Filing_Contact_Mobile__c =
                contactRecord.MobilePhone;
        }
    }

    public override void beforeInsert() {
        List<Case> bregNewList = getBregNewList();
        BREGCaseValidator.validateCases(bregNewList);
        populateFilingContactDetails(bregNewList, null);
        Set<Id> newCasesFormsIds = new Set<Id>();
        for (Case newCase : bregNewList) {
            newCasesFormsIds.add(newCase.breg_Form_Configuration__c);
        }

        Map<Id, breg_Form_Configuration__c> formsById = new Map<Id, breg_Form_Configuration__c>(
            [
                SELECT breg_Business_Process__c
                FROM breg_Form_Configuration__c
                WHERE Id IN :newCasesFormsIds
            ]
        );

        // BULKIFIED: Pre-query all Annual reports for cases with Annual Report business process
        List<Case> annualReportCases = new List<Case>();
        for (Case currentCase : bregNewList) {
            if (formsById.get(currentCase.breg_Form_Configuration__c)?.breg_Business_Process__c == 'Annual Report') {
                annualReportCases.add(currentCase);
            }
        }
        Map<Id, List<breg_Annual__c>> entityIdToAnnualsMapForInsert = getAnnualReportsForNewCases(annualReportCases);
        Map<String, String> jurisdictionLabelMap = BREGUtils.getPicklistLabelMap('Account', 'BillingCountryCode');
        Set<String> jurisdictionCodes = BREGUtils.extractFieldValuesAsSet(bregNewList, 'breg_Entity_Jurisdiction__c');
        jurisdictionCodes.addAll(BREGUtils.extractFieldValuesAsSet(bregNewList, 'breg_New_Entity_Jurisdiction__c'));
        Map<String, String> dependentStateLabelMap = BREGUtils.getStateLabelMapByCountrySet(jurisdictionCodes);
        BREGUtils.LabelFieldConfig entityJurisdictionConfig = new BREGUtils.LabelFieldConfig(
            'breg_Entity_Jurisdiction__c',
            'breg_Entity_Jurisdiction_Label__c',
            null,
            jurisdictionLabelMap
        );
        BREGUtils.LabelFieldConfig formationStateConfig = new BREGUtils.LabelFieldConfig(
            'breg_Formation_State__c',
            'breg_Formation_State_Label__c',
            'breg_Entity_Jurisdiction__c',
            dependentStateLabelMap
        );
        BREGUtils.LabelFieldConfig newEntityJurisdictionConfig = new BREGUtils.LabelFieldConfig(
            'breg_New_Entity_Jurisdiction__c',
            'breg_New_Entity_Jurisdiction_Label__c',
            null,
            jurisdictionLabelMap
        );
        BREGUtils.LabelFieldConfig newFormationStateConfig = new BREGUtils.LabelFieldConfig(
            'breg_New_Formation_State__c',
            'breg_New_Formation_State_Label__c',
            'breg_New_Entity_Jurisdiction__c',
            dependentStateLabelMap
        );

        for (Case currentCase : bregNewList) {
            updateLabelField(null, currentCase, entityJurisdictionConfig);
            updateLabelField(null, currentCase, formationStateConfig);
            updateLabelField(null, currentCase, newEntityJurisdictionConfig);
            updateLabelField(null, currentCase, newFormationStateConfig);
            if(currentCase.breg_TNTMSM_Description__c != null) {
                    currentCase.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_TNTMSM_Description__c);
                
            } else if(currentCase.breg_New_Entity_Name__c != null) {
                    currentCase.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_New_Entity_Name__c);
                
            } else if(currentCase.breg_Name_of_the_Entity__c != null) {
                    currentCase.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_Name_of_the_Entity__c);
                
            }
            currentCase.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_Xref_Name_1__c);
            currentCase.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(currentCase.breg_Xref_Name_2__c);
            currentCase.breg_Need_to_Add_Page_Break__c = shouldAddPageBreakAfterRejectionReason(
                currentCase.breg_Rejection_Reason_Description__c,
                currentCase.Origin
            );
            if (formsById.get(currentCase.breg_Form_Configuration__c)?.breg_Business_Process__c == 'Annual Report') {
                List<breg_Annual__c> relatedAnnuals = entityIdToAnnualsMapForInsert.get(currentCase.breg_Entity__c);
                Integer numberOfDelinquents = checkNumberOfDelinquents(currentCase, relatedAnnuals);
                currentCase.breg_Number_of_Delinquent_Annual_Reports__c = numberOfDelinquents;
                updateStatusForAmendedCase(currentCase, true);
            }
            if (currentCase.breg_Form_Code__c == NAME_RESERVATION_FORMCODE) {
                currentCase.breg_Expiration_Date__c = calculateExpirationDate(currentCase.breg_Effective_Date__c, 120);
            }
        }

        populateTransactionCodeValue(bregNewList, null);

        // Handle status for new cases - perform validation only
        handleStatusChange(bregNewList, new Map<Id, Case>(), true, false);
    }

   private Integer getEstimatedLineCount(String value) {

        if (String.isBlank(value)) {
            return 0;

        }

        Integer totalLines = 0;
        for (String paragraph : value.split('\\r\\n|\\n|\\r', -1)) {
            if (paragraph == '') {
                totalLines++;
            } else {
                totalLines += (Integer)Math.ceil((Decimal)paragraph.length() / getCharsPerLine());
            }
        }

        return totalLines;
    }

    private Boolean shouldAddPageBreakAfterRejectionReason(String rejectionReason, String caseOrigin) {
        Integer linesBeforeRejectionReason = getLinesBeforeRejectionReason();
        if (caseOrigin == null || caseOrigin.equalsIgnoreCase('Web')) {
            linesBeforeRejectionReason += getNonWebPageBreakLinesOffset();
        }

        Integer linesAfterRejectionReason = getLinesAfterRejectionReason();
        Integer totalLines = linesBeforeRejectionReason + getEstimatedLineCount(rejectionReason) + linesAfterRejectionReason;
        Integer remainderLastPage = Math.mod(totalLines, getPageLines());

        return remainderLastPage < linesAfterRejectionReason;

    }

    private static breg_Docusign_Settings__c getDocusignSettings() {
        if (docusignSettings == null) {
            docusignSettings = breg_Docusign_Settings__c.getOrgDefaults();
        }
        return docusignSettings;
    }

    private Integer getCharsPerLine() {
        breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings != null && settings.Chars_per_Line__c != null ? settings.Chars_per_Line__c.intValue() : 88;
    }

    private Integer getPageLines() {
        breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings != null && settings.Page_Lines__c != null ? settings.Page_Lines__c.intValue() : 43;
    }

    private Integer getLinesBeforeRejectionReason() {
       breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings != null && settings.Lines_Before_Rejection_Reason__c != null
            ? settings.Lines_Before_Rejection_Reason__c.intValue()
            : 20;
    }

    private Integer getLinesAfterRejectionReason() {
       breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings != null && settings.Lines_After_Rejection_Reason__c != null
            ? settings.Lines_After_Rejection_Reason__c.intValue()
            : 11;
    }

    private Integer getNonWebPageBreakLinesOffset() {
        breg_Docusign_Settings__c settings = getDocusignSettings();
        return settings != null && settings.Non_Web_Page_Break_Lines_Offset__c != null
            ? settings.Non_Web_Page_Break_Lines_Offset__c.intValue()
            : 13;
    }

    public override void afterUpdate() {
        List<Case> bregNewList = getBregNewList();
        BREGCaseValidator.validateCaseRelations(bregNewList);
        updateGPCaseLLPRegistrationFlag(bregNewList);
        Set<Id> casesWithStartedDocumentGeneration = new Set<Id>();
        List<Case> initialDraftGeneratedCases = getCasesWithChangedFields('breg_Document_Generation_Status__c', 'Draft Initial generated');
        List<Case> initialGeneratedCases = getCasesWithChangedFields('breg_Document_Generation_Status__c', 'Initial Filing Generated');
        List<Case> generationCompletedCases = getCasesWithChangedFields('breg_Document_Generation_Status__c', 'Completed');
        List<Case> changedDocumentGenerationStatusCases = new List<Case>();
        changedDocumentGenerationStatusCases.addAll(initialDraftGeneratedCases);
        changedDocumentGenerationStatusCases.addAll(initialGeneratedCases);
        changedDocumentGenerationStatusCases.addAll(generationCompletedCases);
        //BREGUtils.completeOldestInProcessDocumentGenerationLogs(changedDocumentGenerationStatusCases); //replaced to docusign
        Set<Id> initialDraftGeneratedCaseIdToIsPaidSet = getPaidTransactionLineIdsForCases(initialDraftGeneratedCases);
        for (Id caseId : initialDraftGeneratedCaseIdToIsPaidSet) {
            Case theCase = (Case) this.newMap.get(caseId);
            if (
                theCase.breg_Form_Configuration__c != null && 
                theCase.breg_Form_Code__c != 'DOCDLVR' && 
                theCase.Origin != 'In Person'
            ) {
                // Start integration with DocuSign
                startWorkflowAsync(INITIAL_FILING_WORKFLOW, theCase.Id, 'Draft initial was generated');
                casesWithStartedDocumentGeneration.add(theCase.Id);
            }
            
        }
        

        // Handle status changes - perform actions only
        handleStatusChange(bregNewList, (Map<Id, Case>) this.oldMap, false, true);

        List<Case> receivedCases = getCasesWithChangedStatus(STATUS_RECEIVED, null);
        List<Case> resubmittedCases = new List<Case>();
        List<Case> receivedCasesNeedingAssignmentRule = new List<Case>();
        for (Case theCase : receivedCases) {
            if (theCase.breg_Form_Action__c == 'Resubmit') {
                resubmittedCases.add(theCase);
            } else {
                receivedCasesNeedingAssignmentRule.add(theCase);
            }
            //Initial filing and Patch sheet generation were replaced to BREGTransactionLinrTrigerHandler
            /*if (theCase.breg_Form_Configuration__c != null && theCase.breg_Form_Code__c != 'DOCDLVR') {
                if (theCase.Origin != 'In Person') {
                    // Start integration with DocuSign
                    startWorkflowAsync(INITIAL_FILING_WORKFLOW, theCase.Id);
                }
                // Start integration with DocuSign
                //startWorkflowAsync(CREATE_PATCH_SHEET_WORKFLOW, theCase.Id); //replaced to transaction line trigger handler
            }*/
        }
        if (!receivedCasesNeedingAssignmentRule.isEmpty()) {
            assignCasesUsingAssignmentRule(receivedCasesNeedingAssignmentRule);
        }
        returnToPreviousOwner(resubmittedCases);

        createSearchLogsForRejectedToReceived();

        List<Case> approvedCasesNeedingAssignmentRule = getCasesWithChangedStatus(STATUS_APPROVED, null);
        List<Case> nonAnnualApprovedCases = new List<Case>();
        for (Case caseRecord : approvedCasesNeedingAssignmentRule) {
            if (
                !BREGUtils.isAnnualForm(caseRecord.breg_Form_Code__c) &&
                !FORM_CODES_TO_SKIP_ASSIGNMENT_RULES.contains(caseRecord.breg_Form_Code__c)
            ) {
                nonAnnualApprovedCases.add(caseRecord);
            }
        }
        if (!nonAnnualApprovedCases.isEmpty()) {
            assignCasesUsingAssignmentRule(nonAnnualApprovedCases);
        }

        // BREG-4536 - Reinstatement Certificate is only generated if Reinstatement scenario
        // List<Case> approvedCases = getCasesWithChangedStatus(STATUS_APPROVED, null);
        // for (Case theCase : approvedCases) {
        //     Case originalCaseRecord = (Case) this.newMap.get(theCase.Id);
        //     if (theCase.breg_Form_Configuration__c != null && theCase.breg_Form_Code__c != 'DOCDLVR') {
        //         if (
        //             theCase.breg_Number_of_Delinquent_Annual_Reports__c == 1 && !ReinstCertificateCreated && !theCase.breg_Approved_Automatically__c
        //         ) {
        //             // Start integration with DocuSign
        //             startWorkflowAsync(CREATE_CERTIFICATE_WORKFLOW, theCase.Id);
        //             ReinstCertificateCreated = true;
        //         }
        //         // BREG-3746
        //         // if (theCase.Origin != 'In Person' && !InitialFilingCreated && !theCase.breg_Approved_Automatically__c) {
        //         //     // Start integration with DocuSign
        //         //     startWorkflowAsync(INITIAL_FILING_WORKFLOW, theCase.Id);
        //         //     InitialFilingCreated = true;
        //         // }
        //     }
        // }

        List<Case> completedCases = getCasesWithChangedStatus(STATUS_COMPLETED, null);
        for (Case theCase : completedCases) {
            Case originalCaseRecord = (Case) this.newMap.get(theCase.Id);
            if (
                originalCaseRecord.breg_Form_Configuration__c != null && 
                originalCaseRecord.breg_Form_Code__c != 'DOCDLVR' &&
                !originalCaseRecord.breg_Approved_Automatically__c
            ) {
                // Start integration with DocuSign
                startWorkflowAsync(APPROVAL_WORKFLOW, theCase.Id, 'Case was completed');
                casesWithStartedDocumentGeneration.add(theCase.Id);
            }
        }

        List<Case> allowedForCertificateCases = getCasesWithChangedFields('breg_Is_Allowed_Generate_Reinstatem_Cert__c', true);
        for (Case theCase : allowedForCertificateCases) {
            Case originalCaseRecord = (Case) this.newMap.get(theCase.Id);
            if (
                originalCaseRecord.Status == 'Approved' &&
                !ReinstCertificateCreated &&
                originalCaseRecord.breg_Form_Configuration__c != null &&
                (
                    originalCaseRecord.breg_Form_Code__c == 'X-4' || 
                    (
                        originalCaseRecord.breg_Form_Code__c.contains('ANN-') &&
                        originalCaseRecord.breg_Number_of_Delinquent_Annual_Reports__c == 1
                    )
                ) &&
                !originalCaseRecord.breg_Approved_Automatically__c
            ) {
                // Start integration with DocuSign
                startWorkflowAsync(CREATE_CERTIFICATE_WORKFLOW, theCase.Id, 'Allowed Generate Reinstatement Certificate was set to true');
                casesWithStartedDocumentGeneration.add(theCase.Id);
                ReinstCertificateCreated = true;
            }
        }

        List<Case> processedCases = getCasesWithChangedStatus(STATUS_PROCESSED, null);
        for (Case theCase : processedCases) {
            if (theCase.RecordTypeId == refundRtId && (theCase.breg_Payment_Type__c == 'Credit Card' || theCase.breg_Payment_Type__c == 'Check')) {
                // Start integration with DocuSign
                startWorkflowAsync(CREATE_DOCUMENT_WORKFLOW, theCase.Id, 'Case was processed');
                casesWithStartedDocumentGeneration.add(theCase.Id);
            }
        }

        List<Case> bouncedCases = getCasesWithChangedStatus(STATUS_BOUNCED_CHECK, null);
        if (bouncedCases.size() > 0) {
            Set<Id> casesIds = new Set<Id>();

            for (Case theCase : bouncedCases) {
                casesIds.add(theCase.Id);
            }
            Map<Id, Id> paymentIdToCaseId = BREGUtils.getRelatedPayments(casesIds);
            for (Id paymentId : paymentIdToCaseId.keySet()) {
                String params = '<recordId>' + paymentId + '</recordId>';
                params += '<templateName>' + BOUNCED_CHECK_TEMPLATE + '</templateName>';
                Id relatedCaseId = paymentIdToCaseId.get(paymentId);

                startWorkflowWithParams(CREATE_DOC_FOR_PAYMENT_WORKFLOW, relatedCaseId, params, 'Case Status set to Bounced Check');
                casesWithStartedDocumentGeneration.add(relatedCaseId);
            }
        }

        List<Case> rejectedCases = getCasesWithChangedStatus(STATUS_REJECTED, null);
        for (Case rejectedCase : rejectedCases) {
            if (rejectedCase.breg_Form_Configuration__c != null && rejectedCase.breg_Form_Code__c != 'DOCDLVR') {
                // Start integration with DocuSign
                startWorkflowAsync(REJECTION_WORKFLOW, rejectedCase.Id, 'Case was rejected');
                casesWithStartedDocumentGeneration.add(rejectedCase.Id);
            }
        }

        List<Case> withdrawnCases = getCasesWithChangedStatus(STATUS_WITHDRAWN, null);
        for (Case withdrawnCase : withdrawnCases) {
            if (withdrawnCase.breg_Form_Configuration__c != null && withdrawnCase.breg_Form_Code__c != 'DOCDLVR') {
                // Start integration with DocuSign
                startWorkflowAsync(CHANGE_STATUS_WORKFLOW, withdrawnCase.Id, 'Case was withdrawn');
                casesWithStartedDocumentGeneration.add(withdrawnCase.Id);
            }
        }

        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : casesWithStartedDocumentGeneration) {
            casesToUpdate.add(new Case(Id = caseId, breg_Document_Generation_Status__c = 'Generation in Process'));
        }
        update casesToUpdate;

        BREGCaseDefaultOwnerReassignment.enqueueReassignment(bregNewList);

        List<Case> annualRobotCases = getAnnualRobotCases();
        if (!annualRobotCases.isEmpty()) {
            BREGAnnualRobot.processCases(annualRobotCases);
        }
    }

    private void createSearchLogsForRejectedToReceived() {
        List<Case> rejectedToReceivedCases = getCasesWithChangedStatus(STATUS_RECEIVED, STATUS_REJECTED);
        if (rejectedToReceivedCases.isEmpty()) {
            return;
        }

        List<breg_Search_Log__c> searchLogs = new List<breg_Search_Log__c>();
        for (Case theCase : rejectedToReceivedCases) {
            String previousName = theCase.breg_Name_of_the_Entity_Previous__c;
            String currentName = theCase.breg_New_Entity_Name__c != null ? theCase.breg_New_Entity_Name__c : theCase.breg_Name_of_the_Entity__c;
            if (String.isBlank(previousName) || previousName == currentName) {
                continue;
            }

            breg_Search_Log__c log = new breg_Search_Log__c();
            log.breg_Case__c = theCase.Id;
            log.breg_Search_Term__c = previousName;
            log.breg_Normalized_Search_Term__c = BREGUtils.cleanBusinessName(previousName);
            log.breg_Rejected_Name__c = true;
            searchLogs.add(log);
        }

        if (!searchLogs.isEmpty()) {
            insert searchLogs;
        }
    }

    private Set<Id> getPaidTransactionLineIdsForCases(List<Case> changedCases) {
        Set<Id> result = new Set<Id>();
        if (changedCases == null || changedCases.isEmpty()) {
            return result;
        }

        Set<Id> changedCaseIds = new Set<Id>();
        for (Case changedCase : changedCases) {
            changedCaseIds.add(changedCase.Id);
        }

        for (TransactionLine__c transactionLine : [
            SELECT breg_Case__c
            FROM TransactionLine__c
            WHERE breg_Case__c IN :changedCaseIds AND PaidStatus__c = 'Paid'
        ]) {
            result.add(transactionLine.breg_Case__c);
        }

        return result;
    }


    /**
     * BULKIFIED: Pre-queries all Annual reports for approved cases with Annual Report business process
     * @param approvedCases - list of approved cases
     * @return Map<Id, List<breg_Annual__c>> - map of entity Id to list of related Annual reports
     */
    private Map<Id, List<breg_Annual__c>> getAnnualReportsForApprovedCases(List<Case> approvedCases) {
        Set<Id> entityIds = new Set<Id>();

        // Collect entity IDs for cases with Annual Report business process
        for (Case c : approvedCases) {
            if (c.breg_Form_Configuration__r.breg_Business_Process__c == 'Annual Report' && c.breg_Entity__c != null) {
                entityIds.add(c.breg_Entity__c);
            }
        }

        return queryAnnualReportsByEntityIds(entityIds);
    }

    /**
     * BULKIFIED: Pre-queries all Annual reports for new cases with Annual Report business process
     * @param annualReportCases - list of new cases with Annual Report business process
     * @return Map<Id, List<breg_Annual__c>> - map of entity Id to list of related Annual reports
     */
    private Map<Id, List<breg_Annual__c>> getAnnualReportsForNewCases(List<Case> annualReportCases) {
        Set<Id> entityIds = new Set<Id>();

        // Collect entity IDs
        for (Case c : annualReportCases) {
            if (c.breg_Entity__c != null) {
                entityIds.add(c.breg_Entity__c);
            }
        }

        return queryAnnualReportsByEntityIds(entityIds);
    }

    /**
     * Queries Annual reports for a set of entity IDs
     * @param entityIds - set of entity IDs
     * @return Map<Id, List<breg_Annual__c>> - map of entity Id to list of related Annual reports
     */
    private Map<Id, List<breg_Annual__c>> queryAnnualReportsByEntityIds(Set<Id> entityIds) {
        Map<Id, List<breg_Annual__c>> result = new Map<Id, List<breg_Annual__c>>();

        if (entityIds.isEmpty()) {
            return result;
        }

        // Query all related annuals in one SOQL
        List<breg_Annual__c> allAnnuals = [
            SELECT
                Id,
                breg_Filing_Date__c,
                breg_Filing_Year__c,
                breg_Status__c,
                breg_Received_Date__c,
                breg_Account__c,
                (
                    SELECT Id, Status, breg_Annual__c
                    FROM breg_Cases__r
                    WHERE Status IN ('New', 'Pending Submission')
                )
            FROM breg_Annual__c
            WHERE breg_Account__c IN :entityIds AND (breg_Status__c = 'D' OR breg_Status__c = 'N' OR breg_Status__c = 'F')
            ORDER BY breg_Filing_Year__c DESC
        ];

        // Build map of entity Id to list of annuals
        for (breg_Annual__c annual : allAnnuals) {
            if (!result.containsKey(annual.breg_Account__c)) {
                result.put(annual.breg_Account__c, new List<breg_Annual__c>());
            }
            result.get(annual.breg_Account__c).add(annual);
        }

        return result;
    }

    /**
     * Checks number of delinquent annual reports for a case
     * BULKIFIED: Uses pre-queried relatedAnnuals list instead of querying per case
     * @param theCase - the case to check
     * @param relatedAnnuals - pre-queried list of related annual reports (can be null)
     * @return Integer - number of delinquent annual reports
     */
    private Integer checkNumberOfDelinquents(Case theCase, List<breg_Annual__c> relatedAnnuals) {
        String errorMessage;

        // Handle null list from map lookup
        if (relatedAnnuals == null) {
            relatedAnnuals = new List<breg_Annual__c>();
        }

        if (theCase.breg_Annual_Report_Filing_Year__c == null) {
            throwError('Annual Report Filing Year should be populated on Case for this form');
        }

        if (relatedAnnuals.isEmpty()) {
            return 0;
        }

        String filingYear = theCase.breg_Annual_Report_Filing_Year__c;
        Boolean isFiledAnnualPending = false;
        List<breg_Annual__c> delinquentAnnuals = new List<breg_Annual__c>();
        Boolean hasPendingCases = false;
        for (breg_Annual__c annual : relatedAnnuals) {
            if (annual.breg_Status__c == 'F' && annual.breg_Filing_Year__c == theCase.breg_Annual_Report_Filing_Year__c) {
                isFiledAnnualPending = true;
            }
            if (annual.breg_Status__c == 'D') {
                delinquentAnnuals.add(annual);
            }
            if (annual.breg_Cases__r != null && !annual.breg_Cases__r.isEmpty()) {
                hasPendingCases = true;
            }
        }

        if (isFiledAnnualPending) {
            return Integer.valueOf(theCase.breg_Number_of_Delinquent_Annual_Reports__c);
        }

        if (delinquentAnnuals.isEmpty()) {
            return 0;
        }

        breg_Annual__c first = delinquentAnnuals[0];
        breg_Annual__c second = delinquentAnnuals.size() > 1 ? delinquentAnnuals[1] : null;

        Boolean isFirstMatch = first.breg_Filing_Year__c == filingYear && first.breg_Status__c == 'D';

        Boolean isSecondMatch = second != null && second.breg_Filing_Year__c == filingYear && second.breg_Status__c == 'D';

        if (isFirstMatch) {
            return 1;
        } else if (isSecondMatch) {
            return 2;
        }

        if (!hasPendingCases && (delinquentAnnuals.size() == 1 && !isFirstMatch) || (delinquentAnnuals.size() == 2 && !isFirstMatch && !isSecondMatch)) {
            throwError('You should first create Case for earliest delinquent year');
        }
        //Commented for prod accounts - exist account s with 3 delinquent annual reports
        // if (delinquentAnnuals.size() > 2 || (delinquentAnnuals.size() == 2 && !isFirstMatch && !isSecondMatch)) {
        //     throwError('Entity can have only 2 delinquent annual reports - with statuses Delinquent (1 year) or Delinquent (2 years) accordingly');
        // }
        if (delinquentAnnuals.size() > 3) {
            throwError('Entity can have maximum 3 delinquent annual reports');
        }
        return 3;
    }

    private void throwError(String errorMessage) {
        BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException ex = new BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException(errorMessage);
        ex.errorMessage = errorMessage;
        throw ex;
    }

    public override void afterInsert() {
        List<Case> bregNewList = getBregNewList();
        BREGCaseValidator.validateCaseRelations(bregNewList);
        updateGPCaseLLPRegistrationFlag(bregNewList);

        // Handle status for new cases - perform actions only
        handleStatusChange(bregNewList, new Map<Id, Case>(), false, true);

        List<Case> newCases = getNewCases();

        BREGWorkitemNumberGenerator.generateWorkitemNumbers(newCases);

        Set<Id> casesWithStartedDocumentGeneration = new Set<Id>();
        for (Case theCase : newCases) {
            if (theCase.breg_Form_Configuration__c != null && theCase.breg_Form_Code__c != 'DOCDLVR') {
                if (theCase.Origin == 'Web' && !InitialFilingCreated && theCase.breg_Form_Code__c != 'WD') {
                    startWorkflowAsync(INITIAL_FILING_WORKFLOW, theCase.Id, 'Case was created from Web');
                    InitialFilingCreated = true;
                    casesWithStartedDocumentGeneration.add(theCase.Id);
                }
            }
        }
        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : casesWithStartedDocumentGeneration) {
            casesToUpdate.add(new Case(Id = caseId, breg_Document_Generation_Status__c = 'Generation in Process'));
        }
        update casesToUpdate;

        BREGCaseDefaultOwnerReassignment.enqueueReassignment(bregNewList);
    }

    private void handleStatusChange(List<Case> newCases, Map<Id, Case> oldMap, Boolean performValidation, Boolean performActions) {
        Set<Id> casesIds = new Set<Id>();
        for (Case c : newCases) {
            casesIds.add(c.Id);
        }
        List<Case> bregNewList = getBregNewList();
        Map<String, List<Case>> statusAndHandlerToCasesMap = BREGCaseStatusHandlerUtils.getStatusAndHandlerToCasesMap(bregNewList, oldMap);
        for (String statusAndHandler : statusAndHandlerToCasesMap.keySet()) {
            String newStatus = statusAndHandler.split(BREGCaseStatusHandlerUtils.STATUS_AND_HANDLER_SEPARATOR)[0];
            String handlerClassName = statusAndHandler.split(BREGCaseStatusHandlerUtils.STATUS_AND_HANDLER_SEPARATOR)[1];
            Object handler = BREGUtils.getHandlerInstance(handlerClassName);
            BREGCaseStatusHandlerBase statusHandler = (BREGCaseStatusHandlerBase) handler;
            try {
                statusHandler.handleStatusChange(statusAndHandlerToCasesMap.get(statusAndHandler), newStatus, performValidation, performActions);
            } catch (Exception e) {
                List<Case> affectedCases = statusAndHandlerToCasesMap.get(statusAndHandler);
                String currentUserId = UserInfo.getUserId();
                List<BREG_Handler_Error__e> events = new List<BREG_Handler_Error__e>();
                Datetime errorTimestamp = Datetime.now();
                for (Case affectedCase : affectedCases) {
                    events.add(new BREG_Handler_Error__e(
                        Case_Id__c       = String.valueOf(affectedCase.Id),
                        User_Id__c       = currentUserId,
                        Error_Message__c = e.getMessage(),
                        Stack_Trace__c   = e.getStackTraceString(),
                        Timestamp__c     = errorTimestamp
                    ));
                }
                // PublishImmediately — event is committed even if this transaction rolls back.
                // The BREG_Handler_Error__e subscriber trigger writes breg_Handler_Log_Message__c
                // in a separate async transaction, ensuring durability even after rollback.
                EventBus.publish(events);
                throw e;
            }
        }
    }

    private List<Case> getCasesWithChangedStatus(String newStatus, String oldStatus) {
        Set<Id> changedCasesIds = new Set<Id>();
        List<Case> bregNewList = getBregNewList();
        for (Case theCase : bregNewList) {
            Case oldCase = (Case) this.oldMap.get(theCase.Id);
            if (oldCase.Status != theCase.Status && theCase.Status == newStatus && (oldStatus == null || oldCase.Status == oldStatus)) {
                changedCasesIds.add(theCase.Id);
            }
        }

        return getCasesFromMap(changedCasesIds);
    }

    private List<Case> getCasesWithChangedFields(String fieldName, Object fieldValue) {
        Set<Id> changedCasesIds = new Set<Id>();
        List<Case> bregNewList = getBregNewList();
        for (Case theCase : bregNewList) {
            Case oldCase = (Case) this.oldMap.get(theCase.Id);

            Object oldValue = oldCase.get(fieldName);
            Object newValue = theCase.get(fieldName);
            if (oldValue != newValue && (newValue == fieldValue || fieldValue == null)) {
                changedCasesIds.add(theCase.Id);
            }
        }

        return getCasesFromMap(changedCasesIds);
    }

    /**
     * Sets Is LLP Registration on the linked GP-1 case when GP Case is populated on an LLP-1/FLLP-1 case(BREGMO-733).
     * @param cases - list of cases from trigger context
     */
    private void updateGPCaseLLPRegistrationFlag(List<Case> cases) {
        Set<Id> gpCaseIdsToFlag = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_Form_Code__c != 'LLP-1' && c.breg_Form_Code__c != 'FLLP-1') {
                continue;
            }
            if (c.breg_GP_Case__c == null) {
                continue;
            }
            Case oldCase = (Case) this.oldMap.get(c.Id);
            if (oldCase != null && oldCase.breg_GP_Case__c == c.breg_GP_Case__c) {
                continue;
            }
            gpCaseIdsToFlag.add(c.breg_GP_Case__c);
        }

        if (gpCaseIdsToFlag.isEmpty()) {
            return;
        }

        List<Case> gpCasesToUpdate = new List<Case>();
        for (Id gpCaseId : gpCaseIdsToFlag) {
            gpCasesToUpdate.add(new Case(Id = gpCaseId, breg_Is_LLP_Registration__c = true));
        }
        update gpCasesToUpdate;
    }

    private List<Case> getAnnualRobotCases() {
        List<Case> annualRobotCases = new List<Case>();
        List<Case> bregNewList = getBregNewList();

        for (Case currentCase : bregNewList) {
            Case oldCase = (Case) this.oldMap.get(currentCase.Id);
            if (
                oldCase == null ||
                currentCase.Origin != 'Web' ||
                !BREGUtils.isAnnualForm(currentCase.breg_Form_Code__c)
            ) {
                continue;
            }

            Boolean statusChangedToReceived = oldCase.Status != currentCase.Status && currentCase.Status == STATUS_RECEIVED;
            Boolean noChangesChangedToTrue = oldCase.breg_No_Changes__c != currentCase.breg_No_Changes__c && currentCase.breg_No_Changes__c == true;

            if (statusChangedToReceived || noChangesChangedToTrue) {
                annualRobotCases.add(currentCase);
            }
        }

        return annualRobotCases;
    }

    private static void returnToPreviousOwner(List<Case> resubmittedCases) {
        List<Case> casesToUpdate = new List<Case>();

        for (Case resubmittedCase : resubmittedCases) {
            if (resubmittedCase.breg_Rejected_By_User__c != null) {
                resubmittedCase.OwnerId = resubmittedCase.breg_Rejected_By_User__c;
                casesToUpdate.add(resubmittedCase);
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    private static void assignCasesUsingAssignmentRule(List<Case> cases) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.useDefaultRule = true;
        List<Case> casesToUpdate = new List<Case>();
        for (Case caseRecord : cases) {
            Case caseToUpdate = new Case(Id = caseRecord.Id);
            caseToUpdate.setOptions(dmlOpts);
            casesToUpdate.add(caseToUpdate);
        }
        Database.update(casesToUpdate, false);
    }

    private List<Case> getNewCases() {
        List<Case> bregNewList = getBregNewList();
        Set<Id> newCasesIds = new Set<Id>();
        for (Case theCase : bregNewList) {
            newCasesIds.add(theCase.Id);
        }

        List<Case> newCases = [
            SELECT
                breg_Form_Configuration__r.breg_Suffix_Code__c,
                breg_Form_Configuration__r.breg_Business_Process__c,
                Id,
                CaseNumber,
                breg_ESWM_WFWORKITEM_ID__C,
                breg_Workitem_Number__c,
                breg_Form_Code__c,
                Origin,
                breg_File__c
            FROM Case
            WHERE Id IN :newCasesIds
        ];

        return newCases;
    }

    private Map<Id, Case> getCasesWithRelatedFieldsMap(List<Case> triggeredCases) {
        Set<Id> caseIds = new Set<Id>();
        for (Case c : triggeredCases) {
            caseIds.add(c.Id);
        }

        Map<Id, Case> casesWithRelatedFieldsMap = new Map<Id, Case>( [
            SELECT
                Id,
                breg_Form_Configuration__r.breg_Suffix_Code__c,
                breg_Form_Configuration__r.breg_Business_Process__c,
                breg_Form_Configuration__r.breg_Days_After_Submission_hold_Approval__c,
                breg_Submission_Date__c,
                CaseNumber,
                breg_ESWM_WFWORKITEM_ID__C,
                breg_Workitem_Number__c,
                breg_Form_Code__c,
                Origin,
                breg_File__c
            FROM Case
            WHERE Id IN :caseIds
        ]);

        return casesWithRelatedFieldsMap;
    }

    private Set<Id> getCaseIds(List<Case> cases) {
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }
        return caseIds;
    }

    public static void startWorkflowAsync(String workflowName, Id recordId, String context) {
        if (!Test.isRunningTest()) {
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(recordId, 'Case Trigger Handler, Context: ' + context);
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, recordId, null, 'Case Trigger Handler, Context: ' + context, workflowLogId));
        }
    }

    public static void startWorkflowWithParams(String workflowName, Id caseId, String params, String context) {
        if (!Test.isRunningTest()) {
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(caseId, 'Case Trigger Handler, Context: ' + context);
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, caseId, params, 'Case Trigger Handler, Context: ' + context, workflowLogId));
        }
    }

    private Date calculateExpirationDate(Date effectiveDate, Integer days) {
        if (effectiveDate == null || days == null) {
            return null;
        }
        return effectiveDate.addDays(days);
    }

    private static void updateLabelField(Case oldCase, Case newCase, BREGUtils.LabelFieldConfig config) {
        if (newCase == null) {
            return;
        }

        String newValue = toStringValue(newCase.get(config.sourceFieldApiName));
        String oldValue = oldCase == null ? null : toStringValue(oldCase.get(config.sourceFieldApiName));
        String newControllerValue = config.isDependentPicklist() ? toStringValue(newCase.get(config.controllerFieldApiName)) : null;
        String oldControllerValue = config.isDependentPicklist() && oldCase != null ? toStringValue(oldCase.get(config.controllerFieldApiName)) : null;

        if (oldCase != null && newValue == oldValue && newControllerValue == oldControllerValue) {
            return;
        }

        Map<String, String> valueToLabelMap = config.valueToLabelMap;
        String lookupKey = config.isDependentPicklist() ? (newControllerValue + '.' + newValue) : newValue;
        String labelValue = valueToLabelMap != null && valueToLabelMap.containsKey(lookupKey) ? valueToLabelMap.get(lookupKey) : newValue;
        newCase.put(config.targetLabelFieldApiName, labelValue);
    }

    private static String toStringValue(Object valueObj) {
        return valueObj == null ? null : String.valueOf(valueObj);
    }

    private static void populateTransactionCodeValue(List<Case> cases, Map<Id, Case> oldMap) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        Map<String, String> transactionCodeLabels = BREGUtils.getPicklistLabelMap('Case', 'breg_Trans_Code__c');

        for (Case currentCase : cases) {
            Case oldCase = oldMap == null ? null : oldMap.get(currentCase.Id);

            if (
                oldCase != null &&
                currentCase.breg_Trans_Code__c == oldCase.breg_Trans_Code__c &&
                !String.isBlank(currentCase.breg_Transaction_Code_Value__c)
            ) {
                continue;
            }

            if (String.isBlank(currentCase.breg_Trans_Code__c)) {
                currentCase.breg_Transaction_Code_Value__c = null;
                continue;
            }

            String transactionCodeLabel = transactionCodeLabels.get(currentCase.breg_Trans_Code__c);
            if (!String.isBlank(transactionCodeLabel)) {
                currentCase.breg_Transaction_Code_Value__c = extractTransactionCodeValue(transactionCodeLabel);
            }

            
        }
    }

    private static String extractTransactionCodeValue(String picklistLabel) {
        if (String.isBlank(picklistLabel)) {
            return null;
        }

        List<String> parts = picklistLabel.split(' - ');
        if (parts.size() > 1) {
            return parts[1].trim();
        }

        return picklistLabel.trim();
    }

    private static void updateStatusForAmendedCase(Case currentCase, Boolean isNewCase) {
        if (!currentCase.breg_No_Changes__c && currentCase.breg_Is_Amended__c && (currentCase.Status == 'Pending Submission' || isNewCase)) {
            currentCase.Status = 'Processing In Progress';
        }
    }
}