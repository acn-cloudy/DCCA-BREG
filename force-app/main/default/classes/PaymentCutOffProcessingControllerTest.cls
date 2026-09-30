@isTest(seeAllData=false)
public class PaymentCutOffProcessingControllerTest {

    @isTest
    static void testConstructor() {

        Test.setCurrentPage(new PageReference('/apex/testPage'));
        ApexPages.currentPage().getParameters().put(
            'jobId',
            '707000000000001'
        );

        PaymentCutOffProcessingController ctrl =
            new PaymentCutOffProcessingController();
    }

    @isTest
    static void testGetConfirmationMessage_NoBatch() {

        Test.setCurrentPage(new PageReference('/apex/testPage'));

        PaymentCutOffProcessingController ctrl =
            new PaymentCutOffProcessingController();

        String result = ctrl.getConfirmationMessage();
    }

    @isTest
    static void testGetConfirmationMessage_WithBatch() {

        // Insert actual batch so Name auto-generates
        Reconciliation_Batch__c rb = new Reconciliation_Batch__c(
            Batch_Time__c = System.now(),
            Status__c = 'Pending Review'
        );
        insert rb;

        PaymentCutOffProcessingController ctrl =
            new PaymentCutOffProcessingController();

        ctrl.rb = rb;

        String result = ctrl.getConfirmationMessage();
    }

    @isTest
    static void testCheckStatus_AlreadyCompleted() {

        PaymentCutOffProcessingController ctrl =
            new PaymentCutOffProcessingController();

        ctrl.completed = true;

        Test.startTest();

        ctrl.checkStatus();

        Test.stopTest();
    }

    @isTest
    static void testCheckStatus_CompletesSuccessfully() {

        // Create reconciliation batch
        Reconciliation_Batch__c rb = new Reconciliation_Batch__c(
            Batch_Time__c = System.now(),
            Status__c = 'Pending Review',
            OwnerId = UserInfo.getUserId()
        );
        insert rb;

        // Setup page params BEFORE controller instantiation
        Test.setCurrentPage(new PageReference('/apex/testPage'));

        Test.startTest();

        // Execute batch inside same test window
        Id jobId = Database.executeBatch(
            new ReconciliationBatchJob(),
            1
        );

        ApexPages.currentPage().getParameters().put(
            'jobId',
            String.valueOf(jobId)
        );

        PaymentCutOffProcessingController ctrl =
            new PaymentCutOffProcessingController();

        ctrl.checkStatus();

        Test.stopTest();
    }
}