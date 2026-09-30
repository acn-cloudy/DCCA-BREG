/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*
* Test Class for ApplicationClassificationCreateRecords
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-IC080619 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author Irene Cahilo - Pacificpoint
* @created 08/06/19
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@IsTest
private class ApplicationClassificationCreateRecordsTe {
    @isTest
    static void testApplicationCreateTransRecords(){
        String orgId = UserInfo.getOrganizationId();
        String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
        Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
        String uniqueName = orgId + dateString + randomInt;

        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User dummyUser = new User(
                Alias = 'standu',
                Email = uniqueName + '@test' + orgId + '.org',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                Division__c = 'BREG',
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueName + '@test' + orgId + '.org');
        insert dummyUser;

        System.runAs(dummyUser) {
            Account accountDummy = new Account();
            accountDummy.Name = 'Dummy';
            insert accountDummy;

            Application__c applicationDummy = new Application__c();
            applicationDummy.Applicant__c = accountDummy.Id;
            applicationDummy.Phase__c = 'A - Application Received';
            insert applicationDummy;

            LicenseType__c licenseTypeDummy = new LicenseType__c();
            licenseTypeDummy.Status__c = 'Active';
            licenseTypeDummy.Name = 'CT';
            insert licenseTypeDummy;

            Classification__c classificationDummy = new Classification__c();
            classificationDummy.Status__c = 'Active';
            classificationDummy.Name = 'Class A';
            classificationDummy.LicenseType__c = licenseTypeDummy.Id;
            insert classificationDummy;

            List<ExamTypes__c> examTypesList = new List<ExamTypes__c>();

            ExamTypes__c examTypeDummy = new ExamTypes__c();
            examTypeDummy.Name = 'ET 1';
            examTypeDummy.Status__c = 'Active';
            examTypeDummy.Classification__c = classificationDummy.Id;
            examTypesList.add(examTypeDummy);

            ExamTypes__c examTypeDummy2 = new ExamTypes__c();
            examTypeDummy2.Name = 'ET 2';
            examTypeDummy2.Status__c = 'Active';
            examTypeDummy2.Classification__c = classificationDummy.Id;
            examTypesList.add(examTypeDummy2);

            insert examTypesList;

            ApplicationClassifications__c ac = new ApplicationClassifications__c();
            ac.Application__c = applicationDummy.Id;
            ac.Classification__c = classificationDummy.Id;
            insert ac;

            List<ExamsRequired__c> examRequiredList = [SELECT Id FROM ExamsRequired__c WHERE Application__c =: applicationDummy.Id];
            System.assertEquals(2, examRequiredList.size());
        }

    }
}