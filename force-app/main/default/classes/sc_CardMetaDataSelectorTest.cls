@isTest
private class sc_CardMetaDataSelectorTest {
    @isTest
    static void testGetCardMetaData() {
        sc_CardMetaDataSelector.getCardsByAppIdAndName(null, null);
        sc_CardMetaDataSelector.getCardsAndFieldsByAppId(null);
    }
}