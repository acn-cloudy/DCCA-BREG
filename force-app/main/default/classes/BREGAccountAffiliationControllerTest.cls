@isTest
public class BREGAccountAffiliationControllerTest {
    @testSetup
    static void setupData() {
        // Create test Account with comprehensive data
        Account testAccount = new Account(
            Name = 'Test Corporation',
            Description = 'Test Description',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            //BillingState = 'HI',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountry = 'United States',
            BillingCountryCode = 'US',
            ShippingStreet = '456 Oak Ave',
            ShippingCity = 'Hilo',
            //ShippingState = 'HI',
            ShippingStateCode = 'HI',
            ShippingPostalCode = '96720',
            ShippingCountry = 'United States',
            ShippingCountryCode = 'US',
            breg_File__c = '12345-D1',
            breg_Business_Structure__c = 'Corporation',
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)',
            breg_Formation_Date__c = Date.newInstance(2020, 1, 1),
            breg_Good_Standing__c = true
        );
        insert testAccount;

        // Create test Contact for Account Affiliations
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            AccountId = testAccount.Id,
            MailingStreet = '789 Pine Rd',
            MailingCity = 'Kailua',
            //MailingState = 'HI',
            MailingStateCode = 'HI',
            MailingPostalCode = '96734',
            MailingCountry = 'United States'
        );
        insert testContact;

        // Create Account Affiliations for Account
        List<breg_Account_Affiliation__c> accountAffiliations = new List<breg_Account_Affiliation__c>();
        accountAffiliations.add(
            new breg_Account_Affiliation__c(
                breg_Account__c = testAccount.Id,
                breg_Contact__c = testContact.Id,
                breg_Entity__c = testAccount.Id,
                breg_Role__c = 'Director',
                breg_Type__c = 'Entity',
                breg_Officer_Director_Titles__c = 'AC',
                breg_Start_Date__c = Date.newInstance(2020, 1, 1),
                breg_End_Date__c = null,
                breg_Status__c = 'A',
                breg_First_Name__c = 'John',
                breg_Last_Name__c = 'Doe'
            )
        );
        accountAffiliations.add(
            new breg_Account_Affiliation__c(
                breg_Account__c = testAccount.Id,
                breg_Contact__c = testContact.Id,
                breg_Entity__c = testAccount.Id,
                breg_Role__c = 'Officer',
                breg_Type__c = 'Entity',
                breg_Officer_Director_Titles__c = 'AC',
                breg_Start_Date__c = Date.newInstance(2020, 6, 1),
                breg_End_Date__c = null,
                breg_Status__c = 'A',
                breg_First_Name__c = 'Jane',
                breg_Last_Name__c = 'Smith'
            )
        );
        // Add an inactive affiliation that should be filtered out
        accountAffiliations.add(
            new breg_Account_Affiliation__c(
                breg_Account__c = testAccount.Id,
                breg_Entity__c = testAccount.Id,
                breg_Role__c = 'Officer',
                breg_Type__c = 'Entity',
                breg_Officer_Director_Titles__c = 'AC',
                breg_Start_Date__c = Date.newInstance(2019, 1, 1),
                breg_End_Date__c = Date.newInstance(2019, 12, 31),
                breg_Status__c = 'I',
                breg_First_Name__c = 'Bob',
                breg_Last_Name__c = 'Johnson'
            )
        );
        insert accountAffiliations;

        // Create Annual Reports
        List<breg_Annual__c> annuals = new List<breg_Annual__c>();
        annuals.add(
            new breg_Annual__c(
                breg_Account__c = testAccount.Id,
                breg_Status__c = 'N',
                breg_Filing_Date__c = Date.newInstance(2023, 4, 1),
                breg_Filing_Year__c = '2023',
                breg_Received_Date__c = DateTime.newInstance(2023, 3, 15, 0, 0, 0)
            )
        );
        annuals.add(
            new breg_Annual__c(
                breg_Account__c = testAccount.Id,
                breg_Status__c = 'D',
                breg_Filing_Date__c = Date.newInstance(2024, 1, 10),
                breg_Filing_Year__c = '2024',
                breg_Received_Date__c = DateTime.newInstance(2024, 2, 10, 0, 0, 0)
            )
        );
        insert annuals;

        // Create Stock records (both active and historical)
        List<breg_Stock__c> stocks = new List<breg_Stock__c>();
        // Active stocks
        stocks.add(
            new breg_Stock__c(
                breg_Account__c = testAccount.Id,
                breg_Stock_Class__c = 'Common',
                breg_Number_of_Issued_Shares__c = '1000',
                breg_Class_Series__c = 'A',
                breg_Per_Value__c = '1.00',
                breg_Start_Date__c = Date.newInstance(2020, 1, 1),
                breg_End_Date__c = null
            )
        );
        stocks.add(
            new breg_Stock__c(
                breg_Account__c = testAccount.Id,
                breg_Stock_Class__c = 'Preferred',
                breg_Number_of_Issued_Shares__c = '500',
                breg_Class_Series__c = 'B',
                breg_Per_Value__c = '10.00',
                breg_Start_Date__c = Date.newInstance(2021, 1, 1),
                breg_End_Date__c = null
            )
        );
        // Historical stocks (ended)
        stocks.add(
            new breg_Stock__c(
                breg_Account__c = testAccount.Id,
                breg_Stock_Class__c = 'Common',
                breg_Number_of_Issued_Shares__c = '500',
                breg_Class_Series__c = 'A',
                breg_Per_Value__c = '1.00',
                breg_Start_Date__c = Date.newInstance(2019, 1, 1),
                breg_End_Date__c = Date.newInstance(2019, 12, 31)
            )
        );
        stocks.add(
            new breg_Stock__c(
                breg_Account__c = testAccount.Id,
                breg_Stock_Class__c = 'Common',
                breg_Number_of_Issued_Shares__c = '750',
                breg_Class_Series__c = 'A',
                breg_Per_Value__c = '1.00',
                breg_Start_Date__c = Date.newInstance(2018, 1, 1),
                breg_End_Date__c = Date.newInstance(2018, 12, 31)
            )
        );
        stocks.add(
            new breg_Stock__c(
                breg_Account__c = testAccount.Id,
                breg_Stock_Class__c = 'Preferred',
                breg_Number_of_Issued_Shares__c = '300',
                breg_Class_Series__c = 'B',
                breg_Per_Value__c = '10.00',
                breg_Start_Date__c = Date.newInstance(2019, 1, 1),
                breg_End_Date__c = Date.newInstance(2020, 12, 31)
            )
        );
        insert stocks;

        // Create TN_TM_SM record
        breg_TN_TM_SM__c tradeName = new breg_TN_TM_SM__c(
            breg_Account__c = testAccount.Id,
            breg_Trade_Name__c = 'Test Trade Name',
            breg_File__c = 'TN-12345',
            breg_Type__c = 'Trade Name',
            breg_Status__c = 'A',
            breg_Registration_Date__c = Date.newInstance(2021, 5, 1),
            breg_Start_Date__c = Date.newInstance(2021, 5, 1)
        );
        insert tradeName;

        // Create Account Affiliation for TN_TM_SM
        breg_Account_Affiliation__c tnAffiliation = new breg_Account_Affiliation__c(
            breg_TN_TM_SM__c = tradeName.Id,
            breg_Contact__c = testContact.Id,
            breg_Role__c = 'Assignee',
            breg_Type__c = 'Individual',
            breg_Status__c = 'A',
            breg_Start_Date__c = Date.newInstance(2021, 5, 1),
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe'
        );
        insert tnAffiliation;
    }

    @isTest
    static void testGetAccountWithRelationshipsById_Success() {
        Account testAccount = [SELECT Id, breg_File__c FROM Account WHERE Name = 'Test Corporation' LIMIT 1];

        Test.startTest();
        Account result = BREGAccountAffiliationController.getAccountWithRelationshipsById(testAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Account should not be null');
        System.assertEquals('Test Corporation', result.Name, 'Account name should match');
        System.assertEquals(testAccount.breg_File__c, result.breg_File__c, 'File number should match');

        // Verify Account Affiliations are loaded and filtered correctly
        System.assertEquals(2, result.breg_Account_Affiliations_Entity__r.size(), 'Should have 2 active affiliations');

        // Verify Annuals are loaded
        System.assertEquals(2, result.Annuals__r.size(), 'Should have 2 annual reports');

        // Verify Stocks are loaded (only active ones)
        System.assertEquals(2, result.Stocks__r.size(), 'Should have 2 active stocks');
    }

    @isTest
    static void testGetAccountWithRelationshipsByFileNumber_Success() {
        Test.startTest();
        Account acc = [SELECT Id, breg_File__c FROM Account WHERE Name = 'Test Corporation' LIMIT 1];
        Account result = BREGAccountAffiliationController.getAccountWithRelationshipsByFileNumber(acc.breg_File__c);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Account should not be null');
        System.assertEquals('Test Corporation', result.Name, 'Account name should match');
        System.assertEquals(acc.breg_File__c, result.breg_File__c, 'File number should match');

        // Verify relationships are loaded
        System.assertEquals(2, result.breg_Account_Affiliations_Entity__r.size(), 'Should have 2 active affiliations');
        System.assertEquals(2, result.Annuals__r.size(), 'Should have 2 annual reports');
        System.assertEquals(2, result.Stocks__r.size(), 'Should have 2 active stocks');
    }

    @isTest
    static void testGetAccountWithRelationshipsByFileNumber_WithSuffix() {
        // Test with file number that has suffix
        Account acc = [SELECT Id, breg_File__c FROM Account WHERE Name = 'Test Corporation' LIMIT 1];
        Test.startTest();
        Account result = BREGAccountAffiliationController.getAccountWithRelationshipsByFileNumber(acc.breg_File__c);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Account should not be null');
        System.assertEquals('Test Corporation', result.Name, 'Account name should match');
    }

    @isTest
    static void testGetTNTMSMWithRelationships_Success() {
        breg_TN_TM_SM__c tradeName = [SELECT Id FROM breg_TN_TM_SM__c LIMIT 1];

        Test.startTest();
        breg_TN_TM_SM__c result = BREGAccountAffiliationController.getTNTMSMWithRelationships(tradeName.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'TN_TM_SM record should not be null');
        System.assertEquals('Test Trade Name', result.breg_Trade_Name__c, 'Trade name should match');
        System.assertEquals('TN-12345', result.breg_File__c, 'File number should match');
        System.assertEquals('A', result.breg_Status__c, 'Status should match');

        // Verify Account Affiliations are loaded
        System.assertEquals(1, result.breg_Account_Affiliations__r.size(), 'Should have 1 affiliation');
        System.assertEquals('Assignee', result.breg_Account_Affiliations__r[0].breg_Role__c, 'Role should be Assignee');
    }

    @isTest
    static void testGetHistoricalStocks_Success() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Corporation' LIMIT 1];

        Test.startTest();
        List<breg_Stock__c> result = BREGAccountAffiliationController.getHistoricalStocks(testAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Historical stocks list should not be null');

        // Should return only the most recent historical stock per class
        // We have 2 historical Common stocks (2019 and 2018) - should get only 2019
        // We have 1 historical Preferred stock (2019) - should get that one
        System.assertEquals(2, result.size(), 'Should have 2 historical stocks (most recent per class)');

        // Verify each stock class appears only once
        Set<String> stockClasses = new Set<String>();
        for (breg_Stock__c stock : result) {
            System.assertEquals(false, stockClasses.contains(stock.breg_Stock_Class__c), 'Each stock class should appear only once');
            stockClasses.add(stock.breg_Stock_Class__c);
        }

        // Verify ordering and that we got the most recent ones
        for (breg_Stock__c stock : result) {
            if (stock.breg_Stock_Class__c == 'Common') {
                System.assertEquals(Date.newInstance(2019, 12, 31), stock.breg_End_Date__c, 'Should return most recent Common stock (2019)');
            } else if (stock.breg_Stock_Class__c == 'Preferred') {
                System.assertEquals(Date.newInstance(2020, 12, 31), stock.breg_End_Date__c, 'Should return most recent Preferred stock (2019-2020)');
            }
        }
    }

    @isTest
    static void testGetHistoricalStocks_NoHistoricalStocks() {
        // Create a new account without historical stocks
        Account newAccount = new Account(Name = 'New Test Corp', breg_File__c = '99999-D1', breg_Entity_Type__c = 'D1');
        insert newAccount;

        // Add only active stock
        breg_Stock__c activeStock = new breg_Stock__c(
            breg_Account__c = newAccount.Id,
            breg_Stock_Class__c = 'Common',
            breg_Number_of_Issued_Shares__c = '1000',
            breg_Start_Date__c = Date.newInstance(2024, 1, 1),
            breg_End_Date__c = null
        );
        insert activeStock;

        Test.startTest();
        List<breg_Stock__c> result = BREGAccountAffiliationController.getHistoricalStocks(newAccount.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should have no historical stocks');
    }

    @isTest
    static void testGetHistoricalStocks_EmptyResult() {
        // Create account with no stocks at all
        Account newAccount = new Account(Name = 'Empty Stock Corp', breg_File__c = '88888-D1', breg_Entity_Type__c = 'D1');
        insert newAccount;

        Test.startTest();
        List<breg_Stock__c> result = BREGAccountAffiliationController.getHistoricalStocks(newAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
}