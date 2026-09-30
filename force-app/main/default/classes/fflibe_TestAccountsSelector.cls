public inherited sharing class fflibe_TestAccountsSelector extends fflib_SObjectSelector {

    public static final fflibe_TestAccountsSelector INSTANCE = (fflibe_TestAccountsSelector)fflibe_ApplicationImpl.SELECTOR.newInstance(Account.getSObjectType());

    public fflibe_TestAccountsSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            Account.Id
        };
    }

    public Schema.SObjectType getSObjectType() {
        return Account.getSObjectType();
    }

    

}