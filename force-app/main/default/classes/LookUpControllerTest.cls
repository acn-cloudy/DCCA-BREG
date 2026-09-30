@isTest
public with sharing class LookUpControllerTest {
    
    public static testMethod void testSearchDB() {
        Account record = TestDataFactory.createAccountUnit('test aas', '24234234');
        insert record;
        List<LookUpController.ResultWrapper> wrappers 
            = (List<LookUpController.ResultWrapper>) JSON.deserialize(LookUpController.searchDB('Account', 
                'Id','Name', 10, 'Name', record.Name), List<LookUpController.ResultWrapper>.class);
        System.assert(wrappers.size() > 0);
    }
}