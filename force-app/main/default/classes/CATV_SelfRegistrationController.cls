public without sharing class CATV_SelfRegistrationController {
    
    @AuraEnabled
    public static string createContactAndAccountRequest(String inputData){
        try{
            if (String.isNotBlank(inputData)) {
                RegistrationWrapper registrationData = (RegistrationWrapper) JSON.deserialize(inputData, RegistrationWrapper.class);
                
                String decryptedClearText = decrypt(registrationData.accountId);

                registrationData.accountId = decryptedClearText;

                List<Account> communityAccount = [SELECT Id, Name FROM Account WHERE Type = 'Community' LIMIT 1];
                List<Contact> duplicateContactList = [SELECT Id, Name, Type__c, Email, FirstName, LastName, MiddleName, Phone, Title, Suffix 
                                                      FROM Contact WHERE Email = :registrationData.email AND RecordType.DeveloperName = 'DCCA_CATV'];
                
                if (!duplicateContactList.isEmpty()) {
                    List<Account_Access_Request__c> accessList = [SELECT Id FROM Account_Access_Request__c WHERE Contact__c = :duplicateContactList[0].Id AND Status__c = 'Pending'];

                    if(!accessList.isEmpty()){
                        return 'Pending Account Access Requests exist';
                    }

                    List<User> userList = [SELECT Id, ContactId, Email, Username FROM User 
                                           WHERE ContactId = :duplicateContactList[0].Id LIMIT 1];

                    if (userList.size() == 0) {
                        List<Account_Access_Request__c> aacList = [SELECT Id, Name, Status__c FROM Account_Access_Request__c 
                                                                   WHERE Status__c = 'Pending' 
                                                                   AND Contact__c = :duplicateContactList[0].Id 
                                                                   LIMIT 1];
                        if (aacList.size() > 0) {
                            return 'Contact exists and Account Access Request pending';
                        } else {
                            Contact con = new Contact();
                            con.Id = duplicateContactList[0].Id;
                            con.FirstName = duplicateContactList[0].FirstName != registrationData.firstName ? registrationData.firstName : duplicateContactList[0].FirstName;
                            if(registrationData.middleName != null){
                                con.MiddleName = duplicateContactList[0].MiddleName != registrationData.middleName ? registrationData.middleName : duplicateContactList[0].MiddleName;
                            }
                            con.LastName = duplicateContactList[0].LastName != registrationData.lastName ? registrationData.lastName : duplicateContactList[0].LastName;
                            con.Phone = duplicateContactList[0].Phone != registrationData.phoneNo ? registrationData.phoneNo : duplicateContactList[0].Phone;
                            if(registrationData.suffix != null){
                                con.Suffix = duplicateContactList[0].Suffix != registrationData.suffix ? registrationData.suffix : duplicateContactList[0].Suffix;
                            } 
                            if(registrationData.provideOrRequestor != null){
                                con.Type__c = registrationData.provideOrRequestor;
                            }      
                            update con;
                           
                            
                            Account_Access_Request__c request = insertRequest(registrationData.accountId, duplicateContactList[0].Id);
                            
                            sendRegistrationEmailAsync(duplicateContactList[0].Email, duplicateContactList[0].Id, request.Id);
                            return 'Contact exists but no pending Account Access Requests';
                        }    
                    } else {
                        return 'Contact and User both exists';
                    }
                } else {
                    Contact con = new Contact();
                    con.FirstName = registrationData.firstName;
                    con.MiddleName = registrationData.middleName;
                    con.LastName = registrationData.lastName;
                    con.Email = registrationData.email;
                    con.AccountId = communityAccount[0].Id;
                    con.Phone = registrationData.phoneNo;
                    con.Suffix = registrationData.suffix;
                    con.Type__c = registrationData.provideOrRequestor;
                    insert con;

                    Account_Access_Request__c request = insertRequest(registrationData.accountId, con.Id);                    
                    sendRegistrationEmailAsync(con.Email, con.Id, request.Id);

                    return 'Successfully Registered';
                }
            } else {
                throw new AuraHandledException('Required field(s) missing');
            }
        } catch (Exception ex) {         
            throw new AuraHandledException(ex.getMessage());
        } 
    }
    
    @AuraEnabled
    public static String decrypt(String data){
        Blob key = Blob.valueOf(System.Label.CATV_EncryptionKey);
        Blob encodedEncryptedBlob = EncodingUtil.base64Decode(data);
        Blob decryptedBlob = Crypto.decryptWithManagedIV('AES128', key, encodedEncryptedBlob);
        String decryptedClearText = decryptedBlob.toString();
        return decryptedClearText;
    }
    
    private static Account_Access_Request__c insertRequest(String accId, String conId){
        Account_Access_Request__c request = new Account_Access_Request__c();
        request.Account__c = accId;
        request.Contact__c = conId;
        request.Status__c = 'Pending';
        insert request;
        return request;
    }

    @future
    public static void sendRegistrationEmailAsync(String contactEmail, String contactId, String requestId) {
        try {
            OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress 
                                        WHERE DisplayName = 'DCCA CATV' LIMIT 1];
            EmailTemplate registrationEmail = [SELECT Id, Name FROM EmailTemplate 
                                            WHERE DeveloperName = 'Registration_Form_Submission' LIMIT 1];

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage(); 
            message.setToAddresses(new List<String>{contactEmail});
            message.setTemplateId(registrationEmail.Id);
            message.setOrgWideEmailAddressId(owea.Id);
            message.setTargetObjectId(contactId);
            message.setTreatTargetObjectAsRecipient(false);
            message.setWhatId(requestId);
            message.setSaveAsActivity(true);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { message });
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    public class RegistrationWrapper {
        public String firstName;
        public String middleName;
        public String lastName;
        public String suffix;
        public String email;
        public String phoneNo;
        public String accountId;
        public String provideOrRequestor;
    }
}