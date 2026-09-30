public with sharing class BREGCheckoutController {
    
    @AuraEnabled(cacheable=true)
    public static Contact getContact() {
        Boolean isGuest = UserInfo.getUserType() == 'Guest';
        if (isGuest) {
            return null;
        }

        User curUser = [
            SELECT  ContactId 
            FROM    User
            WHERE   Id = :UserInfo.getUserId()
        ];
        return [
            SELECT  Id,
                    FirstName,
                    LastName,
                    Email
            FROM    Contact
            WHERE   Id = :curUser.ContactId
        ];
    }
}