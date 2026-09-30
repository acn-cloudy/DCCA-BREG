/********************************************************************************************************
*    Name:  PaymentXBatchScheduler.cls
*    Author: PacificPoint
*    Date:  10/22/2018
*    Scheduler Class FOR: PaymentXBatch.cls
**********************************************************************************************************/
global class PaymentXBatchScheduler implements Schedulable {
   global void execute(SchedulableContext sc) {
      PaymentXBatch b = new PaymentXBatch(); 
      database.executebatch(b, 25);
   }
}