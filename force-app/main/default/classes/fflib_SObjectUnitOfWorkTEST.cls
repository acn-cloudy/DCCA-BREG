@IsTest
private class fflib_SObjectUnitOfWorkTEST {
    static fflib_ApexMocks mocks;
    static void setStaticVars(){
        mocks = new fflib_ApexMocks();

    }
    @IsTest
    static void testfflib_SObjectUnitOfWork() {
        fflib_SObjectUnitOfWork sow = new fflib_SObjectUnitOfWork(new List<Schema.SOBjectType>{Account.SObjectType});

        Messaging.SingleEmailMessage fakeEmail = new Messaging.SingleEmailMessage();
        fakeEmail.setToAddresses(new List<String>{'fake@email.com'});
        fakeEmail.setPlainTextBody('Test');
        fflib_SObjectUnitOfWork.SendEmailWork mSow = new fflib_SObjectUnitOfWork.SendEmailWork();
        mSow.registerEmail(fakeEmail);

        mSow.doWork();
        
        Account acc = new Account(Name='Test');
        Account acc1 = new Account(Name='Test1');
        Account pAcc = new Account(Name='Parent');
        List<Account> accs = new List<Account>{acc};

        sow.registerNew(accs);
        sow.registerNew(acc1, Account.ParentId, pAcc);
        sow.registerRelationship(fakeEmail, acc);
        
        sow.commitWork();
        
        acc.Name = 'New Test';
        
        sow.registerDeleted(accs);
        sow.registerDirty(accs, new List<SObjectField>{Account.Name} );
        sow.registerDirty(accs, new List<SObjectField>{Account.Name} );
        sow.registerDirty(acc1, Account.ParentId, pAcc);
        sow.registerDirty(accs);
        sow.registerUpsert(accs);
        sow.registerPermanentlyDeleted(accs);


        try{
            sow.registerPublishAfterFailureTransaction(accs);
        } catch (Exception e) {}
        try{
            sow.registerPublishAfterSuccessTransaction(accs);
        } catch (Exception e) {}
        try{
            sow.registerPublishBeforeTransaction(accs);
        } catch (Exception e) {}

        sow.registerEmptyRecycleBin(new List<Account>{new Account()});

    }
}