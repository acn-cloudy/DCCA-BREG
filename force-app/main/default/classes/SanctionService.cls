public class SanctionService {
    public static Boolean skipTrigger = false;
    public static void generatePayments(List<Sanction__c> sanctions) {
        
        List<Sanction_Payment__c> paymentsToInsert = new List<Sanction_Payment__c>();
        
        for (Sanction__c sanction : sanctions) {
            if(sanction.EntertheNumberofRemainingPayments__c == null) continue;
            Integer numPayments = Integer.valueOf(sanction.EntertheNumberofRemainingPayments__c);
            Date nextScheduledPaymentDate = sanction.StartDateoftheNextScheduledPayment__c;
            Decimal amountDue = sanction.EntertheAmountofEachPayment__c;
            Integer dayOfMonth = Integer.valueOf(sanction.DayoftheMonthPaymentsareDue__c);
            
            for (Integer i = 0; i < numPayments; i++) {
                Sanction_Payment__c newPayment = new Sanction_Payment__c();
                newPayment.Sanction__c = sanction.Id;
                newPayment.AmountDue__c = amountDue;
                newPayment.Type__c = 'Installment Payment';
                
                if (i == 0) {
                    newPayment.DueDate__c = nextScheduledPaymentDate;
                } else {
                    // Calculate the next due date based on the provided day of the month
                    Date newDueDate = nextScheduledPaymentDate.addMonths(i);
                    newDueDate = Date.newInstance(newDueDate.year(), newDueDate.month(), dayOfMonth);
                    newPayment.DueDate__c = newDueDate;
                }
                
                paymentsToInsert.add(newPayment);
            }
        }
        
        if (!paymentsToInsert.isEmpty()) {
            SanctionService.skipTrigger = true;
            insert paymentsToInsert;
            SanctionService.skipTrigger = false;
        }
    }
}