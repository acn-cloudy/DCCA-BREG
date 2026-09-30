public with sharing class BREGAmazonSesAnnualsDataProvider implements BREGAmazonSesDataProvider {
    private Set<Id> whoIds;
    private Set<Id> whatIds;

    public BREGAmazonSesAnnualsDataProvider() {
        whoIds = new Set<Id>();
        whatIds = new Set<Id>();
    }

    public List<Map<String, Object>> getTemplateData(List<Map<String, Id>> recordIdMaps) {
        initParams(recordIdMaps);

        List<Map<String, Object>> templateDataPerRecipient = new List<Map<String, Object>>();

        Map<Id, Contact> contactsMap = new Map<Id, Contact>([SELECT Id, FirstName, LastName FROM Contact WHERE Id IN :whoIds]);
        Map<Id, Account> entitesMap = new Map<Id, Account>([SELECT Name, breg_Annuals_Due_Date__c, breg_File__c FROM Account WHERE Id IN :whatIds]);

        for (Map<String, Id> recordIdMap : recordIdMaps) {
            Id whoId = recordIdMap.get('WhoId');
            Id whatId = recordIdMap.get('WhatId');

            Contact contact = contactsMap.get(whoId);
            Account entity = entitesMap.get(whatId);

            Integer fillingYear = entity.breg_Annuals_Due_Date__c != null ? Date.valueOf(entity.breg_Annuals_Due_Date__c).year() : Date.today().year();

            Map<String, Object> replacementData = new Map<String, Object>{
                'subject' => String.valueOf(fillingYear),
                'fillername' => contact != null ? contact.FirstName + ' ' + contact.LastName : 'Valued Customer',
                'filingyear' => String.valueOf(fillingYear),
                'entityname' => entity != null ? entity.Name : '',
                'filenumber' => entity != null ? entity.breg_File__c : ''
            };
            templateDataPerRecipient.add(replacementData);
        }

        return templateDataPerRecipient;
    }

    private void initParams(List<Map<String, Id>> recordIdMaps) {
        for (Map<String, Object> recordIdMap : recordIdMaps) {
            whoIds.add((Id) recordIdMap.get('WhoId'));
            whatIds.add((Id) recordIdMap.get('WhatId'));
        }
    }
}