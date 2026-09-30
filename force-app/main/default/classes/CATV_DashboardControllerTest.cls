@isTest
public with sharing class CATV_DashboardControllerTest {
    @testsetup static void setup(){
        Account communityDefaultAcc = CATV_TestClassUtility.createAccount('Test Account',false);
        communityDefaultAcc.Type = 'Community';
        insert communityDefaultAcc;
        
        Contact requestorCon = CATV_TestClassUtility.createContact('lname', 'a@b.com', communityDefaultAcc.Id, false);
        requestorCon.Type__c = 'Requestor';
        insert requestorCon;
        
        Account requestorAcc = CATV_TestClassUtility.createAccount('test_acc',false);
        requestorAcc.Type = 'City';
        insert requestorAcc;
        
        Account providerAcc = CATV_TestClassUtility.createAccount('test_acc',false);
        providerAcc.Type = 'Provider';
        insert providerAcc;
        
        Contact providerCon = CATV_TestClassUtility.createContact('lname1', 'a@b1.com', providerAcc.Id, false);
        providerCon.Type__c = 'Provider';
        insert providerCon;
        
        INET_Request__c request = CATV_TestClassUtility.createINETRequest(providerAcc, providerCon, requestorAcc, requestorCon, true);
        
        Quotes__c quote = CATV_TestClassUtility.createQuote(providerAcc, requestorAcc, request, true);
        
        Purchase_Order__c purchaseOrder = CATV_TestClassUtility.createPurchaseOrder(providerAcc, requestorAcc, request, true);
        
        Invoice__c invoice = CATV_TestClassUtility.createInvoice(request, true);
        
    }
    @isTest static void handleFetchINETRequestDataTest(){
        Account requestorAcc = [SELECT Id FROM Account WHERE Type = 'City' LIMIT 1];
        List<INET_Request__c> inetRequestList = CATV_DashboardController.fetchINETRequestData(String.valueOf(requestorAcc.Id), '');
        Assert.isTrue(inetRequestList.size() > 0, 'No INET_Request__c records were found for this account');
    }
    @isTest static void handleFetchQuoteDataTest(){
        INET_Request__c requestId = [SELECT Id FROM INET_Request__c LIMIT 1];
        List<Quotes__c> quoteList = CATV_DashboardController.fetchQuoteData(requestId.Id);
        Assert.isNotNull(quoteList, 'Quote is empty');
    }
    
    @isTest static void handleFetchPurchaseDataTest(){
        INET_Request__c requestId = [SELECT Id FROM INET_Request__c LIMIT 1];
        List<Purchase_Order__c> purchaseOrderList = CATV_DashboardController.fetchPurchaseData(requestId.Id);
        Assert.isNotNull(purchaseOrderList, 'Purchase Order is empty');
    }
    
    @isTest static void handleFetchInvoiceDataTest(){
        INET_Request__c requestId = [SELECT Id FROM INET_Request__c LIMIT 1];
        List<Invoice__c> invoiceList = CATV_DashboardController.fetchInvoiceData(requestId.Id);
        Assert.isNotNull(invoiceList, 'Invoice Order is empty');
    }
    
    @isTest static void handleUpdateRequestStatusTest(){
        INET_Request__c requestId = [SELECT Id FROM INET_Request__c LIMIT 1];
        requestId.Status__c = 'Quote';
        update requestId;
        CATV_DashboardController.updateRequestStatus(requestId.Id, 'Quote Accepted','Quote');
        INET_Request__c request = [SELECT Id, Quote_Subtype__c FROM INET_Request__c LIMIT 1];
        Assert.areEqual(request.Quote_Subtype__c, 'Quote Accepted', 'Subtype is not updated on request');
    }
    
    @isTest static void handleUpdateQuoteTest(){
        Quotes__c requestId = [SELECT Id FROM Quotes__c LIMIT 1];
        CATV_DashboardController.updateQuote(requestId.Id, 'Sent', null);
        Quotes__c quote = [SELECT Id, Status__c FROM Quotes__c LIMIT 1];
        Assert.areEqual(quote.Status__c, 'Sent', 'Subtype is not updated on request');
    }
    
    @isTest static void handleUpdateInvoiceTest(){
        INET_Request__c requestId = [SELECT Id FROM INET_Request__c LIMIT 1];
        CATV_DashboardController.updateInvoice(requestId.Id);
        Invoice__c invoice = [SELECT Id, Status__c FROM Invoice__c LIMIT 1];
        Assert.areEqual(invoice.Status__c, 'Paid', 'Status is not updated on invoice');
    }
    
    @isTest static void getAccountsTest(){
        List<Account> accounts = CATV_DashboardController.getAccounts();
        Assert.isNotNull(accounts, 'Account List is empty');
    }
    
    @isTest static void changeOwnerToQueueTest(){
        INET_Request__c request = [SELECT Id FROM INET_Request__c LIMIT 1];
        CATV_DashboardController.changeOwnerToQueue(request.Id);
        INET_Request__c updatedRequest = [SELECT Id, OwnerId FROM INET_Request__c WHERE Id =: request.Id LIMIT 1];
        Group queue = [SELECT Id, Name, DeveloperName, Type FROM Group WHERE Type = 'Queue' AND DeveloperName = 'CATV_Staff_Reviewers'];
        Assert.areEqual(updatedRequest.OwnerId, queue.Id, 'Owner is not updated to Queue');
    }
    
    @isTest static void getFileContentTest(){
        INET_Request__c request = [SELECT Id FROM INET_Request__c LIMIT 1];
        Test.startTest();
        String resultUp = CATV_DashboardController.uploadFile(request.Id, 'Test1','test','INET_Request__c');
        Map<String, String> resultCont = CATV_DashboardController.getFileContent(request.Id, 'INET_Request__c');
        Assert.isNotNull(resultCont,'File Content not returned');
        Test.stopTest();
        
    }
}