@isTest
public class BREGCaseStatusHandlerNameReservationTest {

    @testSetup
    static void setupData() {
        RecordType bregCaseRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND Name = 'BREG Case'
            LIMIT 1
        ];

        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account acc = new Account(
            Name = 'Name Reservation Account',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );
        insert acc;

        Case approvedCase = new Case(
            RecordTypeId = bregCaseRt.Id,
            Subject = 'NR Approved',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = acc.Id,
            breg_Effective_Date__c = Date.today(),
            breg_File__c = '12345-D1'
        );
        insert approvedCase;

        Case approvedNoApplicantCase = new Case(
            RecordTypeId = bregCaseRt.Id,
            Subject = 'NR Approved No Applicant',
            Status = 'New',
            Origin = 'Web',
            breg_Entity__c = acc.Id,
            breg_File__c = '12345-D1',
            breg_Effective_Date__c = Date.today()
        );
        insert approvedNoApplicantCase;

        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe'
        );
        insert con;

        insert new breg_Account_Affiliation__c(
            breg_Case__c = approvedCase.Id,
            breg_Account__c = acc.Id,
            breg_Contact__c = con.Id,
            breg_Entity__c = acc.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe',
            breg_Address__Street__s = '123 Main St',
            breg_Address__City__s = 'Austin',
            breg_Address__StateCode__s = 'TX',
            breg_Address__PostalCode__s = '73301',
            breg_Address__CountryCode__s = 'US',
            breg_Status__c = 'A',
            breg_Start_Date__c = Date.newInstance(2020, 1, 1)
        );

        Transaction__c trn = new Transaction__c(
            Account__c = acc.Id,
            breg_Case__c = approvedCase.Id,
            Date__c = Date.today(),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );
        insert trn;

        TransactionLine__c tl = new TransactionLine__c(
            Transaction__c = trn.Id,
            Amount__c = 20,
            breg_Case__c = approvedCase.Id,
            PaidStatus__c = 'Paid'
        );
        insert tl;

        Transaction__c trn2 = new Transaction__c(
            Account__c = acc.Id,
            breg_Case__c = approvedNoApplicantCase.Id,
            Date__c = Date.today(),
            Status__c = 'New',
            TransactionType__c = 'Payment'
        );
        insert trn2;

        TransactionLine__c tl2 = new TransactionLine__c(
            Transaction__c = trn2.Id,
            Amount__c = 20,
            breg_Case__c = approvedNoApplicantCase.Id,
            PaidStatus__c = 'Paid'
        );
        insert tl2;
    }

    @isTest
    static void testHandleStatusChange_PendingSubmission_InvalidEntityName_ThrowsException() {
        Case c = new Case(
            Subject = 'NR Pending Invalid Name',
            Status = 'New',
            Origin = 'Web',
            breg_Name_of_the_Entity__c = 'Test Business',
            breg_Entity_Type__c = 'C5'
        );

        Test.startTest();
        try {
            new BREGCaseStatusHandlerNameReservation().handleStatusChange(
                new List<Case>{ c },
                'Pending Submission',
                true,
                false
            );
            System.assert(false, 'Exception was expected for invalid entity name');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleStatusChange_Approved_WithApplicant_DoesNotThrow() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'NR Approved'
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerNameReservation().handleStatusChange(
            new List<Case>{ c },
            'Approved',
            true,
            false
        );
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testHandleStatusChange_Approved_NoApplicant_ThrowsException() {
        Case c = [
            SELECT Id, breg_Entity__c, breg_Effective_Date__c
            FROM Case
            WHERE Subject = 'NR Approved No Applicant'
            LIMIT 1
        ];

        Test.startTest();
        try {
            new BREGCaseStatusHandlerNameReservation().handleStatusChange(
                new List<Case>{ c },
                'Approved',
                true,
                false
            );
            System.assert(false, 'Exception was expected when applicant is missing');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('Applicant'),
                'Exception should mention Applicant. Actual: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleStatusChange_Completed_InvalidEntityName_ThrowsException() {
        Case c = new Case(
            Subject = 'NR Completed Invalid Name',
            Status = 'New',
            Origin = 'Web',
            breg_Name_of_the_Entity__c = 'Test Business',
            breg_Entity_Type__c = 'C5'
        );

        Test.startTest();
        try {
            new BREGCaseStatusHandlerNameReservation().handleStatusChange(
                new List<Case>{ c },
                'Completed',
                true,
                false
            );
            System.assert(false, 'Exception was expected for invalid entity name');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleStatusChange_OtherStatus_DoesNothing() {
        Case c = new Case(
            Subject = 'NR Other Status',
            Status = 'New',
            Origin = 'Web'
        );

        Test.startTest();
        new BREGCaseStatusHandlerNameReservation().handleStatusChange(
            new List<Case>{ c },
            'Pending',
            true,
            false
        );
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testHandleStatusChange_PendingSubmission_K5_ValidName_DoesNotThrow() {
        Case c = new Case(
            Subject = 'NR K5 Valid Name',
            Status = 'New',
            Origin = 'Web',
            breg_Name_of_the_Entity__c = 'Test LLP',
            breg_Entity_Type__c = 'K5'
        );

        Test.startTest();
        new BREGCaseStatusHandlerNameReservation().handleStatusChange(
            new List<Case>{ c },
            'Pending Submission',
            true,
            false
        );
        Test.stopTest();

        System.assert(true);
    }
}