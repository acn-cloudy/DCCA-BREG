@isTest
public class BREGAnnualsControllerTest {
    @testSetup
    static void setupData() {
        BREGTestDataFactory.createFileNumberSequences();
        // Create test Accounts via factory
        List<Account> accounts = BREGTestDataFactory.createEntityAccounts(1);
        accounts[0].breg_File__c = '12345D1';
        update accounts;

        List<breg_Annual__c> annuals = new List<breg_Annual__c>();
        annuals.add(
            new breg_Annual__c(
                breg_Account__c = accounts[0].Id,
                breg_Status__c = 'N',
                breg_Filing_Date__c = Date.newInstance(2024, 4, 1),
                breg_Filing_Year__c = '2024',
                breg_Received_Date__c = null
            )
        );
        annuals.add(
            new breg_Annual__c(
                breg_Account__c = accounts[0].Id,
                breg_Status__c = 'D',
                breg_Filing_Date__c = Date.newInstance(2023, 4, 1),
                breg_Filing_Year__c = '2023',
                breg_Received_Date__c = DateTime.newInstance(2023, 3, 1, 0, 0, 0)
            )
        );
        insert annuals;
    }

    @isTest
    static void testGetAccountDataByAccountId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Inc.' LIMIT 1];

        Test.startTest();
        BREGAnnualsController.AccountDataWrapper result = BREGAnnualsController.getAccountData(null, acc.Id);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual(acc.Id, result.accountId);
        Assert.areEqual('Acme Inc.', result.accountName);
        Assert.areEqual('D1', result.entityType);
        Assert.areNotEqual(null, result.annuals);
        Assert.areEqual(2, result.annuals.size());
    }

    @isTest
    static void testGetAccountDataByFileNumber() {
        Test.startTest();
        BREGAnnualsController.AccountDataWrapper result = BREGAnnualsController.getAccountData('12345D1', null);
        Test.stopTest();

        Assert.areNotEqual(null, result);
        Assert.areEqual('Acme Inc.', result.accountName);
        Assert.areEqual('12345D1', result.fileNumber);
        Assert.areNotEqual(null, result.annuals);
    }

    @isTest
    static void testGetAccountDataAnnualStatusN_ActionText() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Inc.' LIMIT 1];

        Test.startTest();
        BREGAnnualsController.AccountDataWrapper result = BREGAnnualsController.getAccountData(null, acc.Id);
        Test.stopTest();

        BREGAnnualsController.AnnualWrapper annualN = null;
        for (BREGAnnualsController.AnnualWrapper w : result.annuals) {
            if (w.status == 'N') {
                annualN = w;
                break;
            }
        }

        Assert.areNotEqual(null, annualN, 'Annual with status N should exist');
        Assert.areEqual('2024', annualN.filingYear);
        Assert.isTrue(annualN.actionText.startsWith('Begin'), 'Action text for N status should start with Begin');
        Assert.isTrue(annualN.actionText.contains('Annual Report'), 'Action text for N status should contain Annual Report');
    }

    @isTest
    static void testGetAccountDataAnnualStatusD_ActionText() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Inc.' LIMIT 1];

        Test.startTest();
        BREGAnnualsController.AccountDataWrapper result = BREGAnnualsController.getAccountData(null, acc.Id);
        Test.stopTest();

        BREGAnnualsController.AnnualWrapper annualD = null;
        for (BREGAnnualsController.AnnualWrapper w : result.annuals) {
            if (w.status == 'D') {
                annualD = w;
                break;
            }
        }

        Assert.areNotEqual(null, annualD, 'Annual with status D should exist');
        Assert.areEqual('2023', annualD.filingYear);
        Assert.isTrue(annualD.actionText.startsWith('Begin'), 'Action text for D status should start with Begin');
        Assert.areNotEqual(null, annualD.receivedDate, 'Received date should be populated');
    }

    @isTest
    static void testGetAccountDataNoAnnuals() {
        Account acc2 = new Account(
            Name = 'No Annuals Entity',
            BillingPostalCode = '12345',
            breg_Incorporation_Date__c = Date.newInstance(2022, 6, 1),
            breg_File__c = 'D1-002',
            breg_Entity_Type__c = 'D1'
        );
        insert acc2;

        Test.startTest();
        BREGAnnualsController.AccountDataWrapper result = BREGAnnualsController.getAccountData(null, acc2.Id);
        Test.stopTest();

        Assert.areNotEqual(null, result);
        Assert.areEqual('No Annuals Entity', result.accountName);
        Assert.isNull(result.annuals, 'Annuals list should be null when no matching annuals exist');
    }

    @isTest
    static void testGetAnnualFillingsForInternalUser() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Inc.' LIMIT 1];

        Test.startTest();
        Account result = BREGAnnualsController.getAnnualFillingsForInternalUser(acc.Id);
        Test.stopTest();

        Assert.areNotEqual(null, result);
        Assert.areEqual(acc.Id, result.Id);
        Assert.areEqual('D1', result.breg_Entity_Type__c);
        Assert.areNotEqual(null, result.Annuals__r);
        Assert.isTrue(result.Annuals__r.size() > 0, 'Should return at least one annual');
    }

    @isTest
    static void testGetProcessingPrices() {
        List<BREG_Setting__c> existing = [SELECT Id FROM BREG_Setting__c];
        if (!existing.isEmpty()) {
            delete existing;
        }

        BREG_Setting__c setting = new BREG_Setting__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normal_Processing_Price__c = 25.00,
            Expedited_Processing_Price__c = 50.00,
            Archive_Fee__c = 10.00,
            Penalty_Fee__c = 75.00,
            Online_report_discount__c = 5.00
        );
        insert setting;

        Test.startTest();
        Map<String, Decimal> prices = BREGAnnualsController.getProcessingPrices();
        Test.stopTest();

        Assert.areNotEqual(null, prices);
        Assert.areEqual(5, prices.size());
        Assert.areEqual(25.00, prices.get('normal'));
        Assert.areEqual(50.00, prices.get('expedited'));
        Assert.areEqual(10.00, prices.get('archive'));
        Assert.areEqual(75.00, prices.get('penalty'));
        Assert.areEqual(5.00, prices.get('discount'));
    }

    @isTest
    static void testGetAnnualIdByAccountAndYear_Found() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Inc.' LIMIT 1];

        Test.startTest();
        String result = BREGAnnualsController.getAnnualIdByAccountAndYear(acc.Id, '2024');
        Test.stopTest();

        breg_Annual__c annual = [
            SELECT Id
            FROM breg_Annual__c
            WHERE breg_Account__c = :acc.Id AND breg_Filing_Year__c = '2024'
            LIMIT 1
        ];
        Assert.areEqual(annual.Id, result, 'Should return the matching Annual Id');
    }

    @isTest
    static void testGetAnnualIdByAccountAndYear_NotFound() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Inc.' LIMIT 1];

        Test.startTest();
        String result = BREGAnnualsController.getAnnualIdByAccountAndYear(acc.Id, '1900');
        Test.stopTest();

        Assert.isNull(result, 'Should return null when no annual found for the given year');
    }
}