global class CATV_RegistrationHandler implements Auth.RegistrationHandler{   
    
    private class SsoException extends Exception{}
    
    global boolean canCreateUser(Auth.UserData data) {
        Boolean retVal = (data != null 
                          && data.email != null
                          && data.lastName != null
                          && data.firstName != null);
        return retVal;
    }
    
    /**
    * Create the User - A required method to implement the Handler Interface
    * 
    * @param portalId  - Id of the Community
    * @param data - Auth Provider user data describing the User to create
    * 
    * @return User that has been initialized
    **/ 
    global User createUser(Id portalId, Auth.UserData data){
        if(!canCreateUser(data)) {
            return null;
        }
        User user = new User();
        if(data.attributeMap.containsKey('sfdc_networkid')) {
            List<User> userList = [SELECT Id, Name, Username, ContactId, Email, ProfileId FROM User 
                                   WHERE IsActive = true AND Email =: data.email];
            if (!userList.isEmpty()) {
                user = userList[0];
            }else{
                List<Account_Access_Request__c> aacList = [SELECT Id, Name, Status__c FROM Account_Access_Request__c 
                                                           WHERE Status__c = 'Pending' 
                                                           AND Contact__r.Email =: data.email 
                                                           LIMIT 1];
                if (aacList.size() > 0) {
                    throw new SsoException('Access Request Pending');
                }else{
                    Blob key = Blob.valueOf(System.Label.CATV_EncryptionKey);
                    Blob cipherText = Crypto.encryptWithManagedIV('AES128', key, Blob.valueOf(data.email));
                    String encodedCipherText = EncodingUtil.base64Encode(cipherText);
                    throw new SsoException('No User Found @'+encodedCipherText);
                }
                
            }
        }  
        return user;
    }
    
    /**
    * Update the user
    * @param portalId  - Id of the Community
    * @param data - Auth Provider user data describing the User to create
    **/     
    global void updateUser(Id userId, Id portalId, Auth.UserData data){
        User u = new User(id=userId);
        u.lastName = data.lastName;
        u.firstName = data.firstName;
        update(u);
        updateContact(data.email, data.firstName, data.lastName);
    }
    
    @future
    public static void updateContact(String email, String firstName, String lastName){
        List<Contact> contactList = [SELECT Id, Name, Type__c, Email, FirstName, LastName, Phone, Title, Suffix 
                                     FROM Contact WHERE Email = :email AND RecordType.DeveloperName = 'DCCA_CATV'];
        if(!contactList.isEmpty()){
            Contact con = new Contact(id=contactList[0].Id);
            con.lastName = lastName;
            con.firstName = firstName;
            update(con);
        }
    }
}