@isTest
public class sc_TestDataFactory {
    public static void prepareData() {
        String str = 'sc_testData';
        sc_AppMetaDataManagement.parseResource(str);
    }

    public static List<Card_Cache__c> prepareCardCaches() {
        String dataName = 'sc_testCardCaches';
        StaticResource resourceRecords = [Select Id, name, Body, Description from StaticResource where Name =: dataName limit 1];
        Blob value = resourceRecords.Body;
        String str = value.toString();

        List<Card_Cache__c> cardCaches = (List<Card_Cache__c>) JSON.deserialize(str, List<Card_Cache__c>.class);
        for(Card_Cache__c cache:  cardCaches) {
            cache.Id = null;
        }
        return cardCaches;
    }


}