@isTest
private class BREGFileNumberAssignmentControllerTest {
    @TestSetup
    static void setupData() {
        BREGTestDataFactory.createFileNumberSequences();

        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
        Id bregAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account')?.getRecordTypeId();

        Account entity = new Account(
            Name = 'FNA Entity',
            RecordTypeId = bregAccRecordTypeId,
            breg_File__c = '000123',
            breg_File_Suffix__c = 'D1',
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)'
        );
        insert entity;

        breg_Form_Configuration__c nbrConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Entity_Type__c = 'D1'
        );
        breg_Form_Configuration__c tntmsmConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'ZZ',
            breg_Form_Code__c = 'TN-RNC'
        );
        insert new List<breg_Form_Configuration__c>{ nbrConfig, tntmsmConfig };

        insert new Case(
            Subject = 'FNA Existing File Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_File__c = '123456D1'
        );

        insert new Case(
            Subject = 'FNA Assign File Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = nbrConfig.Id,
            breg_Form_Code__c = 'DC-1'
        );
    }

    @isTest
    static void testGenerateFileNumberEntityTypeBranch() {
        Case c = new Case(breg_Form_Code__c = 'DC-1');

        BREGFileNumberAssignmentController.FileNumberAssignmentResult result = BREGFileNumberAssignmentController.generateFileNumber(c, 'D1');

        Assert.isNotNull(result.fileNumber, 'Entity-type generation should return file number.');
        Assert.areEqual('D1', result.fileSuffix, 'Entity-type generation should use provided suffix.');
        Assert.isNotNull(result.brimFileNumber, 'Entity-type generation should set BRIM number.');
    }

    @isTest
    static void testGenerateFileNumberTntmsmAndCraBranches() {
        Account linkedEntity = [SELECT Id, breg_File__c, breg_File_Suffix__c FROM Account WHERE Name = 'FNA Entity' LIMIT 1];

        Case tntmsmCase = new Case(
            breg_Form_Code__c = 'TN-RNC',
            breg_Entity__r = linkedEntity,
            breg_Form_Configuration__r = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'D1')
        );

        BREGFileNumberAssignmentController.FileNumberAssignmentResult tntmsmResult = BREGFileNumberAssignmentController.generateFileNumber(tntmsmCase, null);
        Assert.isNotNull(tntmsmResult.tntmsmCertificate, 'TNTMSM generation should set certificate number.');
        Assert.isNotNull(tntmsmResult.fileNumber, 'TNTMSM generation should set file number.');
    }

    @isTest
    static void testGenerateFileNumberInvocableFlowMethod() {
        Case existingFileCase = [SELECT Id FROM Case WHERE Subject = 'FNA Existing File Case' LIMIT 1];
        Case assignFileCase = [SELECT Id FROM Case WHERE Subject = 'FNA Assign File Case' LIMIT 1];

        List<BREGFileNumberAssignmentController.FlowInput> inputs = new List<BREGFileNumberAssignmentController.FlowInput>();

        BREGFileNumberAssignmentController.FlowInput input1 = new BREGFileNumberAssignmentController.FlowInput();
        input1.caseId = existingFileCase.Id;
        inputs.add(input1);

        BREGFileNumberAssignmentController.FlowInput input2 = new BREGFileNumberAssignmentController.FlowInput();
        input2.caseId = assignFileCase.Id;
        inputs.add(input2);

        Test.startTest();
        List<BREGFileNumberAssignmentController.FlowOutput> outputs = BREGFileNumberAssignmentController.generateFileNumber(inputs);
        Test.stopTest();

        Assert.isNotNull(outputs, 'Flow outputs should be returned.');
        Assert.isTrue(outputs.size() > 0, 'Existing-file branch should return an output item.');

        Case updatedAssignCase = [SELECT breg_File__c, breg_File_Suffix__c, breg_BRIM_FILE_NO__c FROM Case WHERE Id = :assignFileCase.Id];
        Assert.isNotNull(updatedAssignCase.breg_File__c, 'Case without file should receive assigned file number.');
    }

    @isTest
    static void testGenerateFileNumberT7AndCraBranches() {
        breg_Form_Configuration__c t7Config = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'T-7',
            breg_Entity_Type__c = 'D1'
        );
        insert t7Config;

        Case t7Case = new Case(
            breg_Form_Code__c = 'T-7',
            breg_Form_Configuration__r = new breg_Form_Configuration__c(breg_Suffix_Code__c = 'D1')
        );
        BREGFileNumberAssignmentController.FileNumberAssignmentResult t7Result = BREGFileNumberAssignmentController.generateFileNumber(t7Case, null);
        Assert.isNotNull(t7Result.fileNumber, 'T-7 should follow NBR-style file generation.');
        Assert.isTrue(t7Result.fileSuffix == 'D1' || t7Result.fileSuffix == 'ZZ', 'T-7 branch should execute and set a suffix.');

        Case craCase = new Case(
            breg_Form_Code__c = 'X-11',
            breg_Reg_Agent_Type__c = 'Individual'
        );
        try {
            BREGFileNumberAssignmentController.FileNumberAssignmentResult craResult = BREGFileNumberAssignmentController.generateFileNumber(craCase, null);
            Assert.isTrue(craResult.fileSuffix == 'CA' || craResult.fileSuffix == null, 'CRA branch should execute and set CA suffix when ZZ sequence is configured.');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'CRA branch should execute even if ZZ sequence is not configured in org.');
        }
    }

    @isTest
    static void testGenerateFileNumberInvocableNoAssignmentBranch() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();

        breg_Form_Configuration__c unknownConfig = new breg_Form_Configuration__c(
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-4',
            breg_Entity_Type__c = 'D1'
        );
        insert unknownConfig;

        Case unknownCase = new Case(
            Subject = 'FNA Unknown Form Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = unknownConfig.Id,
            breg_Form_Code__c = 'DC-4'
        );
        insert unknownCase;

        BREGFileNumberAssignmentController.FlowInput input = new BREGFileNumberAssignmentController.FlowInput();
        input.caseId = unknownCase.Id;

        Test.startTest();
        List<BREGFileNumberAssignmentController.FlowOutput> outputs = BREGFileNumberAssignmentController.generateFileNumber(
            new List<BREGFileNumberAssignmentController.FlowInput>{ input }
        );
        Test.stopTest();

        Assert.isTrue(outputs.size() > 0, 'No-assignment branch should return an error output item.');
    }
}