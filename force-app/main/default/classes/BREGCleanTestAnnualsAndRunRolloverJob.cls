public class BREGCleanTestAnnualsAndRunRolloverJob extends BREGBaseBatchJob implements Database.Batchable<sObject> {
    //--------------------------------------------------------------------------
    // CONSTRUCTORS
    // -------------------------------------------------------------------------

    public BREGCleanTestAnnualsAndRunRolloverJob() {
    }

    // -------------------------------------------------------------------------
    // BATCHABLE INTERFACE METHODS
    // -------------------------------------------------------------------------

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all test annual records for deletion
        String query = 'SELECT Id FROM breg_Test_Annual__c';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<breg_Test_Annual__c> scope) {
        if (!scope.isEmpty()) {
            try {
                delete scope;
            } catch (Exception e) {
                System.debug('❌ Error deleting test annuals: ' + e.getMessage());
                // Continue processing even if some records fail to delete
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}