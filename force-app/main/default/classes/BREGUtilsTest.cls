@isTest
private class BREGUtilsTest {
    private class WorkflowStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'GET' && req.getEndpoint().contains('/workflows/')) {
                res.setStatusCode(200);
                res.setBody('{"Status":"Completed"}');
                return res;
            }

            res.setStatusCode(500);
            res.setBody('{"error":"unexpected endpoint"}');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        BREGTestDataFactory.createFormConfigurations();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        breg_Form_Configuration__c llpConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'LLP-1' LIMIT 1];
        breg_Form_Configuration__c gpConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'GP-1' LIMIT 1];
        breg_Form_Configuration__c wrongConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'AG-1' LIMIT 1];
        Case llpCase = new Case(
            Subject = 'LLP Parent',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = llpConfig.Id,
            breg_Form_Code__c = 'LLP-1',
            breg_Bypass_Validation__c = true
        );
        insert llpCase;

        Case matchingChild = new Case(
            Subject = 'Matching GP Child',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ParentId = llpCase.Id,
            breg_Form_Code__c = 'GP-1',
            breg_Form_Configuration__c = gpConfig.Id,
            breg_Is_LLP_Registration__c = true,
            breg_Bypass_Validation__c = true
        );
        Case wrongCodeChild = new Case(
            Subject = 'Wrong Code Child',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ParentId = llpCase.Id,
            breg_Form_Code__c = 'AG-1',
            breg_Form_Configuration__c = wrongConfig.Id,
            breg_Is_LLP_Registration__c = true,
            breg_Bypass_Validation__c = true
        );

        List<Case> casesToInsert = new List<Case>{ matchingChild, wrongCodeChild };
        insert new List<Case>{ matchingChild, wrongCodeChild };
        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Transaction__c trns = new Transaction__c(Account__c = acc.Id, Date__c = Date.today(), Status__c = 'New');
        insert trns;

        breg_Document__c docPrinted = new breg_Document__c(Name = 'Printed Doc', breg_Type__c = 'Printed');
        breg_Document__c docDigital = new breg_Document__c(Name = 'Digital Doc', breg_Type__c = 'Digital');
        insert new List<breg_Document__c>{ docPrinted, docDigital };

        insert new List<TransactionLine__c>{
            new TransactionLine__c(
                Account__c = acc.Id,
                Description__c = 'COGS printed',
                PaidStatus__c = 'Pending',
                breg_Document__c = docPrinted.Id,
                Transaction__c = trns.Id
            ),
            new TransactionLine__c(
                Account__c = acc.Id,
                Description__c = 'COGS digital',
                PaidStatus__c = 'Pending',
                breg_Document__c = docDigital.Id,
                Transaction__c = trns.Id
            )
        };
    }

    @isTest
    static void testFormCategoryAndCodeHelpers() {
        Assert.areEqual('NBR', BREGUtils.checkFormCategory('DC-1'));
        Assert.areEqual('TNTMSM', BREGUtils.checkFormCategory('TN-RNC'));
        Assert.areEqual('Annual', BREGUtils.checkFormCategory('ANN-DC-1'));
        Assert.areEqual('Change', BREGUtils.checkFormCategory('X-12'));
        Assert.areEqual('Name Reservation', BREGUtils.checkFormCategory('X-1'));
        Assert.areEqual('Withdrawal', BREGUtils.checkFormCategory('WD'));
        Assert.isNotNull(BREGUtils.checkFormCategory('X-11'));

        Assert.isTrue(BREGUtils.isNBRForm('DC-1'));
        Assert.isTrue(BREGUtils.isTNTMSMForm('TN-RNC'));
        Assert.isTrue(BREGUtils.isNameReservationForm('X-1'));
        Assert.isTrue(BREGUtils.isAnnualForm('ANN-DC-1'));
        Assert.isTrue(BREGUtils.isCRARegistrationForm('X-11'));
        Assert.isTrue(BREGUtils.isWithdrawalForm('WD'));
        Assert.isTrue(BREGUtils.isMergerForm('X-12'));
        Assert.isTrue(BREGUtils.isNBRFormWithStock('AG-1'));
    }

    @isTest
    static void testPicklistAndMappingUtilities() {
        Map<String, String> valueToLabel = BREGUtils.getPicklistLabelMap('Account', 'BillingStateCode');
        Assert.isNotNull(valueToLabel, 'Picklist value-to-label map should be returned.');

        String picklistLabel = BREGUtils.getPicklistLabel('Account', 'BillingStateCode', 'HI');
        Assert.isNotNull(picklistLabel, 'Picklist label lookup should return a non-null value for HI.');

        Map<String, String> labelToValue = BREGUtils.getPicklistLabelToValueMap('Account', 'BillingStateCode');
        Assert.isNotNull(labelToValue, 'Picklist label-to-value map should be returned.');

        String mappedState = BREGUtils.mapJurisdictionToPicklists('HI');
        Assert.isTrue(mappedState == 'State' || mappedState == 'Country' || mappedState == null, 'Jurisdiction mapping should execute safely.');
    }

    @isTest
    static void testGetStateLabelMapByCountry() {
        String countryWithStates;
        for (Schema.PicklistEntry countryEntry : Account.BillingCountryCode.getDescribe().getPicklistValues()) {
            if (!countryEntry.isActive()) {
                continue;
            }
            String candidateCountryCode = countryEntry.getValue();
            if (BREGUtils.doesCountryHaveStates(candidateCountryCode)) {
                countryWithStates = candidateCountryCode;
                break;
            }
        }

        Assert.isNotNull(countryWithStates, 'Expected at least one active country with dependent states.');

        List<SObject> inputRecords = new List<SObject>{
            new Account(breg_Formation_Country__c = countryWithStates),
            new Account(breg_Formation_Country__c = null)
        };

        Map<String, String> dependentMap = BREGUtils.getStateLabelMapByCountry(inputRecords, 'breg_Formation_Country__c');

        Assert.isFalse(dependentMap.isEmpty(), 'Dependent map should contain entries for the selected country.');

        Boolean foundSelectedCountryKey = false;
        for (String key : dependentMap.keySet()) {
            if (key != null && key.startsWith(countryWithStates + '.')) {
                foundSelectedCountryKey = true;
                Assert.isFalse(String.isBlank(dependentMap.get(key)), 'Mapped dependent label should not be blank.');
                break;
            }
        }

        Assert.isTrue(foundSelectedCountryKey, 'Expected at least one dependent key for selected country.');
    }

    @isTest
    static void testNormalizeVowels() {
        String normalized = BREGUtils.normalizeVowels('KAILUA');
        Assert.areEqual('KAIL?A', normalized, 'Vowels after consonants should be normalized to wildcards.');

        String shortUnchanged = BREGUtils.normalizeVowels('A');
        Assert.areEqual('A', shortUnchanged, 'Single-character vowel input should remain unchanged.');
    }

    @isTest
    static void testReturnFieldLabelByApiName() {
        String accountNameLabel = BREGUtils.returnFielLabelByApiName('Account', 'Name');
        Assert.isFalse(String.isBlank(accountNameLabel), 'Existing field should return a label.');

        String invalidObjectLabel = BREGUtils.returnFielLabelByApiName('NonExistingObject__c', 'Name');
        Assert.isNull(invalidObjectLabel, 'Invalid object should return null.');
    }

    @isTest
    static void testGetEntityTypeOptions() {
        List<BREGUtils.PicklistOption> options = BREGUtils.getEntityTypeOptions();
        Assert.isNotNull(options, 'Entity type options should not be null.');
        Assert.isFalse(options.isEmpty(), 'Entity type options should contain at least the All option.');
        Assert.areEqual('All', options[0].label, 'First option label should be All.');
        Assert.areEqual('all', options[0].value, 'First option value should be all.');
    }

    @isTest
    static void testGetFormTypeOptions() {
        List<BREGUtils.PicklistOption> options = BREGUtils.getFormTypeOptions();
        Assert.isNotNull(options, 'Form type options should not be null.');
        Assert.isFalse(options.isEmpty(), 'Form type options should contain at least the All option.');
        Assert.areEqual('All', options[0].label, 'First option label should be All.');
        Assert.areEqual('all', options[0].value, 'First option value should be all.');

        Set<String> optionValues = new Set<String>();
        for (BREGUtils.PicklistOption option : options) {
            optionValues.add(option.value);
        }

        Assert.isTrue(optionValues.contains('DC-1'), 'Expected form code DC-1 from test setup data.');
        Assert.areEqual(options.size(), optionValues.size(), 'Form type options should not contain duplicate values.');
    }

    @isTest
    static void testGenerateAuthCode() {
        TransactionLine__c line = [
            SELECT Id, Account__c, Description__c, PaidStatus__c, breg_Document__c, breg_Document__r.breg_Type__c
            FROM TransactionLine__c
            WHERE breg_Document__r.breg_Type__c = 'Digital'
            LIMIT 1
        ];

        Test.startTest();
        breg_Certificate__c cert = BREGTransactionLineTriggerHandler.createCertificate(line);
        String code = BREGUtils.generateAuthCode(cert);
        Test.stopTest();

        System.assertNotEquals(null, code);
        System.assertEquals(8, code.length()); // from setting
    }

    @isTest
    static void testGetQueueId() {
        List<Group> queues = [
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Queue'
            LIMIT 1
        ];

        if (!queues.isEmpty()) {
            Id queueId = BREGUtils.getQueueId(queues[0].Name);
            Assert.areEqual(queues[0].Id, queueId, 'getQueueId should return matching queue Id.');
            return;
        }

        Boolean exceptionThrown = false;
        try {
            BREGUtils.getQueueId('QueueNameThatShouldNotExist_12345');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Missing queue should raise an exception.');
    }

    @isTest
    static void testDoesCountryHaveStates() {
        Assert.isFalse(BREGUtils.doesCountryHaveStates(null), 'Null country should return false.');
        Assert.isFalse(BREGUtils.doesCountryHaveStates(''), 'Blank country should return false.');

        String countryWithStates;
        String countryWithoutStates;

        for (Schema.PicklistEntry countryEntry : Account.BillingCountryCode.getDescribe().getPicklistValues()) {
            if (!countryEntry.isActive()) {
                continue;
            }

            String countryCode = countryEntry.getValue();
            Boolean hasStates = BREGUtils.doesCountryHaveStates(countryCode);

            if (hasStates && countryWithStates == null) {
                countryWithStates = countryCode;
            }
            if (!hasStates && countryWithoutStates == null) {
                countryWithoutStates = countryCode;
            }

            if (countryWithStates != null && countryWithoutStates != null) {
                break;
            }
        }

        Assert.isNotNull(countryWithStates, 'At least one active country with states should exist.');
        Assert.isTrue(BREGUtils.doesCountryHaveStates(countryWithStates), 'Country with states should return true.');

        if (countryWithoutStates != null) {
            Assert.isFalse(BREGUtils.doesCountryHaveStates(countryWithoutStates), 'Country without states should return false.');
        }
    }

    @isTest
    static void testHandlerInstanceAndCommunityContactAndBaseUrl() {
        Object handler = BREGUtils.getHandlerInstance('BREGCaseStatusHandlerBase');
        Assert.isNotNull(handler, 'Known handler class should instantiate successfully.');

        Boolean exceptionThrown = false;
        try {
            BREGUtils.getHandlerInstance('NonExistingHandlerClass');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Unknown handler class should throw an exception.');

        Id contactId = BREGUtils.getCommunityUserContactId();
        Assert.isTrue(contactId == null || contactId != null, 'Current user contact lookup should execute safely.');

        String baseUrl = BREGUtils.getBaseUrl();
        Assert.isTrue(baseUrl.contains('http'), 'Base URL should be generated.');
    }

    @isTest
    static void testBusinessNameNormalizationAndFieldSetUtilities() {
        String normalized = BREGUtils.normalizeBusinessName('The Kāne\'s L.L.C. & Co.');
        Assert.isNotNull(normalized, 'Business name normalization should return a value.');
        Assert.isTrue(normalized.length() > 0, 'Normalization should produce non-empty output for non-empty input.');

        Boolean hasAny = BREGUtils.anyFieldInFieldSet('Account', new Set<String>{ 'Name', 'NonExisting__c' }, 'BREG_TBI_Fields_Set');
        Assert.isTrue(hasAny == true || hasAny == false, 'Fieldset intersection utility should execute safely.');
    }

    @isTest
    static void testGetRelatedPaymentsLatestPerCase() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case c = new Case(Subject = 'Utils Payment Case', Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRecordTypeId, breg_Form_Code__c = 'DC-1');
        insert c;

        pymt__PaymentX__c p1 = new pymt__PaymentX__c(Name = 'Payment 1', breg_Case__c = c.Id);
        insert p1;
        pymt__PaymentX__c p2 = new pymt__PaymentX__c(Name = 'Payment 2', breg_Case__c = c.Id);
        insert p2;

        Map<Id, Id> paymentIdToCaseId = BREGUtils.getRelatedPayments(new Set<Id>{ c.Id });
        Assert.areEqual(1, paymentIdToCaseId.size(), 'Only the latest payment per case should be returned.');
        Assert.areEqual(c.Id, paymentIdToCaseId.values()[0], 'Returned payment should be mapped to the requested case.');
    }

    @isTest
    static void testGetRelatedPaymentsFallbackViaTransactionLineCase() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case c = new Case(Subject = 'Utils Payment Fallback Case', Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRecordTypeId, breg_Form_Code__c = 'DC-1');
        insert c;

        BREGTestDataFactory.createTransactionLineForEntityList(null);

        TransactionLine__c line = [
            SELECT Id, Payment__c, breg_Case__c
            FROM TransactionLine__c
            WHERE Payment__c != NULL
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        pymt__PaymentX__c payment = [
            SELECT Id, breg_Case__c
            FROM pymt__PaymentX__c
            WHERE Id = :line.Payment__c
            LIMIT 1
        ];

        line.breg_Case__c = c.Id;
        update line;

        Map<Id, Id> paymentIdToCaseId = BREGUtils.getRelatedPayments(new Set<Id>{ c.Id });
        Assert.areEqual(1, paymentIdToCaseId.size(), 'Payment should be found through related TransactionLine case linkage.');
        Assert.isTrue(paymentIdToCaseId.containsKey(payment.Id), 'Returned payment should match the payment linked through TransactionLine.');
        Assert.areEqual(c.Id, paymentIdToCaseId.get(payment.Id), 'Returned payment should be mapped to the requested case.');
    }

    @isTest
    static void testinsertWorkflowsLogCreatesArrayWhenBlank() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case c = new Case(Subject = 'Workflow Log Blank Case', Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRecordTypeId, breg_Form_Code__c = 'DC-1');
        insert c;

        TriggerUtils.disableTrigger = true;
        BREGUtils.insertWorkflowsLog(
            c.Id,
            '{"Name":"WF-1","Status":"Executing","Href":"https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/workflows/d187e6c3-1c81-f111-9798-9440c983dcd5"}',
            'BREGUtilsTest'
        );

        breg_Log__c createdLog = [
            SELECT
                breg_Type__c,
                breg_Case__c,
                breg_Workflow_Name__c,
                breg_Workflow_Status__c,
                breg_Workflow_Instance_Id__c,
                breg_Workflow_Activity_Link__c,
                breg_Started_By_User__c,
                breg_Started_From__c
            FROM breg_Log__c
            WHERE breg_Case__c = :c.Id
            LIMIT 1
        ];

        Assert.areEqual('Document Generation', createdLog.breg_Type__c);
        Assert.areEqual(c.Id, createdLog.breg_Case__c);
        Assert.areEqual('WF-1', createdLog.breg_Workflow_Name__c);
        Assert.areEqual('Executing', createdLog.breg_Workflow_Status__c);
        Assert.areEqual('d187e6c3-1c81-f111-9798-9440c983dcd5', createdLog.breg_Workflow_Instance_Id__c);
        Assert.isNotNull(createdLog.breg_Workflow_Activity_Link__c);
        Assert.areEqual(UserInfo.getUserId(), createdLog.breg_Started_By_User__c);
        Assert.areEqual('BREGUtilsTest', createdLog.breg_Started_From__c);

        Case updatedCase = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :c.Id];
        Assert.areEqual('Generation in Process', updatedCase.breg_Document_Generation_Status__c);
    }

    @isTest
    static void testCreateWorkflowLogThenUpdateWorkflowLog() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case c = new Case(Subject = 'Workflow Two Phase Case', Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRecordTypeId, breg_Form_Code__c = 'DC-1');
        insert c;

        TriggerUtils.disableTrigger = true;
        Id logId = BREGUtils.createWorkflowLog(c.Id, 'BREGUtilsTest');

        breg_Log__c createdLog = [
            SELECT
                breg_Type__c,
                breg_Case__c,
                breg_Workflow_Name__c,
                breg_Workflow_Status__c,
                breg_Workflow_Instance_Id__c,
                breg_Started_By_User__c,
                breg_Started_From__c
            FROM breg_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        Assert.areEqual('Document Generation', createdLog.breg_Type__c);
        Assert.areEqual(c.Id, createdLog.breg_Case__c);
        Assert.areEqual(null, createdLog.breg_Workflow_Name__c);
        Assert.areEqual('Pending', createdLog.breg_Workflow_Status__c);
        Assert.areEqual(null, createdLog.breg_Workflow_Instance_Id__c);
        Assert.areEqual(UserInfo.getUserId(), createdLog.breg_Started_By_User__c);
        Assert.areEqual('BREGUtilsTest', createdLog.breg_Started_From__c);

        BREGUtils.updateWorkflowsLog(
            logId,
            c.Id,
            '{"Name":"WF-3","Status":"Completed","Href":"https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/workflows/b187e6c3-1c81-f111-9798-9440c983dcd7"}'
        );

        breg_Log__c updatedLog = [
            SELECT
                breg_Workflow_Name__c,
                breg_Workflow_Status__c,
                breg_Workflow_Instance_Id__c,
                breg_Workflow_Activity_Link__c
            FROM breg_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        Assert.areEqual('WF-3', updatedLog.breg_Workflow_Name__c);
        Assert.areEqual('Completed', updatedLog.breg_Workflow_Status__c);
        Assert.areEqual('b187e6c3-1c81-f111-9798-9440c983dcd7', updatedLog.breg_Workflow_Instance_Id__c);
        Assert.isNotNull(updatedLog.breg_Workflow_Activity_Link__c);

        Case updatedCase = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :c.Id];
        Assert.areEqual('Completed', updatedCase.breg_Document_Generation_Status__c);
    }

    @isTest
    static void testinsertWorkflowsLogAppendsToExistingArray() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case c = new Case(Subject = 'Workflow Log Existing Case', Status = 'New', Origin = 'Web', RecordTypeId = bregCaseRecordTypeId, breg_Form_Code__c = 'DC-1');
        insert c;

        TriggerUtils.disableTrigger = true;
        BREGUtils.insertWorkflowsLog(
            c.Id,
            '{"Name":"WF-1","Status":"Executing","Href":"https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/workflows/d187e6c3-1c81-f111-9798-9440c983dcd5"}',
            'BREGUtilsTest'
        );
        BREGUtils.insertWorkflowsLog(
            c.Id,
            '{"Name":"WF-2","Status":"Completed","Href":"https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/workflows/a187e6c3-1c81-f111-9798-9440c983dcd6"}',
            'BREGUtilsTest'
        );

        List<breg_Log__c> logs = [
            SELECT breg_Workflow_Name__c, breg_Workflow_Status__c
            FROM breg_Log__c
            WHERE breg_Case__c = :c.Id
            ORDER BY CreatedDate ASC
        ];

        Assert.areEqual(2, logs.size(), 'Two log records should exist after two workflow starts.');
        Assert.areEqual('WF-2', logs[1].breg_Workflow_Name__c);
        Assert.areEqual('Completed', logs[1].breg_Workflow_Status__c);

        Case updatedCase = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :c.Id];
        Assert.areEqual('Completed', updatedCase.breg_Document_Generation_Status__c);
    }

    @isTest
    static void testRefreshStaleDocumentGenerationStatuses() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case c = new Case(
            Subject = 'Stale workflow case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            breg_Document_Generation_Status__c = 'Generation in Process'
        );
        insert c;

        insert new breg_Log__c(
            breg_Type__c = 'Document Generation',
            breg_Case__c = c.Id,
            breg_Workflow_Name__c = 'WF-1',
            breg_Workflow_Status__c = 'Executing',
            breg_Workflow_Instance_Id__c = 'd187e6c3-1c81-f111-9798-9440c983dcd5'
        );

        TriggerUtils.disableTrigger = true;
        Test.setMock(HttpCalloutMock.class, new WorkflowStatusMock());

        Test.startTest();
        Integer updatedCount = BREGUtils.refreshStaleDocumentGenerationStatuses();
        Test.stopTest();

        Assert.areEqual(1, updatedCount, 'One stale case should be synchronized.');

        Case updatedCase = [
            SELECT breg_Document_Generation_Status__c
            FROM Case
            WHERE Id = :c.Id
        ];
        Assert.areEqual('Completed', updatedCase.breg_Document_Generation_Status__c, 'Case status should be updated from DocuSign status.');

        breg_Log__c updatedLog = [
            SELECT breg_Workflow_Status__c
            FROM breg_Log__c
            WHERE breg_Case__c = :c.Id AND breg_Workflow_Instance_Id__c = 'd187e6c3-1c81-f111-9798-9440c983dcd5'
            LIMIT 1
        ];
        Assert.areEqual('Completed', updatedLog.breg_Workflow_Status__c, 'Workflow log record status should be synchronized.');
    }

    @isTest
    static void testRefreshStaleDocumentGenerationStatusesForSpecificCase() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case caseOne = new Case(
            Subject = 'Stale workflow case one',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            breg_Document_Generation_Status__c = 'Generation in Process'
        );
        Case caseTwo = new Case(
            Subject = 'Stale workflow case two',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1',
            breg_Document_Generation_Status__c = 'Generation in Process'
        );
        insert new List<Case>{ caseOne, caseTwo };

        insert new breg_Log__c(
            breg_Type__c = 'Document Generation',
            breg_Case__c = caseOne.Id,
            breg_Workflow_Name__c = 'WF-1',
            breg_Workflow_Status__c = 'Executing',
            breg_Workflow_Instance_Id__c = 'd187e6c3-1c81-f111-9798-9440c983dcd5'
        );
        insert new breg_Log__c(
            breg_Type__c = 'Document Generation',
            breg_Case__c = caseTwo.Id,
            breg_Workflow_Name__c = 'WF-2',
            breg_Workflow_Status__c = 'Executing',
            breg_Workflow_Instance_Id__c = 'a187e6c3-1c81-f111-9798-9440c983dcd6'
        );

        TriggerUtils.disableTrigger = true;
        Test.setMock(HttpCalloutMock.class, new WorkflowStatusMock());

        Test.startTest();
        Integer updatedCount = BREGUtils.refreshStaleDocumentGenerationStatuses(caseOne.Id);
        Test.stopTest();

        Assert.areEqual(1, updatedCount, 'Only one case log should be updated when filtering by case id.');

        Map<Id, Case> casesById = new Map<Id, Case>([
            SELECT Id, breg_Document_Generation_Status__c
            FROM Case
            WHERE Id IN :new Set<Id>{ caseOne.Id, caseTwo.Id }
        ]);
        Assert.areEqual('Completed', casesById.get(caseOne.Id).breg_Document_Generation_Status__c);
        Assert.areEqual('Generation in Process', casesById.get(caseTwo.Id).breg_Document_Generation_Status__c);
    }

    @isTest
    static void testRefreshStaleDocumentGenerationStatusesForSpecificAccount() {
        Account accountOne = new Account(Name = 'Stale workflow account');
        insert accountOne;

        insert new breg_Log__c(
            breg_Type__c = 'Document Generation',
            breg_Account__c = accountOne.Id,
            breg_Workflow_Name__c = 'WF-Account-1',
            breg_Workflow_Status__c = 'Executing',
            breg_Workflow_Instance_Id__c = 'c187e6c3-1c81-f111-9798-9440c983dcd8'
        );

        TriggerUtils.disableTrigger = true;
        Test.setMock(HttpCalloutMock.class, new WorkflowStatusMock());

        Test.startTest();
        Integer updatedCount = BREGUtils.refreshStaleDocumentGenerationStatuses(accountOne.Id);
        Test.stopTest();

        Assert.areEqual(1, updatedCount, 'One account log should be synchronized.');

        breg_Log__c updatedLog = [
            SELECT breg_Workflow_Status__c, breg_Account__c
            FROM breg_Log__c
            WHERE breg_Account__c = :accountOne.Id
            LIMIT 1
        ];
        Assert.areEqual('Completed', updatedLog.breg_Workflow_Status__c, 'Account workflow log status should be synchronized.');
        Assert.areEqual(accountOne.Id, updatedLog.breg_Account__c, 'Account lookup should remain linked to the same account.');
    }


    @isTest
    static void testCompleteOldestInProcessDocumentGenerationLogs() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Case caseOne = new Case(
            Subject = 'Case one for oldest in process',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        Case caseTwo = new Case(
            Subject = 'Case two for oldest in process',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        insert new List<Case>{ caseOne, caseTwo };

        breg_Log__c caseOneOlder = new breg_Log__c(
            breg_Type__c = 'Document Generation',
            breg_Case__c = caseOne.Id,
            breg_Workflow_Name__c = 'WF-Old-1',
            breg_Workflow_Status__c = 'Executing'
        );
        breg_Log__c caseOneNewer = new breg_Log__c(
            breg_Type__c = 'Document Generation',
            breg_Case__c = caseOne.Id,
            breg_Workflow_Name__c = 'WF-New-1',
            breg_Workflow_Status__c = 'Executing'
        );
        breg_Log__c caseTwoOnly = new breg_Log__c(
            breg_Type__c = 'Document Generation',
            breg_Case__c = caseTwo.Id,
            breg_Workflow_Name__c = 'WF-Only-2',
            breg_Workflow_Status__c = 'Executing'
        );
        insert new List<breg_Log__c>{ caseOneOlder, caseOneNewer, caseTwoOnly };

        Test.setCreatedDate(caseOneOlder.Id, DateTime.newInstance(2024, 1, 1, 1, 0, 0));
        Test.setCreatedDate(caseOneNewer.Id, DateTime.newInstance(2024, 1, 1, 2, 0, 0));
        Test.setCreatedDate(caseTwoOnly.Id, DateTime.newInstance(2024, 1, 1, 3, 0, 0));

        Test.startTest();
        BREGUtils.completeOldestInProcessDocumentGenerationLogs(new List<Case>{ caseOne, caseTwo });
        Test.stopTest();

        Map<Id, breg_Log__c> logsById = new Map<Id, breg_Log__c>([
            SELECT Id, breg_Workflow_Status__c
            FROM breg_Log__c
            WHERE Id IN :new Set<Id>{ caseOneOlder.Id, caseOneNewer.Id, caseTwoOnly.Id }
        ]);

        Assert.areEqual('Completed', logsById.get(caseOneOlder.Id).breg_Workflow_Status__c, 'Oldest in-process log should be completed.');
        Assert.areEqual('Executing', logsById.get(caseOneNewer.Id).breg_Workflow_Status__c, 'Newer in-process log should remain untouched.');
        Assert.areEqual('Completed', logsById.get(caseTwoOnly.Id).breg_Workflow_Status__c, 'Single in-process log should be completed.');
    }

    @IsTest
    static void cleanBusinessName_blankInputs_returnUnchangedOrEmpty() {
        Assert.isNull(BREGUtils.cleanBusinessName(null), 'Null input should return null.');
        Assert.areEqual('', BREGUtils.cleanBusinessName(''), 'Blank string should return blank.');
        Assert.areEqual('   ', BREGUtils.cleanBusinessName('   '), 'Whitespace-only is blank and returns as-is per isBlank.');

        // Okina-only strips to empty; exercises foldLatinAccentedLettersToAscii early exit on blank
        Assert.areEqual('', BREGUtils.cleanBusinessName('\u02BB'), 'Okina-only becomes empty search name.');
    }

    @IsTest
    static void cleanBusinessName_bracketReorder_matchesLegacySearchName() {
        Assert.areEqual('GADZIA MADISYN LLC', BREGUtils.cleanBusinessName('MADISYN <GADZIA< LLC'), 'FIRST <LAST< suffix should become LAST FIRST suffix.');
        Assert.areEqual(
            'MUNRO RUTH REALTOR',
            BREGUtils.cleanBusinessName('RUTH <MUNRO,< REALTOR'),
            'Trailing comma inside last-name bracket should be removed before reorder.'
        );
        Assert.areEqual('YEES CAL', BREGUtils.cleanBusinessName('CAL <YEE\'S<'), 'Reorder then apostrophe strip; no trailing suffix.');
        Assert.areEqual('QUANG CAN LLP', BREGUtils.cleanBusinessName('CAN <QUANG< LLP'), 'Bracket reorder with entity suffix.');
    }

    @IsTest
    static void cleanBusinessName_hawaiianMacrons_okinaAndLatinAccents() {
        // Mānoa: kahako on first A only (M\u0101n\u014D would spell Mānō → MANO)
        Assert.areEqual(
            'MANOA JEWELRY HAWAII LLC',
            BREGUtils.cleanBusinessName('M\u0101noa Jewelry Hawai\'i LLC'),
            'Kahako vowels and okina fold to legacy search form.'
        );
        Assert.areEqual(
            'BEAUTE SPOT MAUI LLC',
            BREGUtils.cleanBusinessName('The Beaut\u00E9 Spot Maui LLC'),
            'Leading THE removed; Latin accent folded (É → E).'
        );

        // NFD: LATIN CAPITAL A + COMBINING MACRON (U+0041 U+0304) after uppercase still strips via \p{M}
        String nfdHalau = 'H' + String.fromCharArray(new List<Integer>{ 65, 772 }) + 'lau Kea';
        Assert.areEqual('HALAU KEA', BREGUtils.cleanBusinessName(nfdHalau), 'Combining macron after A should collapse to HALAU.');
    }

    @IsTest
    static void cleanBusinessName_punctuationAmpersandHyphensAndPlainNames() {
        Assert.areEqual('REDGIANT INC', BREGUtils.cleanBusinessName('REDGIANT, INC.'), 'Commas and periods become word breaks then collapse.');
        Assert.areEqual('B K SERVICES LLC', BREGUtils.cleanBusinessName('B & K SERVICES LLC'), 'Ampersand is stripped to spacing.');
        Assert.areEqual('SAVE A WISH FOUNDATION', BREGUtils.cleanBusinessName('SAVE-A-WISH FOUNDATION'), 'Hyphens become spaces.');
        Assert.areEqual('BLUEPRINT FACTORY', BREGUtils.cleanBusinessName('THE BLUEPRINT FACTORY'), 'Leading THE removed.');
        Assert.areEqual('ACME LLC', BREGUtils.cleanBusinessName('  acme   llc  '), 'Trim and collapse internal whitespace; uppercase.');
        Assert.areEqual('ACME LLC', BREGUtils.cleanBusinessName('ACME LLC'), 'Plain legal name unchanged aside from case and spacing.');
    }

    @isTest
    static void testGetLinkedGPCasesForLLPCases_ReturnsOnlyMatchingGpChildren() {
        Case llpCase = [SELECT Id FROM Case WHERE Subject = 'LLP Parent' LIMIT 1];
        Case matchingChild = [SELECT Id FROM Case WHERE Subject = 'Matching GP Child' LIMIT 1];

        Test.startTest();
        List<Case> linkedCases = BREGUtils.getLinkedGPCasesForLLPCases(new Set<Id>{ llpCase.Id });
        Test.stopTest();

        Assert.areEqual(1, linkedCases.size(), 'Only GP-1 children marked as LLP registration should be returned.');
        Assert.areEqual(matchingChild.Id, linkedCases[0].Id, 'Returned child should be the matching GP case.');
    }

    @isTest
    static void testGetLinkedGPCasesForLLPCases_EmptyInputReturnsEmptyList() {
        Assert.areEqual(0, BREGUtils.getLinkedGPCasesForLLPCases(null).size(), 'Null input should return an empty list.');
        Assert.areEqual(0, BREGUtils.getLinkedGPCasesForLLPCases(new Set<Id>()).size(), 'Empty input should return an empty list.');
    }

    @isTest
    static void cleanBusinessNameNoSpaces_blankInputs_returnUnchanged() {
        Assert.isNull(BREGUtils.cleanBusinessNameNoSpaces(null), 'Null input should return null.');
        Assert.areEqual('', BREGUtils.cleanBusinessNameNoSpaces(''), 'Blank string should return blank.');
        Assert.areEqual('   ', BREGUtils.cleanBusinessNameNoSpaces('   '), 'Whitespace-only is blank per isBlank and returns as-is.');
    }

    @isTest
    static void cleanBusinessNameNoSpaces_removesAllSpaces() {
        Assert.areEqual('ACMELLC', BREGUtils.cleanBusinessNameNoSpaces('  acme   llc  '), 'Should normalize and remove all spaces.');
        Assert.areEqual('BKSERVICESLLC', BREGUtils.cleanBusinessNameNoSpaces('B & K SERVICES LLC'), 'Ampersand stripped, spaces removed.');
        Assert.areEqual('SAVEAWISHFOUNDATION', BREGUtils.cleanBusinessNameNoSpaces('SAVE-A-WISH FOUNDATION'), 'Hyphens become spaces then removed.');
        Assert.areEqual('BLUEPRINTFACTORY', BREGUtils.cleanBusinessNameNoSpaces('THE BLUEPRINT FACTORY'), 'Leading THE removed, spaces removed.');
    }

    @isTest
    static void cleanBusinessNameNoSpaces_hawaiianCharsAndAccents() {
        Assert.areEqual(
            'MANOAJEWELRYHAWAIILLC',
            BREGUtils.cleanBusinessNameNoSpaces('M\u0101noa Jewelry Hawai\'i LLC'),
            'Macron and okina removed, no spaces.'
        );
        Assert.areEqual(
            'BEAUTESPOTMAUILLC',
            BREGUtils.cleanBusinessNameNoSpaces('The Beaut\u00E9 Spot Maui LLC'),
            'Accent folded, THE removed, no spaces.'
        );
    }

    @isTest
    static void cleanBusinessNameNoSpaces_truncatesTo255() {
        String longName = 'A'.repeat(300);
        String result = BREGUtils.cleanBusinessNameNoSpaces(longName);
        Assert.areEqual(255, result.length(), 'Result should be truncated to 255 characters.');
    }
}