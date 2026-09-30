@IsTest
private class fflib_SObjectsTest {

    static Account[] accounts;
    static Contact[] contacts;

    static void setStaticVars() {
        List<Id> accountIds = new List<Id>{
            '001000000000ABC',
            '001000000000ABD'
        };
        accounts = new List<Account>{
            new Account(
                Id = accountIds[0],
                Name = 'Test 1'
            ),
            new Account(
                Id = accountIds[1],
                Name = 'Test 2'
            )
        };
        contacts = new List<Contact>{
            new Contact(
                AccountId = accounts[0].Id,
                Id = '003000000000ABC',
                FirstName = 'J',
                LastName = 'Alibi',
                Email = 'j.alibi@email.com'
            ),
            new Contact(
                AccountId = accounts[0].Id,
                Id = '003000000000ABD',
                FirstName = 'F',
                LastName = 'Alibi',
                Email = 'F.alibi@email.com'
            ),
            new Contact(
                AccountId = accounts[0].Id,
                Id = '003000000000AB3',
                FirstName = 'G',
                LastName = 'Alibi',
                Email = 'G.alibi@email.com'
            ),
            new Contact(
                AccountId = accounts[1].Id,
                Id = '003000000000AB4',
                FirstName = 'E',
                LastName = 'Alibi',
                Email = 'E.alibi@email.com'
            ),
            new Contact(
                AccountId = accounts[1].Id,
                Id = '003000000000AB5',
                FirstName = 'K',
                LastName = 'Alibi',
                Email = 'K.alibi@email.com'
            ),
            new Contact(
                AccountId = accounts[1].Id,
                Id = '003000000000AB6',
                FirstName = 'Q',
                LastName = 'Alibi',
                Email = 'q.alibi@email.com'
            )
        };    
    }
    @IsTest
    static void testMethod1() {
        setStaticVars();
        fflib_SObjects sobs1 = new fflib_SObjects(contacts);
        fflib_SObjects sobs = new fflib_SObjects(contacts, Contact.SObjectType);
        sobs.getObjects();
        sobs.getRecordIds();
        sobs.getRecords();
        sobs.getSObjectType();
        sobs.getType();

        sobs.contains(contacts[1]);
        sobs.containsAll(contacts);
        sobs.containsNot(accounts[0]);
        sobs.containsNot(accounts);
        sobs.error('foo bar', contacts[0]);
        sobs.error('foo bar', contacts[0], Contact.FirstName);
        sobs.getFieldValues(Contact.Email);
        sobs.getRecordsByFieldValue(Contact.Email, 'q.alibi@email.com');
        sobs.getRecordsByFieldValues(Contact.Email, new Set<Object>{'q.alibi@email.com','K.alibi@email.com'});
        sobs.getRecordsWithBlankFieldValues(Contact.FirstName);
        sobs.getRecordsWithNotBlankFieldValues(Contact.FirstName);
        sobs.getRecordsWithBlankFieldValues(new Set<Schema.SObjectField>{Contact.FirstName, Contact.Email});
        sobs.getRecordsWithAllBlankFieldValues(new Set<Schema.SObjectField>{Contact.FirstName, Contact.Email});
        sobs.getRecordsWithNotBlankFieldValues(new Set<Schema.SObjectField>{Contact.FirstName, Contact.Email});
        sobs.getRecordsWithAllNotBlankFieldValues(new Set<Schema.SObjectField>{Contact.FirstName, Contact.Email});
        sobs.setFieldValue(Contact.LastName, 'New');

        fflib_SObjects.Errors.error('foo bar', contacts[0]);
        fflib_SObjects.Errors.error('foo bar', contacts[0], Contact.FirstName);
        fflib_SObjects.Errors.getAll();
        fflib_SObjects.Errors.clearAll();
    }

}