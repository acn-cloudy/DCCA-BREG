/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: RealEstateLicensesInactivatorBatchTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10102022 - Created for case 00024595
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/10/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 * @update 10/17/2024: emel.l.agarao@pacificpointcorp.com - For Case 00038273
 * 
 * 
 */
public class RealEstateLicensesInactivatorBatch implements Schedulable, Database.Batchable<SObject>, Database.stateful{
    public List<License__c> forEmailSendingLics = new List<License__c>();
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<License__c> records = (List<License__c>) scope;
        Map<Id, Application__c> applicationsToUpdate = new Map<Id, Application__c>();
        List<LicenseHistory__c> licenseHistoryToCreate = new List<LicenseHistory__c>();
        Map<Id, AssociatedLicense__c> associatedLicensesToUpdate = new Map<Id, AssociatedLicense__c>();
        Map<Id, License__c> licensesToUpdate = new Map<Id, License__c>();
        Map<Id, String> licenseIdApplicationCurrentStatusMap = new Map<Id, String>();
        List<Notification__c> notifications = new List<Notification__c>();       

        LicenseType__c rBBrokerLicenseType = [SELECT Id FROM LicenseType__c WHERE Name = 'RB - Broker' LIMIT 1];
        Id rBBrokerRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - RB - Broker').getRecordTypeId();
        for (License__c l : records) {
            if (l.Applications1__r.isEmpty()) {
                continue;
            }

            for (Application__c a : l.Applications1__r) {
                if (a.LicenseType__c == null) {
                    continue;
                }

                if (a.LicensePeriodRNEW__c != a.LicenseType__r.PreviousLicensePeriod__c) {
                    continue;
                }

                String appCurrentStatus = a.Status__c;

                a.Phase__c = 'H - License Generation';
                a.Status__c = 'HC - Application Completed';
                a.Bypass_Validation__c = true;
                applicationsToUpdate.put(a.Id, a);

                if (!licensesToUpdate.containsKey(l.Id)) {
                    licenseIdApplicationCurrentStatusMap.put(l.Id, appCurrentStatus);

                    l.ExcludeFromInactivationProcess__c = true;
                    l.InactivationDate__c = l.EffectiveExpireDate__c.addDays(1);
                    l.ActiveInactive__c = 'Inactive';                    
                    l.DependentLicense__c = null;
                    l.ThisLicenseRenewed__c = true;
                    l.EffectiveExpireDate__c = a.RNEWRSTRDate__c;

                    // 00038273
                    if(l.Status__c != 'Z - Current & Valid, But Subject To Disciplinary Requirement') l.Status__c = 'C - Current, Valid & In Good Standing';
                    if(l.LicenseType__r?.Name == 'RB - Sole Proprietor'){
                        l.SoleOwner__c = false;
                        l.LicenseType__c = rBBrokerLicenseType.Id;
                        l.RecordTypeId = rBBrokerRecordTypeId;
                        l.BusinessStreet__c = null;
                        l.BusinessCity__c = null;
                        l.BusinessState__c = null;
                        l.BusinessCountry__c = null;
                        l.BusinessZipCode__c = null;
                        l.BusinessAddressEffectiveDate__c = null;
                    }

                    licensesToUpdate.put(l.Id, l);

                    LicenseHistory__c lh = new LicenseHistory__c();
                    lh.License__c = l.Id;
                    lh.EffectiveDate__c = l.InactivationDate__c;
                    lh.LicensePeriod__c = l.LicenseHistoryLicensePeriod__c;
                    lh.Remarks__c = 'License was set to Inactive';
                    lh.TransactionType__c = 'I - INACTIVE';

                    if (appCurrentStatus == 'D1 - Awaiting Dependency Review') {
                        lh.Remarks__c = 'EDEL - EMPLOYER DELINQUENT/FORFEITED (FOR "EMPLOYEES" & NOT SOLE OWNERS) (INDIRECT - WHEN EMPLOYEE RENEWS LICENSE & EMPLR DOES NOT RENEW, EMPLOYEES EMPLMT TERMINATED)';
                    }

                    if (appCurrentStatus == 'D2 - Continuing Education Missing') {
                        lh.Remarks__c = 'CONTE- Continuing  Education';
                    }

                    licenseHistoryToCreate.add(lh);
                }
            }

            if (!licensesToUpdate.containsKey(l.Id)) {
                continue;
            }

            for (AssociatedLicense__c al : l.AssociatedEmployee__r) {
                if (licenseIdApplicationCurrentStatusMap.containsKey(l.Id)) {
                    if (licenseIdApplicationCurrentStatusMap.get(l.Id) == 'D1 - Awaiting Dependency Review') {
                        al.TerminationReason__c = 'EDEL - EMPLOYER DELINQUENT/FORFEITED (FOR "EMPLOYEES" & NOT SOLE OWNERS) (INDIRECT - WHEN EMPLOYEE RENEWS LICENSE & EMPLR DOES NOT RENEW, EMPLOYEE\'S EMPLMT TERMINATED)';
                    }

                    if (licenseIdApplicationCurrentStatusMap.get(l.Id) == 'D2 - Continuing Education Missing') {
                        al.TerminationReason__c = 'CONTE - CONTINUING EDUCATION';
                    }
                }

                al.EmploymentStatus__c = 'Terminated';
                al.EndDate__c = l.LicenseType__r.PreviousLicensePeriodExpireDate__c;
                associatedLicensesToUpdate.put(al.Id, al);
            }

            for (AssociatedLicense__c al : l.AssociatedEntities__r) {
                if (licenseIdApplicationCurrentStatusMap.containsKey(l.Id)) {
                    if (licenseIdApplicationCurrentStatusMap.get(l.Id) == 'D1 - Awaiting Dependency Review') {
                        al.TerminationReason__c = 'EDEL - EMPLOYER DELINQUENT/FORFEITED (FOR "EMPLOYEES" & NOT SOLE OWNERS) (INDIRECT - WHEN EMPLOYEE RENEWS LICENSE & EMPLR DOES NOT RENEW, EMPLOYEE\'S EMPLMT TERMINATED)';
                    }

                    if (licenseIdApplicationCurrentStatusMap.get(l.Id) == 'D2 - Continuing Education Missing') {
                        al.TerminationReason__c = 'CONTE - CONTINUING EDUCATION';
                    }

                    al.EmploymentStatus__c = 'Terminated';
                    al.EndDate__c = l.LicenseType__r.PreviousLicensePeriodExpireDate__c;
                    associatedLicensesToUpdate.put(al.Id, al);
                }
            }

            // 00038273
            Notification__c notification = new Notification__c();
            notification.License__c = l.Id;
            notification.RecordId__c = l.Id;
            if(l.PVL_Portal_User__r != null && l.PVL_Portal_User__r.Email__c != null){
                notification.Scheduled__c = false;
                notification.SendToPrinter__c = false;
                notification.Fire__c = true;
                notification.Status__c = 'Completed';
                notification.DocGeneratorSettings__c = 'REB Renewal Inactivation Notification';
                notification.DocumentTemplateName__c = 'REB Renewal Inactivation Notification';
                forEmailSendingLics.add(l);
            } else {
                notification.Scheduled__c = true;
                notification.SendToPrinter__c = true;
                notification.Fire__c = true;
                notification.Status__c = 'Scheduled';
                notification.PrintStatus__c = 'Ready for Print';
                notification.DocGeneratorSettings__c = 'REB Renewal Inactivation Notification';
                notification.DocumentTemplateName__c = 'REB Renewal Inactivation Notification';
            }
            
            notifications.add(notification);
        }

        if(!notifications.isEmpty()) insert notifications;
        update licensesToUpdate.values();

        if(!Test.isRunningTest()) turnOffAppRenewFlow();
        for (Application__c app : applicationsToUpdate.values()) {
            app.Bypass_Validation__c = false;
        }

        //Case 00027707
        update applicationsToUpdate.values();
        if(!Test.isRunningTest()) turnOnAppRenewFlow();

        update associatedLicensesToUpdate.values();
        insert licenseHistoryToCreate;
    }
    
    private static void turnOffAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = true;
        upsert orgSetting;
    }

    private static void turnOnAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = false;
        upsert orgSetting;
    }

    public void finish(Database.BatchableContext bc) {
        BatchJobFinishNotification notification = new BatchJobFinishNotification('Real Estate Non Renewal Inactivation');
        notification.sendEmail();

        // 00038273
        if(!forEmailSendingLics.isEmpty()){
            String userId = UserInfo.getUserId();
            EmailTemplate[] emailTemplate = [Select Id from EmailTemplate where DeveloperName = 'REBInactivationLetterNotice'];
            OrgWideEmailAddress[] owea = [Select Id from OrgWideEmailAddress where DisplayName = 'DCCA No Reply'];
        
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            for(License__c lic:forEmailSendingLics){
                if(emailTemplate.size() < 1) break;
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();  
                if (owea.size() > 0) email.setOrgWideEmailAddressId(owea[0].Id);
                email.setTemplateId(emailTemplate[0].Id);
                email.setToAddresses(new List<String>{lic.PVL_Portal_User__r.Email__c});
                email.setTargetObjectId(userId);  //                
                email.setTreatTargetObjectAsRecipient(false);
                email.setWhatId(lic.Id);
                email.setSaveAsActivity(true);
                email.setUseSignature(false);
                emails.add(email);
            }

            if(!emails.isEmpty() && !Test.isRunningTest()) Messaging.sendEmail(emails);
            forEmailSendingLics.clear();
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Status__c, OwnerId, DependentLicense__c, LicenseType__c, LicenseType__r.Name, EffectiveExpireDate__c, LicenseType__r.LicenseTypeEffectiveDate__c, LicenseType__r.PreviousLicensePeriodExpireDate__c, LicenseHistoryLicensePeriod__c, PVL_Portal_User__r.Email__c, ' +
            '(SELECT Id, LicensePeriodRNEW__c, LicenseType__r.PreviousLicensePeriod__c, Status__c, RNEWRSTRDate__c FROM Applications1__r ' +
            'WHERE Type__c = \'RNEW - Renewal\' ' +
            'AND (Status__c = \'D1 - Awaiting Dependency Review\' OR Status__c = \'D2 - Continuing Education Missing\')), ' +
            '(SELECT Id FROM AssociatedEmployee__r WHERE (EndDate__c = null OR EndDate__c > TODAY) AND EmploymentStatus__c = \'Employed\'), ' +
            '(SELECT Id FROM AssociatedEntities__r WHERE (EndDate__c = null OR EndDate__c > TODAY) AND EmploymentStatus__c = \'Employed\') ' +
            'FROM License__c ' +
            'WHERE (LicenseType__r.Name = \'RB - Entity\' ' +
            'OR LicenseType__r.Name = \'RB - Broker\'' +
            'OR LicenseType__r.Name = \'RB - Sole Proprietor\' ' +
            'OR LicenseType__r.Name = \'RS\') ' +
            'AND (Status__c = \'R - Valid Thru Expiration Date, Subject To Renewal\' ' +
            ' OR Status__c = \'Z - Current & Valid, But Subject To Disciplinary Requirement\') ' ;

        return Database.getQueryLocator(query);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new RealEstateLicensesInactivatorBatch());
    }
}