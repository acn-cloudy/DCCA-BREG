/**
 * @description       : 
 * @author            : Deepanshu Jain
 * @group             : 
 * @last modified on  : 05-06-2025
 * @last modified by  : Deepanshu Jain
**/
@isTest
public with sharing class CATV_TestClassUtility {
    public static Account createAccount(String name, Boolean doInsert){
        String CATV_RECORD_TYPE_ID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('DCCA_CATV')?.getRecordTypeId();
        
        Account accRec = new Account();
        accRec.Name = name;
        accRec.RecordTypeId = CATV_RECORD_TYPE_ID;
        
        if(doInsert){
            insert accRec;
        }
        return accRec;
    }
    
    public static Contact createContact(String lastName, String email, String accId, Boolean doInsert){
        Contact con = new Contact();
        con.FirstName = 'first Name';
        con.LastName = lastName;
        con.Email = email;
        con.AccountId = accId;
        con.Title = 'Test Title';

        if( doInsert ){
            insert con;
        }
        return con;
    }
    
    public static Account_Access_Request__c createAccountAccessRequest(String accId, String conId, Boolean doInsert ){
        Account_Access_Request__c aar = new Account_Access_Request__c();
        aar.Account__c = accId;
        aar.Contact__c = conId;
        aar.Status__c = 'Pending';

        if( doInsert ){
            insert aar;
        }
        return aar;
    }
    
    public static INET_Request__c createINETRequest(Account provider, Contact providerContact, Account requestor, Contact requestorContact, Boolean doInsert ){
        INET_Request__c request = new INET_Request__c();
        request.Site_Name__c = 'Test Site';
        request.Provider__c = provider.Id;
        request.Requestor__c = requestor.Id;
        request.Requestor_Contact_Name__c = requestorContact.Id;
        request.Provider_Contact_Name__c = providerContact.Id;
        request.Status__c = 'Quote';
        request.Address__c = '6303 Cowboys Way';
        request.City__c = 'HI Pacific Uni';
        request.Island__c = 'Hawaii';
        request.Zip_Code__c = '76554';
        if( doInsert ){
            insert request;
        }
        return request;
    }
        
    public static Quotes__c createQuote(Account provider, Account requestor, INET_Request__c requestId, Boolean doInsert ){
        Quotes__c quote = new Quotes__c();
        quote.Provider__c = provider.Id;
        quote.Requestor__c = requestor.Id;
        quote.Description__c = 'Test desc';
        quote.INET_Request__c = requestId.Id;
        quote.Status__c = 'Sent';
        quote.Submitted_Date__c = System.Today();
        quote.Amount__c = 100;
        if( doInsert ){
            insert quote;
        }
        return quote;
    }
    
    public static Purchase_Order__c createPurchaseOrder(Account provider, Account requestor, INET_Request__c requestId, Boolean doInsert ){
        Purchase_Order__c  purchaseOrder = new Purchase_Order__c  ();
        purchaseOrder.Name = '1111';
        purchaseOrder.PO_Amount__c = 100;
        purchaseOrder.INET_Request__c  = requestId.Id;
        purchaseOrder.PO_Date__c = System.Today();
        purchaseOrder.Provider__c = provider.Id;
        purchaseOrder.Requestor__c = requestor.Id;
        if( doInsert ){
            insert purchaseOrder;
        }
        return purchaseOrder;
    }
    
    public static Invoice__c  createInvoice(INET_Request__c requestId, Boolean doInsert ){
        Invoice__c invoice = new Invoice__c ();
        invoice.Name = '1111';
        invoice.Invoice_Amount__c  = 100;
        invoice.INET_Request__c  = requestId.Id;
        invoice.Status__c = 'Unpaid';
        invoice.Invoice_Date__c = System.Today();
        if( doInsert ){
            insert invoice;
        }
        return invoice;
    }
    
    public static User createuser(String firtName, String lastName, String email, String profileId, String contactId, Boolean doInsert){
        String orgId = UserInfo.getOrganizationId();  
        String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');  
        Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));  
        String uniqueName = orgId + dateString + randomInt;  
        User tempUser = new User(  
            FirstName = firtName,  
            LastName = lastName,  
            Email = email,   
            Username = uniqueName + '@sfdc' + orgId + '.org',  
            EmailEncodingKey = 'ISO-8859-1',  
            Alias = uniqueName.substring(18, 23),  
            TimeZoneSidKey = 'America/Los_Angeles',  
            LocaleSidKey = 'en_US',  
            LanguageLocaleKey = 'en_US',  
            ProfileId = profileId,
            ContactId = contactId,
            IsActive = true,
            FederationIdentifier = 'abc'+System.now()+lastName
        );
        
        if( doInsert ){
            insert tempUser;
        }
        return tempUser;
    }
}