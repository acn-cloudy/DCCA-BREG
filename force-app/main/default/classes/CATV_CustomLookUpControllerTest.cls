@isTest
public with sharing class CATV_CustomLookUpControllerTest {
    @TestSetup
    private static void setup(){
        Account acc = CATV_TestClassUtility.createAccount('Test Account',false);
        acc.Type = 'City';
        insert acc;
    }
    
    @isTest
    static void createContactAndAccountRequestTest(){
        CATV_CustomLookUpController.SearchWrapper sw = new CATV_CustomLookUpController.SearchWrapper();
        sw.objectApiName = 'Account';
        sw.fieldApiName = 'Name';
        sw.otherFieldApiName = 'Type';
        sw.searchString = 'Te';
        sw.selectedOrg = JSON.serialize(new List<String>{'City'});
        sw.parentRecordId = null;
        sw.parentFieldApiName = null;
        
        Test.startTest();
        List<CATV_CustomLookUpController.ResultWrapper> rw = CATV_CustomLookUpController.fetchRecords(sw);       
        Test.stopTest();
        
        Assert.AreNotEqual(rw,null);
    }
}