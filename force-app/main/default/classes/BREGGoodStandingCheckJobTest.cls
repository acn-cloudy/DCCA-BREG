@isTest
public class BREGGoodStandingCheckJobTest {
    private static List<Account> createAccounts() {
        List<Account> accounts = new List<Account>();
        Date today = Date.today();
        for (Integer i = 0; i < 200; i++) {
            Account acc = new Account(
                Name = 'Test Account ' + i,
                breg_Incorporation_Date__c = today.addYears(-1).addMonths(-3),
                breg_Good_Standing__c = true
            );
            accounts.add(acc);
        }
        insert accounts;
        return accounts;
    }

    @isTest
    static void testProcessRecords() {
        BREGBatchInterface.BatchProcessingResult result = new BREGGoodStandingCheckJob().processRecords(new Map<Id, SObject>(createAccounts()), 'Account');
        for (SObject acc : result.recordsToUpsert.values()) {
            Assert.areEqual(false, acc.get('breg_Good_Standing__c'));
        }
    }

    @isTest
    static void testAnnualsCheck() {
        List<Account> accounts = createAccounts();
        new BREGGoodStandingCheckJob().annualsCheck(accounts);
        for (Account acc : accounts) {
            Assert.isFalse(acc.breg_Good_Standing__c);
        }
    }

    @isTest
    static void testBounceCheck() {
        //as there are no contacts for now, check doesn't happen
        //TODO: create user with contact as an account owner
        List<Account> accounts = createAccounts();
        new BREGGoodStandingCheckJob().bounceCheck(accounts);
        for (Account acc : accounts) {
            Assert.isTrue(acc.breg_Good_Standing__c);
        }
    }

    @isTest
    static void testCertAgentCheck() {
        List<Account> accounts = createAccounts();
        new BREGGoodStandingCheckJob().certAgentCheck(accounts);
        for (Account acc : accounts) {
            Assert.isFalse(acc.breg_Good_Standing__c);
        }
    }

    @isTest
    static void testGetQuarter() {
        BREGGoodStandingCheckJob job = new BREGGoodStandingCheckJob();
        Assert.areEqual(1, job.getQuarter(Date.newInstance(2024, 2, 1)));
        Assert.areEqual(2, job.getQuarter(Date.newInstance(2024, 4, 1)));
        Assert.areEqual(3, job.getQuarter(Date.newInstance(2024, 7, 1)));
        Assert.areEqual(4, job.getQuarter(Date.newInstance(2024, 11, 1)));
    }

    @isTest
    static void testLastAnnualFiledDateWithinTheQuarter() {
        BREGGoodStandingCheckJob job = new BREGGoodStandingCheckJob();
        Date today = Date.newInstance(2024, 5, 1);
        Integer quarter = job.getQuarter(today) - 1;

        Date lastAnnual = Date.newInstance(2024, 1, 10);
        Assert.areEqual(true, job.lastAnnualFiledDateWithinTheQuarter(quarter, lastAnnual, today));
        Assert.areEqual(false, job.lastAnnualFiledDateWithinTheQuarter(quarter, lastAnnual.addMonths(-2), today));
    }

    private static Account createLlpParent(Date parentRegisterDate, String entityStatus, Boolean bouncedCheck) {
        Account llpParent = new Account(
            Name = 'LLP Parent',
            breg_Entity_Type__c = 'K5',
            breg_Incorporation_Date__c = parentRegisterDate,
            breg_Entity_Status__c = entityStatus,
            breg_Bounced_Check__c = bouncedCheck,
            breg_Good_Standing__c = true
        );
        insert llpParent;
        return llpParent;
    }

    private static List<Account> createGpUnder(Account llpParent, Date gpRegisterDate, String entityStatus, Boolean bouncedCheck) {
        Account gpAccount = new Account(
            Name = 'GP Child',
            breg_Entity_Type__c = 'G5',
            breg_Incorporation_Date__c = gpRegisterDate,
            breg_Entity_Status__c = entityStatus,
            breg_Bounced_Check__c = bouncedCheck,
            breg_Good_Standing__c = true,
            ParentId = llpParent.Id
        );
        insert gpAccount;
        return new List<Account>{ gpAccount };
    }

    private static List<Account> createGpWithLlpParent(Date parentRegisterDate, Date gpRegisterDate) {
        return createGpUnder(createLlpParent(parentRegisterDate, 'Active (A)', false), gpRegisterDate, 'Active (A)', false);
    }

    private static breg_Account_Affiliation__c createAgentFor(Account entity) {
        Account agent = new Account(Name = 'Agent For ' + entity.Name);
        insert agent;

        breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Account__c = agent.Id,
            breg_Role__c = 'Agent',
            breg_Status__c = 'A'
        );
        insert affiliation;
        return affiliation;
    }

    @isTest
    static void testAnnualsCheckUsesLlpParentRegisterDateForGp() {
        Date today = Date.today();
        // Parent registered long ago -> the GP is due for an annual even though it was registered recently.
        List<Account> accounts = createGpWithLlpParent(today.addYears(-3), today.addDays(-10));

        Test.startTest();
        new BREGGoodStandingCheckJob().annualsCheck(accounts);
        Test.stopTest();

        Assert.isFalse(accounts[0].breg_Good_Standing__c, 'GP account should be evaluated against the K5/K6 parent registration date');
    }

    @isTest
    static void testAnnualsCheckSkipsGpWhenLlpParentRegisteredRecently() {
        Date today = Date.today();
        // Parent registered recently -> no annual due yet, even though the GP itself is old.
        List<Account> accounts = createGpWithLlpParent(today.addDays(-10), today.addYears(-3));

        Test.startTest();
        new BREGGoodStandingCheckJob().annualsCheck(accounts);
        Test.stopTest();

        Assert.isTrue(accounts[0].breg_Good_Standing__c, 'GP account should not lose good standing when the K5/K6 parent was registered recently');
    }

    @isTest
    static void testAnnualsCheckAcceptsAnnualFiledOnLlpParent() {
        Date today = Date.today();
        Account llpParent = createLlpParent(today.addYears(-3), 'Active (A)', false);
        List<Account> accounts = createGpUnder(llpParent, today.addYears(-3), 'Active (A)', false);

        // Annual filed on the parent only - it covers the GP child as well.
        insert new breg_Annual__c(
            breg_Account__c = llpParent.Id,
            breg_Filing_Year__c = String.valueOf(today.year()),
            breg_Filing_Date__c = today,
            breg_Status__c = 'P'
        );

        Test.startTest();
        new BREGGoodStandingCheckJob().annualsCheck(accounts);
        Test.stopTest();

        Assert.isTrue(accounts[0].breg_Good_Standing__c, 'An annual filed on the K5/K6 parent should cover the GP child');
        Assert.areEqual(today, accounts[0].breg_Last_Annual_Filed_Date__c, 'Last annual filed date should come from the parent annual');
    }

    @isTest
    static void testCertAgentCheckUsesLlpParentAgent() {
        Date today = Date.today();
        Account llpParent = createLlpParent(today.addYears(-3), 'Active (A)', false);
        List<Account> accounts = createGpUnder(llpParent, today.addYears(-3), 'Active (A)', false);

        // Agent registered on the parent only.
        createAgentFor(llpParent);

        Test.startTest();
        new BREGGoodStandingCheckJob().certAgentCheck(accounts);
        Test.stopTest();

        Assert.isTrue(accounts[0].breg_Good_Standing__c, 'GP should inherit the registered agent of its K5/K6 parent');
        Assert.isNotNull(accounts[0].breg_Certified_Register_Agent__c, 'Parent agent affiliation should be stamped on the GP');
    }

    @isTest
    static void testCertAgentCheckFailsWhenNeitherGpNorParentHasAgent() {
        Date today = Date.today();
        List<Account> accounts = createGpWithLlpParent(today.addYears(-3), today.addYears(-3));

        Test.startTest();
        new BREGGoodStandingCheckJob().certAgentCheck(accounts);
        Test.stopTest();

        Assert.isFalse(accounts[0].breg_Good_Standing__c, 'GP without its own or a parent agent should not be in good standing');
    }

    @isTest
    static void testStatusCheckFailsWhenLlpParentIsNotActive() {
        Date today = Date.today();
        Account llpParent = createLlpParent(today.addYears(-3), 'Dissolved (D)', false);
        List<Account> accounts = createGpUnder(llpParent, today.addYears(-3), 'Active (A)', false);

        Test.startTest();
        new BREGGoodStandingCheckJob().statusCheck(accounts);
        Test.stopTest();

        Assert.isFalse(accounts[0].breg_Good_Standing__c, 'An active GP under an inactive K5/K6 parent should lose good standing');
    }

    @isTest
    static void testStatusCheckPassesWhenGpAndLlpParentAreActive() {
        Date today = Date.today();
        List<Account> accounts = createGpWithLlpParent(today.addYears(-3), today.addYears(-3));

        Test.startTest();
        new BREGGoodStandingCheckJob().statusCheck(accounts);
        Test.stopTest();

        Assert.isTrue(accounts[0].breg_Good_Standing__c, 'GP and parent both active should keep good standing');
    }

    @isTest
    static void testBounceCheckFailsWhenLlpParentHasBouncedCheck() {
        Date today = Date.today();
        Account llpParent = createLlpParent(today.addYears(-3), 'Active (A)', true);
        List<Account> accounts = createGpUnder(llpParent, today.addYears(-3), 'Active (A)', false);

        Test.startTest();
        new BREGGoodStandingCheckJob().bounceCheck(accounts);
        Test.stopTest();

        Assert.isFalse(accounts[0].breg_Good_Standing__c, 'A bounced check on the K5/K6 parent should break the GP good standing');
    }

    @isTest
    static void testGetLlpParentByGpAccountId() {
        Date today = Date.today();
        Date parentRegisterDate = today.addYears(-3);
        List<Account> gpAccounts = createGpWithLlpParent(parentRegisterDate, today.addDays(-10));

        BREGGoodStandingCheckJob job = new BREGGoodStandingCheckJob();

        Map<Id, Account> llpParents = job.getLlpParentByGpAccountId(gpAccounts);
        Assert.areEqual(1, llpParents.size(), 'GP account with a K5/K6 parent should be mapped');
        Assert.areEqual(
            parentRegisterDate,
            llpParents.get(gpAccounts[0].Id).breg_Incorporation_Date__c,
            'Mapped parent should carry the parent registration date'
        );

        // Non-GP accounts must not trigger the parent lookup at all.
        Assert.isTrue(job.getLlpParentByGpAccountId(createAccounts()).isEmpty(), 'Non-GP accounts should not be mapped');
    }

    @isTest
    static void testGetLlpParentIgnoresNonGpAndNonLlpParents() {
        Date today = Date.today();
        BREGGoodStandingCheckJob job = new BREGGoodStandingCheckJob();
        List<Account> gpAccounts = createGpWithLlpParent(today.addYears(-3), today.addDays(-10));
        Map<Id, Account> llpParents = job.getLlpParentByGpAccountId(gpAccounts);

        Account nonGp = new Account(Id = gpAccounts[0].Id, Name = 'Non GP', breg_Entity_Type__c = 'D1');
        Assert.isNull(job.getLlpParent(nonGp, llpParents), 'Non-GP accounts must never resolve an LLP parent');

        Account gpWithoutParent = new Account(Name = 'GP No Parent', breg_Entity_Type__c = 'G6');
        Assert.isNull(job.getLlpParent(gpWithoutParent, llpParents), 'GP without a mapped K5/K6 parent should resolve to null');
    }

    @isTest
    static void testGetAnnualsRegisterDateFallsBackToOwnDate() {
        Date today = Date.today();
        BREGGoodStandingCheckJob job = new BREGGoodStandingCheckJob();

        Account gpWithoutParent = new Account(Name = 'GP No Parent', breg_Entity_Type__c = 'G6', breg_Incorporation_Date__c = today.addYears(-2));
        Assert.areEqual(
            gpWithoutParent.breg_Incorporation_Date__c,
            job.getAnnualsRegisterDate(gpWithoutParent, null),
            'GP without a K5/K6 parent should fall back to its own registration date'
        );

        Account parentWithoutDate = new Account(Name = 'LLP No Date', breg_Entity_Type__c = 'K5');
        Assert.areEqual(
            gpWithoutParent.breg_Incorporation_Date__c,
            job.getAnnualsRegisterDate(gpWithoutParent, parentWithoutDate),
            'A parent without a registration date should fall back to the GP own date'
        );
    }

    @isTest
    static void testIsRelevantForAnnualCheck() {
        BREGGoodStandingCheckJob job = new BREGGoodStandingCheckJob();
        Date today = Date.today();
        Date regDate = today.addYears(-2);

        Integer currentQ = job.getQuarter(today);
        Integer filingQ = currentQ == 1 ? 4 : currentQ - 1;

        Assert.areEqual(true, job.isRelevantForAnnualCheck(today, regDate, currentQ, filingQ));
    }
}