@isTest
private class BREGAnnualTriggerHandlerTest {
 @IsTest
    static void testPopulateUniqueKey() {
        // Create a dummy Account
         List<Account> accounts = BREGTestDataFactory.createEntityAccounts(3);

        // Create Annual record
        breg_Annual__c annual = new breg_Annual__c(
            breg_Account__c = accounts[0].Id,
            breg_Filing_Year__c = '2025'
        );

        insert annual;

        // Retrieve to verify key was populated
        annual = [SELECT breg_Unique_Key__c, breg_Account__c, breg_Filing_Year__c
                  FROM breg_Annual__c
                  WHERE Id = :annual.Id];

        System.assertEquals(accounts[0].Id + '-2025', annual.breg_Unique_Key__c);

        // Test update logic
        annual.breg_Filing_Year__c = '2026';
        update annual;

        annual = [SELECT breg_Unique_Key__c FROM breg_Annual__c WHERE Id = :annual.Id];
        System.assertEquals(accounts[0].Id + '-2026', annual.breg_Unique_Key__c);
    }
}