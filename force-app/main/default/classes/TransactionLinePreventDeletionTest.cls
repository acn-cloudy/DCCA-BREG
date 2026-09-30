/*
 * Prevent from deleting a transaction line if the Paid Status is either Paid Or Refunded
 * Created on 11/16/2018.
 * Author irene.cahilo@pacificpointcorp.com
 */
@IsTest
public class TransactionLinePreventDeletionTest {
    @IsTest
    static void validateTransactionLineTest() {
        String orgId = UserInfo.getOrganizationId();
        String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
        Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
        String uniqueName = orgId + dateString + randomInt;

        Profile p = [SELECT Id FROM Profile WHERE Name='DCCA SEC Administrator'];
        User dummyUser = new User(
                Alias = 'standu',
                Email = uniqueName + '@test' + orgId + '.org',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueName + '@test' + orgId + '.org');
        insert dummyUser;

        Account dummyAccount = new Account(Name = 'Test');
        insert dummyAccount;

        Contact dummyContact = new Contact(LastName = 'Test', AccountId = dummyAccount.Id);
        insert dummyContact;

        Transaction__c dummyTransaction = new Transaction__c(Account__c = dummyAccount.Id);

        System.runAs(dummyUser) {
            insert dummyTransaction;
        }

        CashierCode__c dummyCashierCode = new CashierCode__c(Description__c = 'Test', Amount__c = 1.00);
        insert dummyCashierCode;

        TransactionLine__c dummyTransactionLine = new TransactionLine__c(
                PaidStatus__c = 'Paid',
                Transaction__c = dummyTransaction.Id,
                CashierCode__c = dummyCashierCode.Id);

        System.runAs(dummyUser) {
            insert dummyTransactionLine;
        }

        try {
            System.runAs(dummyUser) {
                delete dummyTransactionLine;
            }
        } catch (Exception e) {
            System.assert(e.getMessage().contains(
                    'Cannot delete record if Transaction Line has a Paid Status of Paid or Refunded.'));
        }

    }
}