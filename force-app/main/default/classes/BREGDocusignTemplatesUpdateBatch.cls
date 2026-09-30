public with sharing class BREGDocusignTemplatesUpdateBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private static final Integer DEFAULT_BATCH_SIZE = 10;
    private static final String FILTER_TYPE_LABEL = 'LABEL';
    private static final String FILTER_TYPE_FOLDER = 'FOLDER';

    private String labelFilter;
    private Set<String> labelFilters;
    private Set<String> folderPathFilters;
    private String listFilterType = FILTER_TYPE_LABEL;
    private Integer processedCount = 0;
    private Integer errorCount = 0;

    public BREGDocusignTemplatesUpdateBatch() {
    }

    public BREGDocusignTemplatesUpdateBatch(String labelFilter) {
        this.labelFilter = labelFilter;
    }

    public BREGDocusignTemplatesUpdateBatch(List<String> labelFilters) {
        this(labelFilters, FILTER_TYPE_LABEL);
    }

    public BREGDocusignTemplatesUpdateBatch(List<String> filters, String filterType) {
        if (String.isNotBlank(filterType)) {
            String normalizedFilterType = filterType.trim().toUpperCase();
            if (normalizedFilterType == FILTER_TYPE_FOLDER) {
                this.listFilterType = FILTER_TYPE_FOLDER;
            }
        }

        if (this.listFilterType == FILTER_TYPE_FOLDER) {
            this.folderPathFilters = normalizeFilters(filters);
            return;
        }

        this.labelFilters = normalizeFilters(filters);
    }

    private static Set<String> normalizeFilters(List<String> filters) {
        Set<String> normalizedFilters = new Set<String>();
        if (filters == null) {
            return normalizedFilters;
        }

        for (String nextFilter : filters) {
            if (String.isNotBlank(nextFilter)) {
                normalizedFilters.add(nextFilter.trim());
            }
        }

        return normalizedFilters;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (labelFilters == null) {
            labelFilters = new Set<String>();
        }
        if (folderPathFilters == null) {
            folderPathFilters = new Set<String>();
        }

        if (String.isNotBlank(labelFilter)) {
            labelFilters.add(labelFilter.trim());
        }

        String baseQuery =
            'SELECT Id, Label, breg_Folder_Path__c, breg_Template_Name__c ' +
            'FROM BREG_Docusign_Templates_Setting__mdt ' +
            'WHERE breg_Template_Name__c != NULL AND breg_Folder_Path__c != NULL';

        if (!labelFilters.isEmpty()) {
            baseQuery += ' AND Label IN :labelFilters';
        } else if (!folderPathFilters.isEmpty()) {
            baseQuery += ' AND breg_Folder_Path__c IN :folderPathFilters';
        }

        return Database.getQueryLocator(baseQuery);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope.isEmpty()) {
            return;
        }

        List<BREG_Docusign_Templates_Setting__mdt> templateSettings = new List<BREG_Docusign_Templates_Setting__mdt>();
        for (SObject row : scope) {
            templateSettings.add((BREG_Docusign_Templates_Setting__mdt) row);
        }

        try {
            DocusignAPI.updateDocumentTemplates(templateSettings, 'BREGDocusignTemplatesUpdateBatch');
            processedCount += templateSettings.size();
        } catch (Exception e) {
            errorCount++;
            System.debug(LoggingLevel.ERROR, 'BREGDocusignTemplatesUpdateBatch execute failed: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'BREGDocusignTemplatesUpdateBatch completed. Processed: ' + processedCount + ', Errors: ' + errorCount
        );
    }

    public static Id runBatch() {
        return Database.executeBatch(new BREGDocusignTemplatesUpdateBatch(), DEFAULT_BATCH_SIZE);
    }

    public static Id runBatch(String labelFilter) {
        return Database.executeBatch(new BREGDocusignTemplatesUpdateBatch(labelFilter), DEFAULT_BATCH_SIZE);
    }

    public static Id runBatch(List<String> labelFilters) {
        return Database.executeBatch(new BREGDocusignTemplatesUpdateBatch(labelFilters), DEFAULT_BATCH_SIZE);
    }

    public static Id runBatch(List<String> filters, String filterType) {
        return Database.executeBatch(new BREGDocusignTemplatesUpdateBatch(filters, filterType), DEFAULT_BATCH_SIZE);
    }
}