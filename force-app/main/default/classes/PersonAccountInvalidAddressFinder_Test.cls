@isTest
private class PersonAccountInvalidAddressFinder_Test {

    // Helper method to fetch the Person Account Record Type ID (remains the same)
    private static Id getPersonAccountRecordTypeId() {
        // 1. Try to find the RecordType by the standard Developer Name
        List<RecordType> personRTs = [
            SELECT Id 
            FROM RecordType 
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        // 2. Fallback: Check by Name 'Person Account'
        if (personRTs.isEmpty()) {
            personRTs = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND Name = 'Person Account' LIMIT 1];
        }
        // 3. Final Fallback: Check for the default 'Master' name
        if (personRTs.isEmpty()) {
             personRTs = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND Name = 'Master' LIMIT 1];
        }
        return personRTs.isEmpty() ? null : personRTs[0].Id;
    }

    // Helper method to create a valid Person Account test record (remains the same)
    private static Account createTestPersonAccount(String firstName, String lastName, String street, String email, String city, String stateCode, String zip) {
        Id paRTId = getPersonAccountRecordTypeId();
        System.assert(paRTId != null, 'FATAL SETUP ERROR: Person Account Record Type ID could not be retrieved.');
        
        return new Account(
            RecordTypeId = paRTId, 
            FirstName = firstName,
            LastName = lastName,
            PersonMailingStreet = street,
            PersonEmail = email,
            PersonMailingCity = city,
            PersonMailingStateCode = stateCode,         
            PersonMailingCountryCode = 'US',            
            PersonMailingPostalCode = zip,
            Phone = '555-555-1212',
            Invalid_Address__c = false
        );
    }

    // --- Test 1: Positive Cases (MANUALLY CALLS EXECUTE) ---
    @isTest
    static void test1_InvalidAddressFoundScenario() {
        // SETUP: Create the 3 records that should be flagged
        Account dupePa = createTestPersonAccount('Test', 'DupeFinder', '123456 123456', 'dupe@example.com', 'Miami', 'FL', '33101');
        Account cityPa = createTestPersonAccount('City', 'Finder', 'Miami Test', 'city@example.com', 'Miami', 'FL', '33101');
        Account zipPa = createTestPersonAccount('Zip', 'Finder', '100 Main St 33602', 'zip@example.com', 'Tampa', 'FL', '33602');
        
        List<Account> testRecords = new List<Account>{dupePa, cityPa, zipPa};
        insert testRecords;
        
        Set<Id> accountIds = new Set<Id>{dupePa.Id, cityPa.Id, zipPa.Id};
        
        Test.startTest();
        PersonAccountInvalidAddressFinder finderBatch = new PersonAccountInvalidAddressFinder(); 
        
        // ** DEFINITIVE FIX: Manually call execute() with the test records **
        // 1. Call start (optional, but good practice)
        finderBatch.start(null); 
        
        // 2. Call execute with the list of records
        finderBatch.execute(null, testRecords); 
        
        // 3. Call finish to collect results
        finderBatch.finish(null);
        Test.stopTest();
        
        // ASSERTION: All 3 records must be marked true and collected.
        List<Account> results = [SELECT Invalid_Address__c FROM Account WHERE Id IN :accountIds];
        
        System.assertEquals(3, finderBatch.invalidAddressResults.size(), 'Test 1 Failed: All 3 invalid records should have been found (collected).');
        for(Account acc : results) {
            System.assertEquals(true, acc.Invalid_Address__c, 'Test 1 Failed: All invalid records should be TRUE.');
        }
    }
    
    // --- Test 2: Negative/Exclusion Cases (MANUALLY CALLS EXECUTE) ---
    @isTest
    static void test2_ExclusionCasesPassed() {
        // Records that should be excluded due to designators
        Account pahoaExclusion = createTestPersonAccount('Pahoa', 'Village', '15-2827 Pahoa Village', 'pahoa@ex.com', 'Pahoa', 'HI', '96778');
        Account keaauExclusion = createTestPersonAccount('Keaau', 'Loop', '16-390 Keaau Loop', 'keaau@ex.com', 'Keaau', 'HI', '96749');
        Account waianaeExclusion = createTestPersonAccount('Waianae', 'Valley', '85-209 Waianae Valley Rd.', 'valley@ex.com', 'Waianae', 'HI', '96792');
        Account hwyExclusion = createTestPersonAccount('Hwy', 'Exclude', '100 Phoenix Hwy', 'hwy@ex.com', 'Phoenix', 'AZ', '85001');
        
        List<Account> testRecords = new List<Account>{pahoaExclusion, keaauExclusion, waianaeExclusion, hwyExclusion};
        insert testRecords;
        
        Set<Id> exclusionIds = new Set<Id>();
        for(Account a : testRecords) {
            exclusionIds.add(a.Id);
        }
        
        Test.startTest();
        PersonAccountInvalidAddressFinder finderBatch = new PersonAccountInvalidAddressFinder(); 
        
        // ** DEFINITIVE FIX: Manually call execute() with the test records **
        finderBatch.start(null); 
        finderBatch.execute(null, testRecords);
        finderBatch.finish(null);
        Test.stopTest();
        
        // ASSERTION: No invalid results should be collected.
        List<Account> results = [SELECT Invalid_Address__c FROM Account WHERE Id IN :exclusionIds];
        
        System.assertEquals(0, finderBatch.invalidAddressResults.size(), 'Test 2 Failed: Exclusion case was incorrectly collected.');
        for(Account acc : results) {
            System.assertEquals(false, acc.Invalid_Address__c, 'Test 2 Failed: Exclusion case was incorrectly flagged as TRUE.');
        }
    }
}