public inherited sharing class fflibe_TestAccountsDomain extends fflib_SObjectDomain {

    /*********************
    * DEFAULT DOMAIN CODE
    *********************/

    Account[] castedRecords { get { return (Account[])Records; } }

    public static fflibe_TestAccountsDomain newInstance(Account[] records) {
        return (fflibe_TestAccountsDomain)fflibe_ApplicationImpl.DOMAIN.newInstance(records);
    }

    public fflibe_TestAccountsDomain(Account[] records) {
        super(records);
    }

    public class Constructor implements fflib_IDomainConstructor {
        public fflib_SObjects construct(List<Object> objectList) {
            return new fflibe_TestAccountsDomain((List<SObject>) objectList);
        }
    }


    /*********************
    * DOMAIN METHODS
    *********************/

    

}