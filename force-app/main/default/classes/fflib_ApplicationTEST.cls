@IsTest
private class fflib_ApplicationTEST {
    static fflib_ApexMocks mocks;
    static void setStaticVars(){
        mocks = new fflib_ApexMocks();
    }

    @IsTest
    private static void UnitOfWorkFactoryTest(){
        setStaticVars();
        fflib_Application.UnitOfWorkFactory fact = new fflib_Application.UnitOfWorkFactory();
        fact = new fflib_Application.UnitOfWorkFactory(new List<SObjectType>{Account.SObjectType});
        fflib_SObjectUnitOfWork.IDML dml = new fflib_SObjectUnitOfWork.SimpleDML();
        fact.newInstance();
        fact.newInstance(dml);
        fact.newInstance(new List<SObjectType>{Account.SObjectType});
        fact.newInstance(new List<SObjectType>{Account.SObjectType}, dml);
        fflib_SObjectUnitOfWork mockUow = (fflib_SObjectUnitOfWork)mocks.mock(fflib_SObjectUnitOfWork.class);
        fact.setMock(mockUow);
        fact.newInstance();
        fact.newInstance(dml);
        fact.newInstance(new List<SObjectType>{Account.SObjectType});
        fact.newInstance(new List<SObjectType>{Account.SObjectType}, dml);
    }

    @IsTest
    private static void ServiceFactoryTest(){
        setStaticVars();
        fflib_Application.ServiceFactory fact = new fflib_Application.ServiceFactory();
        fact = new fflib_Application.ServiceFactory(new Map<Type,Type>{fflib_Application.class => fflib_Application.class});
        fact.newInstance(fflib_Application.class);
        try{
            fact.newInstance(null);
        } catch (Exception e) {
            
        }
        fact.setMock(fflib_Application.class, fflib_Application.class);
        fact.newInstance(fflib_Application.class);
    }
    @IsTest
    private static void SelectorFactoryTest(){
        setStaticVars();
        Id accountId = '001000000000ABC';
        fflib_Application.SelectorFactory fact = new fflib_Application.SelectorFactory();
        fact = new fflib_Application.SelectorFactory(new Map<SObjectType,Type>{Account.SObjectType => fflib_AccountsSelector.class});
        fact.newInstance(Account.SObjectType);
        try{
            fact.newInstance(null);
        } catch (Exception e) {
            
        }
        try{
            fact.selectById(new Set<Id>());
        } catch (Exception e) {}

        fact.selectById(new Set<Id>{accountId});

        try{
            fact.selectById(new Set<Id>{accountId, '005000000000ABC'});
        } catch (Exception e) {}

        List<Contact> contacts = new List<Contact>{
            new Contact(
                AccountId = accountId
            )
        };

        fact.selectByRelationship(contacts, Contact.AccountId);

        fact.setMock(Account.SObjectType, new fflib_AccountsSelector());
        fact.newInstance(Account.SObjectType);
    }

    @IsTest
    private static void DomainFactoryTest(){
        setStaticVars();
        Id accountId = '001000000000ABC';
        List<Account> accounts = new List<Account>{new Account (Id=accountId)};
        List<SObject> genericObjects = new List<SObject>();
        fflib_Application.DomainFactory fact = new fflib_Application.DomainFactory();
        fflib_Application.SelectorFactory sFact = new fflib_Application.SelectorFactory(new Map<SObjectType,Type>{Account.SObjectType => fflib_AccountsSelector.class});

        fflib_AccountsSelector mockfflib_AccountsSelector = (fflib_AccountsSelector)mocks.mock(fflib_AccountsSelector.class);
        sFact.setMock(Account.sObjectType, mockfflib_AccountsSelector);

        mocks.startStubbing();
        mocks.when(mockfflib_AccountsSelector.selectSObjectsById(new Set<Id>{accountId})).thenReturn(accounts);
        mocks.stopStubbing();

        fact = new fflib_Application.DomainFactory(sFact, new Map<SObjectType, Type>{Account.SObjectType => fflib_AccountDomain.Constructor.class});
        fact = new fflib_Application.DomainFactory(sFact, new Map<Object, Type>{Account.SObjectType => fflib_AccountDomain.Constructor.class});
        fact.newInstance(new Set<Id>{accountId});
        fact.newInstance(accounts);
        try{
            fact.newInstance(genericObjects);
        } catch (Exception e) {}
        fact.newInstance(accounts, Account.SObjectType);

        try{
            fact.newInstance(accounts, null);
        } catch (Exception e) {}
        fact.newInstance(accounts, Account.SObjectType);
        
        fflib_AccountDomain mockfflib_AccountDomain = (fflib_AccountDomain)mocks.mock(fflib_AccountDomain.class);
        fact.setMock(Account.getSObjectType(), (fflib_ISObjectDomain)mockfflib_AccountDomain);
        fact.setMock((fflib_ISObjectDomain)mockfflib_AccountDomain);
        fact.setMock((fflib_IDomain)mockfflib_AccountDomain);
        fact.newInstance(accounts, Account.SObjectType);

    }
}