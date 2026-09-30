public inherited sharing class fflibe_TestContactsDomain extends fflib_SObjectDomain {

    /*********************
    * DEFAULT DOMAIN CODE
    *********************/

    Contact[] castedRecords { get { return (Contact[])Records; } }

    public static fflibe_TestContactsDomain newInstance(Contact[] records) {
        return (fflibe_TestContactsDomain)fflibe_ApplicationImpl.DOMAIN.newInstance(records);
    }

    public fflibe_TestContactsDomain(Contact[] records) {
        super(records);
    }

    public class Constructor implements fflib_IDomainConstructor {
        public fflib_SObjects construct(List<Object> objectList) {
            return new fflibe_TestContactsDomain((List<SObject>) objectList);
        }
    }


    /*********************
    * DOMAIN METHODS
    *********************/

    

}