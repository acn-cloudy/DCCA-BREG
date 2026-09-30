public without sharing class BREGCaseStatusHandlerUtils {
    public static final String STATUS_AND_HANDLER_SEPARATOR = ';';
    public static final String DISSOLUTION_TERMINATION_WITHDRAWAL_CANCELLATION_FORMCODES = 'DC-10, DC-13, DNP-6, DNP-7, FC-4, FLLC-2, GP-4, LLC-11, LLP-2, LP-4, SOLE-7, X-6';

    /**
     * Returns a map of status to list of cases where status has changed (for update context)
     * @param newList - new list of cases from trigger
     * @param oldMap - old map of cases from trigger
     * @return Map<String, List<Case>> - map of new status to list of cases
     */
    public static Map<String, List<Case>> getStatusAndHandlerToCasesMap(List<Case> newList, Map<Id, Case> oldMap) {
        Map<String, List<Case>> statusAndHandlerToCasesMap = new Map<String, List<Case>>();

        for (Case newCase : newList) {
            Case oldCase = oldMap.get(newCase.Id);
            if (newCase.breg_Form_Code__c != null && ((oldCase != null && oldCase.Status != newCase.Status) || oldCase == null)) {
                String newStatus = newCase.Status;
                String handlerClassName = getHandlerClassName(newCase.breg_Form_Code__c);
                String mapKey = newStatus + STATUS_AND_HANDLER_SEPARATOR + handlerClassName;
                if (!statusAndHandlerToCasesMap.containsKey(mapKey)) {
                    statusAndHandlerToCasesMap.put(mapKey, new List<Case>());
                }
                statusAndHandlerToCasesMap.get(mapKey).add(newCase);
            }
        }

        return statusAndHandlerToCasesMap;
    }

    /**
     * Returns a map of case id to boolean indicating if payment is done for the case
     * Checks both completed payments and paid transaction line items
     * @param cases - list of cases
     * @return Map<Id, Boolean> - map of case id to boolean indicating if payment is done for the case
     */
    public static Map<Id, Boolean> isPaymentDoneForCases(List<Case> cases) {
        Map<Id, Boolean> caseIdToPaymentDoneMap = new Map<Id, Boolean>();
        Set<Id> caseIds = new Set<Id>();

        for (Case c : cases) {
            if (c.breg_Form_Code__c == 'GP-1' && c.breg_Is_LLP_Registration__c) {
                caseIds.add(c.ParentId);
                caseIdToPaymentDoneMap.put(c.ParentId, false);
            } else {
                caseIds.add(c.Id);
                caseIdToPaymentDoneMap.put(c.Id, false);
            }
            if (c.breg_Override_Payment__c) {
                caseIdToPaymentDoneMap.put(c.Id, true);
            }
        }

        // Check paid transaction line items
        List<TransactionLine__c> transactionLines = getPaidTransactionLines(caseIds);
        for (TransactionLine__c transactionLine : transactionLines) {
            caseIdToPaymentDoneMap.put(transactionLine.breg_Case__c, true);
        }

        return caseIdToPaymentDoneMap;
    }

    /**
     * Validates the case status change based on form code or case configuration
     * @param inputs - list of flow inputs
     * @return List<FlowOutput> - list of flow outputs
     */
    @InvocableMethod(
        label='Validate Case Status Change'
        description='Validates the case status change based on form code or case configuration'
        category='Case'
    )
    public static List<FlowOutput> validateCaseStatusChange(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        try {
            for (FlowInput input : inputs) {
                Case c = getCase(input.caseId);
                String formCode;

                if (input.checkFormCode == true) {
                    formCode = c.breg_Form_Code__c;
                } else {
                    formCode = input.formCode;
                }

                Object handler = getHandlerInstance(formCode);
                BREGCaseStatusHandlerBase statusHandler = (BREGCaseStatusHandlerBase) handler;
                statusHandler.handleStatusChange(new List<Case>{ c }, input.newStatus, true, false);
            }
        } catch (BREGCaseStatusHandlerException e) {
            System.debug(e.errorMessage);
            outputs.add(new FlowOutput(true, e.errorMessage));
        } catch (Exception e) {
            System.debug(e.getMessage());
            outputs.add(new FlowOutput(true, e.getMessage()));
        }

        return outputs;
    }

    /**
     * Returns the handler instance based on the form code
     * @param formCode - form code
     * @return Object - handler instance
     */
    private static Object getHandlerInstance(String formCode) {
        String handlerClassName = getHandlerClassName(formCode);
        return BREGUtils.getHandlerInstance(handlerClassName);
    }

    /**
     * Returns the handler class name based on the form code
     * @param formCode - form code
     * @return String - handler class name
     */
    public static String getHandlerClassName(String formCode) {
        String handlerClassName = 'BREGCaseStatusHandler';
        if (BREGUtils.isNBRForm(formCode)) {
            handlerClassName += 'NBR';
        } else if (formCode == 'T-1' || formCode == 'T-2' || formCode == 'T-3') {
            handlerClassName += 'TNTMSMRenewal';
        } else if (formCode == 'T-4') {
            handlerClassName += 'TNTMSMAssignment';
        } else if (formCode == 'T-5' || formCode == 'TN-RNC') {
            handlerClassName += 'TNTMSMRegNameChange';
        } else if (formCode == 'T-7') {
            handlerClassName += 'PublicityRightsReg';
        } else if (formCode == 'TN-CANC' || formCode == 'TMSM-CANC') {
            handlerClassName += 'TNTMSMCancel';
        } else if (DISSOLUTION_TERMINATION_WITHDRAWAL_CANCELLATION_FORMCODES.split(', ').contains(formCode)) {
            handlerClassName += 'DissTermWithdrCanc';
        } else if (formCode == 'X-1') {
            handlerClassName += 'NameReservation';
        } else if (formCode == 'X-3') {
            handlerClassName += 'Corrections';
        } else if (formCode == 'X-4') {
            handlerClassName += 'Reinstatement';
        } else if (formCode == 'X-7') {
            handlerClassName += 'X7ChangeCRA';
        } else if (formCode == 'X-8') {
            handlerClassName += 'ChangeNonComCRA';
        } else if (formCode == 'X-9') {
            handlerClassName += 'ResignationCRA';
        } else if (formCode == 'X-10') {
            handlerClassName += 'Conversion';
        } else if (formCode == 'X-11') {
            handlerClassName += 'CRARegistration';
        } else if (formCode == 'X-12') {
            handlerClassName += 'Merger';
        } else if (formCode == 'X-13') {
            handlerClassName += 'CRATermination';
        } else if (formCode == 'X-14') {
            handlerClassName += 'CRAChange';
        } else if (formCode == 'X-15') {
            handlerClassName += 'AbandOfConversion';
        } else if (
            formCode == 'ANN-AG-1' ||
            formCode == 'ANN-CONS-1' ||
            formCode == 'ANN-DC-1' ||
            formCode == 'ANN-DNP-1' ||
            formCode == 'ANN-FC-1' ||
            formCode == 'ANN-FLLC-1' ||
            formCode == 'ANN-FLLP-1' ||
            formCode == 'ANN-FLP-1' ||
            formCode == 'ANN-GP-1' ||
            formCode == 'ANN-LLC-1' ||
            formCode == 'ANN-LLP-1' ||
            formCode == 'ANN-LP-1' ||
            formCode == 'ANN-PC-1' ||
            formCode == 'ANN-SBC-1' ||
            formCode == 'ANN-SOLE-1'
        ) {
            handlerClassName += 'Annuals';
        } else if (formCode == 'ADD') {
            handlerClassName += 'Add';
        } else if (formCode == 'ADD-TNTMSM') {
            handlerClassName += 'AddTNTMSM';
        } else if (formCode == 'ADD-MEMBER') {
            handlerClassName += 'AddMember';
        } else if (formCode == 'DC-7') {
            handlerClassName += 'CancAcquiredShares';
        } else if (formCode == 'DC-12' || formCode == 'DNP-8') {
            handlerClassName += 'Revocation';
        } else if (
            formCode == 'DC-2' ||
            formCode == 'DC-3' ||
            formCode == 'DNP-2' ||
            formCode == 'DNP-3' ||
            formCode == 'FLP-2' ||
            formCode == 'GP-3' ||
            formCode == 'LLC-3' ||
            formCode == 'LLC-2' ||
            formCode == 'LLP-2' ||
            formCode == 'LLP-3' ||
            formCode == 'LP-2' ||
            formCode == 'NC'
        ) {
            handlerClassName += 'AmendmentChanges';
        } else if (formCode == 'DC-6') {
            handlerClassName += 'Issuance';
        } else if (formCode == 'DC-4' || formCode == 'DC-5' || formCode == 'DNP-4' || formCode == 'DNP-5' || formCode == 'LLC-4' || formCode == 'LLC-5') {
            handlerClassName += 'RestatedArticles';
        } else if (formCode == 'ODC') {
            handlerClassName += 'ODC';
        } else {
            handlerClassName += 'Base';
        }

        return handlerClassName;
    }

    /**
     * Returns a list of paid transaction line items for the case ids
     * @param caseIds - set of case ids
     * @return List<TransactionLine__c> - list of paid transaction line items
     */
    private static List<TransactionLine__c> getPaidTransactionLines(Set<Id> caseIds) {
        return [SELECT Id, breg_Case__c FROM TransactionLine__c WHERE breg_Case__c IN :caseIds AND PaidStatus__c = 'Paid'];
    }

    /**
     * Returns a case based on the case id
     * @param caseId - case id
     * @return Case - case
     */
    private static Case getCase(Id caseId) {
        return [
            SELECT
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Business_Process__c,
                breg_New_Registrant_First_Name__c,
                breg_New_Registrant_Last_Name__c,
                breg_New_Registrant_Name__c,
                breg_Entity_Jurisdiction__c,
                breg_TNTMSM_Registration_Type__c,
                breg_Organizing_Articles_Changes__c,
                breg_Resubmission_Due_Date__c,
                breg_Last_Rejection_Date__c,
                breg_Effective_Date__c,
                breg_Name_of_the_Entity__c,
                breg_Entity_Type__c,
                breg_Entity__c,
                breg_Entity__r.Name,
                breg_Entity__r.breg_Formation_State__c,
                breg_Remaining_Shares_Class_Series__c,
                breg_Remaining_Shares_Count__c,
                breg_Cancelled_Shares_Class_Series__c,
                breg_Cancelled_Shares_Count__c,
                breg_Resubmission_Received_Date__c,
                breg_File_Suffix__c,
                breg_Reg_Agent_Address__c,
                breg_Registered_Agent_Address__City__s,
                breg_Registered_Agent_Address__CountryCode__s,
                breg_Reg_Agent_Address_Has_Changed__c,
                breg_Reg_Agent_Address_State__c,
                breg_Registered_Agent_Address__StateCode__s,
                breg_Registered_Agent_Address__Street__s,
                breg_Reg_Agent_Address_Street2__c,
                breg_Registered_Agent_Address__PostalCode__s,
                breg_Reg_Agent_Entity_Location__c,
                breg_Reg_Agent_Entity_Name__c,
                breg_Reg_Agent_First_Name__c,
                breg_Reg_Agent_Has_Changed__c,
                breg_Reg_Agent_Is_Entity__c,
                breg_Reg_Agent_Last_Name__c,
                breg_Reg_Agent_Type__c,
                breg_BRIM_FILE_NO__c,
                breg_TNTMSM_Classification__c,
                breg_Entity_Type_Has_Changed__c,
                breg_Entity_Jurisdiction_Has_Changed__c,
                breg_Update_Child_Entity__c,
                breg_Entity__r.breg_Entity_Type__c,
                breg_Entity__r.breg_Certified_Register_Agent__c,
                breg_Is_Allowed_Generate_Reinstatem_Cert__c,
                ParentId,
                breg_Outstanding_Shares_Count__c,
                breg_GP_Already_Registered__c,
                breg_GP_Entity__c,
                breg_GP_Case__r.breg_Entity__c,
                breg_Is_LLP_Registration__c,
                breg_File__c,
                breg_Portal_User_Entity_Selected__c,
                breg_New_Registrant_Address__c,
                breg_New_Registrant_Address__Street__s,
                breg_New_Registrant_Address__City__s,
                breg_New_Registrant_Address__StateCode__s,
                breg_New_Registrant_Address__PostalCode__s,
                breg_New_Registrant_Address__CountryCode__s,
                breg_New_Registrant_Address_State_Text__c,
                breg_New_Registrant_Address_Street_2__c,
                breg_New_Registrant_Is_Entity__c,
                breg_New_Registrant_Type__c,
                breg_TN_TM_SM__c,
                breg_New_Mailing_Address__CountryCode__s,
                breg_New_Mailing_Address__StateCode__s,
                breg_New_Mailing_Address__City__s,
                breg_New_Mailing_Address__Street__s,
                breg_New_Mailing_Address__PostalCode__s,
                breg_Entity__r.breg_File__c,
                breg_Entity__r.breg_File_Suffix__c,
                breg_Override_Payment__c,
                breg_TNTMSM_Certificate__c,
                breg_TNTMSM_Type__c,
                breg_Submission_Date__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    public static void updateTargetRecordsFromCaseMap(
        Map<Id, Case> targetIdToCaseMap,
        String targetObjectName,
        Map<SObjectField, SObjectField> fieldMapping
    ) {
        updateTargetRecordsFromCaseMap(targetIdToCaseMap, targetObjectName, null, fieldMapping);
    }

    public static void updateTargetRecordsFromCaseMap(
        Map<Id, Case> targetIdToCaseMap,
        String targetObjectName,
        Map<Id, Map<SObjectField, SObjectField>> perCaseMappings,
        Map<SObjectField, SObjectField> defaultMapping
    ) {
        if (targetIdToCaseMap == null || targetIdToCaseMap.isEmpty())
            return;

        Set<Id> targetIds = targetIdToCaseMap.keySet();
        Set<SObjectField> allTargetFields = new Set<SObjectField>();

        if (defaultMapping != null) {
            allTargetFields.addAll(defaultMapping.values());
        }

        if (perCaseMappings != null) {
            for (Map<SObjectField, SObjectField> m : perCaseMappings.values()) {
                allTargetFields.addAll(m.values());
            }
        }

        String query = 'SELECT Id';
        Set<String> queryFieldNames = new Set<String>{ 'Id' };

        for (SObjectField f : allTargetFields) {
            String fieldName = f.getDescribe().getName();
            if (!queryFieldNames.contains(fieldName)) {
                query += ', ' + fieldName;
                queryFieldNames.add(fieldName);
            }
        }

        // Include TBI fieldset fields for Account objects to support transaction record creation
        if (targetObjectName == 'Account') {
            List<Schema.FieldSetMember> tbiFields = Account.SObjectType.getDescribe().fieldSets.getMap().get('BREG_TBI_Fields_Set').getFields();
            for (Schema.FieldSetMember fsm : tbiFields) {
                String fieldPath = fsm.getFieldPath();
                if (!queryFieldNames.contains(fieldPath)) {
                    query += ', ' + fieldPath;
                    queryFieldNames.add(fieldPath);
                }
            }
        }

        query += ' FROM ' + targetObjectName + ' WHERE Id IN :targetIds';
        List<SObject> targetRecords = Database.query(query);

        Map<Id, SObject> targetMap = new Map<Id, SObject>();
        for (SObject rec : targetRecords) {
            targetMap.put((Id) rec.get('Id'), rec);
        }

        List<SObject> toUpdate = new List<SObject>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();

        for (Id targetId : targetIdToCaseMap.keySet()) {
            Case sourceCase = targetIdToCaseMap.get(targetId);

            SObject target = targetMap.get(targetId);

            if (sourceCase == null || target == null)
                continue;

            Map<SObjectField, SObjectField> mapping = (perCaseMappings != null && perCaseMappings.containsKey(sourceCase.Id))
                ? perCaseMappings.get(sourceCase.Id)
                : defaultMapping;

            if (mapping == null || mapping.isEmpty())
                continue;

            Boolean isChanged = false;

            for (SObjectField caseField : mapping.keySet()) {
                if (targetObjectName == 'Account' && caseField == Case.breg_New_Entity_Jurisdiction__c) {
                    String jurisdiction = (String) sourceCase.get(caseField);
                    String countryOrState = BREGUtils.mapJurisdictionToPicklists(jurisdiction);

                    Account acc = (Account) target;
                    Boolean changed = false;

                    if (countryOrState == 'State') {
                        if (acc.breg_Formation_State__c != jurisdiction) {
                            acc.breg_Formation_State__c = jurisdiction;
                            changed = true;
                        }
                        if (acc.breg_Formation_Country__c != null) {
                            acc.breg_Formation_Country__c = null;
                            changed = true;
                        }
                    } else if (countryOrState == 'Country') {
                        if (acc.breg_Formation_Country__c != jurisdiction) {
                            acc.breg_Formation_Country__c = jurisdiction;
                            changed = true;
                        }
                        if (acc.breg_Formation_State__c != null) {
                            acc.breg_Formation_State__c = null;
                            changed = true;
                        }
                    }

                    if (changed) {
                        isChanged = true;
                        if (targetObjectName == 'Account') {
                            Id tid = acc.Id;
                            Set<String> fields = accountUpdatedFieldsMap.get(tid);
                            if (fields == null)
                                fields = new Set<String>();
                            // track all potential business-info fields affected by jurisdiction change
                            fields.add('breg_Formation_State__c');
                            fields.add('breg_Formation_Country__c');
                            accountUpdatedFieldsMap.put(tid, fields);
                        }
                    }
                    continue;
                }
                SObjectField targetField = mapping.get(caseField);
                Object caseValue = sourceCase.get(caseField);

                Object targetValue = target.get(targetField);

                if (caseValue != targetValue && caseValue != null && !caseValue.equals(targetValue)) {
                    target.put(targetField, caseValue);

                    // track updated Account field API names for Account target handling
                    if (targetObjectName == 'Account') {
                        Id tid = (Id) target.get('Id');
                        Set<String> fields = accountUpdatedFieldsMap.get(tid);
                        if (fields == null)
                            fields = new Set<String>();
                        fields.add(targetField.getDescribe().getName());
                        accountUpdatedFieldsMap.put(tid, fields);
                    }

                    isChanged = true;
                }
            }

            if (isChanged)
                toUpdate.add(target);
        }

        if (!toUpdate.isEmpty()) {
            if (targetObjectName == 'Account') {
                List<Account> accountsToUpdate = new List<Account>();
                for (SObject s : toUpdate) {
                    accountsToUpdate.add((Account) s);
                }

                // Build map of Account Id -> Case for accounts being updated
                Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
                for (Account a : accountsToUpdate) {
                    if (targetIdToCaseMap.containsKey(a.Id)) {
                        entityToCaseMap.put(a.Id, targetIdToCaseMap.get(a.Id));
                    }
                }

                BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(accountsToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
            } else {
                update toUpdate;
            }
        }

        // After updating target records, create transaction records and transaction addresses
        // for Account address changes. Detect if any address-related case fields caused the change
        if (targetObjectName == 'Account') {
            // address-related case field API names
            Set<String> addressCaseFields = new Set<String>{
                'breg_Mailing_Address__Street__s',
                'breg_Mailing_Address_Number_and_Street_2__c',
                'breg_Mailing_Address__City__s',
                'breg_Mailing_Address__StateCode__s',
                'breg_Mailing_Address_State__c',
                'breg_Mailing_Address__PostalCode__s',
                'breg_Mailing_Address__CountryCode__s',
                'breg_Company_Address__City__s',
                'breg_Company_Address__Street__s',
                'breg_Company_Address_Street2__c',
                'breg_Company_Address__StateCode__s',
                'breg_Company_Address_State__c',
                'breg_Company_Address__PostalCode__s',
                'breg_Company_Address__CountryCode__s',
                'breg_New_Mailing_Address__City__s',
                'breg_New_Mailing_Address__Street__s',
                'breg_New_Mailing_Address__StateCode__s',
                'breg_New_Mailing_Address__PostalCode__s',
                'breg_New_Mailing_Address__CountryCode__s',
                'breg_New_Company_Address__City__s',
                'breg_New_Company_Address__Street__s',
                'breg_New_Company_Address__StateCode__s',
                'breg_New_Company_Address__PostalCode__s',
                'breg_New_Company_Address__CountryCode__s'
            };

            // Build a quick lookup of caseId -> Case for the provided map values
            Map<Id, Case> casesById = new Map<Id, Case>();
            for (Case c : targetIdToCaseMap.values()) {
                if (c != null && c.Id != null)
                    casesById.put(c.Id, c);
            }

            // caseId -> targetId for cases that had address changes
            Map<Id, Id> caseToRecordMap = new Map<Id, Id>();

            for (Id targetId : targetIdToCaseMap.keySet()) {
                Case sourceCase = targetIdToCaseMap.get(targetId);
                if (sourceCase == null)
                    continue;

                // Determine mapping used for this case
                Map<SObjectField, SObjectField> mapping = (perCaseMappings != null && perCaseMappings.containsKey(sourceCase.Id))
                    ? perCaseMappings.get(sourceCase.Id)
                    : defaultMapping;

                if (mapping == null || mapping.isEmpty())
                    continue;

                Boolean addressChanged = false;
                // If any of the address fields in mapping were changed, mark
                for (SObjectField caseField : mapping.keySet()) {
                    String caseFieldApi = caseField.getDescribe().getName();
                    if (addressCaseFields.contains(caseFieldApi)) {
                        Object caseValue = sourceCase.get(caseField);
                        // If the case has a value for the address field, consider it a change candidate
                        if (caseValue != null) {
                            addressChanged = true;
                            break;
                        }
                    }
                }

                if (addressChanged) {
                    caseToRecordMap.put(sourceCase.Id, targetId);
                }
            }
            System.debug('Starting transaction record creation for ' + caseToRecordMap.size() + ' cases');
            if (!caseToRecordMap.isEmpty()) {
                // Build cases map filtered to only relevant cases
                System.debug('Building cases map for transaction creation');
                Map<Id, Case> casesForTransactions = new Map<Id, Case>();
                for (Id caseId : caseToRecordMap.keySet()) {
                    if (casesById.containsKey(caseId))
                        casesForTransactions.put(caseId, casesById.get(caseId));
                }

                // Create and insert transactions, then create and insert transaction addresses
                System.debug('Searching transactions');
                List<breg_Transaction__c> transactions = [SELECT Id, breg_Case__c FROM breg_Transaction__c WHERE breg_Case__c IN :casesForTransactions.keySet()];
                if (transactions != null && !transactions.isEmpty()) {
                    upsert transactions;
                    List<breg_Transaction_Address__c> transAddrs = BREGTransactionUtils.createTransactionAdresses(
                        casesForTransactions,
                        transactions,
                        null
                    );
                    if (transAddrs != null && !transAddrs.isEmpty()) {
                        insert transAddrs;
                    }
                    System.debug('Finished creating and inserting transactions and transaction addresses');
                }
            }
        }
    }

    public class FlowInput {
        @InvocableVariable(required=true)
        public String formCode;

        @InvocableVariable(required=true)
        public Id caseId;

        @InvocableVariable(required=true)
        public String newStatus;

        @InvocableVariable(
            label='Check Form Code'
            description='Indicates if the form code on the case should be checked instead of the form code passed in the input'
            required=true
        )
        public Boolean checkFormCode;
    }

    public class FlowOutput {
        @InvocableVariable(label='Is Error' description='Indicates if the case status change is not valid')
        public Boolean isError;

        @InvocableVariable(label='Error Message' description='Error message if the case status change is not valid')
        public String errorMessage;

        public FlowOutput(Boolean isError, String errorMessage) {
            this.isError = isError;
            this.errorMessage = errorMessage;
        }
    }

    public class BREGCaseStatusHandlerException extends Exception {
        public String errorMessage { get; set; }
    }
}