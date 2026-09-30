public without sharing class BREGAccountInfoController {
    //TODO: sharing settings  for Account object
    @AuraEnabled
    public static AccountInfoWrapper getInfo(){
        return new AccountInfoWrapper(getContact());
    }

    private static Contact getContact() {
        User curUser = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        return [
            SELECT  FirstName, LastName, Email, Phone, MobilePhone, OtherPhone, breg_Mobile_Service_Provider__c,
                    MailingStreet, MailingCity, MailingStateCode, MailingPostalCode, MailingCountryCode, breg_Mailing_Address_Street_2__c
            FROM    Contact
            WHERE   Id = :curUser.ContactId
        ];
    }

    @AuraEnabled
    public static void saveInfo(String infoPayload) {
        if(String.isBlank(infoPayload)) {
            throw new AuraHandledException('Info payload is empty');
        }
        AccountInfoWrapper info = (AccountInfoWrapper)JSON.deserialize(infoPayload, AccountInfoWrapper.class);
        Contact userContact = getContact();
        userContact.FirstName = info.FirstName;
        userContact.LastName = info.LastName;
        userContact.Email = info.Email;
        userContact.Phone = info.Phone;
        userContact.OtherPhone = info.SecondaryPhone;
        userContact.MobilePhone = info.MobilePhone;
        userContact.MailingStreet = info.street;
        userContact.breg_Mailing_Address_Street_2__c = info.street2;
        userContact.MailingCity = info.city;
        userContact.MailingStateCode = info.state;
        userContact.MailingPostalCode = info.postalCode;
        userContact.MailingCountryCode = info.country;
        update userContact;

        User communityUser = new User(Id = UserInfo.getUserId());
        communityUser.BREG_Portal_Registration_Complete__c = true;
        update communityUser;
    }

    public class AccountInfoWrapper {
        @AuraEnabled
        public String FirstName {get; set;}
        @AuraEnabled
        public String LastName {get; set;}
        @AuraEnabled
        public String Email {get; set;}
        @AuraEnabled
        public String Phone {get; set;}
        @AuraEnabled
        public String SecondaryPhone {get; set;}
        @AuraEnabled
        public String MobilePhone {get; set;}
        @AuraEnabled
        public String MobileServiceProvider {get; set;}
        @AuraEnabled
        public String street {get; set;}
        @AuraEnabled
        public String street2 {get; set;}
        @AuraEnabled
        public String city {get; set;}
        @AuraEnabled
        public String state {get; set;}
        @AuraEnabled
        public String postalCode {get; set;}
        @AuraEnabled
        public String country {get; set;}

        public AccountInfoWrapper(){}

        public AccountInfoWrapper(Contact c){
            this.FirstName = c.FirstName;
            this.LastName = c.LastName;
            this.Email = c.Email;
            this.Phone = c.Phone;
            this.SecondaryPhone = c.OtherPhone;
            this.MobilePhone = c.MobilePhone;
            this.MobileServiceProvider = c.breg_Mobile_Service_Provider__c;
            this.street = c.MailingStreet;
            this.street2 = c.breg_Mailing_Address_Street_2__c;
            this.city = c.MailingCity;
            this.state = c.MailingStateCode;
            this.postalCode = c.MailingPostalCode;
            this.country = c.MailingCountryCode;
        }
    }
}