/********************************************************************************************************
*    Name:  PaymentAllHandlerTest.cls
*    Date:  10/1/2018
*    
*    Class: PaymentAllHandler.cls
********************************************************************************************************/
@isTest
public class PaymentAllHandlerTest {
    
    private static testmethod void testGroupTransaction(){
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;
        
        date sd = Date.Today();
        
        Transaction__c groupTransaction = new Transaction__c();
        groupTransaction.Account__c = acc.Id;
        groupTransaction.Contact__c = cnt.Id;
        groupTransaction.Date__c = sd.addDays(-2);
        groupTransaction.Status__c = 'New';
        groupTransaction.TransactionType__c = 'Group';
        insert groupTransaction;
        
        Transaction__c trans1 = new Transaction__c();
        trans1.Account__c = acc.Id;
        trans1.Contact__c = cnt.Id;
        trans1.Date__c = sd.addDays(-2);
        trans1.Status__c = 'New';
        trans1.TransactionGroup__c = groupTransaction.Id;
        trans1.TransactionType__c = 'Payment';
        insert trans1;
        
        CashierCode__c cc1 = new CashierCode__c();
        cc1.Name = 'Cashier Code 1';
        cc1.Amount__c = 30;
        cc1.CashierCode__c = '000011';
        cc1.Category__c = 'Categ1';
        cc1.Division__c = 'BREG';
        insert cc1;
        
        TransactionLine__c tl1 = new TransactionLine__c();
        tl1.Transaction__c = trans1.Id;
        tl1.Amount__c = 30;
        tl1.CashierCode__c = cc1.Id;
        tl1.Description__c = 'aaa';
        insert tl1;
        
        TransactionLine__c tl11 = new TransactionLine__c();
        tl11.Transaction__c = trans1.Id;
        tl11.Amount__c = 30;
        tl11.CashierCode__c = cc1.Id;
        tl11.Description__c = 'aaa';
        tl11.PaidStatus__c = 'Paid';
        insert tl11;
        
        Transaction__c trans2 = new Transaction__c();
        trans2.Account__c = acc.Id;
        trans2.Contact__c = cnt.Id;
        trans2.Date__c = sd.addDays(-2);
        trans2.Status__c = 'New';
        trans2.TransactionGroup__c = groupTransaction.Id;
        trans2.TransactionType__c = 'Payment';
        insert trans2;
        
        CashierCode__c cc2 = new CashierCode__c();
        cc2.Name = 'Cashier Code 1';
        cc2.Amount__c = 70;
        cc2.CashierCode__c = '000011';
        cc2.Category__c = 'Categ1';
        cc2.Division__c = 'BREG';
        insert cc2;
        
        TransactionLine__c tl2 = new TransactionLine__c();
        tl2.Transaction__c = trans2.Id;
        tl2.CashierCode__c = cc2.Id;
        tl2.Description__c = 'bbb';
        insert tl2;
        Test.startTest();
        TransactionLine__c tl21 = new TransactionLine__c();
        tl21.Transaction__c = trans2.Id;
        tl21.CashierCode__c = cc2.Id;
        tl21.Description__c = 'bbb';
        insert tl21;

        pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
        currentYearPayment1.pymt__Status__c = 'Completed';
        currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(),1,12);
        currentYearPayment1.CreditCardFee__c = 20;
        currentYearPayment1.pymt__Transaction_Fee__c  = 50;
        currentYearPayment1.pymt__Amount__c = 1000;
        currentYearPayment1.Transaction__c = groupTransaction.Id;
        //insert currentYearPayment1;
        
        
        
            
            insert currentYearPayment1;

        Test.stopTest();    
        
        List<TransactionLine__c> UpdatedTransLines = [SELECT Id, PaidStatus__c, Payment__c FROM TransactionLine__c WHERE Transaction__r.TransactionGroup__c =: groupTransaction.Id];
        for( TransactionLine__c tr: UpdatedTransLines ) {
            System.assertEquals('Paid', tr.PaidStatus__c);
            if(tr.Id !=  tl11.Id)
                System.assertEquals(currentYearPayment1.Id, tr.Payment__c);
        }    
    }
    
    private static testmethod void testCreateCollectionAllications(){
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;
        date sd = Date.Today();
        Transaction__c groupTransaction = new Transaction__c(
            Account__c = acc.Id,
            Contact__c = cnt.Id,
            Date__c = sd.addDays(-2),
            Status__c = 'New',
            TransactionType__c = 'Group'
        );
        insert groupTransaction;
        CashierCode__c cashierCode = new CashierCode__c(
        	Name = 'Cashier Code 1',
        	Amount__c = 30,
        	CashierCode__c = '000011',
        	Category__c = 'Categ1',
        	Division__c = 'BREG'
        );
        insert cashierCode;
        
        // create trans 
        List<Transaction__c> transactionsList= new List<Transaction__c>();
        for(Integer i = 0; i < 200; i++){
            Transaction__c trans = new Transaction__c(
            	Account__c = acc.Id,
            	Contact__c = cnt.Id,
       			Date__c = sd.addDays(-2),
            	Status__c = 'New',
        		TransactionGroup__c = i >= 100 ? groupTransaction.Id : null,
        		TransactionType__c = 'Payment'
        	);
            transactionsList.add(trans);
        }
        insert transactionsList;
        List<TransactionLine__c> transactionLinesList= new List<TransactionLine__c>();
        for(Integer i = 0; i < 200; i++){
          	TransactionLine__c transLine = new TransactionLine__c(
            	Transaction__c = transactionsList[i].Id,
            	Amount__c = 30,
            	RequestRefund__c = true,
                RefundAmount__c = 10,
                PaidStatus__c = 'Paid',
                Overpayment__c = true,
            	CashierCode__c = cashierCode.Id,
            	Description__c = 'transLine_' + i
        	);
            transactionLinesList.add(transLine);
        }
        insert transactionLinesList;
        
        Test.startTest();      
        List<pymt__PaymentX__c> payments = new List<pymt__PaymentX__c>();
       	pymt__PaymentX__c paymentWithGroupTransaction = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
        	pymt__Date__c = Date.newInstance(sd.year(),1,12),
        	CreditCardFee__c = 20,
        	pymt__Transaction_Fee__c  = 50,
        	pymt__Amount__c = 1000,
            Transaction__c = groupTransaction.Id
        );
        payments.add(paymentWithGroupTransaction);
        pymt__PaymentX__c payment1 = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
        	pymt__Date__c = Date.newInstance(sd.year(),1,12),
        	CreditCardFee__c = 20,
        	pymt__Transaction_Fee__c  = 50,
        	pymt__Amount__c = 1000,
	        Transaction__c = transactionsList[0].Id 
        );
        payments.add(payment1);
        insert payments;
        List<CollectionsAllocation__c> collectionsAllocations = [
            select id, AllocationType__c, TransactionLine__c, Transaction__c, Payment__c
            from CollectionsAllocation__c
        ];
        // System.assertEquals(collectionsAllocations.size(), 101);
        // for( CollectionsAllocation__c collectionsAllocation: collectionsAllocations ) {
        //     System.assertEquals(collectionsAllocation.AllocationType__c, 'Payment Allocation');
        //     System.assert(collectionsAllocation.TransactionLine__c != null);
        //     if(collectionsAllocation.Transaction__c == payment1.Transaction__c) {
        //     	System.assert(collectionsAllocation.Payment__c!= null);
        //     } else{
        //         System.assert(collectionsAllocation.Payment__c!= null);
        //     }
        // }
        Test.stopTest();

    }

    // ----- Helpers for partial-refund allocation tests -----

    private static CashierCode__c setupCashierCode() {
        CashierCode__c cc = new CashierCode__c(
            Name = 'Cashier Code 1',
            Amount__c = 30,
            CashierCode__c = '000011',
            Category__c = 'Categ1',
            Division__c = 'BREG'
        );
        insert cc;
        return cc;
    }

    private static TransactionLine__c buildRefundLine(Id transId, Id ccId, Decimal refundAmount, Boolean prioritize) {
        return new TransactionLine__c(
            Transaction__c = transId,
            Amount__c = refundAmount,
            CashierCode__c = ccId,
            Description__c = 'tl',
            PaidStatus__c = 'Paid',          // RequestRefund requires a Paid line (Prevent_Refunds_on_NonPaid_Lines)
            RequestRefund__c = true,
            Overpayment__c = true,           // a refund reason is required (RequireAReasonIfRefund)
            RefundAmount__c = refundAmount,
            PartialRefundApply__c = prioritize
        );
    }

    // Returns allocated amount (positive magnitude) per TransactionLine Id for the given payment.
    private static Map<Id, Decimal> allocByLine(Id paymentId) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        for(CollectionsAllocation__c ca : [
            SELECT TransactionLine__c, AmountAllocated__c
            FROM CollectionsAllocation__c WHERE Payment__c = :paymentId
        ]) {
            result.put(ca.TransactionLine__c, Math.abs(ca.AmountAllocated__c));
        }
        return result;
    }

    private static Decimal totalAllocated(Id paymentId) {
        Decimal total = 0;
        for(Decimal amt : allocByLine(paymentId).values()) {
            total += amt;
        }
        return total;
    }

    private static Transaction__c regularTransaction() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;
        Transaction__c trans = new Transaction__c(
            Account__c = acc.Id,
            Contact__c = cnt.Id,
            Date__c = Date.today().addDays(-2),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );
        insert trans;
        return trans;
    }

    // 3.1 Single PartialRefundApply line, refund less than its requested amount:
    //     one capped allocation on the prioritized line, none on the others.
    private static testmethod void testSinglePrioritizedLineCapped() {
        CashierCode__c cc = setupCashierCode();
        Transaction__c trans = regularTransaction();
        List<TransactionLine__c> lines = new List<TransactionLine__c>{
            buildRefundLine(trans.Id, cc.Id, 20, true),   // prioritized
            buildRefundLine(trans.Id, cc.Id, 30, false),
            buildRefundLine(trans.Id, cc.Id, 40, false)
        };
        insert lines;

        Test.startTest();
        pymt__PaymentX__c refund = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
            pymt__Date__c = Date.today(),
            pymt__Amount__c = -15,
            Transaction__c = trans.Id
        );
        insert refund;
        Test.stopTest();

        Map<Id, Decimal> alloc = allocByLine(refund.Id);
        System.assertEquals(1, alloc.size(), 'Only the prioritized line should be allocated');
        System.assertEquals(15, alloc.get(lines[0].Id), 'Prioritized line capped at refund amount');
        System.assertEquals(15, totalAllocated(refund.Id), 'Total equals refund amount');
    }

    // 3.2 Multiple PartialRefundApply lines, refund spans them:
    //     FIFO allocation, last line reduced, total equals refund amount.
    private static testmethod void testMultiplePrioritizedFifo() {
        CashierCode__c cc = setupCashierCode();
        Transaction__c trans = regularTransaction();
        List<TransactionLine__c> lines = new List<TransactionLine__c>{
            buildRefundLine(trans.Id, cc.Id, 20, true),   // prioritized, first FIFO
            buildRefundLine(trans.Id, cc.Id, 30, true),   // prioritized, second FIFO
            buildRefundLine(trans.Id, cc.Id, 40, false)
        };
        insert lines;

        Test.startTest();
        pymt__PaymentX__c refund = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
            pymt__Date__c = Date.today(),
            pymt__Amount__c = -40,
            Transaction__c = trans.Id
        );
        insert refund;
        Test.stopTest();

        Map<Id, Decimal> alloc = allocByLine(refund.Id);
        System.assertEquals(2, alloc.size(), 'Two prioritized lines allocated');
        System.assertEquals(20, alloc.get(lines[0].Id), 'First prioritized line fully allocated');
        System.assertEquals(20, alloc.get(lines[1].Id), 'Second prioritized line reduced to remaining balance');
        System.assertEquals(null, alloc.get(lines[2].Id), 'Non-prioritized line not allocated');
        System.assertEquals(40, totalAllocated(refund.Id), 'Total equals refund amount');
    }

    // 3.3 Prioritized line fully consumed, remaining balance flows to non-prioritized lines (FIFO).
    private static testmethod void testRemainderFlowsToNonPrioritized() {
        CashierCode__c cc = setupCashierCode();
        Transaction__c trans = regularTransaction();
        List<TransactionLine__c> lines = new List<TransactionLine__c>{
            buildRefundLine(trans.Id, cc.Id, 20, true),   // prioritized
            buildRefundLine(trans.Id, cc.Id, 30, false),  // FIFO #1 of non-prioritized
            buildRefundLine(trans.Id, cc.Id, 40, false)   // FIFO #2 of non-prioritized
        };
        insert lines;

        Test.startTest();
        pymt__PaymentX__c refund = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
            pymt__Date__c = Date.today(),
            pymt__Amount__c = -35,
            Transaction__c = trans.Id
        );
        insert refund;
        Test.stopTest();

        Map<Id, Decimal> alloc = allocByLine(refund.Id);
        System.assertEquals(2, alloc.size(), 'Prioritized line plus first non-prioritized line');
        System.assertEquals(20, alloc.get(lines[0].Id), 'Prioritized line fully allocated first');
        System.assertEquals(15, alloc.get(lines[1].Id), 'Remaining balance flows to next FIFO line');
        System.assertEquals(null, alloc.get(lines[2].Id), 'Last line gets nothing once refund is exhausted');
        System.assertEquals(35, totalAllocated(refund.Id), 'Total equals refund amount');
    }

    // 3.4 No PartialRefundApply line: fallback FIFO allocation capped at refund amount.
    private static testmethod void testFallbackFifo() {
        CashierCode__c cc = setupCashierCode();
        Transaction__c trans = regularTransaction();
        List<TransactionLine__c> lines = new List<TransactionLine__c>{
            buildRefundLine(trans.Id, cc.Id, 20, false),  // FIFO #1
            buildRefundLine(trans.Id, cc.Id, 30, false),  // FIFO #2
            buildRefundLine(trans.Id, cc.Id, 40, false)   // FIFO #3
        };
        insert lines;

        Test.startTest();
        pymt__PaymentX__c refund = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
            pymt__Date__c = Date.today(),
            pymt__Amount__c = -35,
            Transaction__c = trans.Id
        );
        insert refund;
        Test.stopTest();

        Map<Id, Decimal> alloc = allocByLine(refund.Id);
        System.assertEquals(2, alloc.size(), 'FIFO allocates first two lines');
        System.assertEquals(20, alloc.get(lines[0].Id), 'First FIFO line fully allocated');
        System.assertEquals(15, alloc.get(lines[1].Id), 'Second FIFO line reduced to remaining balance');
        System.assertEquals(null, alloc.get(lines[2].Id), 'Third line not allocated');
        System.assertEquals(35, totalAllocated(refund.Id), 'Total equals refund amount');
    }

    // 3.5 Refund covers all requested lines: each line fully allocated (full-refund behavior unchanged).
    private static testmethod void testFullRefundUnchanged() {
        CashierCode__c cc = setupCashierCode();
        Transaction__c trans = regularTransaction();
        List<TransactionLine__c> lines = new List<TransactionLine__c>{
            buildRefundLine(trans.Id, cc.Id, 20, false),
            buildRefundLine(trans.Id, cc.Id, 30, false),
            buildRefundLine(trans.Id, cc.Id, 40, false)
        };
        insert lines;

        Test.startTest();
        pymt__PaymentX__c refund = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
            pymt__Date__c = Date.today(),
            pymt__Amount__c = -200,   // exceeds total requested (90)
            Transaction__c = trans.Id
        );
        insert refund;
        Test.stopTest();

        Map<Id, Decimal> alloc = allocByLine(refund.Id);
        System.assertEquals(3, alloc.size(), 'All requested lines allocated');
        System.assertEquals(20, alloc.get(lines[0].Id));
        System.assertEquals(30, alloc.get(lines[1].Id));
        System.assertEquals(40, alloc.get(lines[2].Id));
        System.assertEquals(90, totalAllocated(refund.Id), 'Total equals sum of requested amounts, not refund amount');
    }

    // 3.6 Group transaction partial refund mirrors regular-transaction behavior.
    // 3.7 Total allocated never exceeds the refund payment amount.
    private static testmethod void testGroupTransactionParity() {
        CashierCode__c cc = setupCashierCode();
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;

        Transaction__c groupTransaction = new Transaction__c(
            Account__c = acc.Id,
            Contact__c = cnt.Id,
            Date__c = Date.today().addDays(-2),
            Status__c = 'New',
            TransactionType__c = 'Group'
        );
        insert groupTransaction;

        Transaction__c child = new Transaction__c(
            Account__c = acc.Id,
            Contact__c = cnt.Id,
            Date__c = Date.today().addDays(-2),
            Status__c = 'New',
            TransactionGroup__c = groupTransaction.Id,
            TransactionType__c = 'Payment'
        );
        insert child;

        List<TransactionLine__c> lines = new List<TransactionLine__c>{
            buildRefundLine(child.Id, cc.Id, 20, true),   // prioritized
            buildRefundLine(child.Id, cc.Id, 30, false),
            buildRefundLine(child.Id, cc.Id, 40, false)
        };
        insert lines;

        Test.startTest();
        pymt__PaymentX__c refund = new pymt__PaymentX__c(
            pymt__Transaction_Type__c = 'Refund',
            pymt__Date__c = Date.today(),
            pymt__Amount__c = -35,
            Transaction__c = groupTransaction.Id
        );
        insert refund;
        Test.stopTest();

        Map<Id, Decimal> alloc = allocByLine(refund.Id);
        // Same expectation as the regular-transaction 3.3 scenario.
        System.assertEquals(2, alloc.size(), 'Group refund allocates prioritized line then next FIFO line');
        System.assertEquals(20, alloc.get(lines[0].Id), 'Prioritized line fully allocated first');
        System.assertEquals(15, alloc.get(lines[1].Id), 'Remaining balance flows to next FIFO line');
        System.assertEquals(null, alloc.get(lines[2].Id), 'Last line gets nothing');
        System.assertEquals(35, totalAllocated(refund.Id), 'Total equals refund amount');
        System.assert(totalAllocated(refund.Id) <= Math.abs(refund.pymt__Amount__c),
            'Total allocated must never exceed the refund payment amount');
    }
}