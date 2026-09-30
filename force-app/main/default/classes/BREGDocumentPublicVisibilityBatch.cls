public with sharing class BREGDocumentPublicVisibilityBatch extends BREGBaseBatchJob implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
    // Tracking variables
    private Integer processedCount = 0;
    private Integer updatedCount = 0;
    private Integer futureDocCount = 0;
    private Integer pastDocCount = 0;
    private Integer errorCount = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, breg_Effective_Date__c
                FROM Case
                WHERE Status = 'Completed' AND breg_Form_Code__c IN ('X-13', 'X-9') AND breg_Effective_Date__c != NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Case> cases) {
        Date today = Date.today();
        Set<Id> futureCaseIds = new Set<Id>();
        Set<Id> pastCaseIds = new Set<Id>();

        processedCount += cases.size();

        for (Case iCase : cases) {
            if (iCase.breg_Effective_Date__c > today) {
                futureCaseIds.add(iCase.Id);
            } else if (iCase.breg_Effective_Date__c <= today) {
                pastCaseIds.add(iCase.Id);
            }
        }

        List<breg_Document__c> documentsToUpdate = new List<breg_Document__c>();
        documentsToUpdate.addAll(processFutureDocuments(futureCaseIds));
        documentsToUpdate.addAll(processPastDocuments(pastCaseIds));

        if (!documentsToUpdate.isEmpty()) {
            try {
                update documentsToUpdate;
                updatedCount += documentsToUpdate.size();
                System.debug('✅ Updated ' + documentsToUpdate.size() + ' documents public visibility.');
            } catch (Exception e) {
                errorCount += documentsToUpdate.size();
                System.debug('❌ Error updating documents: ' + e.getMessage());
                logs.add('Error updating documents: ' + e.getMessage());
            }
        }
    }

    private List<breg_Document__c> processFutureDocuments(Set<Id> caseIds) {
        List<breg_Document__c> documentsToUpdate = new List<breg_Document__c>();
        if (caseIds.isEmpty()) {
            return documentsToUpdate;
        }
        List<breg_Document__c> futureDocs = getDocumentByCaseIdsAndIsPublic(caseIds, true);
        futureDocCount += futureDocs.size();
        for (breg_Document__c doc : futureDocs) {
            doc.breg_Is_Public__c = false;
            documentsToUpdate.add(doc);
        }

        return documentsToUpdate;
    }

    private List<breg_Document__c> processPastDocuments(Set<Id> caseIds) {
        List<breg_Document__c> documentsToUpdate = new List<breg_Document__c>();
        if (caseIds.isEmpty()) {
            return documentsToUpdate;
        }
        List<breg_Document__c> pastDocs = getDocumentByCaseIdsAndIsPublic(caseIds, false);
        pastDocCount += pastDocs.size();
        for (breg_Document__c doc : pastDocs) {
            doc.breg_Is_Public__c = true;
            documentsToUpdate.add(doc);
        }

        return documentsToUpdate;
    }

    private List<breg_Document__c> getDocumentByCaseIdsAndIsPublic(Set<Id> caseIds, Boolean isPublic) {
        return [
            SELECT Id, breg_Is_Public__c
            FROM breg_Document__c
            WHERE breg_Case__c IN :caseIds AND breg_Is_Public__c = :isPublic
            LIMIT 10000
        ];
    }

    public void finish(Database.BatchableContext bc) {
        // Create Batch Job Execution record to track batch results
        try {
            // Build detailed results summary in JSON format
            Map<String, Object> summaryData = new Map<String, Object>();
            summaryData.put('jobName', 'BREGDocumentPublicVisibilityBatch');
            addExecutionModeToSummary(summaryData);

            // Counts section
            Map<String, Integer> counts = new Map<String, Integer>();
            counts.put('processedCount', this.processedCount);
            counts.put('updatedCount', this.updatedCount);
            counts.put('futureDocCount', this.futureDocCount);
            counts.put('pastDocCount', this.pastDocCount);
            counts.put('errorCount', this.errorCount);
            counts.put('totalProcessed', this.processedCount);
            summaryData.put('counts', counts);

            // Additional metadata
            summaryData.put('processingDate', Date.today().format());
            summaryData.put('formCodes', 'X-13, X-9');

            // Add logs if any
            if (!logs.isEmpty()) {
                summaryData.put('logs', logs);
            }

            breg_Batch_Job_Execution__c jobRecord = createBatchExecutionRecord('BREGDocumentPublicVisibilityBatch', summaryData);

            // Set legacy count fields for this specific job
            jobRecord.breg_Total_Count__c = this.processedCount;

            insert jobRecord;

            System.debug(
                '🏁 BREGDocumentPublicVisibilityBatch completed. Processed: ' +
                    processedCount +
                    ', Updated: ' +
                    updatedCount +
                    ', Future Docs: ' +
                    futureDocCount +
                    ', Past Docs: ' +
                    pastDocCount +
                    ', Errors: ' +
                    errorCount
            );
        } catch (Exception e) {
            System.debug('Error creating Batch Job Execution record: ' + e.getMessage());
            System.debug(
                '🏁 BREGDocumentPublicVisibilityBatch completed. Processed: ' +
                    processedCount +
                    ', Updated: ' +
                    updatedCount +
                    ', Future Docs: ' +
                    futureDocCount +
                    ', Past Docs: ' +
                    pastDocCount +
                    ', Errors: ' +
                    errorCount
            );
        }
    }

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new BREGDocumentPublicVisibilityBatch(), 200);
    }
}