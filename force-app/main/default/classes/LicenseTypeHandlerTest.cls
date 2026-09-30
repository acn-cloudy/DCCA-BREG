@isTest
private class LicenseTypeHandlerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        
        // Create DocGeneratorSettings for DeficiencyNotification tests
        DocGeneratorSettings__c docSetting1 = new DocGeneratorSettings__c();
        docSetting1.Name = 'Deficiency Letter Template 1';
        docSetting1.DocumentType__c = 'Word';
        insert docSetting1;
        
        DocGeneratorSettings__c docSetting2 = new DocGeneratorSettings__c();
        docSetting2.Name = 'Deficiency Letter Template 2';
        docSetting2.DocumentType__c = 'Word';
        insert docSetting2;
    }
    
    @isTest
    static void handlerTest() {
        List<LicenseType__c> licenseTypes = [Select Id, ResetAudit__c, GenerateRenewalNotice__c, PostcardContent__c, SendRenewalEmailforallLicenses__c, FlagLicenseandRenewNotifications__c, StarttheRenewalCycle__c, ResetLicenseType__c, RunBatchUpdateToLicense__c, 
            GenerateRenewalPostcards__c,BatchUpdateField__c, BatchUpdateValue__c from LicenseType__c];

        for(LicenseType__c licenseType: licenseTypes) {
            licenseType.BatchConditionField__c = 'FlaggedforAudit__c';
            licenseType.BatchUpdateField__c = 'Status__c';
            licenseType.BatchUpdateValue__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            licenseType.ResetAudit__c = true;
            licenseType.StarttheRenewalCycle__c = true;
            licenseType.GenerateRenewalPostcards__c = true;
            licenseType.RunBatchUpdateToLicense__c = true;
            licenseType.ResetLicenseType__c = true;
            licenseType.FlagLicenseandRenewNotifications__c = true;
            licenseType.AuditStatuses__c = 'C - Current, Valid & In Good Standing';
            licenseType.AuditActiveInactive__c = 'Active';
            licenseType.SendRenewalEmailforallLicenses__c = true;
            licenseType.GenerateRenewalNotice__c = true;
            licenseType.SelectRenewalPostcard__c = 'Renewal Postcard';
        }

        update licenseTypes;
        LicenseTypeHandler handler = new licenseTypeHandler();
        handler.beforeDelete(licenseTypes.get(0));
        handler.afterDelete(licenseTypes.get(0));
        handler.beforeUnDelete(licenseTypes.get(0));
        handler.afterUnDelete(licenseTypes.get(0));
    }
    
    /**
     * Test: Insert LicenseType with DeficiencyNotification set
     * Scenario: When inserting a LicenseType with DeficiencyNotification__c populated,
     * SpringCM_Deficiency_Letter__c should be set to the DocGeneratorSettings Name
     */
    @isTest
    static void testInsertWithDeficiencyNotification() {
        // Get the DocGeneratorSettings created in TestSetup
        DocGeneratorSettings__c docSetting = [SELECT Id, Name FROM DocGeneratorSettings__c WHERE Name = 'Deficiency Letter Template 1' LIMIT 1];
        
        // Create a new LicenseType with DeficiencyNotification set
        LicenseType__c newLicenseType = new LicenseType__c();
        newLicenseType.Name = 'Test LT With Deficiency';
        newLicenseType.DeficiencyNotification__c = docSetting.Id;
        newLicenseType.Status__c = 'Active';
        
        Test.startTest();
        insert newLicenseType;
        Test.stopTest();
        
        // Verify that SpringCM_Deficiency_Letter__c was populated with DocGeneratorSettings Name
        LicenseType__c insertedLT = [SELECT Id, SpringCM_Deficiency_Letter__c, DeficiencyNotification__c 
                                      FROM LicenseType__c WHERE Id = :newLicenseType.Id];
        System.assertEquals(docSetting.Name, insertedLT.SpringCM_Deficiency_Letter__c, 
            'SpringCM_Deficiency_Letter__c should be set to DocGeneratorSettings Name on insert');
    }
    
    /**
     * Test: Insert LicenseType without DeficiencyNotification
     * Scenario: When inserting a LicenseType without DeficiencyNotification__c,
     * SpringCM_Deficiency_Letter__c should remain null
     */
    @isTest
    static void testInsertWithoutDeficiencyNotification() {
        // Create a new LicenseType without DeficiencyNotification
        LicenseType__c newLicenseType = new LicenseType__c();
        newLicenseType.Name = 'Test LT Without Deficiency';
        newLicenseType.Status__c = 'Active';
        
        Test.startTest();
        insert newLicenseType;
        Test.stopTest();
        
        // Verify that SpringCM_Deficiency_Letter__c remains null
        LicenseType__c insertedLT = [SELECT Id, SpringCM_Deficiency_Letter__c, DeficiencyNotification__c 
                                      FROM LicenseType__c WHERE Id = :newLicenseType.Id];
        System.assertEquals(null, insertedLT.SpringCM_Deficiency_Letter__c, 
            'SpringCM_Deficiency_Letter__c should be null when DeficiencyNotification__c is not set');
    }
    
    /**
     * Test: Update DeficiencyNotification to a new value
     * Scenario: When updating DeficiencyNotification__c to a new value,
     * SpringCM_Deficiency_Letter__c should be updated to the new DocGeneratorSettings Name
     */
    @isTest
    static void testUpdateDeficiencyNotificationToNewValue() {
        // Get the DocGeneratorSettings created in TestSetup
        List<DocGeneratorSettings__c> docSettings = [SELECT Id, Name FROM DocGeneratorSettings__c ORDER BY Name];
        DocGeneratorSettings__c docSetting1 = docSettings[0];
        DocGeneratorSettings__c docSetting2 = docSettings[1];
        
        // Create a LicenseType with initial DeficiencyNotification
        LicenseType__c newLicenseType = new LicenseType__c();
        newLicenseType.Name = 'Test LT Update Deficiency';
        newLicenseType.DeficiencyNotification__c = docSetting1.Id;
        newLicenseType.Status__c = 'Active';
        insert newLicenseType;
        
        // Verify initial state
        LicenseType__c insertedLT = [SELECT Id, SpringCM_Deficiency_Letter__c FROM LicenseType__c WHERE Id = :newLicenseType.Id];
        System.assertEquals(docSetting1.Name, insertedLT.SpringCM_Deficiency_Letter__c, 
            'Initial SpringCM_Deficiency_Letter__c should match first DocGeneratorSettings Name');
        
        // Update DeficiencyNotification to a different value
        newLicenseType.DeficiencyNotification__c = docSetting2.Id;
        
        Test.startTest();
        update newLicenseType;
        Test.stopTest();
        
        // Verify that SpringCM_Deficiency_Letter__c was updated to new DocGeneratorSettings Name
        LicenseType__c updatedLT = [SELECT Id, SpringCM_Deficiency_Letter__c, DeficiencyNotification__c 
                                     FROM LicenseType__c WHERE Id = :newLicenseType.Id];
        System.assertEquals(docSetting2.Name, updatedLT.SpringCM_Deficiency_Letter__c, 
            'SpringCM_Deficiency_Letter__c should be updated to new DocGeneratorSettings Name');
    }
    
    /**
     * Test: Clear DeficiencyNotification (set to null)
     * Scenario: When DeficiencyNotification__c is cleared,
     * SpringCM_Deficiency_Letter__c should also be cleared
     */
    @isTest
    static void testClearDeficiencyNotification() {
        // Get the DocGeneratorSettings created in TestSetup
        DocGeneratorSettings__c docSetting = [SELECT Id, Name FROM DocGeneratorSettings__c WHERE Name = 'Deficiency Letter Template 1' LIMIT 1];
        
        // Create a LicenseType with DeficiencyNotification
        LicenseType__c newLicenseType = new LicenseType__c();
        newLicenseType.Name = 'Test LT Clear Deficiency';
        newLicenseType.DeficiencyNotification__c = docSetting.Id;
        newLicenseType.Status__c = 'Active';
        insert newLicenseType;
        
        // Verify initial state
        LicenseType__c insertedLT = [SELECT Id, SpringCM_Deficiency_Letter__c FROM LicenseType__c WHERE Id = :newLicenseType.Id];
        System.assertEquals(docSetting.Name, insertedLT.SpringCM_Deficiency_Letter__c, 
            'Initial SpringCM_Deficiency_Letter__c should be set');
        
        // Clear the DeficiencyNotification
        newLicenseType.DeficiencyNotification__c = null;
        
        Test.startTest();
        update newLicenseType;
        Test.stopTest();
        
        // Verify that SpringCM_Deficiency_Letter__c was cleared
        LicenseType__c updatedLT = [SELECT Id, SpringCM_Deficiency_Letter__c, DeficiencyNotification__c 
                                     FROM LicenseType__c WHERE Id = :newLicenseType.Id];
        System.assertEquals(null, updatedLT.SpringCM_Deficiency_Letter__c, 
            'SpringCM_Deficiency_Letter__c should be cleared when DeficiencyNotification__c is cleared');
    }
    
    /**
     * Test: Update LicenseType without changing DeficiencyNotification
     * Scenario: When updating other fields but not DeficiencyNotification__c,
     * SpringCM_Deficiency_Letter__c should remain unchanged
     */
    @isTest
    static void testUpdateWithoutChangingDeficiencyNotification() {
        // Get the DocGeneratorSettings created in TestSetup
        DocGeneratorSettings__c docSetting = [SELECT Id, Name FROM DocGeneratorSettings__c WHERE Name = 'Deficiency Letter Template 1' LIMIT 1];
        
        // Create a LicenseType with DeficiencyNotification
        LicenseType__c newLicenseType = new LicenseType__c();
        newLicenseType.Name = 'Test LT No Change Deficiency';
        newLicenseType.DeficiencyNotification__c = docSetting.Id;
        newLicenseType.Status__c = 'Active';
        insert newLicenseType;
        
        // Update other fields without changing DeficiencyNotification
        newLicenseType.Name = 'Updated Test LT Name';
        
        Test.startTest();
        update newLicenseType;
        Test.stopTest();
        
        // Verify that SpringCM_Deficiency_Letter__c remains unchanged
        LicenseType__c updatedLT = [SELECT Id, Name, SpringCM_Deficiency_Letter__c, DeficiencyNotification__c 
                                     FROM LicenseType__c WHERE Id = :newLicenseType.Id];
        System.assertEquals(docSetting.Name, updatedLT.SpringCM_Deficiency_Letter__c, 
            'SpringCM_Deficiency_Letter__c should remain unchanged when DeficiencyNotification__c is not modified');
        System.assertEquals('Updated Test LT Name', updatedLT.Name, 
            'Name should be updated');
    }
    
    /**
     * Test: Bulk insert with DeficiencyNotification
     * Scenario: Inserting multiple LicenseTypes with DeficiencyNotification__c
     * should correctly set SpringCM_Deficiency_Letter__c for all records
     */
    @isTest
    static void testBulkInsertWithDeficiencyNotification() {
        // Get the DocGeneratorSettings created in TestSetup
        List<DocGeneratorSettings__c> docSettings = [SELECT Id, Name FROM DocGeneratorSettings__c ORDER BY Name];
        
        // Create multiple LicenseTypes with different DeficiencyNotifications
        List<LicenseType__c> licenseTypesToInsert = new List<LicenseType__c>();
        for (Integer i = 0; i < 5; i++) {
            LicenseType__c lt = new LicenseType__c();
            lt.Name = 'Bulk Test LT ' + i;
            lt.DeficiencyNotification__c = docSettings[Math.mod(i, docSettings.size())].Id;
            lt.Status__c = 'Active';
            licenseTypesToInsert.add(lt);
        }
        
        Test.startTest();
        insert licenseTypesToInsert;
        Test.stopTest();
        
        // Verify all records have SpringCM_Deficiency_Letter__c populated correctly
        List<LicenseType__c> insertedLTs = [SELECT Id, Name, SpringCM_Deficiency_Letter__c, DeficiencyNotification__c 
                                             FROM LicenseType__c WHERE Name LIKE 'Bulk Test LT%' ORDER BY Name];
        System.assertEquals(5, insertedLTs.size(), 'Should have inserted 5 LicenseTypes');
        
        for (LicenseType__c lt : insertedLTs) {
            System.assertNotEquals(null, lt.SpringCM_Deficiency_Letter__c, 
                'SpringCM_Deficiency_Letter__c should be populated for: ' + lt.Name);
        }
    }
    
    /**
     * Test: Bulk update with DeficiencyNotification changes
     * Scenario: Updating multiple LicenseTypes with DeficiencyNotification__c changes
     * should correctly update SpringCM_Deficiency_Letter__c for all records
     */
    @isTest
    static void testBulkUpdateDeficiencyNotification() {
        // Get the DocGeneratorSettings created in TestSetup
        List<DocGeneratorSettings__c> docSettings = [SELECT Id, Name FROM DocGeneratorSettings__c ORDER BY Name];
        DocGeneratorSettings__c docSetting1 = docSettings[0];
        DocGeneratorSettings__c docSetting2 = docSettings[1];
        
        // Create multiple LicenseTypes with same DeficiencyNotification
        List<LicenseType__c> licenseTypesToInsert = new List<LicenseType__c>();
        for (Integer i = 0; i < 5; i++) {
            LicenseType__c lt = new LicenseType__c();
            lt.Name = 'Bulk Update Test LT ' + i;
            lt.DeficiencyNotification__c = docSetting1.Id;
            lt.Status__c = 'Active';
            licenseTypesToInsert.add(lt);
        }
        insert licenseTypesToInsert;
        
        // Update all to different DeficiencyNotification
        for (LicenseType__c lt : licenseTypesToInsert) {
            lt.DeficiencyNotification__c = docSetting2.Id;
        }
        
        Test.startTest();
        update licenseTypesToInsert;
        Test.stopTest();
        
        // Verify all records have SpringCM_Deficiency_Letter__c updated correctly
        List<LicenseType__c> updatedLTs = [SELECT Id, Name, SpringCM_Deficiency_Letter__c, DeficiencyNotification__c 
                                            FROM LicenseType__c WHERE Name LIKE 'Bulk Update Test LT%' ORDER BY Name];
        
        for (LicenseType__c lt : updatedLTs) {
            System.assertEquals(docSetting2.Name, lt.SpringCM_Deficiency_Letter__c, 
                'SpringCM_Deficiency_Letter__c should be updated to second DocGeneratorSettings Name for: ' + lt.Name);
        }
    }
}