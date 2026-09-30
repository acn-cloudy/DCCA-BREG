/*
* ─────────────────────────────────────────────────────────
* class for the Application Handller used to handle 
* Application trigger
* ─────────────────────────────────────────────────────────
* PacPoint-CZ100419 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-10-04
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class AccountService {
    private static Set<String> accountToUpdate_L = new Set<String>();
    private static List<LicenseHistory__c> licenseHistories = new List<LicenseHistory__c>();
    private static List<AccountName__c> accountNames = new List<AccountName__c>();
    private static set<String> recordIdsForAddresCaptured = new Set<String>();
    private static Set<String> recordIdsForNameInfoCaptured = new Set<String>();
    private static Id dccaIntegrationProfileId;
    private static Set<Id> pvlProfileIds;

    //00005836 Creation of a trigger to populate the BPID field for Business Accounts
    public static void populateBPID(SObject so) {
        Account account = (Account) so;
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
        if(account.RecordTypeId == accountRecordTypeId) {
            accountToUpdate_L.add(account.Id);
        }
    }

    // 00011964
    public static void recordAddressUpdate() {
        if(!licenseHistories.isEmpty()) {
            AccessLess.insertRecords(licenseHistories);
            licenseHistories.clear();
        }
    }
    // 00011964
    public static void captureAddressesUpdate(SObject oldSo, SObject so) {
        Account oldRecord = (Account) oldSo;
        Account record = (Account) so;
        if(recordIdsForAddresCaptured.contains(record.Id)) {
            return;
        }
        if (record.PersonMailingStreet != oldRecord.PersonMailingStreet
            || record.PersonMailingCity != oldRecord.PersonMailingCity
            || record.PersonMailingState != oldRecord.PersonMailingState
            || record.PersonMailingPostalCode != oldRecord.PersonMailingPostalCode 
            || record.PersonMailingCountry != oldRecord.PersonMailingCountry ) {
                LicenseHistory__c history = new LicenseHistory__c();
                history.Account__c = record.Id;
                history.EffectiveDate__c = oldRecord.ResidenceAddressEffectiveDate__pc;
                if(record.ResidenceAddressEffectiveDate__pc != oldRecord.ResidenceAddressEffectiveDate__pc) {
                    history.TermDate__c= record.ResidenceAddressEffectiveDate__pc;
                } else {
                    history.TermDate__c= Date.today();
                }
                
                history.TransactionType__c = 'CRADD - CHANGE OF RESIDENCE ADDRESS';
                history.Remarks__c = generateRemarksField(oldRecord.PersonMailingStreet, oldRecord.PersonMailingCity,
                oldRecord.PersonMailingState, oldRecord.PersonMailingPostalCode, oldRecord.PersonMailingCountry );
                licenseHistories.add(history);
                recordIdsForAddresCaptured.add(record.Id);
        }

    }

    public static void captureNameInfo(SObject oldSo, SObject so) {
        Account oldRecord = (Account) oldSo;
        Account record = (Account) so;
        if(recordIdsForNameInfoCaptured.contains(record.Id)) {
            return;
        }
        if (record.isPersonAccount && (record.Salutation != oldRecord.Salutation
            || record.FirstName != oldRecord.FirstName
            || record.LastName != oldRecord.LastName
            || record.MiddleName != oldRecord.MiddleName 
            || record.Suffix != oldRecord.Suffix)  ) {
                AccountName__c history = new AccountName__c();
                history.Account__c = record.Id;
                history.EffectiveDate__c = record.LegacyEffectiveLegalNameDate__c;
                history.NameType__c = 'L - Legal Name (Married/Maiden)';
                history.BPName__c = generateNameFields(oldRecord );
                accountNames.add(history);
                recordIdsForNameInfoCaptured.add(record.Id);
        } else if(!record.isPersonAccount && record.Name != oldRecord.Name) {
            AccountName__c history = new AccountName__c();
            history.Account__c = record.Id;
            history.EffectiveDate__c = record.LegacyEffectiveLegalNameDate__c;
            history.NameType__c = 'L - Legal Name (Married/Maiden)';
            history.BPName__c = oldRecord.Name;
            accountNames.add(history);
            recordIdsForNameInfoCaptured.add(record.Id);
        }
    }
    public static String generateNameFields(Account record) {
        String saluation = record.Salutation;
        String firstName = record.FirstName;
        String lastName = record.LastName;
        String middleName = record.MiddleName;
        String suffix = record.Suffix;
        if(saluation == null ) saluation = '';
        if(firstName == null ) firstName = '';
        if(lastName == null ) lastName = '';
        if(middleName == null ) middleName = '';
        if(suffix == null ) suffix = '';
        String concatStr = saluation + ' ' + firstName + ', ' +middleName+' '+ lastName + ' ' + suffix;
        if(concatStr.trim() == ',') concatStr = '';
        return concatStr;
    }
    public static String generateRemarksField(String street, String city, String state, String zipCode, String country) {
        if(street == null ) street = '';
        if(city == null ) city = '';
        if(state == null ) state = '';
        if(zipCode == null ) zipCode = '';
        if(country == null ) country = '';
        String concatStr = street + ' ' + city + ', ' +state+' '+ zipCode + ' ' + country;
        if(concatStr.trim() == ',') concatStr = '';
        return concatStr;

    }
    //00005836 Creation of a trigger to populate the BPID field for Business Accounts
    public static void updateAccountBPID(List<Account> accounts) {
        Id profileId = UserInfo.getProfileId();
        Profile profileRec = [Select Name from Profile where Id =: profileId];
        if(
            !profileRec.Name.contains('PVL') && profileRec.Name != 'System Administrator' 
            && !profileRec.Name.contains('Wordpress') && !profileRec.Name.contains('form')
            && !profileRec.Name.contains('Digital')) {
            return;
        }
        if(accounts == null) return;
        List<Account> records = (new AccountDomain(accounts)).filterRecordsForCounterUpdate();
        // retrieve Custom Setting status
        BusinessAccountCounter__c setting = BusinessAccountCounter__c.getOrgDefaults();
        if (system.today() != setting.ResetDate__c)  {
            setting.Counter__c = 1;
            setting.ResetDate__c = system.today();
            upsert setting;
        }
        setting = [Select Id, ResetDate__c, Counter__c from BusinessAccountCounter__c limit 1  FOR UPDATE];
        Decimal newCounter = (new AccountDomain(records)).updateAccountBPID(setting);
        // If there duplicates, then recalculate the counter.
        setting.Counter__c = newCounter;
        upsert setting;
        // }
    }
    public static void recordAccountNamesUpdate(){
        if(!accountNames.isEmpty()) {
            insert accountNames;
            accountNames.clear();
        }
    }
    public static void runFinally(List<Account> accounts) {
        
        if(Trigger.isBefore != null && Trigger.isBefore) {
            if(Trigger.isInsert != null && Trigger.isInsert) {
                updateAccountBPID(accounts);
            }
        }
        if(Trigger.isAfter != null && Trigger.isAfter) {
            recordAddressUpdate();
            recordAccountNamesUpdate();
        }
    }
}