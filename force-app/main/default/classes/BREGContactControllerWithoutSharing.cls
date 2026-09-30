public without sharing class BREGContactControllerWithoutSharing {
    @AuraEnabled
    public static Id createNewContact(String firstName, 
                                    String lastName, 
                                    String email, 
                                    String phone, 
                                    String street, 
                                    String city, 
                                    String stateCode, 
                                    String postalCode, 
                                    String country) {
        Contact newContact = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Phone = phone,
            MailingStreet = street,
            MailingCity = city,
            MailingPostalCode = postalCode,
            MailingCountryCode = country
        );
        if (!String.isBlank(stateCode)) {
            newContact.MailingStateCode = stateCode;
        }
        insert newContact;
        return newContact.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Id findExistingContact(String firstName, String lastName, String email, String phone, String street, String city, String stateCode, String postalCode, String country) {
        List<Contact> contacts;
        if (!String.isBlank(stateCode)) {
            contacts = [SELECT Id FROM Contact WHERE 
                        FirstName = :firstName AND
                        LastName = :lastName AND
                        Email = :email AND 
                        Phone = :phone AND 
                        MailingStreet = :street AND
                        MailingCity = :city AND
                        MailingStateCode = :stateCode AND
                        MailingPostalCode = :postalCode AND
                        MailingCountryCode = :country
                        LIMIT 1];
        } else {
            contacts = [SELECT Id FROM Contact WHERE 
                        FirstName = :firstName AND
                        LastName = :lastName AND
                        Email = :email AND 
                        Phone = :phone AND 
                        MailingStreet = :street AND
                        MailingCity = :city AND
                        MailingPostalCode = :postalCode AND
                        MailingCountryCode = :country
                        LIMIT 1];
        }
        if (!contacts.isEmpty()) {
            return contacts[0].Id;
        }
        return null;
    }
}