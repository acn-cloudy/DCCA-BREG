@IsTest
private class BREGAmazonSesAnnualsDataProviderTest {
    @IsTest
    static void testGetTemplateDataWithContactAndAccount() {
        Contact contact = new Contact(FirstName = 'Jane', LastName = 'Doe', Email = 'jane.doe@example.com');
        insert contact;

        Account accountRecord = BREGTestDataFactory.createEntityAccounts(1)[0];
        accountRecord.Name = 'Acme Inc.';
        accountRecord.breg_Annuals_Due_Date__c = Date.newInstance(2026, 12, 31);
        accountRecord.breg_File__c = 'FILE-123';
        update accountRecord;

        List<Map<String, Id>> recordIdMaps = new List<Map<String, Id>>{
            new Map<String, Id>{ 'WhoId' => contact.Id, 'WhatId' => accountRecord.Id }
        };

        BREGAmazonSesAnnualsDataProvider provider = new BREGAmazonSesAnnualsDataProvider();
        List<Map<String, Object>> templateData = provider.getTemplateData(recordIdMaps);

        System.assertEquals(1, templateData.size(), 'Expected one replacement map');
        System.assertEquals('2026', (String) templateData[0].get('subject'), 'Subject should use the annual due year');
        System.assertEquals('Jane Doe', (String) templateData[0].get('fillername'), 'Filler name should come from the contact');
        System.assertEquals('2026', (String) templateData[0].get('filingyear'), 'Filing year should use the annual due year');
        System.assertEquals('Acme Inc.', (String) templateData[0].get('entityname'), 'Entity name should come from the account');
        System.assertEquals('FILE-123', (String) templateData[0].get('filenumber'), 'File number should come from the account');
    }

    @IsTest
    static void testGetTemplateDataUsesFallbackValues() {
        Account accountRecord = BREGTestDataFactory.createEntityAccounts(1)[0];
        accountRecord.Name = 'Fallback Entity';
        accountRecord.breg_File__c = 'FILE-999';
        accountRecord.breg_Annuals_Due_Date__c = null;
        update accountRecord;

        List<Map<String, Id>> recordIdMaps = new List<Map<String, Id>>{
            new Map<String, Id>{ 'WhoId' => UserInfo.getUserId(), 'WhatId' => accountRecord.Id }
        };

        BREGAmazonSesAnnualsDataProvider provider = new BREGAmazonSesAnnualsDataProvider();
        List<Map<String, Object>> templateData = provider.getTemplateData(recordIdMaps);

        String currentYear = String.valueOf(Date.today().year());

        System.assertEquals(1, templateData.size(), 'Expected one replacement map');
        System.assertEquals(currentYear, (String) templateData[0].get('subject'), 'Subject should fall back to the current year');
        System.assertEquals('Valued Customer', (String) templateData[0].get('fillername'), 'Missing contact should use the fallback recipient name');
        System.assertEquals(currentYear, (String) templateData[0].get('filingyear'), 'Filing year should fall back to the current year');
        System.assertEquals('Fallback Entity', (String) templateData[0].get('entityname'), 'Entity name should come from the account when present');
        System.assertEquals('FILE-999', (String) templateData[0].get('filenumber'), 'File number should come from the account when present');
    }
}