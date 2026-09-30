@isTest
private class sc_LookupControllerTest {
    
    public static testMethod void testSearchDB() {
        Account record = TestDataFactory.createAccountUnit('test aas', '24234234');
        insert record;
        List<sc_LookUpController.ResultWrapper> wrappers 
            = (List<sc_LookUpController.ResultWrapper>) JSON.deserialize(sc_LookUpController.searchDB('Account', 
                'Id','Name', 10, 'Name', record.Name), List<sc_LookUpController.ResultWrapper>.class);
        System.assert(wrappers.size() > 0);
    }
}