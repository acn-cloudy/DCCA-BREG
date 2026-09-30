/*
 * ----------------------------------------------------------------------
 * Description: For Case 00040975
 * 
 * Integration - Salesforce to return License Details to Compact
 * ----------------------------------------------------------------------
 *
 * 
 * @author emel.l.agarao@pacificpointcorp.com
 * created 01/17/2025
 */
global without sharing class IMLCCPushBatchJob implements Schedulable, Database.AllowsCallouts {  
    /* method to execute the schedulable context */
    global void execute(SchedulableContext context) {
        List<IMLCCQueueable.IMLCCQueueablePushItem> pushItems = new List<IMLCCQueueable.IMLCCQueueablePushItem>();
        Map<String, IMLCCQueueable.IMLCCQueueableBulkPushItem> bulkPushItems = new Map<String, IMLCCQueueable.IMLCCQueueableBulkPushItem>();
        List<License__c> lics = [
            SELECT Id, Name, OriginalDateofLicensure__c, 
            EffectiveExpireDate__c, LicenseType__r.Signer__c, 
            Application__r.IMLCCLicenseId__c
            FROM License__c 
            WHERE CreatedDate >= YESTERDAY
            AND Application__r.IMLCCLicenseId__c !=  NULL
        ];

        if(Test.isRunningTest()){
            lics.add(new License__c(
                Name = 'TEST LIC',
                OriginalDateofLicensure__c = Date.today(),
                EffectiveExpireDate__c = Date.today(),
                LicenseType__r = new LicenseType__c(Signer__c = 'Test Signer'),
                Application__r = new Application__c(IMLCCLicenseId__c = '1234567890')
            ));
        }

        for(License__c lic: lics){
            // IMLCCQueueable.IMLCCQueueablePushItem pushItem = new IMLCCQueueable.IMLCCQueueablePushItem();
            // pushItem.licenseNumber = lic.Name;
            // pushItem.dateOfIssue = String.valueOf(lic.OriginalDateofLicensure__c);
            // pushItem.dateOfExpiration = String.valueOf(lic.EffectiveExpireDate__c);
            // pushItem.signer = lic.LicenseType__r != null && lic.LicenseType__r.Signer__c != null  ? lic.LicenseType__r.Signer__c : '';
            // pushItem.physicianId = lic.Application__r.IMLCCLicenseId__c;
            // pushItems.add(pushItem);

            String key = String.valueOf(lic.OriginalDateofLicensure__c) + String.valueOf(lic.EffectiveExpireDate__c);
            IMLCCQueueable.IMLCCQueueableBulkPushItem bulkPushItem = bulkPushItems.get(key);
            if(bulkPushItem == null) bulkPushItem = new IMLCCQueueable.IMLCCQueueableBulkPushItem();
            bulkPushItem.new_issueddate = String.valueOf(lic.OriginalDateofLicensure__c);
            bulkPushItem.new_expires = String.valueOf(lic.EffectiveExpireDate__c);
            bulkPushItem.imlcc_signaturembtypedname = lic.LicenseType__r != null && lic.LicenseType__r.Signer__c != null ? lic.LicenseType__r.Signer__c : '';
            if(bulkPushItem.licenseNumbers == null) bulkPushItem.licenseNumbers = new Map<String, String>();
            bulkPushItem.licenseNumbers.put(lic.Application__r.IMLCCLicenseId__c, lic.Name);
            bulkPushItems.put(key, bulkPushItem);

            // if(pushItems.size() >= 90){
            //     System.enqueueJob(new IMLCCQueueable(3, pushItems));
            //     pushItems.clear();               
            // }
        }

        if(!bulkPushItems.isEmpty()) System.enqueueJob(new IMLCCQueueable(4, bulkPushItems.values()));
        // if(!pushItems.isEmpty()) System.enqueueJob(new IMLCCQueueable(3, pushItems));
    }
}