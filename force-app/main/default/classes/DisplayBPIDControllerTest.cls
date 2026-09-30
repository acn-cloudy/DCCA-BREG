@isTest
private class DisplayBPIDControllerTest {
    @isTest
    static void testValidateBPID() {
        BusinessAccountCounter__c accountCounterSetting = new BusinessAccountCounter__c();
        accountCounterSetting.ResetDate__c = Date.today();
        accountCounterSetting.Counter__c = 1;
        insert accountCounterSetting;

        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');

        Account acc = new Account();
        acc.Name = 'acc';
        acc.BPID__c = 'acc';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        insert acc;
        Account acc1 = [Select Id, BPID__c from Account  where Id =: acc.Id];
        Test.startTest();
        try {
            DisplayBPIDController.validateBPIDs(acc1.BPID__c, 'REGISTERED NURSE');
            
        } catch(Exception ex) {}
        DisplayBPIDController.getAccountInfo(acc1.BPID__c);

        Test.stopTest();
    }
}