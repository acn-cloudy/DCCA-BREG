public with sharing class BREGXMLGenerator {

    public static String getXMLforDecreeDocument(List<Account> dissolvedEntities, String groupLabel) {
        if (dissolvedEntities == null || dissolvedEntities.isEmpty()) {
            return null;
        }

        User currentUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId()];
        Datetime today = Datetime.now();
        Date status2DueDateValue = dissolvedEntities[0].breg_Delinquency_Due_Date__c;
        String status2DueDate = status2DueDateValue != null
            ? status2DueDateValue.format()
            : '';
        
        String status2DueDateDay = status2DueDateValue != null
            ? String.valueOf(status2DueDateValue.day())
            : '';
        
        String status2DueDateFullMonth = status2DueDateValue != null
            ? DateTime.newInstance(
                status2DueDateValue,
                Time.newInstance(0, 0, 0, 0)
              ).format('MMMM')
            : '';
        
        String status2DueDateYear = status2DueDateValue != null
            ? String.valueOf(status2DueDateValue.year())
            : '';
        
        Datetime effectiveDate = dissolvedEntities[0].breg_Involuntary_Dissolution_Notice_Date__c != null
            ? dissolvedEntities[0].breg_Involuntary_Dissolution_Notice_Date__c
            : today;
        
        String effectiveDay = String.valueOf(effectiveDate.day());
        String effectiveFullMonth = effectiveDate.format('MMMM');
        String effectiveYear = String.valueOf(effectiveDate.year());
        
        String byCommissioner = currentUser.Name;
        
        String resultXML = '';
        resultXML += '<TemplateFieldData>';
        resultXML +=
            '<EffectiveDay>' + effectiveDay + '</EffectiveDay>' +
            '<EffectiveFullMonth>' + effectiveFullMonth + '</EffectiveFullMonth>' +
            '<EffectiveYear>' + effectiveYear + '</EffectiveYear>' +
            '<Status2DueDate>' + status2DueDate + '</Status2DueDate>' +
            '<Status2DueDateDay>' + status2DueDateDay + '</Status2DueDateDay>' +
            '<Status2DueDateFullMonth>' + status2DueDateFullMonth + '</Status2DueDateFullMonth>' +
            '<Status2DueDateYear>' + status2DueDateYear + '</Status2DueDateYear>' +
            '<Status2DueDate_unformatted />' +
            '<ByCommissioner>' + byCommissioner + '</ByCommissioner>';
        List<String> groupedEntityTypes = new List<String>();
        if (String.isNotBlank(groupLabel)) {
            for (String item : groupLabel.split(',')) {
                String trimmed = item.trim();
                if (String.isNotBlank(trimmed)) {
                    groupedEntityTypes.add(trimmed);
                }
            }
        }

        // Build containers strictly in group label order. Empty containers are preserved.
        if (groupedEntityTypes.isEmpty()) {
            resultXML += buildUpdatedEntitiesContainer(dissolvedEntities, '');
        } else {
            Map<String, List<Account>> accountsByEntityType = new Map<String, List<Account>>();
            for (Account acc : dissolvedEntities) {
                if (String.isBlank(acc.breg_Entity_Type__c)) {
                    continue;
                }
                if (!accountsByEntityType.containsKey(acc.breg_Entity_Type__c)) {
                    accountsByEntityType.put(acc.breg_Entity_Type__c, new List<Account>());
                }
                accountsByEntityType.get(acc.breg_Entity_Type__c).add(acc);
            }

            for (Integer i = 0; i < groupedEntityTypes.size(); i++) {
                String entityType = groupedEntityTypes[i];
                List<Account> accountsForType = accountsByEntityType.containsKey(entityType)
                    ? accountsByEntityType.get(entityType)
                    : new List<Account>();
                String suffix = i == 0 ? '' : String.valueOf(i + 1);
                resultXML += buildUpdatedEntitiesContainer(accountsForType, suffix);
            }
        }

        resultXML += '</TemplateFieldData>';
        return resultXML;
    }

    private static String buildUpdatedEntitiesContainer(List<Account> accounts, String suffix) {
        String updatedEntitiesTag = 'UpdatedEntities' + suffix;
        String entityNameTag = 'EntityName' + suffix;
        String containerTag = updatedEntitiesTag + '_Container';
        String resultXML = '<' + containerTag + ' displayName="' + updatedEntitiesTag + '" displayValue="' + updatedEntitiesTag + '">';
        for (Account acc : accounts) {
            resultXML += '<' + updatedEntitiesTag + ' displayName="" displayValue=""><' + entityNameTag + '>' + String.valueOf(acc.Name).escapeXml() + '</' + entityNameTag + '></' + updatedEntitiesTag + '>';
        }
        resultXML += '</' + containerTag + '>';
        return resultXML;
    }
}