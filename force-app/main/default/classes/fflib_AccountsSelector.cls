public inherited sharing class fflib_AccountsSelector extends fflib_SObjectSelector {

    //public static final AccountsSelector INSTANCE = (AccountsSelector)Application.SELECTOR.newInstance(Account.getSObjectType());

    public fflib_AccountsSelector() {
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