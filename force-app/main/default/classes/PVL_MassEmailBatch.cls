/*
 * ─────────────────────────────────────────────────────────────
 * Batchable class that sends mass emails to Licenses or
 * Applications for a given License Type, with optional filters.
 *
 * Uses PVL_Portal_User__c.Email__c as the recipient address.
 * Creates a Task (Activity History) for each email sent.
 * ─────────────────────────────────────────────────────────────
 * VPVL-37 - Mass Email from License Type
 * ─────────────────────────────────────────────────────────────
 * @author  VPVL-37
 * @created 2026-02-06
 * ─────────────────────────────────────────────────────────────
 */
public with sharing class PVL_MassEmailBatch implements Database.Batchable<SObject>, Database.Stateful {

    // ── Input parameters (set once in constructor) ──────────

    private String licenseTypeId;
    private String target;          // 'Licenses' or 'Applications'
    private String contentType;     // 'Template' or 'FreeText'
    private String emailTemplateId;
    private String emailSubject;
    private String emailBody;

    // Filters – public so dynamic-SOQL bind variables resolve
    public List<String> statusFilter;
    public List<String> molFilter;
    public List<String> specialPrivilegeFilter;
    public List<String> classificationFilter;

    // ── Internal state ──────────────────────────────────────

    private String orgWideEmailAddressId;
    private String templateName;
    private Integer successCount = 0;
    private Integer failureCount = 0;

    // ── Constructor ─────────────────────────────────────────

    public PVL_MassEmailBatch(
        String licenseTypeId,
        String target,
        String contentType,
        String emailTemplateId,
        String emailSubject,
        String emailBody,
        List<String> statusFilter,
        List<String> molFilter,
        List<String> specialPrivilegeFilter,
        List<String> classificationFilter
    ) {
        this.licenseTypeId          = licenseTypeId;
        this.target                 = target;
        this.contentType            = contentType;
        this.emailTemplateId        = emailTemplateId;
        this.emailSubject           = emailSubject;
        this.emailBody              = emailBody;
        this.statusFilter           = statusFilter;
        this.molFilter              = molFilter;
        this.specialPrivilegeFilter = specialPrivilegeFilter;
        this.classificationFilter   = classificationFilter;

        // Resolve Org-Wide Email Address
        List<OrgWideEmailAddress> owea = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE DisplayName = 'DCCA No Reply'
            LIMIT 1
        ];
        if (!owea.isEmpty()) {
            this.orgWideEmailAddressId = owea[0].Id;
        }

        // Resolve template name (used in Task subject)
        if (contentType == 'Template' && String.isNotBlank(emailTemplateId)) {
            List<EmailTemplate> templates = [
                SELECT Name FROM EmailTemplate WHERE Id = :emailTemplateId LIMIT 1
            ];
            if (!templates.isEmpty()) {
                this.templateName = templates[0].Name;
            }
        }
    }

    // ── Batchable interface ─────────────────────────────────

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(buildQuery());
    }

    public void execute(Database.BatchableContext bc, List<SObject> records) {
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<Task> pendingTasks = new List<Task>();

        for (SObject record : records) {
            String email = getEmail(record);
            if (String.isBlank(email)) {
                continue;
            }

            // ── Build email message ─────────────────────────
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[]{ email });
            msg.setTargetObjectId(UserInfo.getUserId());
            msg.setWhatId(record.Id);
            msg.setTreatTargetObjectAsRecipient(false);
            msg.setSaveAsActivity(false);

            if (orgWideEmailAddressId != null) {
                msg.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }

            // ── Build Task fields ───────────────────────────
            String taskSubject;
            String taskBody;

            if (contentType == 'Template') {
                msg.setTemplateId(emailTemplateId);
                taskSubject = 'Mass Email: ' + (templateName != null ? templateName : 'Email Template');
                taskBody = 'Sent via email template: ' + (templateName != null ? templateName : emailTemplateId);
            } else {
                String mergedSubject = replaceMergeTags(emailSubject, record);
                String mergedBody    = replaceMergeTags(emailBody, record);
                msg.setSubject(mergedSubject);
                msg.setPlainTextBody(mergedBody);
                taskSubject = 'Mass Email: ' + mergedSubject;
                taskBody    = mergedBody;
            }

            messages.add(msg);

            // Prepare corresponding Task
            Task t = new Task();
            t.TaskSubtype  = 'Email';
            t.Subject      = truncate(taskSubject, 255);
            t.WhatId       = record.Id;
            t.Description  = truncate(taskBody, 32000);
            t.ActivityDate = Date.today();
            t.Status       = 'Completed';
            pendingTasks.add(t);
        }

        if (messages.isEmpty()) {
            return;
        }

        // ── Send emails ─────────────────────────────────────
        List<Messaging.SendEmailResult> results = Messaging.sendEmail(messages, false);

        // Only insert Tasks for successfully sent emails
        List<Task> tasksToInsert = new List<Task>();
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
                tasksToInsert.add(pendingTasks[i]);
            } else {
                failureCount++;
                for (Messaging.SendEmailError err : results[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'PVL_MassEmailBatch send error: ' + err.getMessage());
                }
            }
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }

    public void finish(Database.BatchableContext bc) {
        LicenseType__c lt = [
            SELECT Id, Name FROM LicenseType__c WHERE Id = :this.licenseTypeId LIMIT 1
        ];

        String summary = lt.Name + ' - Sent: ' + successCount + ', Failed: ' + failureCount;
        BatchJobFinishNotification notification =
            new BatchJobFinishNotification('Send Mass Email', summary);
        notification.sendEmail();
    }

    // ── Private helpers ─────────────────────────────────────

    /**
     * Builds the dynamic SOQL query for Licenses or Applications.
     * Bind variables (e.g. :licenseTypeId, :statusFilter) reference
     * instance variables of this batch class.
     */
    private String buildQuery() {
        String fields;
        String objectName;
        String baseFilter;

        if (target == 'Licenses') {
            fields = 'Id, Name, PVL_Portal_User__r.Email__c, '
                + 'LicenseeNameFormula__c, LicenseNumberFormula__c, '
                + 'LicenseTypeName__c, Status__c, '
                + 'MethodofLicensure__c, Privilege__c';
            objectName = 'License__c';
            baseFilter = 'LicenseType__c = :licenseTypeId '
                + 'AND PVL_Portal_User__c != null '
                + 'AND PVL_Portal_User__r.Email__c != null';
        } else {
            fields = 'Id, Name, PVLPortalUser__r.Email__c, '
                + 'Applicant__r.Name, LicenseNumber__c, '
                + 'LicenseType__r.Name, Status__c, MethodofLicensure__c';
            objectName = 'Application__c';
            baseFilter = 'LicenseType__c = :licenseTypeId '
                + 'AND PVLPortalUser__c != null '
                + 'AND PVLPortalUser__r.Email__c != null';
        }

        String query = 'SELECT ' + fields + ' FROM ' + objectName
            + ' WHERE ' + baseFilter;

        // Status filter
        if (!statusFilter.isEmpty()) {
            query += ' AND Status__c IN :statusFilter';
        }

        // Method of Licensure filter
        if (!molFilter.isEmpty()) {
            query += ' AND MethodofLicensure__c IN :molFilter';
        }

        // Special Privilege filter (Licenses only – field is Privilege__c)
        if (target == 'Licenses' && !specialPrivilegeFilter.isEmpty()) {
            query += ' AND Privilege__c IN :specialPrivilegeFilter';
        }

        // Classification filter via sub-query
        if (!classificationFilter.isEmpty()) {
            if (target == 'Licenses') {
                query += ' AND Id IN (SELECT License__c FROM LicenseClassification__c '
                    + 'WHERE ClassificationName__c IN :classificationFilter)';
            } else {
                query += ' AND Id IN (SELECT Application__c FROM ApplicationClassifications__c '
                    + 'WHERE Classification__r.Name IN :classificationFilter)';
            }
        }

        return query;
    }

    /** Extracts the recipient email from a License or Application record. */
    private String getEmail(SObject record) {
        if (target == 'Licenses') {
            License__c lic = (License__c) record;
            return lic.PVL_Portal_User__r != null ? lic.PVL_Portal_User__r.Email__c : null;
        } else {
            Application__c app = (Application__c) record;
            return app.PVLPortalUser__r != null ? app.PVLPortalUser__r.Email__c : null;
        }
    }

    /**
     * Replaces merge-tag placeholders in free-text content.
     * Supported tags: {!Name}, {!LicenseNumber}, {!LicenseType}
     */
    private String replaceMergeTags(String text, SObject record) {
        if (String.isBlank(text)) {
            return text;
        }

        if (target == 'Licenses') {
            License__c lic = (License__c) record;
            text = text.replace('{!Name}',          nullSafe(lic.LicenseeNameFormula__c));
            text = text.replace('{!LicenseNumber}', nullSafe(String.valueOf(lic.LicenseNumberFormula__c)));
            text = text.replace('{!LicenseType}',   nullSafe(lic.LicenseTypeName__c));
        } else {
            Application__c app = (Application__c) record;
            String applicantName = (app.Applicant__r != null) ? app.Applicant__r.Name : null;
            String licTypeName   = (app.LicenseType__r != null) ? app.LicenseType__r.Name : null;
            text = text.replace('{!Name}',          nullSafe(applicantName));
            text = text.replace('{!LicenseNumber}', nullSafe(String.valueOf(app.LicenseNumber__c)));
            text = text.replace('{!LicenseType}',   nullSafe(licTypeName));
        }

        return text;
    }

    private static String nullSafe(String value) {
        return value != null ? value : '';
    }

    private static String truncate(String value, Integer maxLen) {
        if (value == null) {
            return null;
        }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }
}