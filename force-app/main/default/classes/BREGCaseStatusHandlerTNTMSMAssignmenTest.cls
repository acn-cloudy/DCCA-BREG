@isTest
public class BREGCaseStatusHandlerTNTMSMAssignmenTest {

    @testSetup
    static void setupData() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName()
            .get('BREG Case')
            .getRecordTypeId();

        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        breg_Form_Configuration__c testFormConfig = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'T-4', breg_Form_Code__c = 'T-4');
        insert testFormConfig;

        Account oldAccount = new Account(
            Name = 'Old Owner Account',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );
        insert oldAccount;

        Account existingAssigneeAccount = new Account(
            Name = 'Existing Assignee Account',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ',
            breg_File__c = '1234567',
            breg_File_Suffix__c = 'AB'
        );
        insert existingAssigneeAccount;

        breg_TN_TM_SM__c tnTmSmExistingEntity = new breg_TN_TM_SM__c(
            breg_Account__c = oldAccount.Id
        );
        insert tnTmSmExistingEntity;

        breg_TN_TM_SM__c tnTmSmFromAffiliation = new breg_TN_TM_SM__c(
            breg_Account__c = oldAccount.Id
        );
        insert tnTmSmFromAffiliation;

        Case caseWithEntity = new Case(
            RecordTypeId = bregCaseRecordTypeId,
            Subject = 'Assignment - Existing Entity',
            Status = 'New',
            Origin = 'Web',
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_Form_Code__c = 'T-4',
            breg_TN_TM_SM__c = tnTmSmExistingEntity.Id,
            breg_Entity__c = existingAssigneeAccount.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert caseWithEntity;

        Case caseWithoutEntity = new Case(
            RecordTypeId = bregCaseRecordTypeId,
            Subject = 'Assignment - Create Entity',
            Status = 'Received',
            Origin = 'Web',
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_Form_Code__c = 'T-4',
            breg_TN_TM_SM__c = tnTmSmFromAffiliation.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert caseWithoutEntity;

        breg_Account_Affiliation__c accAff = new breg_Account_Affiliation__c(
            breg_Case__c = caseWithoutEntity.Id,
            breg_Role__c = 'Assignee',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'New Assignee Entity',
            breg_Entity_Type_Description__c = 'Test Entity Type',
            breg_Entity_Location__c = 'CA',
            breg_File__c = '7654321',
            breg_Address__CountryCode__s = 'US',
            breg_Address__Street__s = '100 Main St',
            breg_Address_Street_2__c = 'Suite 200',
            breg_Address__City__s = 'Los Angeles',
            breg_Address__StateCode__s = 'CA',
            breg_Address__PostalCode__s = '90001'
        );
        insert accAff;

        insert new breg_Account_Affiliation__c(
            breg_Case__c = caseWithoutEntity.Id,
            breg_Role__c = 'Assignor',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Existing',
            breg_Last_Name__c = 'Owner'
        );

        insert new breg_Account_Affiliation__c(
            breg_TN_TM_SM__c = tnTmSmFromAffiliation.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Current',
            breg_Last_Name__c = 'Applicant',
            breg_Status__c = 'A'
        );

        Case approvalCase = new Case(
            RecordTypeId = bregCaseRecordTypeId,
            Subject = 'Assignment - No Existing Applicant',
            Status = 'New',
            Origin = 'Web',
            breg_Form_Code__c = 'T-4',
            breg_Form_Configuration__c = testFormConfig.Id,
            breg_TN_TM_SM__c = tnTmSmExistingEntity.Id,
            breg_TNTMSM_Certificate__c = 'CERT-100',
            breg_TNTMSM_Type__c = 'Trademark',
            breg_Effective_Date__c = Date.today()
        );
        insert approvalCase;

        insert new breg_Account_Affiliation__c(
            breg_Case__c = approvalCase.Id,
            breg_Role__c = 'Assignee',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Only New Applicant Entity',
            breg_Entity_Type_Description__c = 'Test Entity Type',
            breg_Entity_Location__c = 'CA',
            breg_File__c = '5550001',
            breg_Address__CountryCode__s = 'US',
            breg_Address__Street__s = '200 Main St',
            breg_Address__City__s = 'Sacramento',
            breg_Address__StateCode__s = 'CA',
            breg_Address__PostalCode__s = '95814'
        );

        insert new breg_Account_Affiliation__c(
            breg_Case__c = approvalCase.Id,
            breg_Role__c = 'Assignor',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Approval',
            breg_Last_Name__c = 'Assignor'
        );
    }

    @isTest
    static void testHandleStatusChange_Approved_WithExistingEntity() {
        Case c = [
            SELECT Id, breg_TN_TM_SM__c, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_File__c, breg_File_Suffix__c
            FROM Case
            WHERE Subject = 'Assignment - Existing Entity'
            LIMIT 1
        ];

        Id newEntityId = c.breg_Entity__c;

        Test.startTest();
        new BREGCaseStatusHandlerTNTMSMAssignment().handleStatusChange(
            new List<Case>{ c },
            'Approved',
            false,
            true
        );
        Test.stopTest();

        breg_TN_TM_SM__c updatedTnTmSm = [
            SELECT Id, breg_Account__c, breg_File__c, breg_File_Suffix__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :c.breg_TN_TM_SM__c
        ];

        Account newEntity = [
            SELECT Id, breg_File__c, breg_File_Suffix__c
            FROM Account
            WHERE Id = :newEntityId
        ];

        System.assertEquals(newEntityId, updatedTnTmSm.breg_Account__c);
        System.assertEquals(newEntity.breg_File__c, updatedTnTmSm.breg_File__c);
        System.assertEquals(newEntity.breg_File_Suffix__c, updatedTnTmSm.breg_File_Suffix__c);
    }

    @isTest
    static void testHandleStatusChange_Received_ChangesApplicantToAssignor() {
        Case c = [
            SELECT Id, breg_Form_Code__c
            FROM Case
            WHERE Subject = 'Assignment - Create Entity'
            LIMIT 1
        ];

        breg_Account_Affiliation__c applicantAffiliation = new breg_Account_Affiliation__c(
            breg_Case__c = c.Id,
            breg_Role__c = 'Applicant',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Portal',
            breg_Last_Name__c = 'Applicant'
        );
        insert applicantAffiliation;

        Test.startTest();
        new BREGCaseStatusHandlerTNTMSMAssignment().handleStatusChange(
            new List<Case>{ c },
            'Received',
            false,
            true
        );
        Test.stopTest();

        applicantAffiliation = [
            SELECT Id, breg_Role__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :applicantAffiliation.Id
        ];

        breg_Account_Affiliation__c assigneeAffiliation = [
            SELECT Id, breg_Role__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :c.Id AND breg_Role__c = 'Assignee'
            LIMIT 1
        ];

        System.assertEquals('Assignor', applicantAffiliation.breg_Role__c);
        System.assertEquals('Assignee', assigneeAffiliation.breg_Role__c);
    }

    @isTest
    static void testHandleStatusChange_Approved_WithAffiliationCreatesAccount() {
        Case cBefore = [
            SELECT Id, breg_TN_TM_SM__c, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_File__c, breg_File_Suffix__c
            FROM Case
            WHERE Subject = 'Assignment - Create Entity'
            LIMIT 1
        ];

        System.assertEquals(null, cBefore.breg_Entity__c);

        Test.startTest();
        new BREGCaseStatusHandlerTNTMSMAssignment().handleStatusChange(
            new List<Case>{ cBefore },
            'Approved',
            false,
            true
        );
        Test.stopTest();

        Case cAfter = [
            SELECT Id, breg_Entity__c, breg_TN_TM_SM__c
            FROM Case
            WHERE Id = :cBefore.Id
        ];

        System.assertNotEquals(null, cAfter.breg_Entity__c);

        Account createdAccount = [
            SELECT Id, Name, breg_Registrant_Type__c, breg_Entity_Type__c,
                   breg_Entity_Type_Description__c, breg_Formation_State__c,
                   breg_File__c, breg_File_Suffix__c, BillingCountryCode,
                   BillingStreet, BillingCity, BillingStateCode, BillingPostalCode,
                   breg_Billing_Address_Street_2__c, breg_Start_Date__c
            FROM Account
            WHERE Id = :cAfter.breg_Entity__c
        ];

        breg_TN_TM_SM__c updatedTnTmSm = [
            SELECT Id, breg_Account__c, breg_File__c, breg_File_Suffix__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :cAfter.breg_TN_TM_SM__c
        ];

        breg_Account_Affiliation__c updatedApplicantAffiliation = [
            SELECT Id, breg_Role__c, breg_TN_TM_SM__c, breg_Account__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :cAfter.Id AND breg_Entity_Name__c = 'New Assignee Entity'
            LIMIT 1
        ];

        breg_Account_Affiliation__c skippedAssignorAffiliation = [
            SELECT Id, breg_Role__c, breg_TN_TM_SM__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :cAfter.Id AND breg_Role__c = 'Assignor'
            LIMIT 1
        ];

        breg_Account_Affiliation__c oldApplicantAffiliation = [
            SELECT Id, breg_Status__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_TN_TM_SM__c = :cAfter.breg_TN_TM_SM__c AND breg_Case__c = NULL AND breg_Role__c = 'Applicant'
            LIMIT 1
        ];

        System.assertEquals('New Assignee Entity', createdAccount.Name);
        System.assertEquals('Entity', createdAccount.breg_Registrant_Type__c);
        System.assertEquals('ZZ', createdAccount.breg_Entity_Type__c);
        System.assertEquals('Test Entity Type', createdAccount.breg_Entity_Type_Description__c);
        System.assertEquals('CA', createdAccount.breg_Formation_State__c);
        // System.assertEquals('7654321', createdAccount.breg_File__c);
        // System.assertEquals('ZZ', createdAccount.breg_File_Suffix__c);
        System.assertEquals('US', createdAccount.BillingCountryCode);
        System.assertEquals('100 Main St', createdAccount.BillingStreet);
        System.assertEquals('Los Angeles', createdAccount.BillingCity);
        System.assertEquals('CA', createdAccount.BillingStateCode);
        System.assertEquals('90001', createdAccount.BillingPostalCode);
        System.assertEquals('Suite 200', createdAccount.breg_Billing_Address_Street_2__c);

        System.assertEquals(createdAccount.Id, updatedTnTmSm.breg_Account__c);
        System.assertEquals(createdAccount.breg_File__c, updatedTnTmSm.breg_File__c);
        System.assertEquals(createdAccount.breg_File_Suffix__c, updatedTnTmSm.breg_File_Suffix__c);
        System.assertEquals('Applicant', updatedApplicantAffiliation.breg_Role__c);
        System.assertEquals(cAfter.breg_TN_TM_SM__c, updatedApplicantAffiliation.breg_TN_TM_SM__c);
        System.assertNotEquals(updatedApplicantAffiliation.breg_Account__c, null);
        System.assertEquals('Assignor', skippedAssignorAffiliation.breg_Role__c);
        System.assertEquals(null, skippedAssignorAffiliation.breg_TN_TM_SM__c);
        System.assertEquals('I', oldApplicantAffiliation.breg_Status__c);
        System.assertEquals(cBefore.breg_Effective_Date__c, oldApplicantAffiliation.breg_End_Date__c);
    }

    @isTest
    static void testHandleStatusChange_Approved_RequiresAffiliationsToHaveAccountOrContact() {
        Case approvalCase = [
            SELECT
                Id,
                breg_TN_TM_SM__c,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Override_Payment__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Due_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_TNTMSM_Certificate__c,
                breg_TNTMSM_Type__c
            FROM Case
            WHERE Subject = 'Assignment - No Existing Applicant'
            LIMIT 1
        ];
        approvalCase.breg_Override_Payment__c = true;
        approvalCase.breg_Last_Rejection_Date__c = null;
        approvalCase.breg_Resubmission_Due_Date__c = null;
        approvalCase.breg_Resubmission_Received_Date__c = null;
        approvalCase.breg_TNTMSM_Certificate__c = 'CERT-100';
        approvalCase.breg_TNTMSM_Type__c = 'Trademark';

        BREGCaseStatusHandlerTNTMSMAssignment handler = new BREGCaseStatusHandlerTNTMSMAssignment();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ approvalCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Approval validation should fail when an affiliation has neither Account nor Contact populated.');
        System.assert(
            exceptionMessage.contains(BREGCaseStatusHandlerTNTMSMAssignment.ERROR_ASSIGNOR_ACCOUNT_OR_CONTACT_REQUIRED),
            'Validation message should explain that Assignor affiliation must have an Account or Contact lookup.'
        );
    }

    @isTest
    static void testHandleStatusChange_Approved_RequiresTNTMSMCertificate() {
        Case approvalCase = [
            SELECT
                Id,
                breg_TN_TM_SM__c,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Override_Payment__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Due_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_TNTMSM_Certificate__c,
                breg_TNTMSM_Type__c
            FROM Case
            WHERE Subject = 'Assignment - No Existing Applicant'
            LIMIT 1
        ];
        approvalCase.breg_Override_Payment__c = true;
        approvalCase.breg_Last_Rejection_Date__c = null;
        approvalCase.breg_Resubmission_Due_Date__c = null;
        approvalCase.breg_Resubmission_Received_Date__c = null;
        approvalCase.breg_TNTMSM_Certificate__c = null;
        approvalCase.breg_TNTMSM_Type__c = 'Trademark';

        BREGCaseStatusHandlerTNTMSMAssignment handler = new BREGCaseStatusHandlerTNTMSMAssignment();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ approvalCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Approval validation should fail when the TN/TM/SM Certificate is missing.');
        System.assert(
            exceptionMessage.contains(BREGCaseStatusHandlerTNTMSMAssignment.ERROR_TNTMSM_CERTIFICATE_REQUIRED),
            'Validation message should explain that the TN/TM/SM Certificate field is required.'
        );
    }

    @isTest
    static void testHandleStatusChange_Approved_RequiresTNTMSMType() {
        Case approvalCase = [
            SELECT
                Id,
                breg_TN_TM_SM__c,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Override_Payment__c,
                breg_Last_Rejection_Date__c,
                breg_Resubmission_Due_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_TNTMSM_Certificate__c,
                breg_TNTMSM_Type__c
            FROM Case
            WHERE Subject = 'Assignment - No Existing Applicant'
            LIMIT 1
        ];
        approvalCase.breg_Override_Payment__c = true;
        approvalCase.breg_Last_Rejection_Date__c = null;
        approvalCase.breg_Resubmission_Due_Date__c = null;
        approvalCase.breg_Resubmission_Received_Date__c = null;
        approvalCase.breg_TNTMSM_Certificate__c = 'CERT-100';
        approvalCase.breg_TNTMSM_Type__c = null;

        BREGCaseStatusHandlerTNTMSMAssignment handler = new BREGCaseStatusHandlerTNTMSMAssignment();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ approvalCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Approval validation should fail when the TN/TM/SM Type is missing.');
        System.assert(
            exceptionMessage.contains(BREGCaseStatusHandlerTNTMSMAssignment.ERROR_TNTMSM_TYPE_REQUIRED),
            'Validation message should explain that the TN/TM/SM Type field is required.'
        );
    }

    @isTest
    static void testHandleStatusChange_NotApproved_DoesNothing() {
        Case c = [
            SELECT Id, breg_TN_TM_SM__c, breg_Entity__c, breg_Form_Code__c
            FROM Case
            WHERE Subject = 'Assignment - Existing Entity'
            LIMIT 1
        ];

        breg_TN_TM_SM__c beforeTnTmSm = [
            SELECT Id, breg_Account__c, breg_File__c, breg_File_Suffix__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :c.breg_TN_TM_SM__c
        ];

        Test.startTest();
        new BREGCaseStatusHandlerTNTMSMAssignment().handleStatusChange(
            new List<Case>{ c },
            'Pending',
            false,
            true
        );
        Test.stopTest();

        breg_TN_TM_SM__c afterTnTmSm = [
            SELECT Id, breg_Account__c, breg_File__c, breg_File_Suffix__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :c.breg_TN_TM_SM__c
        ];

        System.assertEquals(beforeTnTmSm.breg_Account__c, afterTnTmSm.breg_Account__c);
        System.assertEquals(beforeTnTmSm.breg_File__c, afterTnTmSm.breg_File__c);
        System.assertEquals(beforeTnTmSm.breg_File_Suffix__c, afterTnTmSm.breg_File_Suffix__c);
    }

    @isTest
    static void testHandleStatusChange_Approved_WithoutExistingApplicant_KeepsNewApplicantActive() {


        Case approvalCase = [
            SELECT Id, breg_TN_TM_SM__c, breg_Entity__c, breg_Effective_Date__c, breg_Form_Code__c, breg_File__c, breg_File_Suffix__c
            FROM Case
            WHERE Subject = 'Assignment - No Existing Applicant'
            LIMIT 1
        ];

        Test.startTest();
        new BREGCaseStatusHandlerTNTMSMAssignment().handleStatusChange(
            new List<Case>{ approvalCase },
            'Approved',
            false,
            true
        );
        Test.stopTest();

        breg_Account_Affiliation__c newApplicantAffiliation = [
            SELECT Id, breg_Role__c, breg_TN_TM_SM__c, breg_Status__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c = :approvalCase.Id AND breg_Entity_Name__c = 'Only New Applicant Entity'
            LIMIT 1
        ];

        Integer activeApplicantCount = [
            SELECT COUNT()
            FROM breg_Account_Affiliation__c
            WHERE breg_TN_TM_SM__c = :approvalCase.breg_TN_TM_SM__c AND breg_Role__c = 'Applicant' AND breg_End_Date__c = NULL
        ];

        System.assertEquals('Applicant', newApplicantAffiliation.breg_Role__c);
        System.assertEquals(approvalCase.breg_TN_TM_SM__c, newApplicantAffiliation.breg_TN_TM_SM__c);
        System.assertNotEquals('I', newApplicantAffiliation.breg_Status__c);
        System.assertEquals(null, newApplicantAffiliation.breg_End_Date__c);
        System.assertEquals(1, activeApplicantCount);
    }
}