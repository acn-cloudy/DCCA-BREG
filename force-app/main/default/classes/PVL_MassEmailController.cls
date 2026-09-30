/*
 * ─────────────────────────────────────────────────────────────
 * Controller for the pvlMassEmail LWC Quick Action.
 * Allows sending mass emails to Licenses or Applications
 * of a given License Type.
 * ─────────────────────────────────────────────────────────────
 * VPVL-37 - Mass Email from License Type
 * ─────────────────────────────────────────────────────────────
 * @author  VPVL-37
 * @created 2026-02-06
 * ─────────────────────────────────────────────────────────────
 * Changes
 * Phase 1: Stub implementation (UI wiring only)
 * Phase 2: Full batch implementation
 * ─────────────────────────────────────────────────────────────
 */
public with sharing class PVL_MassEmailController {

    private static final Integer DEFAULT_BATCH_SIZE = 50;

    /**
     * Validates inputs and enqueues PVL_MassEmailBatch to send
     * emails to all matching Licenses or Applications.
     */
    @AuraEnabled
    public static String runMassEmail(
        String licenseTypeId,
        String target,
        String contentType,
        String emailTemplateId,
        String subject,
        String body,
        List<String> statusFilter,
        List<String> molFilter,
        List<String> specialPrivilegeFilter,
        List<String> classificationFilter
    ) {
        // ── Validation ──────────────────────────────────────
        if (String.isBlank(licenseTypeId)) {
            throw new AuraHandledException('License Type Id is required.');
        }
        if (String.isBlank(target) || (target != 'Licenses' && target != 'Applications')) {
            throw new AuraHandledException('Target must be Licenses or Applications.');
        }
        if (contentType == 'Template' && String.isBlank(emailTemplateId)) {
            throw new AuraHandledException('Please select an email template.');
        }
        if (contentType == 'FreeText' && (String.isBlank(subject) || String.isBlank(body))) {
            throw new AuraHandledException('Subject and Body are required for free-text emails.');
        }

        // ── Normalize filters ───────────────────────────────
        List<String> safeStatus = statusFilter != null ? statusFilter : new List<String>();
        List<String> safeMol = molFilter != null ? molFilter : new List<String>();
        List<String> safePrivilege = specialPrivilegeFilter != null ? specialPrivilegeFilter : new List<String>();
        List<String> safeClassification = classificationFilter != null ? classificationFilter : new List<String>();

        // ── Enqueue batch ───────────────────────────────────
        PVL_MassEmailBatch batch = new PVL_MassEmailBatch(
            licenseTypeId, target, contentType,
            emailTemplateId, subject, body,
            safeStatus, safeMol, safePrivilege, safeClassification
        );

        Database.executeBatch(batch, DEFAULT_BATCH_SIZE);

        return 'Mass email job has been queued successfully for ' + target + '.';
    }

    /**
     * Returns active Email Templates for the template-picker dropdown.
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailTemplateWrapper> getEmailTemplates() {
        List<EmailTemplateWrapper> wrappers = new List<EmailTemplateWrapper>();
        for (EmailTemplate et : [
            SELECT Id, Name, DeveloperName, Subject
            FROM EmailTemplate
            WHERE IsActive = true
            ORDER BY Name
            LIMIT 200
        ]) {
            wrappers.add(new EmailTemplateWrapper(et.Id, et.Name, et.DeveloperName, et.Subject));
        }
        return wrappers;
    }

    /**
     * Returns Status picklist values for License__c or Application__c
     * depending on the target parameter.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getStatusPicklistValues(String target) {
        List<PicklistOption> options = new List<PicklistOption>();
        List<Schema.PicklistEntry> entries;

        if (target == 'Applications') {
            entries = Application__c.Status__c.getDescribe().getPicklistValues();
        } else {
            entries = License__c.Status__c.getDescribe().getPicklistValues();
        }

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    /**
     * Returns Method of Licensure picklist values for License__c or Application__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getMolPicklistValues(String target) {
        List<PicklistOption> options = new List<PicklistOption>();
        List<Schema.PicklistEntry> entries;

        if (target == 'Applications') {
            entries = Application__c.MethodofLicensure__c.getDescribe().getPicklistValues();
        } else {
            entries = License__c.MethodofLicensure__c.getDescribe().getPicklistValues();
        }

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    /**
     * Returns Special Privilege (Privilege__c) picklist values from License__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getPrivilegePicklistValues() {
        List<PicklistOption> options = new List<PicklistOption>();
        List<Schema.PicklistEntry> entries = License__c.Privilege__c.getDescribe().getPicklistValues();

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    /**
     * Returns active Classification names for a given License Type.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getClassificationValues(String licenseTypeId) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Classification__c cls : [
            SELECT Id, Name
            FROM Classification__c
            WHERE LicenseType__c = :licenseTypeId
              AND Status__c = 'Active'
            ORDER BY Name
        ]) {
            options.add(new PicklistOption(cls.Name, cls.Name));
        }
        return options;
    }

    /**
     * Generic picklist option wrapper.
     */
    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * Lightweight wrapper so the LWC can read template details.
     */
    public class EmailTemplateWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String developerName;
        @AuraEnabled public String subject;

        public EmailTemplateWrapper(String id, String name, String developerName, String subject) {
            this.id = id;
            this.name = name;
            this.developerName = developerName;
            this.subject = subject;
        }
    }
}