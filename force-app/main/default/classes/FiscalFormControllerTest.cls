@isTest
private class FiscalFormControllerTest {
    @TestSetup
    static void makeData(){
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
        for(Integer i = 0; i < 10; i++){
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
        for(Integer i = 0; i < 10; i++){
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
        List<CollectionsAllocation__c> collections = new List<CollectionsAllocation__c>();
        for(TransactionLine__c rec: transactionLinesList) {
            CollectionsAllocation__c col = new CollectionsAllocation__c();
            col.Payment__c = payments.get(0).Id;
            col.TransactionLine__c = rec.Id;
            collections.add(col);
        }
        
        insert collections;
        
    }
    public static testMethod void testData() {
        
        Test.startTest();  
        FiscalFormFeed.SearchFeed feed = new FiscalFormFeed.SearchFeed();
        feed.fundType = 'S';
        feed.cutOffDate = Date.today();
        feed.startDate = Date.today().addDays(-100);
        feed.division = 'BREG';
        feed.paymentType = 'Cash';
        String feedStr = JSON.serialize(feed);
        System.assert(FiscalFormsController.searchJVData(feedStr) != null);
    }

    static testMethod void testInitFiscalForms() {
        RecordType rts = [Select Id, Name from RecordType Where SObjectType = 'FiscalForm__c' limit 1];
        String recordTypeId = rts.Id;
        System.assertEquals(FiscalFormsController.getRecordType(recordTypeId), rts.Name);
        String fiscalFormId = FiscalFormsController.initFiscalForms(recordTypeId);
        System.assert(fiscalFormId != null);

    }
    static testmethod void testSubmitForFile() {
        RecordType rts = [Select Id, Name from RecordType Where SObjectType = 'FiscalForm__c' and DeveloperName = 'JV'];
        String recordTypeId = rts.Id;
        String feedStr = '{"fundType":"Special","paymentType":"Cash","cutOffDate":"2020-09-20","startDate":"2020-01-01","division":""}';
        List<CollectionsAllocation__c> collectionsAllocations = [
            select id, AllocationType__c, TransactionLine__c, Transaction__c, Payment__c
            from CollectionsAllocation__c
        ];
        Test.startTest();
        String rId1 = collectionsAllocations.get(0).Id;
        // String rId2 = collectionsAllocations.get(1).Id;
        // String rId3 = collectionsAllocations.get(2).Id;
        // String rId4 = collectionsAllocations.get(3).Id;
        // String rId5 = collectionsAllocations.get(4).Id;
        for(Integer i = 0; i< 5; i++) {
            
        }
        String str = '[{"departmentNo":"201103","departmentDate":"09/20/2020","fundName":"Special","comptrollerNo":"","dateStr":"","explanation":"TO '
            + 'CORRECT THE ACCOUNT FOR BAD CHECKS: <br/><br/><br/><br/>  CC:DCCA/'
            + 'FISCAL","departmentalCertification":"Commerce Consumer Affairs","commerceConsumerAffairs":"","comptrollerApproval":"","comptroller":"","funds":[{"indexValue":"01",'
            + '"tcValue":"011","fValue":"S","yrValue":"20","appValue":"305",'
            + '"dValue":"R","alltCatValue":"","sourceObjValue":"0159","costCenterValue":"0092","projectNumValue":"001","projectPhValue":"","deptActValue"'
            + ':"","gLActValue":"","sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVA'
            + 'mount2":"00","modValue":"","revValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"50","recordId":"'+rId1+'"}'
            + ',{"indexValue":"02","tcValue":"011","fValue":"S","yrValue":"20","appValue":"305","dValue":"'
            + 'R","alltCatValue":"","sourceObjValue":"0159","costCenterValue":"0092","projectNumValue":"001","projectPhValue":"","deptActValue":"",'
            + '"gLActValue":"","sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2":"0'
            + '0","modValue":"","revValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"50","recordId":"'+rId1+'"},'
            + '{"indexValue":"03","tcValue":"011","fValue":"S","yrValue":"20","appValue":"305","dValue":"R","alltCa'
            + 'tValue":"","sourceObjValue":"0159","costCenterValue":"0092","projectNumValue":"001","projectPhValue":"","deptActValue":"","gLActValue":"",'
            + '"sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2":"00","modVal'
            + 'ue":"","revValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"50","recordId":"'+rId1+'"},{"indexValue":"04"'
            + ',"tcValue":"011","fValue":"S","yrValue":"20","appValue":"305","dValue":"R","alltCatValue":""'
            + ',"sourceObjValue":"0159","costCenterValue":"0092","projectNumValue":"001","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"",'
            + '"referenceNumValue":"","referenceSFXValue":"","jVAmount2":"00","modValue":"","re'
            + 'vValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"50","recordId":"'+rId1+'"},{"indexValue":"05","tcValue"'
            + ':"011","fValue":"S","yrValue":"20","appValue":"305","dValue":"R","alltCatValue":"","sourceOb'
            + 'jValue":"0159","costCenterValue":"0092","projectNumValue":"001","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"",'
            + '"referenceNumValue":"","referenceSFXValue":"","jVAmount2":"00","modValue":"","revValue":""'
            + ',"optionalDepartmentalDate":"","remarks":"","jVAmount1":"50","recordId":"'+rId1+'"},{"indexValue":"","tcValue":"","fValue":"",'
            + '"yrValue":"","appValue":"","dValue":"","alltCatValue":"","sourceObjValue":"","costCenter'
            + 'Value":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2"'
            + ':"","modValue":"","revValue":"","optionalDepartmentalDate":"","rem'
            + 'arks":"","jVAmount1":"","recordId":""},{"indexValue":"","tcValue":"","fValue":"","yrValue":"","appValue":"",'
            + '"dValue":"","alltCatValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","dep'
            + 'tActValue":"","gLActValue":"","sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2":"","modValue":"","revValue":"","optionalDepartmentalDate"'
            + ':"","remarks":"","jVAmount1":"","recordId":""},{"indexValue":""'
            + ',"tcValue":"","fValue":"","yrValue":"","appValue":"","dValue":"","alltCatValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue"'
            + ':"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","referenc'
            + 'eNumValue":"","referenceSFXValue":"","jVAmount2":"","modValue":"","revValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"","recordId"'
            + ':""},{"indexValue":"","tcValue":"","fValue":"","yrValue":"","appValue":"","d'
            + 'Value":"","alltCatValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue"'
            + ':"","referenceNumValue":"","referenceSFXValue":"","jVAmount2":"","mo'
            + 'dValue":"","revValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"","recordId":""},{"indexValue":"","tcValue":"",'
            + '"fValue":"","yrValue":"","appValue":"","dValue":"","alltCatValue":"","sourceObjValue":"","costCe'
            + 'nterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2"'
            + ':"","modValue":"","revValue":"","optionalDepartmentalDate":"",'
            + '"remarks":"","jVAmount1":"","recordId":""},{"indexValue":"","tcValue":"","fValue":"","yrValue":"","appValue":"",'
            + '"dValue":"","alltCatValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"",'
            + '"deptActValue":"","gLActValue":"","sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2":"","modValue":"","revValue":"","optionalDepartmentalDate"'
            + ':"","remarks":"","jVAmount1":"","recordId":""},{"indexValue'
            + '":"","tcValue":"","fValue":"","yrValue":"","appValue":"","dValue":"","alltCatValue":"","sourceObjValue":"","costCenterValue":"",'
            + '"projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","refe'
            + 'renceNumValue":"","referenceSFXValue":"","jVAmount2":"","modValue":"","revValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"","recordId"'
            + ':""},{"indexValue":"","tcValue":"","fValue":"","yrValue":"","appValue":"'
            + '","dValue":"","alltCatValue":"","sourceObjValue":"","costCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"",'
            + '"sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2":""'
            + ',"modValue":"","revValue":"","optionalDepartmentalDate":"","remarks":"","jVAmount1":"","recordId":""},{"indexValue":"","tcValue":"",'
            + '"fValue":"","yrValue":"","appValue":"","dValue":"","alltCatValue":"","sourceObjValue":"","co'
            + 'stCenterValue":"","projectNumValue":"","projectPhValue":"","deptActValue":"","gLActValue":"","sLActValue":"","referenceNumValue":"","referenceSFXValue":"","jVAmount2"'
            + ':"","modValue":"","revValue":"","optionalDepartmentalDate"'
            + ':"","remarks":"","jVAmount1":"","recordId":""}]}]';
        String recordId =  FiscalFormsController.submitForFile(str, null, recordTypeId, feedStr);
        FiscalFormsController.saveJVFile(recordId);
        FiscalFormsController.saveAsFile(recordId);
        System.assert(recordId != null);
            
    }
    
}