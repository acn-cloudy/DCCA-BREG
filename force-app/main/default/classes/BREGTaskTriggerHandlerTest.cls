@isTest
public with sharing class BREGTaskTriggerHandlerTest {

    private static Task createEmailTask(String status, String emailSendingStatus, String to, String cc, String bcc) {
        Task t = new Task(
            Subject = 'Test Email Task',
            TaskSubtype = 'Email',
            Status = status,
            breg_To__c = to,
            breg_Cc__c = cc,
            breg_Bcc__c = bcc
        );
        if (emailSendingStatus != null) {
            t.breg_Email_Sending_Status__c = emailSendingStatus;
        }
        return t;
    }

    @isTest
    static void testAfterInsert_EmailTask_EnqueuesJob() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());
        Task t = createEmailTask('Open', 'Repeat', 'test1@example.com', null, null);

        Test.startTest();
        insert t;
        Test.stopTest();

        // Assert
        // Check that a job was enqueued
        Assert.areEqual(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], '1 queueable job should be enqueued');
    }

    @isTest
    static void testAfterInsert_NonEmailTask_DoesNotEnqueueJob() {
        Task t = new Task(
            Subject = 'Test Non-Email Task',
            TaskSubtype = 'Call',
            Status = 'Open'
        );

        Test.startTest();
        insert t;
        Test.stopTest();

        // Assert
        Assert.areEqual(0, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'No queueable job should be enqueued');
    }

    @isTest
    static void testAfterUpdate_EmailTask_StatusChangedToRepeat_EnqueuesJob() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());
        Task t = createEmailTask('Open', null, 'test1@example.com', null, null);
        insert t;

        // Simulate update to Repeat
        t.breg_Email_Sending_Status__c = 'Repeat';

        Test.startTest();
        update t;
        Test.stopTest();

        // Assert
        // 2 jobs should be enqueued, one for insert, then second when update to Repeat
        Assert.areEqual(2, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], '2 queueable jobs should be enqueued');
    }

    @isTest
    static void testAfterUpdate_EmailTask_OtherFieldChange_DoesNotEnqueueJob() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());
        Task t = createEmailTask('Open', null, 'test1@example.com', null, null);
        insert t;

        t.Subject = 'New Subject';

        Test.startTest();
        update t;
        Test.stopTest();

        // Assert
        // 2 jobs should be enqueued, one for insert, then second when update to Repeat
        Assert.areEqual(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], '1 queueable jobs should be enqueued');
    }

    @isTest
    static void testAfterInsert_EmailTask_RecipientsSplitAcrossFields() {
        // 20 in To, 20 in Cc, 10 in Bcc = 50
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesEmailServiceTest.BREGAmazonSesMockHttpPositiveResponse());
        List<String> toEmails = new List<String>();
        List<String> ccEmails = new List<String>();
        List<String> bccEmails = new List<String>();
        for (Integer i = 0; i < 10; i++) {
            toEmails.add('to' + i + '@example.com');
            ccEmails.add('cc' + i + '@example.com');
        }
        for (Integer i = 0; i < 10; i++) {
            bccEmails.add('bcc' + i + '@example.com');
        }

        Task t = createEmailTask('Open', 'Repeat', String.join(toEmails, ','), String.join(ccEmails, ','), String.join(bccEmails, ','));

        Test.startTest();
        insert t;
        Test.stopTest();

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], '1 queueable job should be enqueued');
    }
}