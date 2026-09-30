@isTest
public class SanctionServiceTest {
    @TestSetup
    static void setup(){
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        
        SEBCase__c SEBCase = new SEBCase__c(
            Account__c = acct.Id
            
        );
        insert SEBCase;
        // Setup: Create 50 Sanction__c records
        List<Sanction__c> testSanctions = new List<Sanction__c>();
        for (Integer i = 0; i < 50; i++) {
            Sanction__c newSanction = new Sanction__c(
                EntertheNumberofRemainingPayments__c = 3,
                StartDateoftheNextScheduledPayment__c = Date.newInstance(2023, 9, 1),
                EntertheAmountofEachPayment__c = 100.0,
                DayoftheMonthPaymentsareDue__c = '1',
                SEBCaseID__c=SEBCase.Id
            );
            testSanctions.add(newSanction);
        }
        insert testSanctions;
        List<Sanction_Payment__c> initialPayments = new List<Sanction_Payment__c>();
        for(Sanction__c record: testSanctions) {
            initialPayments.add(new Sanction_Payment__c(
            Sanction__c = record.Id,
            AmountDue__c = 0,
            Type__c = 'Initial Payment',
            DueDate__c = Date.today().addDays(30) // Dummy date
            ));
        }
        
        insert initialPayments;
    }
    

    

    @isTest
    static void testTriggerBulk() {
        // Setup: Create 200 Sanction__c records
        // Retrieve the inserted records
        List<Sanction__c> testSanctions = 
            [SELECT Id, GeneratePaymentSchedule__c, EntertheNumberofRemainingPayments__c, StartDateoftheNextScheduledPayment__c, EntertheAmountofEachPayment__c FROM Sanction__c];


        // Update Sanctions to fire the trigger
        for (Sanction__c record : testSanctions) {
            record.GeneratePaymentSchedule__c = true;
            record.EntertheNumberofRemainingPayments__c = 3;
        }
        Test.startTest();
        update testSanctions;
        Test.stopTest();

        // Verify: Trigger should have called SanctionService.generatePayments
        List<Sanction_Payment__c> generatedPayments = [SELECT Id, AmountDue__c, DueDate__c, Type__c, Sanction__c 
            FROM Sanction_Payment__c WHERE Sanction__c IN :testSanctions and Type__c = 'Installment Payment'];
        
        // 3 payments should be created for each of the 200 Sanctions
        System.assertEquals(150, generatedPayments.size(), 'Should have generated 150 payments.');

        // Count the number of payments generated for each Sanction__c
        Map<Id, Integer> sanctionPaymentCount = new Map<Id, Integer>();
        
        for (Sanction_Payment__c payment : generatedPayments) {
            if (sanctionPaymentCount.containsKey(payment.Sanction__c)) {
                sanctionPaymentCount.put(payment.Sanction__c, sanctionPaymentCount.get(payment.Sanction__c) + 1);
            } else {
                sanctionPaymentCount.put(payment.Sanction__c, 1);
            }
        }

        // Verify that 3 payments were generated for each Sanction__c
        for (Id sanctionId : sanctionPaymentCount.keySet()) {
            System.assertEquals(3, sanctionPaymentCount.get(sanctionId), 'Should have generated 3 payments for each Sanction__c');
        }
    }
}