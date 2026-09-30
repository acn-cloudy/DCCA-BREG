/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: LicenseTypeRenewalEmailSenderTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04222022 - Created for PVL Case 00021111
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@outlook.ph
 *
 * @created 04/12/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public with sharing class LicenseTypeRenewalEmailSender implements Database.Batchable<SObject>{

    private String licenseTypeId;

    private String templateName;

    private String query;

    private String emailTemplateId;

    private String orgWideFromAddressId;

    public Set<String> licenseStatusFilter;

    private String mdEmailTemplateId;

    private String dosEmailTemplateId;

    private String etMd = 'IMLCC_MD_Renewal_Email_Template';
    private String etDos = 'IMLCC_DOS_Renewal_Email_Template';

    public LicenseTypeRenewalEmailSender(String licenseTypeId, String emailTemplateName) {
        this.templateName = emailTemplateName;
        this.licenseTypeId = licenseTypeId;
        this.emailTemplateId = [
            SELECT
                Id
            FROM EmailTemplate
            WHERE DeveloperName = :emailTemplateName
        ][0].Id;

        this.mdEmailTemplateId = [
            SELECT
                Id
            FROM EmailTemplate
            WHERE DeveloperName = :this.etMd
        ][0].Id;

        this.dosEmailTemplateId = [
            SELECT
                Id
            FROM EmailTemplate
            WHERE DeveloperName = :this.etDos
        ][0].Id;

        this.orgWideFromAddressId = [
            SELECT
                Id
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'DCCA No Reply'
            LIMIT 1
        ][0].Id;

        licenseStatusFilter = new Set<String>();
        licenseStatusFilter.add('R - Valid Thru Expiration Date, Subject To Renewal');
        licenseStatusFilter.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');
        licenseStatusFilter.add('Z - Current & Valid, But Subject To Disciplinary Requirement');
        licenseStatusFilter.add('ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)');
        licenseStatusFilter.add('ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement');

        this.query = 'SELECT Id, PVL_Portal_User__r.Email__c, LicenseTypeName__c, MethodofLicensure__c FROM License__c ' +
            'WHERE Status__c IN :licenseStatusFilter ' +
            'AND LicenseType__c = :licenseTypeId ' +
            'AND PVL_Portal_User__c != null ' +
            'AND PVL_Portal_User__r.Email__c != null ' +
            'AND ThisLicenseRenewed__c = false';
    }

    public void execute(Database.BatchableContext bc, List<SObject> records) {
        List<License__c> licenses = (List<License__c>) records;
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<String> licenseIds = new List<String>();
        for (License__c lic : licenses) {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            if(lic.LicenseTypeName__c == 'MD' && lic.MethodofLicensure__c == 'LC - Licensure Compact'){
                msg.setTemplateId(this.mdEmailTemplateId);
            }
            else if(lic.LicenseTypeName__c == 'DOS' && lic.MethodofLicensure__c == 'LC - Licensure Compact'){
                msg.setTemplateId(this.dosEmailTemplateId);
            }
            else{
                msg.setTemplateId(this.emailTemplateId);
            }

            msg.setOrgWideEmailAddressId(this.orgWideFromAddressId);
            msg.setTargetObjectId(UserInfo.getUserId());
            msg.setWhatId(lic.Id);
            msg.setToAddresses(new String[]{lic.PVL_Portal_User__r.Email__c});
            msg.setTreatTargetObjectAsRecipient(false);
            messages.add(msg);

            lic.RenewalEmailSent__c = Datetime.now();
            licenseIds.add(lic.Id);
        }

        List<Messaging.SendEmailResult> results = Messaging.sendEmail(messages, false);
        for (Messaging.SendEmailResult rs : results) {
            if (!rs.isSuccess()) {
                for (Messaging.SendEmailError err : rs.getErrors()) {
                    System.debug(err.getMessage());
                    //ToDo:Do not generate PDF version if send of email failed
                }
            }
        }

        update licenses;
    }


    public void finish(Database.BatchableContext bc) {
        LicenseType__c lt = [SELECT Id, Name FROM LicenseType__c WHERE Id = :this.licenseTypeId];
        BatchJobFinishNotification notification = new BatchJobFinishNotification('Send Renewal Emails', lt.Name);
        notification.sendEmail();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(this.query);
    }

}