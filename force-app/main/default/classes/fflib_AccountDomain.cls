public with sharing class fflib_AccountDomain extends fflib_SObjectDomain{
    
    public fflib_AccountDomain(List<Account> records) {
        super(records);
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> records){
           return new fflib_AccountDomain((Account[])records);
        }
     }

}