/*
 * ----------------------------------------------------------------------
 * Description:
 * ----------------------------------------------------------------------
 *
 * @author emel.l.agarao@pacificpointcorp.com
 * created 1/28/2026
 */
public without sharing class SEBSearchController {
    @AuraEnabled(cacheable = true)
    public static PagedResult searchSEBCaseContacts(String queryTerm, Integer pageSize, Integer pageNumber) {
        Integer offsetVal = (pageNumber - 1) * pageSize;

        List<Contact> contacts = [
            SELECT Id, Name
            FROM Contact 
            WHERE Name LIKE :('%' + queryTerm + '%')
            AND Id IN (
                SELECT Contact__c 
                FROM SEBCaseContact__c
                WHERE CaseResult__c IN ('Closed', 'Pending', 'Legal Action Taken', 'Warning Letter Issued')
                AND Contact__c != NULL
            )

            ORDER BY Name
            LIMIT :pageSize
            OFFSET :offsetVal
        ];

        Integer total = [
            SELECT COUNT()
            FROM Contact 
            WHERE Name LIKE :('%' + queryTerm + '%')
            AND Id IN (
                SELECT Contact__c 
                FROM SEBCaseContact__c
                WHERE CaseResult__c IN ('Closed', 'Pending', 'Legal Action Taken', 'Warning Letter Issued')
                AND Contact__c != NULL
            )
        ];

        return new PagedResult(contacts, total);
    }

    @AuraEnabled(cacheable = true)
    public static List<SEBCaseContact__c> getContactSEBCases(String contactId) {
        if (String.isBlank(contactId)) {
            return new List<SEBCaseContact__c>();
        }

        return [
            SELECT Id, Name, SEBCase__r.SEBCaseNumber__c, SEBCase__r.ClosedDateTime__c, CaseResult__c, Public__c
            FROM SEBCaseContact__c
            WHERE Contact__c =: contactId
            AND CaseResult__c IN ('Closed', 'Pending', 'Legal Action Taken', 'Warning Letter Issued')
        ];
    }

    @AuraEnabled(cacheable = true)
    public static List<EnforcementActionDocument__c> getCaseContactDocuments(String caseContactId) {
        if (String.isBlank(caseContactId)) {
            return new List<EnforcementActionDocument__c>();
        }

        return [
            SELECT Id, Name, PublicURL__c, CreatedDate
            FROM EnforcementActionDocument__c
            WHERE SEBCaseContact__c =: caseContactId
            AND SEBCaseContact__r.Public__c = true
        ];
    }

    public class PagedResult {
        @AuraEnabled public List<Contact> records;
        @AuraEnabled public Integer totalRecords;

        public PagedResult(List<Contact> records, Integer totalRecords) {
            this.records = records;
            this.totalRecords = totalRecords;
        }
    }

    @InvocableMethod(label='Publicly Share Document'  category='Docusign' description='Creates a ShareLink in docusign for the supplied document' callout=true iconName='slds:standard:channel_program_members')
    public static SpringCMShareDocumentControllerOutput[] shareDocument(SpringCMShareDocumentControllerInput[] inputs) {
        SpringCMShareDocumentControllerOutput[] resultingShareLinks = new SpringCMShareDocumentControllerOutput[]{};
        for(SpringCMShareDocumentControllerInput input : inputs) {
            SpringCMShareDocumentControllerOutput result = new SpringCMShareDocumentControllerOutput();
            SpringCMService service = new SpringCMService();
            SpringCMDocument document = service.getDocumentShareLinks(input.documentId);
            if(
                document?.ShareLinks?.Items != null
                && !document.ShareLinks.Items.isEmpty()
            ){
                result.shareLink =  document.ShareLinks.Items[0];
            } else {
                result.shareLink = service.postShareLink(input.documentId);
            }

            resultingShareLinks.add(result);
        }

        return resultingShareLinks;
    }

    public class SpringCMShareDocumentControllerInput {
        @InvocableVariable(label='Document Id' required=true)
        public String documentId;
    }
    public class SpringCMShareDocumentControllerOutput {
        @InvocableVariable(label='Share Link')
        public SpringCMShareLink shareLink;
    }
}