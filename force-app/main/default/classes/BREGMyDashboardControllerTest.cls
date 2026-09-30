@isTest
public with sharing class BREGMyDashboardControllerTest {
    public static Id contactId;
    public static User communityUser;

    @testSetup
    static void setupData() {
        // Enable mock mode globally for all tests
        BREGAmazonSesEmailService.mockMode = true;

        // Keep all triggers disabled during setup to prevent any HTTP callouts
        BREGBaseTriggerHandler.disableTrigger(Account.SObjectType);
        BREGBaseTriggerHandler.disableTrigger(Contact.SObjectType);
        BREGBaseTriggerHandler.disableTrigger(BREGTaskTriggerHandler.class);
        BREGBaseTriggerHandler.disableTrigger(BREGCaseTriggerHandler.class);
        BREGBaseTriggerHandler.disableTrigger(BREGDocumentTriggerHandler.class);

        List<User> internalUsersWithRole = [
            SELECT Id
            FROM User
            WHERE IsActive = true
                AND UserRoleId != null
                AND ContactId = null
                AND UserType = 'Standard'
                AND Profile.UserType = 'Standard'
            LIMIT 1
        ];
        System.assert(
            !internalUsersWithRole.isEmpty(),
            'No active internal standard user with role found; cannot create portal/community users in this test context.'
        );
        Id setupActorId = internalUsersWithRole[0].Id;
        Id accountOwnerId = setupActorId;

        Account acc = new Account(Name = 'Test Business', OwnerId = accountOwnerId);
        insert acc;

        Contact con = new Contact(LastName = 'Test', Email = 'test@example.com', AccountId = acc.Id);
        insert con;
        contactId = con.Id;

        List<Profile> pList = [SELECT Id FROM Profile WHERE Name = 'DCCA BREG - CustomerCommunityUser' LIMIT 1];
        if (pList.isEmpty()) {
            pList = [SELECT Id FROM Profile WHERE UserType = 'PowerCustomerSuccess' LIMIT 1];
        }
        System.assert(!pList.isEmpty(), 'No community profile found for dashboard tests.');

        String usernameStamp = String.valueOf(DateTime.now().getTime());
        communityUser = new User(
            LastName = 'test',
            Alias = 'testu',
            Email = 'test+' + usernameStamp + '@example.com',
            Username = 'testuser+' + usernameStamp + '@example.com.test',
            CommunityNickname = 'testnick' + usernameStamp,
            ProfileId = pList[0].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = contactId
        );

        User insertActor = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(insertActor) {
            insert communityUser;
        }

        // Add test data - Email tasks will be created in individual test methods
        breg_TN_TM_SM__c tn = new breg_TN_TM_SM__c(Name = 'Test TN', breg_Type__c = 'Publicity Rights Name');
        insert tn;
        breg_Annual__c annual = new breg_Annual__c(breg_Account__c = acc.Id);
        insert annual;

        Case caseRecord = new Case(Subject = 'Test Case');
        insert caseRecord;

        breg_Document__c doc = new breg_Document__c(
            Name = 'Test Doc',
            breg_Case__c = caseRecord.Id,
            breg_Docusign_Document_Id__c = 'DOC-001',
            breg_Is_Public__c = true,
            breg_Is_Irrelevant__c = false
        );
        insert doc;

        // Triggers remain disabled - individual test methods will re-enable as needed
    }

    @isTest
    static void testGetMyCommunications() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser+%@example.com.test' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Id = :communityUser.ContactId LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Business' LIMIT 1];
        breg_TN_TM_SM__c tn = [SELECT Id FROM breg_TN_TM_SM__c WHERE Name = 'Test TN' LIMIT 1];
        breg_Annual__c annual = [SELECT Id FROM breg_Annual__c LIMIT 1];
        Case caseRecord = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        // This test only reads persisted email tasks, so keep the email-sending trigger disabled.
        BREGBaseTriggerHandler.disableTrigger(BREGTaskTriggerHandler.class);
        Test.startTest();
        Task t1 = new Task(Subject = 'Email to Account', WhoId = con.Id, WhatId = acc.Id, TaskSubtype = 'Email', Description = 'Body 1');
        Task t2 = new Task(Subject = 'Email to TN', WhoId = con.Id, WhatId = tn.Id, TaskSubtype = 'Email', Description = 'Body 2');
        Task t3 = new Task(Subject = 'Email to Annual', WhoId = con.Id, WhatId = annual.Id, TaskSubtype = 'Email', Description = 'Body 3');
        insert new List<Task>{ t1, t2, t3 };

        Task t4 = new Task(
            Subject = 'Email with Doc',
            WhoId = con.Id,
            WhatId = acc.Id,
            TaskSubtype = 'Email',
            breg_Case__c = caseRecord.Id,
            Description = 'Body 4'
        );
        insert t4;
        Task t5 = new Task(Subject = 'Email with Doc (via Task)', WhoId = con.Id, WhatId = acc.Id, TaskSubtype = 'Email', Description = 'Body 5');
        insert t5;
        Test.stopTest();

        // Create documents for t5
        breg_Document__c docTask = new breg_Document__c(
            Name = 'Test Doc Task',
            breg_TaskId__c = t5.Id,
            breg_Docusign_Document_Id__c = 'DOC-002',
            breg_Is_Public__c = true,
            breg_Is_Irrelevant__c = false
        );
        insert docTask;

        System.runAs(communityUser) {
            List<BREGMyDashboardController.CommunicationWrapper> communications = BREGMyDashboardController.getMyCommunications();

            System.assertEquals(5, communications.size());

            Boolean foundEmailWithTaskDoc = false;
            for (BREGMyDashboardController.CommunicationWrapper c : communications) {
                if (c.subject == 'Email with Doc (via Task)') {
                    System.assertEquals('Body 5', c.body);
                    System.assertNotEquals(null, c.attachments, 'Attachments list should always be initialized');
                    foundEmailWithTaskDoc = true;
                }
            }
            System.assert(foundEmailWithTaskDoc, 'Expected to find task-linked email communication in result set');
        }
    }

    @isTest
    static void testGetMyBusinessesDeduplicatesTnTmSm() {
        User runAsUser = [SELECT Id, ContactId FROM User WHERE Username LIKE 'testuser+%@example.com.test' LIMIT 1];

        breg_TN_TM_SM__c tnRecord = new breg_TN_TM_SM__c(
            Name = 'Trade Name A',
            breg_Type__c = 'Trade Name',
            breg_Status__c = 'A',
            breg_File__c = '2001',
            breg_File_Suffix__c = 'B'
        );
        insert tnRecord;

        insert new List<Case>{
            new Case(Subject = 'TN Case 1', ContactId = runAsUser.ContactId, breg_TN_TM_SM__c = tnRecord.Id),
            new Case(Subject = 'TN Case 2 Duplicate', ContactId = runAsUser.ContactId, breg_TN_TM_SM__c = tnRecord.Id)
        };

        System.runAs(runAsUser) {
            List<BREGMyDashboardController.MyBusinessWrapper> businesses = BREGMyDashboardController.getMyBusinesses();

            Integer tnCount = 0;
            for (BREGMyDashboardController.MyBusinessWrapper business : businesses) {
                if (business.recordId == String.valueOf(tnRecord.Id)) {
                    tnCount++;
                    Assert.areEqual('Trade Name', business.recordType, 'Expected TN/TM/SM type as record type');
                    Assert.areEqual('2001 B', business.fileNumber, 'Expected TN/TM/SM file number and suffix formatting');
                }
            }

            Assert.areEqual(1, tnCount, 'Duplicate TN/TM/SM-related cases should be deduplicated');
        }
    }

    @isTest
    static void testGetMapEntityNameCoversCaseFallbacks() {
        Account acc = new Account(Name = 'Entity Map Account');
        insert acc;

        breg_TN_TM_SM__c tn = new breg_TN_TM_SM__c(Name = 'Entity Map TN', breg_Type__c = 'Trade Name');
        insert tn;

        breg_Annual__c annual = new breg_Annual__c(breg_Account__c = acc.Id);
        insert annual;

        Case caseWithEntityName = new Case(Subject = 'Case Entity Name', breg_Name_of_the_Entity__c = 'Case Entity Label');
        Case caseWithTnDesc = new Case(Subject = 'Case TN Desc', breg_TNTMSM_Description__c = 'Fallback TN Description');
        Case caseWithoutNames = new Case(Subject = 'Case Without Names');
        insert new List<Case>{ caseWithEntityName, caseWithTnDesc, caseWithoutNames };

        List<Task> emailTasks = new List<Task>{
            new Task(WhatId = acc.Id),
            new Task(WhatId = tn.Id),
            new Task(WhatId = annual.Id),
            new Task(WhatId = caseWithEntityName.Id),
            new Task(WhatId = caseWithTnDesc.Id),
            new Task(WhatId = caseWithoutNames.Id)
        };

        Map<Id, String> whatIdToName = BREGMyDashboardController.getMapEntityName(emailTasks);

        Assert.areEqual('Entity Map Account', whatIdToName.get(acc.Id), 'Account name should map correctly');
        Assert.areEqual('Entity Map TN', whatIdToName.get(tn.Id), 'TN/TM/SM name should map correctly');
        Assert.areEqual('Entity Map Account', whatIdToName.get(annual.Id), 'Annual should map to related account name');
        Assert.areEqual('Case Entity Label', whatIdToName.get(caseWithEntityName.Id), 'Case should use entity name when present');
        Assert.areEqual('Fallback TN Description', whatIdToName.get(caseWithTnDesc.Id), 'Case should fallback to TNTMSM description');
        Assert.areEqual('Without entity', whatIdToName.get(caseWithoutNames.Id), 'Case should fallback to default without entity text');
    }

    @isTest
    static void testGetMapTaskAttachmentsHandlesCaseAndTaskParents() {
        Account acc = new Account(Name = 'Attachment Account');
        insert acc;

        Contact con = new Contact(LastName = 'Attachment Contact', AccountId = acc.Id, Email = 'attachment@example.com');
        insert con;

        Case caseRecord = new Case(Subject = 'Attachment Case');
        insert caseRecord;

        // This test only verifies attachment mapping, so keep the email-sending trigger disabled.
        BREGBaseTriggerHandler.disableTrigger(BREGTaskTriggerHandler.class);
        Test.startTest();
        Task caseTask = new Task(Subject = 'Case Task', WhoId = con.Id, TaskSubtype = 'Email', breg_Case__c = caseRecord.Id);
        Task standaloneTask = new Task(Subject = 'Standalone Task', WhoId = con.Id, TaskSubtype = 'Email');
        insert new List<Task>{ caseTask, standaloneTask };
        Test.stopTest();

        insert new List<breg_Document__c>{
            new breg_Document__c(
                Name = 'Doc By Case',
                breg_Case__c = caseRecord.Id,
                breg_Docusign_Document_Id__c = 'ATTACH-CASE-001',
                breg_Is_Irrelevant__c = false,
                breg_Is_Public__c = true
            ),
            new breg_Document__c(
                Name = 'Doc By Task',
                breg_TaskId__c = standaloneTask.Id,
                breg_Docusign_Document_Id__c = 'ATTACH-TASK-001',
                breg_Is_Irrelevant__c = false,
                breg_Is_Public__c = true
            )
        };

        Map<Id, List<breg_Document__c>> attachmentsMap = BREGMyDashboardController.getMapTaskAttachments(new List<Task>{ caseTask, standaloneTask });

        Assert.isNotNull(attachmentsMap, 'Attachments map should be initialized');
    }

    @isTest
    static void testGetTransactionLineWrappersNoPaidPayments() {
        User runAsUser = [SELECT Id FROM User WHERE Username LIKE 'testuser+%@example.com.test' LIMIT 1];

        System.runAs(runAsUser) {
            Test.startTest();
            List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGMyDashboardController.getTransactionLineWrappers();
            Test.stopTest();

            Assert.isNotNull(wrappers, 'Wrappers list should not be null even with no paid payments');
        }
    }
}