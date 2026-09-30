@IsTest
private class BREGTestDataFactoryTest {
    @IsTest
    static void testCreatesCoreFactoryData() {
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(2);
        List<breg_Notification_Category__mdt> categories = BREGTestDataFactory.getAllCategories();
        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();
        BREGTestDataFactory.createFeeSettings();
        BREGTestDataFactory.createFileNumberSequences();

        System.assertEquals(2, accounts.size(), 'Expected two test accounts');
        System.assertEquals('D1', accounts[0].breg_Entity_Type__c, 'Entity accounts should use the default test entity type');
        System.assertEquals(2, categories.size(), 'Expected two notification categories');
        System.assertEquals(8, forms.size(), 'Expected eight form configurations');
        System.assertEquals(2, [SELECT COUNT() FROM breg_Fee__c], 'Expected two fee settings');
        System.assertEquals(8, [SELECT COUNT() FROM BREG_File_Number_Sequence__c], 'Expected eight file number sequences');
    }

    @IsTest
    static void testCreatesRegistrationCases() {
        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();

        List<Case> cases = BREGTestDataFactory.createRegistrationCases(forms);

        System.assertEquals(32, cases.size(), 'Expected four cases per form configuration');
        System.assertEquals('Completed', [SELECT pymt__Status__c FROM pymt__PaymentX__c LIMIT 1].pymt__Status__c, 'Registration cases should create completed payments');
    }

    @IsTest
    static void testCreatesAnnuals() {
        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();
        List<breg_Form_Configuration__c> singleForm = new List<breg_Form_Configuration__c>{ forms[0] };

        List<breg_Annual__c> annuals = BREGTestDataFactory.createAnnuals(singleForm);

        System.assertEquals(4, annuals.size(), 'Expected one annual per generated case');
        System.assertEquals(4, [SELECT COUNT() FROM Case WHERE breg_Annual__c != NULL], 'Annual helper should link annuals back to cases');
    }

    @IsTest
    static void testCreatesTransactionLines() {
        breg_Entity_List__c entityList = new breg_Entity_List__c(breg_Status__c = 'All');
        insert entityList;

        breg_Agent_Search_List__c agentSearchList = new breg_Agent_Search_List__c(
            breg_Agents_JSON__c = '[{"name":"Test Agent","address":"123 Test St"}]'
        );
        insert agentSearchList;

        BREGTestDataFactory.createTransactionLineForEntityList(entityList.Id);
        BREGTestDataFactory.createTransactionLineForAgentSearch(agentSearchList.Id);

        TransactionLine__c entityListLine = [
            SELECT Amount__c, Description__c, breg_Type__c, breg_Entity_List__c
            FROM TransactionLine__c
            WHERE breg_Entity_List__c = :entityList.Id
            LIMIT 1
        ];
        TransactionLine__c agentSearchLine = [
            SELECT Amount__c, Description__c, breg_Type__c, breg_Agent_Search_List__c
            FROM TransactionLine__c
            WHERE breg_Agent_Search_List__c = :agentSearchList.Id
            LIMIT 1
        ];

        System.assertEquals(0.05, entityListLine.Amount__c, 'Entity list helper should create the default priced line');
        System.assertEquals('Entity List', entityListLine.breg_Type__c, 'Entity list helper should set the type');
        System.assertEquals(2.05, agentSearchLine.Amount__c, 'Agent search helper should create the expected priced line');
        System.assertEquals('Agent Search List', agentSearchLine.breg_Type__c, 'Agent search helper should set the type');
    }
}