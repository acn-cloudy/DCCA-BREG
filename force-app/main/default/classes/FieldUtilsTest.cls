@isTest
private class FieldUtilsTest {
    public static testmethod void testGetPicklistOptions() {
        System.assert(FieldUtils.getPicklistOptions('Lead', 'Status').size() > 0);
    }
    public static testmethod void testGetDependentOptions() {
        FieldUtils.getDependentOptions('FileDetails__c',  'Category__c', 'Type__c') ;
    }

    public static testmethod void testGetPicklistOptions_Exception() {
        System.assert(FieldUtils.getPicklistOptions('Account', 'PersonMailingState').size() > 0);
    }
}