/**
 * @description Handler for Case trigger - Qualtrics integration
 * Supports three lifecycle events: Opened, Updated, Closed
 * @author Qualtrics Integration Team
 */
public with sharing class QualCaseTriggerHandler {
    
    // Recursion guard
    private static Boolean isExecuting = false;

    /**
     * @description Handle after insert trigger event - detects newly created Cases
     * @param newCases List of newly inserted Cases
     */
    public static void handleAfterInsert(List<Case> newCases) {
        if (isExecuting) {
            return;
        }

        qual_Config__mdt config = QualConfigSelector.getActiveConfig();
        if (config == null || !config.qual_Is_Active__c) {
            return;
        }

        if (!isEventTypeEnabled(config, 'Opened')) {
            return;
        }

        try {
            isExecuting = true;

            List<Id> eligibleCaseIds = filterEligibleCases(newCases, config, 'Opened');

            if (!eligibleCaseIds.isEmpty()) {
                Integer delayMinutes = getDelayMinutes(config);
                if (delayMinutes > 0) {
                    Map<Id, String> deferMap = new Map<Id, String>();
                    for (Id caseId : eligibleCaseIds) {
                        deferMap.put(caseId, 'Opened');
                    }
                    QualIntegrationLogger.createDeferredLogs(deferMap, delayMinutes, config);
                } else {
                    Map<Id, String> eventTypeMap = new Map<Id, String>();
                    for (Id caseId : eligibleCaseIds) {
                        eventTypeMap.put(caseId, 'Opened');
                    }
                    System.enqueueJob(new QualCalloutQueueable(eligibleCaseIds, eventTypeMap));
                }
            }

        } finally {
            isExecuting = false;
        }
    }
    
    /**
     * @description Handle after update trigger event
     * Detects two event types: Closed (existing) and Updated (new)
     * @param newCases List of updated Cases
     * @param oldCaseMap Map of old Case values
     */
    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        if (isExecuting) {
            return;
        }
        
        qual_Config__mdt config = QualConfigSelector.getActiveConfig();
        if (config == null || !config.qual_Is_Active__c) {
            return;
        }
        
        try {
            isExecuting = true;

            Boolean closedEnabled = isEventTypeEnabled(config, 'Closed');
            Boolean updatedEnabled = isEventTypeEnabled(config, 'Updated');
            Set<String> trackedFields = updatedEnabled
                ? parseFilterList(config.qual_Case_Tracked_Update_Fields__c)
                : new Set<String>();
            
            // Collect candidates by event type
            List<Case> closedCandidates = new List<Case>();
            List<Case> updatedCandidates = new List<Case>();
            
            for (Case newCase : newCases) {
                Case oldCase = oldCaseMap.get(newCase.Id);
                
                if (isCaseJustClosed(newCase, oldCase)) {
                    // Closed takes priority — do not also fire Updated
                    if (closedEnabled) {
                        closedCandidates.add(newCase);
                    }
                } else if (updatedEnabled && !newCase.IsClosed && hasSignificantUpdate(newCase, oldCase, trackedFields)) {
                    updatedCandidates.add(newCase);
                }
            }
            
            // Apply filters
            List<Id> closedIds = filterEligibleCases(closedCandidates, config, 'Closed');
            List<Id> updatedIds = filterEligibleCases(updatedCandidates, config, 'Updated');

            // Cancel any pending deferred logs for cases that are now closing
            if (!closedIds.isEmpty()) {
                QualIntegrationLogger.cancelDeferredLogs(new Set<Id>(closedIds));
            }

            // Closed events always send immediately
            Map<Id, String> immediateMap = new Map<Id, String>();
            for (Id caseId : closedIds) {
                immediateMap.put(caseId, 'Closed');
            }

            if (!immediateMap.isEmpty()) {
                List<Id> immediateIds = new List<Id>(immediateMap.keySet());
                System.enqueueJob(new QualCalloutQueueable(immediateIds, immediateMap));
            }

            // Updated events are deferred if delay > 0
            if (!updatedIds.isEmpty()) {
                Integer delayMinutes = getDelayMinutes(config);
                if (delayMinutes > 0) {
                    Map<Id, String> deferMap = new Map<Id, String>();
                    for (Id caseId : updatedIds) {
                        deferMap.put(caseId, 'Updated');
                    }
                    QualIntegrationLogger.createDeferredLogs(deferMap, delayMinutes, config);
                } else {
                    Map<Id, String> updatedMap = new Map<Id, String>();
                    for (Id caseId : updatedIds) {
                        updatedMap.put(caseId, 'Updated');
                    }
                    System.enqueueJob(new QualCalloutQueueable(new List<Id>(updatedMap.keySet()), updatedMap));
                }
            }
            
        } finally {
            isExecuting = false;
        }
    }

    /**
     * @description Check if a given event type is enabled in configuration
     * @param config Active configuration record
     * @param eventType Event type to check (Opened, Updated, Closed)
     * @return True if the event type is enabled
     */
    @TestVisible
    private static Boolean isEventTypeEnabled(qual_Config__mdt config, String eventType) {
        if (config == null || String.isBlank(eventType)) {
            return false;
        }

        String configValue = config.qual_Case_Event_Types__c;

        // Default to Closed only for backward compatibility
        if (String.isBlank(configValue)) {
            return eventType.equalsIgnoreCase('Closed');
        }

        Set<String> enabledTypes = parseFilterList(configValue);
        return enabledTypes.contains(eventType.toLowerCase());
    }

    /**
     * @description Check if any tracked field changed between old and new Case
     * @param newCase Updated Case record
     * @param oldCase Previous Case record
     * @param trackedFields Set of field API names to check (lowercase)
     * @return True if at least one tracked field changed
     */
    @TestVisible
    private static Boolean hasSignificantUpdate(Case newCase, Case oldCase, Set<String> trackedFields) {
        if (trackedFields == null || trackedFields.isEmpty()) {
            return false;
        }

        Map<String, SObjectField> fieldMap = Case.SObjectType.getDescribe().fields.getMap();

        for (String fieldName : trackedFields) {
            // parseFilterList lowercases; field map keys are also lowercase
            SObjectField field = fieldMap.get(fieldName);
            if (field == null) {
                continue;
            }
            Object newVal = newCase.get(field);
            Object oldVal = oldCase.get(field);
            if (newVal != oldVal) {
                return true;
            }
        }

        return false;
    }
    
    /**
     * @description Filter candidate cases based on configuration criteria
     * @param candidateCases List of candidate Cases
     * @param config Configuration with filter settings
     * @param eventType Lifecycle event type — status filter is only applied for Closed events
     * @return List of Case IDs that pass all filters
     */
    @TestVisible
    private static List<Id> filterEligibleCases(List<Case> candidateCases, qual_Config__mdt config, String eventType) {
        if (candidateCases.isEmpty()) {
            return new List<Id>();
        }
        
        Boolean skipStatusFilter = !'Closed'.equalsIgnoreCase(eventType);
        CaseFilterContext ctx = new CaseFilterContext(config, candidateCases, skipStatusFilter);
        
        List<Id> passingIds = new List<Id>();
        for (Case c : candidateCases) {
            if (passesCaseFilters(c, ctx)) {
                passingIds.add(c.Id);
            }
        }
        
        if (String.isNotBlank(config.qual_Case_Custom_Soql_Filter__c) && !passingIds.isEmpty()) {
            passingIds = applyCustomSoqlFilter(passingIds, config.qual_Case_Custom_Soql_Filter__c);
        }
        
        return passingIds;
    }
    
    /**
     * @description Context object holding parsed filter criteria
     */
    private class CaseFilterContext {
        public Set<String> allowedStatuses;
        public Set<String> allowedOrigins;
        public Set<String> allowedPriorities;
        public Set<String> allowedTypes;
        public Set<String> allowedRecordTypes;
        public Boolean requireContact;
        public Map<Id, String> recordTypeMap;
        
        public CaseFilterContext(qual_Config__mdt config, List<Case> cases, Boolean skipStatusFilter) {
            this.allowedStatuses = skipStatusFilter ? new Set<String>() : parseFilterList(config.qual_Case_Filter_Statuses__c);
            this.allowedOrigins = parseFilterList(config.qual_Case_Filter_Origins__c);
            this.allowedPriorities = parseFilterList(config.qual_Case_Filter_Priorities__c);
            this.allowedTypes = parseFilterList(config.qual_Case_Filter_Types__c);
            this.allowedRecordTypes = parseFilterList(config.qual_Case_Filter_RecordTypes__c);
            this.requireContact = config.qual_Case_Require_Contact__c == true;
            this.recordTypeMap = this.allowedRecordTypes.isEmpty() 
                ? new Map<Id, String>() 
                : getRecordTypeDevNameMap(cases);
        }
    }
    
    /**
     * @description Check if a single Case passes all configured filters
     */
    private static Boolean passesCaseFilters(Case c, CaseFilterContext ctx) {
        if (ctx.requireContact && c.ContactId == null) {
            return false;
        }
        if (!ctx.allowedStatuses.isEmpty() && !ctx.allowedStatuses.contains(normalizeValue(c.Status))) {
            return false;
        }
        if (!ctx.allowedOrigins.isEmpty() && !ctx.allowedOrigins.contains(normalizeValue(c.Origin))) {
            return false;
        }
        if (!ctx.allowedPriorities.isEmpty() && !ctx.allowedPriorities.contains(normalizeValue(c.Priority))) {
            return false;
        }
        if (!ctx.allowedTypes.isEmpty() && !ctx.allowedTypes.contains(normalizeValue(c.Type))) {
            return false;
        }
        if (!ctx.allowedRecordTypes.isEmpty()) {
            String devName = ctx.recordTypeMap.get(c.RecordTypeId);
            if (devName == null || !ctx.allowedRecordTypes.contains(devName.toLowerCase())) {
                return false;
            }
        }
        return true;
    }
    
    /**
     * @description Parse comma/newline-separated filter list into a Set (lowercase)
     */
    @TestVisible
    private static Set<String> parseFilterList(String filterValue) {
        Set<String> result = new Set<String>();
        
        if (String.isBlank(filterValue)) {
            return result;
        }
        
        List<String> parts = filterValue.split('[,\\n\\r]+');
        for (String part : parts) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed.toLowerCase());
            }
        }
        
        return result;
    }
    
    /**
     * @description Normalize a field value for comparison (lowercase, handle null)
     */
    private static String normalizeValue(String value) {
        return value == null ? '' : value.toLowerCase();
    }
    
    /**
     * @description Build a map of RecordTypeId to DeveloperName for the given Cases
     */
    private static Map<Id, String> getRecordTypeDevNameMap(List<Case> cases) {
        Set<Id> recordTypeIds = new Set<Id>();
        for (Case c : cases) {
            if (c.RecordTypeId != null) {
                recordTypeIds.add(c.RecordTypeId);
            }
        }
        
        Map<Id, String> result = new Map<Id, String>();
        if (!recordTypeIds.isEmpty()) {
            for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE Id IN :recordTypeIds WITH SECURITY_ENFORCED]) {
                result.put(rt.Id, rt.DeveloperName);
            }
        }
        
        return result;
    }
    
    /**
     * @description Apply custom SOQL WHERE predicate to filter case IDs
     */
    @TestVisible
    private static List<Id> applyCustomSoqlFilter(List<Id> caseIds, String predicate) {
        String cleanPredicate = predicate.trim();
        if (cleanPredicate.toLowerCase().startsWith('where ')) {
            cleanPredicate = cleanPredicate.substring(6).trim();
        }
        
        String query = 'SELECT Id FROM Case WHERE Id IN :caseIds AND (' + cleanPredicate + ')';
        
        try {
            Map<String, Object> binds = new Map<String, Object>{ 'caseIds' => caseIds };
            List<Case> matchingCases = Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
            
            List<Id> result = new List<Id>();
            for (Case c : matchingCases) {
                result.add(c.Id);
            }
            return result;
            
        } catch (QueryException ex) {
            System.debug(LoggingLevel.WARN, 'QualCaseTriggerHandler: Invalid custom SOQL predicate: ' + predicate + '. Error: ' + ex.getMessage());
            return new List<Id>();
        }
    }
    
    /**
     * @description Check if Case just transitioned to closed status
     */
    @TestVisible
    private static Boolean isCaseJustClosed(Case newCase, Case oldCase) {
        if (newCase.IsClosed && !oldCase.IsClosed) {
            return true;
        }
        return false;
    }
    
    /**
     * @description Get configured delay for non-Closed events (0 = immediate)
     */
    private static Integer getDelayMinutes(qual_Config__mdt config) {
        if (config != null && config.qual_Case_Opened_Delay_Minutes__c != null) {
            return Integer.valueOf(config.qual_Case_Opened_Delay_Minutes__c);
        }
        return 120;
    }

    /**
     * @description Reset recursion guard (for testing)
     */
    @TestVisible
    private static void resetRecursionGuard() {
        isExecuting = false;
    }
}