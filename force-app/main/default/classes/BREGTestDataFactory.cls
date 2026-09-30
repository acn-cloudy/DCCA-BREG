@isTest
public class BREGTestDataFactory {
    public static List<Account> createEntityAccounts(Integer numAccts) {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < numAccts; i++) {
            Account acct = new Account();
            acct.Name = (i + 1) == numAccts ? 'Acme Inc.' : 'Test Entity ' + i;
            acct.BillingPostalCode = '12345';
            acct.breg_Incorporation_Date__c = Date.newInstance(2023, 12, 12);
            acct.breg_Entity_Type__c = 'D1';
            acct.RecordTypeId = bregAccRecordType;
            //TODO: create additional fields as needed
            accounts.add(acct);
        }
        insert accounts;
        return accounts;
    }

    public static List<breg_Notification_Category__mdt> getAllCategories() {
        List<breg_Notification_Category__mdt> mockData = new List<breg_Notification_Category__mdt>();

        breg_Notification_Category__mdt m1 = new breg_Notification_Category__mdt();
        m1.breg_Related_Object__c = 'Account';
        m1.breg_Subscription_Category__c = 'Annual Report Reminder';
        m1.Display_Options__c = 'Always Show Category for Related Object';
        m1.breg_Fee_Code__c = 'FEE001';
        mockData.add(m1);

        breg_Notification_Category__mdt m2 = new breg_Notification_Category__mdt();
        m2.breg_Related_Object__c = 'breg_TN_TM_SM__c';
        m2.breg_Subscription_Category__c = 'Publicity Rights Name Renewal Reminder';
        m2.Display_Options__c = 'Depends on Related Object Field';
        m2.breg_Fee_Code__c = 'FEE002';
        mockData.add(m2);

        return mockData;
    }

    public static List<breg_Form_Configuration__c> createFormConfigurations() {
        List<breg_Form_Configuration__c> formConfigurations = new List<breg_Form_Configuration__c>();
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'D1',
                breg_Suffix_Code__c = 'D1',
                breg_Form_Code__c = 'DC-1',
                breg_Business_Process__c = 'New Business'
            )
        );
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'C5',
                breg_Suffix_Code__c = 'C5',
                breg_Form_Code__c = 'LLC-1',
                breg_Business_Process__c = 'New Business'
            )
        );
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'D2',
                breg_Suffix_Code__c = 'D2',
                breg_Form_Code__c = 'DNP-1',
                breg_Business_Process__c = 'New Business'
            )
        );
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'A1',
                breg_Suffix_Code__c = 'A1',
                breg_Form_Code__c = 'AG-1',
                breg_Business_Process__c = 'New Business'
            )
        );
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'K6',
                breg_Suffix_Code__c = 'K6',
                breg_Form_Code__c = 'LLP-1',
                breg_Business_Process__c = 'New Business'
            )
        );
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'G5',
                breg_Suffix_Code__c = 'G5',
                breg_Form_Code__c = 'GP-1',
                breg_Business_Process__c = 'New Business'
            )
        );
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'D2',
                breg_Suffix_Code__c = 'D2',
                breg_Business_Process__c = 'Annual Report',
                Name = 'ANN-DNP-1'
            )
        );
        formConfigurations.add(
            new breg_Form_Configuration__c(
                breg_Entity_Type__c = 'D1',
                breg_Suffix_Code__c = 'DC-2',
                breg_Business_Process__c = 'Change',
                Name = 'DC-2'
            )
        );
        insert formConfigurations;
        return formConfigurations;
    }

    public static List<Case> createRegistrationCases(List<breg_Form_Configuration__c> forms) {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        List<Case> cases = new List<Case>();
        Map<String, String> formCodeBySuffixCode = new Map<String, String>{ 'D1' => 'DC-1', 'C5' => 'LLC-1', 'D2' => 'DNP-1', 'A1' => 'AG-1' };
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'test@example.com');
        insert testContact;
        for (breg_Form_Configuration__c form : forms) {
            for (Integer i = 1; i < 5; i++) {
                cases.add(
                    new Case(
                        Subject = 'Test Case for ' + form.breg_Entity_Type__c,
                        Status = 'New',
                        Origin = 'Web',
                        RecordTypeId = bregCaseRecordTypeId,
                        breg_New_Entity_Name__c = 'Corporation Company LLC ' + i,
                        breg_Name_of_the_Entity__c = 'Corporation Company LLC ' + i,
                        breg_Form_Configuration__c = form.Id,
                        breg_Form_Code__c = formCodeBySuffixCode.get(form.breg_Suffix_Code__c),
                        breg_Company_Address__CountryCode__s = 'US',
                        breg_Company_Address__StateCode__s = 'HI',
                        breg_Company_Address__City__s = 'Honolulu',
                        breg_Company_Address__Street__s = 'Mart rd, 134',
                        breg_Company_Address__PostalCode__s = '1234',
                        breg_Annual_Report_Filing_Year__c = '2024',
                        breg_Stock_Type__c = 'Without Stock',
                        breg_Effective_Date__c = Date.today(),
                        ContactId = testContact.Id
                    )
                );
            }
        }
        insert cases;
        List<pymt__PaymentX__c> payments = new List<pymt__PaymentX__c>();
        for (Case c : cases) {
            payments.add(new pymt__PaymentX__c(Name = 'Test Payment for Case ' + c.Id, breg_Case__c = c.Id, pymt__Status__c = 'Completed'));
        }
        insert payments;
        return cases;
    }

    public static List<breg_Account_Affiliation__c> createAccountAffiliationsForRole(Id caseId, String role, Integer count) {
        List<breg_Account_Affiliation__c> affiliations = new List<breg_Account_Affiliation__c>();
        if (caseId == null || String.isBlank(role) || count == null || count <= 0) {
            return affiliations;
        }

        for (Integer index = 0; index < count; index++) {
            breg_Account_Affiliation__c affiliation = new breg_Account_Affiliation__c(
                breg_Case__c = caseId,
                breg_Role__c = role,
                breg_Type__c = 'Individual',
                breg_First_Name__c = 'Test',
                breg_Last_Name__c = role + ' ' + String.valueOf(index + 1),
                breg_Address__CountryCode__s = 'US',
                breg_Address__Street__s = '123 Test St',
                breg_Address__StateCode__s = 'HI',
                breg_Address__City__s = 'Honolulu',
                breg_Address__PostalCode__s = '96813'
            );

            if (role == 'Director') {
                affiliation.breg_Officer_Director_Titles__c = 'AC';
            }

            affiliations.add(affiliation);
        }

        insert affiliations;
        return affiliations;
    }

    public static List<breg_Annual__c> createAnnuals(List<breg_Form_Configuration__c> forms) {
        List<Case> relatedCases = createRegistrationCases(forms);
        List<breg_Annual__c> annuals = new List<breg_Annual__c>();
        for (Integer i = 0; i < relatedCases.size(); i++) {
            breg_Annual__c annual = new breg_Annual__c(breg_Status__c = 'N');
            annuals.add(annual);
        }
        insert annuals;
        for (Integer i = 0; i < relatedCases.size(); i++) {
            relatedCases[i].breg_Annual__c = annuals[i].Id;
        }
        update relatedCases;
        return annuals;
    }

    public static void createFeeSettings() {
        List<breg_Fee__c> fees = new List<breg_Fee__c>();
        fees.add(
            new breg_Fee__c(
                breg_Record_Type__c = 'Entity List',
                breg_Fee_Amount__c = 0.05,
                breg_Purchase_Type_Fee_type__c = 'Document',
                breg_Cashier_Code__c = 'B71'
            )
        );
        fees.add(
            new breg_Fee__c(
                breg_Record_Type__c = 'Entity List',
                breg_Fee_Amount__c = 1000,
                breg_Purchase_Type_Fee_type__c = 'Document',
                breg_Cashier_Code__c = 'B72'
            )
        );
        insert fees;
    }

    public static void createFileNumberSequences() {
        BREG_File_Number_Sequence__c seq1 = new BREG_File_Number_Sequence__c();
        seq1.Name = 'L5,Q5,L6,Q6 Sequence';
        seq1.breg_Entity_Codes__c = 'L5,Q5,L6,Q6';
        seq1.breg_Current_Index__c = 1;

        BREG_File_Number_Sequence__c seq2 = new BREG_File_Number_Sequence__c();
        seq2.Name = 'D1,D2,P1,S1,A1,A2,C1,C2,D9';
        seq2.breg_Entity_Codes__c = 'D1,D2,P1,S1,A1,A2,C1,C2,D9,A1';
        seq2.breg_Current_Index__c = 1;

        BREG_File_Number_Sequence__c seq3 = new BREG_File_Number_Sequence__c();
        seq3.Name = 'C5,C6 Sequence';
        seq3.breg_Entity_Codes__c = 'C5,C6';
        seq3.breg_Current_Index__c = 1;

        BREG_File_Number_Sequence__c seq4 = new BREG_File_Number_Sequence__c();
        seq4.Name = 'G5,G6 Sequence';
        seq4.breg_Entity_Codes__c = 'G5,G6';
        seq4.breg_Current_Index__c = 1;

        BREG_File_Number_Sequence__c seq5 = new BREG_File_Number_Sequence__c();
        seq5.Name = 'K5,K6 Sequence';
        seq5.breg_Entity_Codes__c = 'K5,K6';
        seq5.breg_Current_Index__c = 1;

        BREG_File_Number_Sequence__c seq6 = new BREG_File_Number_Sequence__c();
        seq6.Name = 'TNTMSM Sequence';
        seq6.breg_Entity_Codes__c = 'T-1,T-2,T-3';
        seq6.breg_Current_Index__c = 1;

        BREG_File_Number_Sequence__c seq7 = new BREG_File_Number_Sequence__c();
        seq7.Name = 'Publicity Rights Sequence';
        seq7.breg_Entity_Codes__c = 'PR1';
        seq7.breg_Current_Index__c = 1;

        BREG_File_Number_Sequence__c seq8 = new BREG_File_Number_Sequence__c();
        seq8.Name = 'Name Reservations Sequence';
        seq8.breg_Entity_Codes__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE;
        seq8.breg_Current_Index__c = 1;

        insert new List<BREG_File_Number_Sequence__c>{ seq1, seq2, seq3, seq4, seq5, seq6, seq7, seq8 };
    }

    public static void createTransactionLineForEntityList(Id entityListId) {
        // Create a transaction
        Transaction__c trans = new Transaction__c();
        insert trans;

        pymt__PaymentX__c payment = new pymt__PaymentX__c();

        payment.Transaction__c = trans.Id;
        insert payment;

        TransactionLine__c transLine = new TransactionLine__c();
        transLine.Payment__c = payment.Id;
        transLine.Amount__c = 0.05; // Default price
        transLine.Description__c = 'Entity List';
        transLine.Transaction__c = trans.Id;
        transLine.breg_Type__c = 'Entity List';
        transLine.breg_Entity_List__c = entityListId;
        insert transLine;
    }

    public static void createTransactionLineForAgentSearch(Id agentSearchListId) {
        Transaction__c trans = new Transaction__c();
        insert trans;

        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.Transaction__c = trans.Id;
        insert payment;

        TransactionLine__c transLine = new TransactionLine__c();
        transLine.Payment__c = payment.Id;
        transLine.Amount__c = 2.05;
        transLine.Description__c = 'Agent Search - 1 CRA agent(s)';
        transLine.Transaction__c = trans.Id;
        transLine.breg_Type__c = 'Agent Search List';
        transLine.breg_Agent_Search_List__c = agentSearchListId;
        insert transLine;
    }

    public static User createCommunityUser() {
        List<User> internalUsersWithRole = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND UserRoleId != NULL AND ContactId = NULL AND UserType = 'Standard' AND Profile.UserType = 'Standard'
            LIMIT 1
        ];
        System.assert(
            !internalUsersWithRole.isEmpty(),
            'No active internal standard user with role found; cannot create portal/community users in this test context.'
        );
        Id accountOwnerId = internalUsersWithRole[0].Id;

        Account accountRecord = new Account(Name = 'BREG Unit Test Portal Account', OwnerId = accountOwnerId);
        insert accountRecord;

        Contact contactRecord = new Contact(LastName = 'Portal User', Email = 'breg.unit.test@example.com', AccountId = accountRecord.Id);
        insert contactRecord;

        List<Profile> portalProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'DCCA BREG - CustomerCommunityUser'
            LIMIT 1
        ];
        List<PermissionSet> permSets = [SELECT Id FROM PermissionSet WHERE Name = 'BREG_Portal_User' LIMIT 1];

        // User and PermissionSetAssignment are setup objects; Account/Contact are not.
        // Mixing their DML in the same transaction causes a Mixed DML error.
        // System.runAs() creates a separate DML context for setup object inserts.
        User communityUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String usernameStamp = String.valueOf(DateTime.now().getTime());
            communityUser = new User(
                LastName = 'BREGTestUser',
                Alias = 'bregtest',
                Email = 'bregtest.' + usernameStamp + '@example.com',
                Username = 'bregtest.' + usernameStamp + '@example.com.test',
                CommunityNickname = 'bregtest' + usernameStamp,
                ProfileId = portalProfiles[0].Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ContactId = contactRecord.Id
            );
            insert communityUser;

            if (!permSets.isEmpty()) {
                insert new PermissionSetAssignment(PermissionSetId = permSets[0].Id, AssigneeId = communityUser.Id);
            }
        }

        return communityUser;
    }

    public static void createTestInternalUser() {
        Profile internalProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String usernameStamp = String.valueOf(DateTime.now().getTime());
        User internalUser = new User(
            LastName = 'BREG Internal Test User',
            Alias = 'bregint',
            Email = 'bregint.' + usernameStamp + '@example.com',
            Username = 'bregint.' + usernameStamp + '@example.com.test',
            CommunityNickname = 'bregint' + usernameStamp,
            ProfileId = internalProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert internalUser;

            List<PermissionSet> permSets = [SELECT Id FROM PermissionSet WHERE Name = 'BREG_Standard_User' OR Name = 'BREG_Supervisor_User'];
            if (!permSets.isEmpty()) {
                insert new List<PermissionSetAssignment> {
                    new PermissionSetAssignment(PermissionSetId = permSets[0].Id, AssigneeId = internalUser.Id),
                    new PermissionSetAssignment(PermissionSetId = permSets[1].Id, AssigneeId = internalUser.Id)
                };
            }
        }
    }

    public static User getTestCommunityUser() {
        return [SELECT Id FROM User WHERE Alias = 'bregtest' AND Profile.Name = 'DCCA BREG - CustomerCommunityUser' LIMIT 1];
    }

    public static User getTestInternalUser() {
        return [SELECT Id FROM User WHERE Alias = 'bregint' AND Profile.Name = 'Standard User' LIMIT 1];
    }
}