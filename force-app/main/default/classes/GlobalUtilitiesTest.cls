@isTest
private class GlobalUtilitiesTest {
    private static testMethod void testUnits() {
        GlobalUtilities.convertDate(Date.today());
        GlobalUtilities.getPrefixToSObjectType();
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        List<String> ids = new List<String>();
        ids.add(acc.Id);
        GlobalUtilities.convertIdsToIdStr(ids);
        GlobalUtilities.getIntegrationProfileId();
    }
}