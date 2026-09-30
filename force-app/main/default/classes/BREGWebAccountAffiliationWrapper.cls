public class BREGWebAccountAffiliationWrapper {
    public Contact Contact;
    public Account Account;
    public breg_Account_Affiliation__c accountAffiliation;

    public BREGWebAccountAffiliationWrapper() {
        this.Contact = new Contact();
        this.Account = new Account();
        this.accountAffiliation = new breg_Account_Affiliation__c();
    }
}