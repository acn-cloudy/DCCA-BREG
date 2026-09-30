@isTest
private class WithoutSharingDmlHelperTest {

    @isTest
    static void testHelper() {
        Test.startTest();
        WithoutSharingDmlHelper.doInsert(new Account(Name = 'Test'));        
        WithoutSharingDmlHelper.doInsert(new List<Account>{new Account(Name = 'Test 2')});

        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        if(acc != null) {
            acc.Name = acc.Name + ' - UPDATED';
            WithoutSharingDmlHelper.doUpdate(new List<Account>{acc});
        }        
        Test.stopTest();
    }
}