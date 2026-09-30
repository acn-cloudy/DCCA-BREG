@IsTest
private class BREGAnnualRobotTest {

    @TestSetup
    private static void setupData() {
        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFormConfigurations();
        upsert new breg_Docusign_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        upsert new BREG_Setting__c(
            SetupOwnerId = UserInfo.getUserId(),
            Annual_Robot_Enabled__c = true,
            Global_Data_Migration_Triggers_Disabled__c = false
        );
    }

    @IsTest
    static void processCasesStartsWorkflowAndCreatesSuccessComment() {
        Account entity = [
            SELECT Id, Name, breg_File__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_Incorporation_Date__c, breg_Bounced_Check__c, breg_BRIM_CRA_FL__c, breg_Purpose__c, BillingStreet, BillingCity, BillingStateCode, BillingPostalCode, BillingCountryCode
            FROM Account
            LIMIT 1
        ];
        entity.breg_File__c = '12345-D1';
        entity.breg_Entity_Type__c = 'D1';
        entity.breg_Entity_Status__c = 'Active (A)';
        entity.breg_Incorporation_Date__c = Date.today().addYears(-1);
        entity.breg_Bounced_Check__c = false;
        entity.breg_BRIM_CRA_FL__c = false;
        entity.BillingStreet = '123 Main St';
        entity.BillingCity = 'Honolulu';
        entity.BillingStateCode = 'HI';
        entity.BillingPostalCode = '96813';
        entity.BillingCountryCode = 'US';
        update entity;

        Contact testContact = new Contact(FirstName = 'Annual', LastName = 'Contact');
        insert testContact;

        Account agentAccount = new Account(
            Name = 'Agent Account',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert new breg_Account_Affiliation__c(
            breg_Account__c = agentAccount.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );

        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Annual',
            breg_Last_Name__c = 'Director',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );
        insert new breg_Account_Affiliation__c(
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Annual',
            breg_Last_Name__c = 'Officer',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );

        breg_Annual__c annual = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Status__c = 'D',
            breg_Filing_Date__c = Date.today().addDays(-10),
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Received_Date__c = System.now().addDays(-1)
        );
        insert annual;

        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }

        Case annualCase = new Case(
            Subject = 'Annual Robot Success',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            ContactId = testContact.Id,
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = '0001',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Effective_Date__c = Date.today(),
            breg_Annual_Report_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Annual__c = annual.Id,
            breg_Name_of_the_Entity__c = entity.Name,
            breg_Entity_Type__c = entity.breg_Entity_Type__c,
            breg_Entity_Nature_Of_Business__c = entity.breg_Purpose__c,
            breg_Company_Address__Street__s = entity.BillingStreet,
            breg_Company_Address__City__s = entity.BillingCity,
            breg_Company_Address__StateCode__s = entity.BillingStateCode,
            breg_Company_Address__PostalCode__s = entity.BillingPostalCode,
            breg_Company_Address__CountryCode__s = entity.BillingCountryCode
        );
        insert annualCase;
        BREGAnnualRobotTestHelper.attachMatchingAffiliationsAndStocksToCase(annualCase.Id, entity.Id);
        BREGAnnualRobotTestHelper.createPublicInitialFilingDocument(annualCase);

        Transaction__c transactionRecord = new Transaction__c(Account__c = entity.Id, breg_Case__c = annualCase.Id, Date__c = Date.today(), Status__c = 'New');
        insert transactionRecord;
        insert new TransactionLine__c(
            Transaction__c = transactionRecord.Id,
            breg_Case__c = annualCase.Id,
            PaidStatus__c = 'Paid',
            Amount__c = 10,
            Description__c = 'Annual Fee'
        );

        Test.startTest();
        BREGAnnualRobot.processCases(new List<Case>{ annualCase });
        Test.stopTest();

        List<CaseComment> comments = [SELECT CommentBody FROM CaseComment WHERE ParentId = :annualCase.Id ORDER BY CreatedDate ASC];
        Case updatedCase = [SELECT breg_Annual_Robot_Status__c, breg_Robot_Processed_DateTime__c FROM Case WHERE Id = :annualCase.Id];
        System.assertEquals(1, comments.size(), 'Successful annual robot processing should create one case comment.');
        System.assertEquals('All business rules passed. Annual was processed by the robot.', comments[0].CommentBody, 'Success path should log the success comment.');
        System.assertEquals('Completed', updatedCase.breg_Annual_Robot_Status__c, 'Success path should store Completed robot status.');
        System.assertNotEquals(null, updatedCase.breg_Robot_Processed_DateTime__c, 'Success path should stamp processed datetime.');
    }

    @IsTest
    static void processCasesCreatesFailureCommentWhenContactMissing() {
        Account entity = [
            SELECT Id, breg_File__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_Incorporation_Date__c, breg_Bounced_Check__c, breg_BRIM_CRA_FL__c
            FROM Account
            LIMIT 1
        ];
        entity.breg_File__c = '67890-D1';
        entity.breg_Entity_Type__c = 'D1';
        entity.breg_Entity_Status__c = 'Active (A)';
        entity.breg_Incorporation_Date__c = Date.today().addYears(-2);
        entity.breg_Bounced_Check__c = false;
        entity.breg_BRIM_CRA_FL__c = false;
        update entity;

        Account agentAccount = new Account(
            Name = 'Missing Contact Agent Account',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert new breg_Account_Affiliation__c(
            breg_Account__c = agentAccount.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );

        breg_Annual__c annual = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Status__c = 'D',
            breg_Filing_Date__c = Date.today().addDays(-10),
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Received_Date__c = System.now().addDays(-1)
        );
        insert annual;

        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }

        Case annualCase = new Case(
            Subject = 'Annual Robot Missing Contact',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = '0002',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Annual__c = annual.Id,
            breg_Override_Payment__c = true
        );
        insert annualCase;

        Test.startTest();
        BREGAnnualRobot.processCases(new List<Case>{ annualCase });
        Test.stopTest();

        List<CaseComment> comments = [SELECT CommentBody FROM CaseComment WHERE ParentId = :annualCase.Id ORDER BY CreatedDate ASC];
        Case updatedCase = [SELECT breg_Annual_Robot_Status__c, breg_Robot_Processed_DateTime__c FROM Case WHERE Id = :annualCase.Id];

        System.assertEquals(1, comments.size(), 'Failure path should create one case comment.');
        System.assert(
            comments[0].CommentBody.contains(System.Label.BREG_AnnualRobot_Failure_Header),
            'Failure path should include the failure header.'
        );
        System.assert(
            comments[0].CommentBody.contains(System.Label.BREG_AnnualRobot_Contact_Missing),
            'Failure path should log the contact error in the aggregated message.'
        );
        System.assertEquals('Routed for manual', updatedCase.breg_Annual_Robot_Status__c, 'Validation failures should store Routed for manual status.');
        System.assertEquals(null, updatedCase.breg_Robot_Processed_DateTime__c, 'Validation failures should not stamp processed datetime.');
    }

    @IsTest
    static void processCasesAggregatesMultipleFailureReasons() {
        Account entity = [
            SELECT Id, breg_File__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_Incorporation_Date__c, breg_Bounced_Check__c, breg_BRIM_CRA_FL__c
            FROM Account
            LIMIT 1
        ];
        entity.breg_File__c = '77777-D1';
        entity.breg_Entity_Type__c = 'D1';
        entity.breg_Entity_Status__c = 'Active (A)';
        entity.breg_Incorporation_Date__c = Date.today().addYears(-2);
        entity.breg_Bounced_Check__c = false;
        entity.breg_BRIM_CRA_FL__c = false;
        update entity;

        Account agentAccount = new Account(
            Name = 'Entity Agent Account',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert new List<breg_Account_Affiliation__c>{
            new breg_Account_Affiliation__c(
                breg_Account__c = agentAccount.Id,
                breg_Entity__c = entity.Id,
                breg_Role__c = 'Agent',
                breg_Type__c = 'Entity',
                breg_Address__Street__s = '123 Main St',
                breg_Address__City__s = 'Honolulu',
                breg_Address__StateCode__s = 'HI',
                breg_Address_State_Text__c = 'HI',
                breg_Address__PostalCode__s = '96813',
                breg_Address__CountryCode__s = 'US',
                breg_Start_Date__c = Date.today().addMonths(-1),
                breg_Status__c = 'A'
            ),
            new breg_Account_Affiliation__c(
                breg_Account__c = agentAccount.Id,
                breg_Entity__c = entity.Id,
                breg_Role__c = 'Officer',
                breg_Type__c = 'Entity',
                breg_Start_Date__c = Date.today().addMonths(-1),
                breg_Status__c = 'A'
            )
        };

        breg_Annual__c olderAnnual = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Status__c = 'P',
            breg_Filing_Year__c = String.valueOf(Date.today().year() - 1)
        );
        breg_Annual__c currentAnnual = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Status__c = 'D',
            breg_Filing_Date__c = Date.today().addMonths(-4),
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Received_Date__c = System.now().addDays(-1)
        );
        insert new List<breg_Annual__c>{ olderAnnual, currentAnnual };

        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }

        Case annualCase = new Case(
            Subject = 'Annual Robot Multiple Failures',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = '0003',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Annual__c = currentAnnual.Id,
            breg_Override_Payment__c = true
        );
        insert annualCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = annualCase.Id,
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Annual Robot Multiple Failures',
            breg_Mapping_Status__c = 'Error'
        );

        Test.startTest();
        BREGAnnualRobot.processCases(new List<Case>{ annualCase });
        Test.stopTest();

        CaseComment commentRecord = [SELECT CommentBody FROM CaseComment WHERE ParentId = :annualCase.Id LIMIT 1];

        System.assert(commentRecord.CommentBody.contains(System.Label.BREG_AnnualRobot_Failure_Header), 'Failure comment should include the header.');
        System.assert(commentRecord.CommentBody.contains(System.Label.BREG_AnnualRobot_Mapping_Error), 'Failure comment should include the web filing mapping reason.');
        System.assert(commentRecord.CommentBody.contains(System.Label.BREG_AnnualRobot_Contact_Missing), 'Failure comment should include the contact reason.');
        System.assert(commentRecord.CommentBody.contains(System.Label.BREG_AnnualRobot_Agent_Is_Entity), 'Failure comment should include the agent type reason.');
        System.assert(commentRecord.CommentBody.contains(System.Label.BREG_AnnualRobot_Entity_Affiliation), 'Failure comment should include the entity affiliation reason.');
    }

    @IsTest
    static void processCasesStopsWhenWebFilingMappingNotStarted() {
        Account entity = [
            SELECT Id, breg_File__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_Incorporation_Date__c, breg_Bounced_Check__c, breg_BRIM_CRA_FL__c
            FROM Account
            LIMIT 1
        ];
        entity.breg_File__c = '88888-D1';
        entity.breg_Entity_Type__c = 'D1';
        entity.breg_Entity_Status__c = 'Active (A)';
        entity.breg_Incorporation_Date__c = Date.today().addYears(-2);
        entity.breg_Bounced_Check__c = false;
        entity.breg_BRIM_CRA_FL__c = false;
        update entity;

        Contact testContact = new Contact(FirstName = 'Ready', LastName = 'Contact');
        insert testContact;

        Account agentAccount = new Account(
            Name = 'Good Agent Account',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;

        insert new breg_Account_Affiliation__c(
            breg_Account__c = agentAccount.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );

        breg_Annual__c annual = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Status__c = 'D',
            breg_Filing_Date__c = Date.today().addMonths(-4),
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Received_Date__c = System.now().addDays(-1)
        );
        insert annual;

        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }

        Case annualCase = new Case(
            Subject = 'Annual Robot Mapping Not Started',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            ContactId = testContact.Id,
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = '0004',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Annual__c = annual.Id,
            breg_Override_Payment__c = true
        );
        insert annualCase;

        insert new breg_WEB_WEB_FILING_INFO__c(
            breg_WEB_Case__c = annualCase.Id,
            breg_WEB_RDPMS_WFCOMPANY_NAME__c = 'Annual Robot Mapping Not Started',
            breg_Mapping_Status__c = 'Not Started'
        );

        Test.startTest();
        BREGAnnualRobot.processCases(new List<Case>{ annualCase });
        Test.stopTest();

        CaseComment commentRecord = [SELECT CommentBody FROM CaseComment WHERE ParentId = :annualCase.Id LIMIT 1];
        System.assert(commentRecord.CommentBody.contains(System.Label.BREG_AnnualRobot_Mapping_Not_Started), 'Failure comment should include the Not Started mapping reason.');
    }

    @IsTest
    static void processCasesQueuesLaterAnnualWhenOlderCaseIsUnresolved() {
        Account entity = [
            SELECT Id, breg_File__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_Incorporation_Date__c, breg_Bounced_Check__c, breg_BRIM_CRA_FL__c
            FROM Account
            LIMIT 1
        ];
        entity.breg_File__c = '99991-D1';
        entity.breg_Entity_Type__c = 'D1';
        entity.breg_Entity_Status__c = 'Active (A)';
        entity.breg_Incorporation_Date__c = Date.today().addYears(-2);
        entity.breg_Bounced_Check__c = false;
        entity.breg_BRIM_CRA_FL__c = false;
        update entity;

        Contact testContact = new Contact(FirstName = 'Queue', LastName = 'Contact');
        insert testContact;

        Account agentAccount = new Account(
            Name = 'Queue Agent Account',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US',
            breg_BRIM_CRA_FL__c = false
        );
        insert agentAccount;
        insert new breg_Account_Affiliation__c(
            breg_Account__c = agentAccount.Id,
            breg_Entity__c = entity.Id,
            breg_Role__c = 'Agent',
            breg_Type__c = 'Individual',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Honolulu',
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI',
            breg_Address__PostalCode__s = '96813',
            breg_Address__CountryCode__s = 'US',
            breg_Start_Date__c = Date.today().addMonths(-1),
            breg_Status__c = 'A'
        );

        insert new List<breg_Annual__c>{
            new breg_Annual__c(breg_Account__c = entity.Id, breg_Status__c = 'D', breg_Filing_Year__c = String.valueOf(Date.today().year() - 1)),
            new breg_Annual__c(
                breg_Account__c = entity.Id,
                breg_Status__c = 'D',
                breg_Filing_Date__c = Date.today().addMonths(-4),
                breg_Filing_Year__c = String.valueOf(Date.today().year()),
                breg_Received_Date__c = System.now().addDays(-1)
            )
        };

        List<breg_Annual__c> annuals = [SELECT Id, breg_Filing_Year__c FROM breg_Annual__c WHERE breg_Account__c = :entity.Id ORDER BY breg_Filing_Year__c ASC];

        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }

        Case olderCase = new Case(
            Subject = 'Older Manual Annual',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            ContactId = testContact.Id,
            breg_No_Changes__c = false,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = '0010',
            breg_Submission_Date__c = System.now().addHours(-2),
            breg_Annual_Report_Filing_Year__c = annuals[0].breg_Filing_Year__c,
            breg_Annual__c = annuals[0].Id,
            breg_Annual_Robot_Status__c = 'Routed for manual'
        );
        insert olderCase;

        Case laterCase = new Case(
            Subject = 'Later Queued Annual',
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            ContactId = testContact.Id,
            breg_No_Changes__c = true,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = '0011',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = annuals[1].breg_Filing_Year__c,
            breg_Annual__c = annuals[1].Id,
            breg_Override_Payment__c = true
        );
        insert laterCase;

        Test.startTest();
        BREGAnnualRobot.processCases(new List<Case>{ laterCase });
        Test.stopTest();

        Case queuedCase = [SELECT breg_Annual_Robot_Status__c FROM Case WHERE Id = :laterCase.Id];
        CaseComment commentRecord = [SELECT CommentBody FROM CaseComment WHERE ParentId = :laterCase.Id LIMIT 1];

        System.assertEquals('Routed for manual', queuedCase.breg_Annual_Robot_Status__c, 'Later annual should be routed for manual when an older annual is already final-blocked.');
        System.assert(
            commentRecord.CommentBody.contains('A previous annual case for an earlier filing year is not closed and blocks robot processing.'),
            'Later annual should log the unresolved earlier-annual reason.'
        );
    }

    @IsTest
    static void processCasesIgnoresCasesOutsideStartCriteria() {
        Account entity = [
            SELECT Id, breg_File__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_Incorporation_Date__c, breg_Bounced_Check__c, breg_BRIM_CRA_FL__c
            FROM Account
            LIMIT 1
        ];
        entity.breg_File__c = '55555-D1';
        entity.breg_Entity_Type__c = 'D1';
        entity.breg_Entity_Status__c = 'Active (A)';
        entity.breg_Incorporation_Date__c = Date.today().addYears(-1);
        entity.breg_Bounced_Check__c = false;
        entity.breg_BRIM_CRA_FL__c = false;
        update entity;

        Contact testContact = new Contact(FirstName = 'Ignored', LastName = 'Case');
        insert testContact;

        breg_Annual__c annual = new breg_Annual__c(
            breg_Account__c = entity.Id,
            breg_Status__c = 'D',
            breg_Filing_Date__c = Date.today().addMonths(-4),
            breg_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Received_Date__c = System.now().addDays(-1)
        );
        insert annual;

        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }

        Case ignoredCase = new Case(
            Subject = 'Ignored by annual robot',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            ContactId = testContact.Id,
            breg_No_Changes__c = false,
            breg_Form_Configuration__c = annualForm.Id,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = entity.Id,
            breg_File__c = entity.breg_File__c,
            breg_Workitem_Number__c = '0099',
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = String.valueOf(Date.today().year()),
            breg_Annual__c = annual.Id
        );
        insert ignoredCase;

        Test.startTest();
        BREGAnnualRobot.processCases(new List<Case>{ ignoredCase });
        Test.stopTest();

        Integer commentCount = [SELECT count() FROM CaseComment WHERE ParentId = :ignoredCase.Id];
        Case unchangedCase = [SELECT breg_Annual_Robot_Status__c, breg_Robot_Processed_DateTime__c FROM Case WHERE Id = :ignoredCase.Id];

        System.assertEquals(0, commentCount, 'Cases outside start criteria must be ignored before validation.');
        System.assertEquals(null, unchangedCase.breg_Annual_Robot_Status__c, 'Ignored cases must not receive robot status updates.');
        System.assertEquals(null, unchangedCase.breg_Robot_Processed_DateTime__c, 'Ignored cases must not receive robot timestamps.');
    }
}