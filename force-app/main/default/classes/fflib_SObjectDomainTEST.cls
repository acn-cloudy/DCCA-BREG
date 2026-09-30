@IsTest
private class fflib_SObjectDomainTEST {
    static fflib_ApexMocks mocks;
    static void setStaticVars(){
        mocks = new fflib_ApexMocks();

    }
    @IsTest
    static void testSObjectDomain(){
        setStaticVars();
        Id accountId = '001000000000ABC';
        Id accountId2 = '001000000000ABD';
        List<Account> accounts = new List<Account>{new Account (Id=accountId, Name='Test'), new Account(Id=accountId2)};
        fflib_Application.DomainFactory fact = new fflib_Application.DomainFactory();
        fflib_Application.SelectorFactory sFact = new fflib_Application.SelectorFactory(new Map<SObjectType,Type>{Account.SObjectType => fflib_AccountsSelector.class});

        fflib_AccountsSelector mockfflib_AccountsSelector = (fflib_AccountsSelector)mocks.mock(fflib_AccountsSelector.class);
        sFact.setMock(Account.sObjectType, mockfflib_AccountsSelector);

        mocks.startStubbing();
        mocks.when(mockfflib_AccountsSelector.selectSObjectsById(new Set<Id>{accountId,accountId2})).thenReturn(accounts);
        mocks.stopStubbing();
        
        fact = new fflib_Application.DomainFactory(sFact, new Map<SObjectType, Type>{Account.SObjectType => fflib_AccountDomain.Constructor.class});
        
        fflib_AccountDomain accountDomain = (fflib_AccountDomain)fact.newInstance(new Set<Id>{accountId,accountId2});
        Map<Id, Account> accMap = new Map<Id, Account>{accountId => new Account(Id=accountId,Name='Old Test')};
        
        fflib_SObjectDomain.Test.Database.onInsert(accounts);
        fflib_SObjectDomain.Test.Database.onUndelete(accounts);
        fflib_SObjectDomain.Test.Database.onUpdate(accounts, accMap);
        fflib_SObjectDomain.Test.Database.onDelete(accMap);
        fflib_SObjectDomain.triggerHandler(fflib_AccountDomain.class);
        
        accountDomain.onApplyDefaults();
        accountDomain.onValidate();
        accountDomain.onValidate(accMap);
        accountDomain.onBeforeInsert();
        accountDomain.onAfterInsert();
        accountDomain.onBeforeDelete();
        accountDomain.onAfterUpdate(accMap);
        accountDomain.onAfterDelete(accMap);
        accountDomain.onAfterUndelete();
        accountDomain.handleBeforeInsert();
        accountDomain.handleAfterInsert();
        accountDomain.handleBeforeUpdate(accMap);
        accountDomain.handleAfterUpdate(accMap);
        accountDomain.handleBeforeDelete();
        accountDomain.handleAfterDelete(accMap);
        accountDomain.handleAfterUndelete();

        accountDomain.some(Account.Name, 'Test');
        accountDomain.every(Account.Name, 'Test');
        accountDomain.filter(Account.Name, 'Test');
        accountDomain.findIndex(Account.Name, 'Test1');
        accountDomain.find(Account.Name, 'Test1');

        SObjectType temp = accountDomain.sObjectType();
        List<SObject> genObs = accountDomain.getChangedRecords(new Set<String>{'Name'});
        genObs = accountDomain.getChangedRecords(new Set<SObjectField>{Account.Name});
        
        accountDomain.error('test error', accounts[0]);
        accountDomain.error('test error', accounts[0], Account.Name);

        fflib_SObjectDomain.ErrorFactory ef = fflib_SObjectDomain.Errors;
        ef.error('test error', accounts[0]);
        ef.error('test error', accounts[0], Account.Name);
        ef.getAll();
        ef.clearAll();

        fflib_SObjectDomain.TriggerEvent te = new fflib_SObjectDomain.TriggerEvent();
        te.disableAll();
        te.enableAll();
        te.isEnabled(true, true, true, true, true, true);
        te.isEnabled(true, true, false, true, true, true);
        te.isEnabled(true, true, false, false, true, true);
        te.isEnabled(false, true, true, true, true, true);
        te.isEnabled(false, true, false, true, true, true);
        te.isEnabled(false, true, false, false, true, true);
        te.isEnabled(false, true, false, false, false, true);
        te.isEnabled(false, false, false, false, false, true);

        fflib_SObjectDomain.Configuration co = new fflib_SObjectDomain.Configuration();
        co.enableTriggerState()
        .disableTriggerState()
        .enforceTriggerCRUDSecurity()
        .disableTriggerCRUDSecurity()
        .enableOldOnUpdateValidateBehaviour()
        .disableOldOnUpdateValidateBehaviour();

        fflib_SObjectDomain.FieldError fe = new fflib_SObjectDomain.FieldError();
        fflib_SObjectDomain.ObjectError oe = new fflib_SObjectDomain.ObjectError();


        (new fflib_SObjectDomain.TestSObjectDisableBehaviourConstructor()).construct(accounts);
        fflib_SObjectDomain.TestSObjectChangedRecords tscr = new fflib_SObjectDomain.TestSObjectChangedRecords(new List<Opportunity>());
        fflib_SObjectDomain.TestSObjectDisableBehaviour tsdb = new fflib_SObjectDomain.TestSObjectDisableBehaviour(new List<Opportunity>());
        try{
            tsdb.onAfterInsert();
        } catch (Exception e) {}
        try{
            tsdb.onBeforeInsert();
        } catch (Exception e) {}
        try{
            tsdb.onAfterUpdate(null);
        } catch (Exception e) {}
        try{
            tsdb.onBeforeUpdate(null);
        } catch (Exception e) {}
        try{
            tsdb.onAfterDelete(null);
        } catch (Exception e) {}
        try{
            tsdb.onBeforeDelete();
        } catch (Exception e) {}
        try{
            tsdb.onAfterUndelete();
        } catch (Exception e) {}

        fflib_SObjectDomain.getTriggerInstance(fflib_AccountDomain.class);
    }
    @IsTest
    static void testTestSObjectDomain(){
        setStaticVars();
        Id accountId = '006000000000ABC';
        Id accountId2 = '006000000000ABD';
        List<Opportunity> accounts = new List<Opportunity>{new Opportunity (Id=accountId, Name='Test', Type='Existing'), new Opportunity(Id=accountId2)};

        fflib_SObjectDomain.TestSObjectDomain dom = new fflib_SObjectDomain.TestSObjectDomain(accounts);
        dom = new fflib_SObjectDomain.TestSObjectDomain(accounts, Opportunity.SObjectType);
        dom.onApplyDefaults();
        dom.onValidate();
        dom.onValidate(new Map<Id, Opportunity>{accountId => new Opportunity(Id=accountId,Type='New'), accountId2 => new Opportunity(Id=accountId2)});
        dom.onBeforeDelete();
        dom.onAfterUndelete();
        dom.onBeforeInsert();

    }
}