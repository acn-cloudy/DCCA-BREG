@isTest
private class LicenseNumberAssignmentDomainTest {
    private static testMethod void testGetLicenseNumberAssignmentsByBoardProgram() {
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        insert licenseTypeRecord;

        BoardProgram__c boardProgram = new BoardProgram__c();
        boardProgram.Type__c = 'Program';
        boardProgram.Name = 'Test';
        insert boardProgram;

        LicenseNumberAssignments__c assignment = new LicenseNumberAssignments__c();
        assignment.BoardProgram__c = boardProgram.Id;
        assignment.LicenseType__c = licenseTypeRecord.Id;
        assignment.LicenseNumber__c = 33939932;
        insert assignment;

        List<LicenseNumberAssignments__c> records = [Select Id, Name,  BoardProgram__c, LicenseNumber__c, 
        LicensePrefix__c, LicenseType__c, LicenseType__r.LicensePrefix__c from LicenseNumberAssignments__c];
        (new LicenseNumberAssignmentDomain(records)).getLicenseNumberAssignmentByBoardProgram(boardProgram.Id);
        (new LicenseNumberAssignmentDomain(records)).getLicenseNumberAssignmentByLicenseType(licenseTypeRecord.Id);
        (new LicenseNumberAssignmentDomain(records)).getLicenseTypePrefix();
        (new LicenseNumberAssignmentDomain(records)).getLicenseTypePrefixMap();

    }
}