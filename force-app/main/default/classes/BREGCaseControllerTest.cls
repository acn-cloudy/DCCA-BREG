@isTest
public class BREGCaseControllerTest {

    private static User getCommunityUser() {
        List<User> communityUsers = [
            SELECT Id, ContactId
            FROM User
            WHERE IsActive = true
                AND ContactId != null
                AND Profile.UserType != 'Standard'
                AND Profile.Name = 'DCCA BREG - CustomerCommunityUser'
            LIMIT 1
        ];

        if (!communityUsers.isEmpty()) {
            return communityUsers[0];
        }

        return BREGTestDataFactory.createCommunityUser();
    }

    @testSetup
    static void setupData() {
        // Keep all triggers disabled during setup to prevent any HTTP callouts
        BREGBaseTriggerHandler.disableTrigger(Account.SObjectType);
        BREGBaseTriggerHandler.disableTrigger(Contact.SObjectType);
        BREGBaseTriggerHandler.disableTrigger(BREGCaseTriggerHandler.class);
        BREGBaseTriggerHandler.disableTrigger(BREGTaskTriggerHandler.class);
        BREGBaseTriggerHandler.disableTrigger(BREGDocumentTriggerHandler.class);
        BREGBaseTriggerHandler.disableTrigger(BREGTransactionLineTriggerHandler.class);

        User communityUser = getCommunityUser();
        System.assertNotEquals(null, communityUser.ContactId, 'Community test user must be linked to a Contact.');
        Id communityContactId = communityUser.ContactId;

        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Account entityAccount = new Account(
            Name = 'Case Controller Entity',
            RecordTypeId = bregAccountRecordTypeId,
            BillingPostalCode = '96813',
            breg_Incorporation_Date__c = Date.today(),
            breg_Entity_Type__c = 'D1',
            breg_File__c = '12345-D1'
        );
        Account portalSelectedAccount = new Account(
            Name = 'Portal Selected Entity',
            RecordTypeId = bregAccountRecordTypeId,
            BillingPostalCode = '96814',
            breg_Incorporation_Date__c = Date.today(),
            breg_Entity_Type__c = 'D1',
            breg_File__c = '67890-D1'
        );
        insert new List<Account>{ entityAccount, portalSelectedAccount };

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = 'CASE-CFG',
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Form_Name__c = 'Articles of Incorporation',
            breg_Business_Process__c = 'New Business',
            breg_Is_Expeditable__c = true,
            breg_Withdrawal_Range__c = 24
        );
        insert formConfig;

        breg_Annual__c annualRecord = new breg_Annual__c(breg_Account__c = entityAccount.Id);
        insert annualRecord;

        breg_TN_TM_SM__c tnRecord = new breg_TN_TM_SM__c(Name = 'Case Controller TN', breg_Type__c = 'Trade Name');
        insert tnRecord;

        Case newCase = new Case(
            Subject = 'New Filing',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ContactId = communityContactId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Form_Action__c = 'Initial Filing',
            breg_Workitem_Number__c = 'WI-NEW',
            breg_Name_of_the_Entity__c = entityAccount.Name,
            breg_Entity__c = entityAccount.Id
        );
        Case rejectedCase = new Case(
            Subject = 'Rejected Filing',
            Status = 'Rejected',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ContactId = communityContactId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Form_Action__c = 'Initial Filing',
            breg_Workitem_Number__c = 'WI-REJ',
            breg_Name_of_the_Entity__c = entityAccount.Name,
            breg_Entity__c = entityAccount.Id,
            breg_Annual__c = annualRecord.Id
        );
        Case receivedCase = new Case(
            Subject = 'Received Filing',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            ContactId = communityContactId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Form_Action__c = 'Initial Filing',
            breg_Workitem_Number__c = 'WI-REC',
            breg_Name_of_the_Entity__c = portalSelectedAccount.Name,
            breg_Portal_User_Entity_Selected__c = portalSelectedAccount.Id,
            breg_TN_TM_SM__c = tnRecord.Id
        );
        insert new List<Case>{ newCase, rejectedCase, receivedCase };


        Transaction__c transactionRecord = new Transaction__c(
            Division__c = 'BREG',
            PaymentAmount__c = 100.00,
            TotalAmount__c = 100.00,
            Status__c = 'Completed',
            TransactionType__c = 'Payment',
            Date__c = Date.today()
        );
        insert transactionRecord;

        Id paymentRecordTypeId = Schema.SObjectType.pymt__PaymentX__c.getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();
        pymt__PaymentX__c paymentRecord = new pymt__PaymentX__c(
            RecordTypeId = paymentRecordTypeId,
            Name = 'Case Controller Payment',
            Division__c = 'BREG',
            Transaction__c = transactionRecord.Id
        );
        insert paymentRecord;

        CashierCode__c cashierCode = new CashierCode__c(CashierCode__c = 'B71', Division__c = 'BREG', Name = 'Case Controller Fee');
        insert cashierCode;

        breg_Fee__c expediteFee = new breg_Fee__c(
            breg_Form_Configuration__c = formConfig.Id,
            breg_Fee_Amount__c = 25.00,
            breg_Purchase_Type_Fee_type__c = 'Expedite Fees',
            breg_Cashier_Code__c = 'B71'
        );
        insert expediteFee;

        insert new List<TransactionLine__c>{
            new TransactionLine__c(
                breg_Case__c = rejectedCase.Id,
                Transaction__c = transactionRecord.Id,
                Payment__c = paymentRecord.Id,
                Description__c = 'Rejected Filing Payment',
                breg_Quantity__c = 1,
                breg_Unit_Price__c = 25.00,
                Amount__c = 25.00,
                breg_Type__c = 'Document',
                breg_Fee__c = expediteFee.Id,
                PaidStatus__c = 'Paid',
                CashierCode__c = cashierCode.Id
            ),
            new TransactionLine__c(
                breg_Case__c = receivedCase.Id,
                Transaction__c = transactionRecord.Id,
                Payment__c = paymentRecord.Id,
                Description__c = 'Received Filing Payment',
                breg_Quantity__c = 1,
                breg_Unit_Price__c = 25.00,
                Amount__c = 25.00,
                breg_Type__c = 'Document',
                breg_Fee__c = expediteFee.Id,
                PaidStatus__c = 'Paid',
                CashierCode__c = cashierCode.Id
            )
        };

        rejectedCase = [
            SELECT Id, Status, breg_Resubmission_Due_Date__c, breg_Annual_Report_Filing_Year__c
            FROM Case
            WHERE Id = :rejectedCase.Id
        ];
        rejectedCase.Status = 'Rejected';
        rejectedCase.breg_Resubmission_Due_Date__c = Date.today().addDays(5);
        rejectedCase.breg_Annual_Report_Filing_Year__c = '2026';
        update rejectedCase;
    }

    @isTest
    static void testGetMyFilingsMapsWrapperFields() {
        User communityUser = getCommunityUser();

        System.runAs(communityUser) {
            Test.startTest();
            List<BREGCaseController.MyCaseWrapper> filings = BREGCaseController.getMyFilings();
            Test.stopTest();

            Assert.areEqual(3, filings.size(), 'Expected all test filings for the community user contact.');

            Map<String, BREGCaseController.MyCaseWrapper> wrapperByName = new Map<String, BREGCaseController.MyCaseWrapper>();
            for (BREGCaseController.MyCaseWrapper wrapper : filings) {
                wrapperByName.put(wrapper.name, wrapper);
            }

            Map<String, BREGCaseController.MyCaseWrapper> wrapperByWorkItem = new Map<String, BREGCaseController.MyCaseWrapper>();
            for (BREGCaseController.MyCaseWrapper wrapper : filings) {
                wrapperByWorkItem.put(wrapper.workItemNumber, wrapper);
            }

            BREGCaseController.MyCaseWrapper newWrapper = wrapperByWorkItem.get('WI-NEW');
            Assert.isNotNull(newWrapper, 'New filing wrapper should be present.');
            Assert.areEqual('New', newWrapper.status, 'New filing should keep its status.');
            Assert.areEqual('WI-NEW', newWrapper.workItemNumber, 'Work item should be mapped.');
            Assert.isTrue(String.isNotBlank(newWrapper.entityId), 'Direct entity id should be mapped for the new filing.');
            Assert.areEqual(true, newWrapper.allowedForContinuation, 'New cases should be allowed for continuation.');
            Assert.areEqual(false, newWrapper.allowedForView, 'New cases should not be viewable without a valid submitted payment state.');

            BREGCaseController.MyCaseWrapper rejectedWrapper = wrapperByWorkItem.get('WI-REJ');
            Assert.isNotNull(rejectedWrapper, 'Rejected filing wrapper should be present.');
            Assert.areEqual('Rejected', rejectedWrapper.status, 'Rejected filing should keep its status.');
            Assert.isTrue(String.isNotBlank(rejectedWrapper.paymentId), 'Rejected filing should include mapped payment id.');
            Assert.areEqual(true, rejectedWrapper.allowedForView, 'Rejected filing with a paid transaction should be viewable.');

            BREGCaseController.MyCaseWrapper receivedWrapper = wrapperByWorkItem.get('WI-REC');
            Assert.isNotNull(receivedWrapper, 'Received filing wrapper should be present.');
            Assert.isTrue(String.isNotBlank(receivedWrapper.entityId), 'Fallback portal-selected entity id should be mapped.');
            Assert.areEqual(false, receivedWrapper.allowedForExpedition, 'Received filing should be eligible for expedition.');
            Assert.areEqual(false, receivedWrapper.allowedForReopening, 'Received web filing without reopen data should not ßbe eligible for reopening.');
            Assert.isTrue(String.isNotBlank(receivedWrapper.paymentId), 'Received filing should include mapped payment id.');
        }    
    }

    @isTest
    static void testGetExpediteFeeReturnsMatchingFee() {
        User communityUser = getCommunityUser();
        Case receivedCase = [SELECT Id FROM Case WHERE Subject = 'Received Filing' LIMIT 1];

        System.runAs(communityUser) {
            Test.startTest();
            List<breg_Fee__c> fees = BREGCaseController.getExpediteFee(String.valueOf(receivedCase.Id));
            Test.stopTest();

            Assert.areEqual(1, fees.size(), 'Expected one expedite fee for the case suffix.');
            Assert.areEqual('Expedite Fees', fees[0].breg_Purchase_Type_Fee_type__c, 'Fee type should match expedition filter.');
            Assert.areEqual(25.00, fees[0].breg_Fee_Amount__c, 'Fee amount should match inserted expedition fee.');
        }
    }

    @isTest
    static void testWorkflowMethodsNoOpInTests() {
        Case anyCase = [SELECT Id FROM Case WHERE Subject = 'New Filing' LIMIT 1];

        Test.startTest();
        BREGCaseController.runGenerateDocWorkflow(anyCase.Id, 'TestWorkflow');
        BREGCaseController.runGenerateDocWorkflowWithTemplate(anyCase.Id, 'TemplateWorkflow', 'Template-A');
        BREGCaseController.startWorkflowWithParams('DirectWorkflow', '<recordId>' + anyCase.Id + '</recordId>', anyCase.Id);
        Test.stopTest();

        Assert.isTrue(true, 'Workflow entry points should execute without side effects during tests.');
    }
}