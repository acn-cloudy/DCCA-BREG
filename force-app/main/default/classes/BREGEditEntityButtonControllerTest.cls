@IsTest
private class BREGEditEntityButtonControllerTest {

    private static Account buildAccount(String nameValue) {
        Account acc = new Account(
            Name = nameValue,
            breg_Entity_Type__c = 'D1'
        );

        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND DeveloperName = 'BREG_Account'
            LIMIT 1
        ];
        if (!rts.isEmpty()) {
            acc.RecordTypeId = rts[0].Id;
        }

        return acc;
    }

    private static Case buildCase(Id accountId, String statusValue, String formCode) {
        return new Case(
            Subject = 'BREG Test',
            Status = statusValue,
            Origin = 'Web',
            AccountId = accountId,
            breg_Entity__c = accountId,
            breg_Form_Code__c = formCode
        );
    }

    private static User createUserWithoutBypassPermissions() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String uniqueValue = String.valueOf(System.currentTimeMillis());

        return new User(
            FirstName = 'Test',
            LastName = 'NoBypass',
            Alias = 'tnbp',
            Email = 'test.nobypass' + uniqueValue + '@test.com',
            Username = 'test.nobypass' + uniqueValue + '@test.com',
            CommunityNickname = 'tnbp' + uniqueValue,
            ProfileId = p.Id,
            TimeZoneSidKey = 'Pacific/Honolulu',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    @IsTest
    static void testInit_nullAccountId() {
        Test.startTest();
        BREGEditEntityButtonController.InitResponse res =
            BREGEditEntityButtonController.findEditableFields(null);
        Test.stopTest();

        System.assertEquals(false, res.allowed);
        System.assertEquals('Account Id is required.', res.message);
        System.assertNotEquals(null, res.editableFields);
        System.assertEquals(0, res.editableFields.size());
    }

    @IsTest
    static void testValidateBeforeSave_nullAccountId() {
        Test.startTest();
        try {
            BREGEditEntityButtonController.validateBeforeSave(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testInit_notAllowed() {
        User testUser = createUserWithoutBypassPermissions();
        insert testUser;

        System.runAs(testUser) {
            Account denied = buildAccount('Denied');
            insert denied;

            insert buildCase(denied.Id, 'Draft', 'X-3');

            Test.startTest();
            BREGEditEntityButtonController.InitResponse res =
                BREGEditEntityButtonController.findEditableFields(denied.Id);
            Test.stopTest();

            System.assertEquals(false, res.allowed);
            System.assertEquals(
                'Edit Entity is available only when Account has an approved case with Form Code = X-3.',
                res.message
            );
        }
    }

    @IsTest
    static void testValidateBeforeSave_notAllowed() {
        User testUser = createUserWithoutBypassPermissions();
        insert testUser;

        System.runAs(testUser) {
            Account denied = buildAccount('Denied Validate');
            insert denied;

            insert buildCase(denied.Id, 'Draft', 'X-3');

            Test.startTest();
            try {
                BREGEditEntityButtonController.validateBeforeSave(denied.Id);
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testInit_allowedAndValidatePasses() {
        Account allowed = buildAccount('Allowed');
        insert allowed;

        Case allowedCase = buildCase(allowed.Id, 'New', 'X-3');
        insert allowedCase;

        allowedCase = [
            SELECT Id, Status, breg_Entity__c, breg_Form_Code__c
            FROM Case
            WHERE Id = :allowedCase.Id
        ];

        allowedCase.Status = 'Approved';
        allowedCase.breg_Entity__c = allowed.Id;
        allowedCase.breg_Form_Code__c = 'X-3';
        update allowedCase;

        System.assertEquals(1, [
            SELECT COUNT()
            FROM Case
            WHERE breg_Entity__c = :allowed.Id
              AND Status = 'Approved'
              AND breg_Form_Code__c = 'X-3'
        ]);

        Test.startTest();
        BREGEditEntityButtonController.InitResponse res =
            BREGEditEntityButtonController.findEditableFields(allowed.Id);
        BREGEditEntityButtonController.validateBeforeSave(allowed.Id);
        Test.stopTest();

        System.assertEquals(true, res.allowed);
        System.assertEquals(null, res.message);
        System.assertNotEquals(null, res.editableFields);
    }
}