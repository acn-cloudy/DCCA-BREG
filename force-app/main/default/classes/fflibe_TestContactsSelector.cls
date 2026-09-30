public inherited sharing class fflibe_TestContactsSelector extends fflib_SObjectSelector {

    public static final fflibe_TestContactsSelector INSTANCE = (fflibe_TestContactsSelector)fflibe_ApplicationImpl.SELECTOR.newInstance(contact.getSObjectType());

    public fflibe_TestContactsSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            contact.Id
        };
    }

    public Schema.SObjectType getSObjectType() {
        return contact.getSObjectType();
    }

    

}