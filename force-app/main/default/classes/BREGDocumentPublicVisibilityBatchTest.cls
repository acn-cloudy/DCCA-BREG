@isTest
public class BREGDocumentPublicVisibilityBatchTest {

    @isTest
    static void testBatchProcessesFutureAndPastDocuments() {
        Date today = Date.today();

        breg_Form_Configuration__c formConfigX13 = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'X-13'
        );

        breg_Form_Configuration__c formConfigX9 = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'X-9',
            breg_Form_Code__c = 'X-9'
        );

        insert new List<breg_Form_Configuration__c>{ formConfigX13, formConfigX9 };

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case futureCase = new Case(
            Status = 'New',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'X-13',
            breg_Form_Configuration__c = formConfigX13.Id,
            breg_Effective_Date__c = today.addDays(10),
            breg_Bypass_Validation__c = true
        );

        Case pastCase = new Case(
            Status = 'New',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'X-9',
            breg_Form_Configuration__c = formConfigX9.Id,
            breg_Effective_Date__c = today.addDays(-5),
            breg_Bypass_Validation__c = true
        );

        insert new List<Case>{ futureCase, pastCase };

        futureCase.Status = 'Completed';
        pastCase.Status = 'Completed';
        update new List<Case>{ futureCase, pastCase };

        breg_Document__c futureDoc = new breg_Document__c(
            Name = 'Future Document',
            breg_Case__c = futureCase.Id,
            breg_Is_Public__c = true
        );

        breg_Document__c pastDoc = new breg_Document__c(
            Name = 'Past Document',
            breg_Case__c = pastCase.Id,
            breg_Is_Public__c = false
        );

        insert new List<breg_Document__c>{ futureDoc, pastDoc };

        Test.startTest();
        Database.executeBatch(new BREGDocumentPublicVisibilityBatch(), 200);
        Test.stopTest();

        futureDoc = [SELECT Id, breg_Is_Public__c FROM breg_Document__c WHERE Id = :futureDoc.Id];
        pastDoc = [SELECT Id, breg_Is_Public__c FROM breg_Document__c WHERE Id = :pastDoc.Id];

        Assert.isFalse(futureDoc.breg_Is_Public__c, 'Future document should be set to not public');
        Assert.isTrue(pastDoc.breg_Is_Public__c, 'Past document should be set to public');
    }

    @isTest
    static void testBatchIgnoresNonMatchingCases() {
        Date today = Date.today();

        breg_Form_Configuration__c formConfigX1 = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'X-1',
            breg_Form_Code__c = 'X-1'
        );

        breg_Form_Configuration__c formConfigX13 = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'X-13'
        );

        insert new List<breg_Form_Configuration__c>{ formConfigX1, formConfigX13 };

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case wrongFormCodeCase = new Case(
            Status = 'New',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'X-1',
            breg_Form_Configuration__c = formConfigX1.Id,
            breg_Effective_Date__c = today.addDays(10),
            breg_Bypass_Validation__c = true
        );

        Case wrongStatusCase = new Case(
            Status = 'New',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Code__c = 'X-13',
            breg_Form_Configuration__c = formConfigX13.Id,
            breg_Effective_Date__c = today.addDays(10),
            breg_Bypass_Validation__c = true
        );

        insert new List<Case>{ wrongFormCodeCase, wrongStatusCase };

        wrongFormCodeCase.Status = 'Completed';
        update wrongFormCodeCase;

        breg_Document__c doc1 = new breg_Document__c(
            Name = 'Wrong Form Code Doc',
            breg_Case__c = wrongFormCodeCase.Id,
            breg_Is_Public__c = true
        );

        breg_Document__c doc2 = new breg_Document__c(
            Name = 'Wrong Status Doc',
            breg_Case__c = wrongStatusCase.Id,
            breg_Is_Public__c = true
        );

        insert new List<breg_Document__c>{ doc1, doc2 };

        Test.startTest();
        Database.executeBatch(new BREGDocumentPublicVisibilityBatch(), 200);
        Test.stopTest();

        doc1 = [SELECT Id, breg_Is_Public__c FROM breg_Document__c WHERE Id = :doc1.Id];
        doc2 = [SELECT Id, breg_Is_Public__c FROM breg_Document__c WHERE Id = :doc2.Id];

        Assert.isTrue(doc1.breg_Is_Public__c, 'Document with wrong form code should not be updated');
        Assert.isTrue(doc2.breg_Is_Public__c, 'Document with wrong status should not be updated');
    }
}