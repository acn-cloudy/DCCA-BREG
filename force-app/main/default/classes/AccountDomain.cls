/*
* ─────────────────────────────────────────────────────────
* class for the Account Handller used to handle 
* Account trigger
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
public  class AccountDomain extends SObjectDomain{
    public AccountDomain(List<Account> accounts) {
        super(accounts);
    }
    // 00005836 
    // Used to filter account by business account and personal Account 
    // 1) When a Business Account is created and FILEID=NULL and profile <> "DCCA Integration" (Existing logic)
    // OR
    // 2) When the Person Account is created and PVLBPID == null and profile contains "PVL" (new logic)
    public List<Account> filterRecordsForCounterUpdate() {
        String dccaIntegrationProfileId;
        Set<String> pvlProfileIds = new Set<String>();
        List<Profile> dccaIntegrationProfile = ProfileSelector.getProfileByName('DCCA Integration');
        if (!dccaIntegrationProfile.isEmpty()) {
            //If no DCCA Integration Profile found exit;
            dccaIntegrationProfileId = dccaIntegrationProfile[0].Id;
        }
        List<Profile> pvlProfiles  = ProfileSelector.getProfilesWithKeyword('PVL');
        
        List<String> profileIds = (new SObjectDomain(pvlProfiles)).getIds();
        pvlProfileIds.addAll(profileIds);
        List<Profile> wordPressProfiles  = ProfileSelector.getProfilesWithKeyword('Wordpress');
        pvlProfileIds.addAll((new SObjectDomain(wordPressProfiles)).getIds());
        List<Profile> formProfiles  = ProfileSelector.getProfilesWithKeyword('form');
        pvlProfileIds.addAll((new SObjectDomain(formProfiles)).getIds());
        List<Profile> formProfiles2  = ProfileSelector.getProfilesWithKeyword('Digital');
        pvlProfileIds.addAll((new SObjectDomain(formProfiles2)).getIds());
        List<Profile> adminProfiles = ProfileSelector.getProfileByName('System Administrator');
        pvlProfileIds.addAll((new SObjectDomain(adminProfiles)).getIds());

        String currentProfileId = UserInfo.getProfileId();
        Id businessAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
        Id personalAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        List<Account> filteredRecords = new List<Account>();
        for(Account record: (List<Account>) records) {
            if(dccaIntegrationProfileId != currentProfileId 
                && record.RecordTypeId == businessAccountRecordTypeId
                && record.FileID__c == null 
            || (pvlProfileIds.contains(currentProfileId) 
                && record.RecordTypeId == personalAccountRecordTypeId 
                && record.BPID__c == null)) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }
    // Used to update BPID__c and update setting
    public Decimal updateAccountBPID(BusinessAccountCounter__c setting) {
        if (system.today() != setting.ResetDate__c) setting.Counter__c = 1;
        Decimal rInteger = setting != null ? setting.Counter__c : 1;
        for(SObject record : records) {
            String countString = convertToString(rInteger);
            Account account = (Account) record;
            account.BPID__c = account.BusinessAccountPrefix__c + countString;
            rInteger ++;
        }
        return rInteger;
    }

    private String convertToString(Decimal inNumber) {
        String outString = '';
        if (inNumber > 0 && inNumber < 10) {
            outString = '00' + string.valueof(inNumber.format());
        } else if (inNumber >= 10 && inNumber < 100) {
            outString = '0' + string.valueof(inNumber.format());
        } else {
            outString = string.valueof(inNumber.format());
        }
        return outString;
    }
}