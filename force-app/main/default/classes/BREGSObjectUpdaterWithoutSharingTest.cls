@isTest
public class BREGSObjectUpdaterWithoutSharingTest {
    private static String joinIdsForSoql(Set<Id> ids) {
        List<String> quotedIds = new List<String>();
        for (Id recordId : ids) {
            quotedIds.add('\'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'');
        }
        return String.join(quotedIds, ',');
    }

    @isTest
    static void testUpdateRecordsBulk() {
        List<Case> casesToInsert = new List<Case>{
            new Case(Subject = 'Bulk Case 1', Status = 'New', Origin = 'Web', Type = 'Other'),
            new Case(Subject = 'Bulk Case 2', Status = 'New', Origin = 'Web', Type = 'Other')
        };
        insert casesToInsert;

        casesToInsert[0].Subject = 'Bulk Updated 1';
        casesToInsert[1].Subject = 'Bulk Updated 2';

        Test.startTest();
        BREGSObjectUpdaterWithoutSharing.updateRecords(new List<SObject>{ casesToInsert[0], casesToInsert[1] });
        Test.stopTest();

        List<Case> updatedCases = [
            SELECT Id, Subject
            FROM Case
            WHERE Id IN :new Set<Id>{ casesToInsert[0].Id, casesToInsert[1].Id }
        ];
        Map<Id, Case> updatedCasesById = new Map<Id, Case>(updatedCases);

        System.assertEquals('Bulk Updated 1', updatedCasesById.get(casesToInsert[0].Id).Subject);
        System.assertEquals('Bulk Updated 2', updatedCasesById.get(casesToInsert[1].Id).Subject);
    }

    @isTest
    static void testUpdateRecordSingle() {
        Case caseRecord = new Case(Subject = 'Single Case', Status = 'New', Origin = 'Web', Type = 'Other');
        insert caseRecord;

        caseRecord.Subject = 'Single Updated';

        Test.startTest();
        BREGSObjectUpdaterWithoutSharing.updateRecord(caseRecord);
        Test.stopTest();

        Case updatedCase = [SELECT Subject FROM Case WHERE Id = :caseRecord.Id];
        System.assertEquals('Single Updated', updatedCase.Subject);
    }

    @isTest
    static void testUpdateRecordsByQuery() {
        List<Case> casesToInsert = new List<Case>{
            new Case(Subject = 'Query Case 1', Status = 'New', Origin = 'Web', Type = 'Other'),
            new Case(Subject = 'Query Case 2', Status = 'New', Origin = 'Web', Type = 'Other')
        };
        insert casesToInsert;

        String query = 'SELECT Id, Subject FROM Case WHERE Id IN (' + joinIdsForSoql(new Map<Id, Case>(casesToInsert).keySet()) + ')';

        Test.startTest();
        BREGSObjectUpdaterWithoutSharing.updateRecordsByQuery(query, new Map<String, Object>{ 'Subject' => 'Query Updated' });
        Test.stopTest();

        List<Case> updatedCases = [
            SELECT Id, Subject
            FROM Case
            WHERE Id IN :new Map<Id, Case>(casesToInsert).keySet()
        ];

        for (Case updatedCase : updatedCases) {
            System.assertEquals('Query Updated', updatedCase.Subject);
        }
    }

    @isTest
    static void testSelectRecordsByQuery() {
        List<Case> casesToInsert = new List<Case>{
            new Case(Subject = 'Select Case 1', Status = 'New', Origin = 'Web', Type = 'Other'),
            new Case(Subject = 'Select Case 2', Status = 'New', Origin = 'Web', Type = 'Other')
        };
        insert casesToInsert;

        String query = 'SELECT Id, Subject FROM Case WHERE Id IN (' + joinIdsForSoql(new Map<Id, Case>(casesToInsert).keySet()) + ')';

        Test.startTest();
        List<SObject> selectedRecords = BREGSObjectUpdaterWithoutSharing.selectRecordsByQuery(query);
        List<SObject> blankQueryRecords = BREGSObjectUpdaterWithoutSharing.selectRecordsByQuery('');
        Test.stopTest();

        System.assertEquals(2, selectedRecords.size());
        System.assertEquals(0, blankQueryRecords.size());
    }

    @isTest
    static void testUpdateRecordsNullOrEmpty() {
        Test.startTest();
        BREGSObjectUpdaterWithoutSharing.updateRecords(null);
        BREGSObjectUpdaterWithoutSharing.updateRecords(new List<SObject>());
        BREGSObjectUpdaterWithoutSharing.updateRecord(null);
        BREGSObjectUpdaterWithoutSharing.updateRecordsByQuery(null, new Map<String, Object>{ 'Subject' => 'Ignored' });
        BREGSObjectUpdaterWithoutSharing.updateRecordsByQuery('', new Map<String, Object>{ 'Subject' => 'Ignored' });
        BREGSObjectUpdaterWithoutSharing.updateRecordsByQuery('SELECT Id FROM Case WHERE Id = NULL', null);
        BREGSObjectUpdaterWithoutSharing.updateRecordsByQuery('SELECT Id FROM Case WHERE Id = NULL', new Map<String, Object>());
        Test.stopTest();

        System.assertEquals(true, true, 'Null and empty inputs should be safely ignored.');
    }

    @isTest
    static void testUpsertRecordsBulk() {
        List<Case> casesToUpsert = new List<Case>{
            new Case(Subject = 'Upsert Case 1', Status = 'New', Origin = 'Web', Type = 'Other'),
            new Case(Subject = 'Upsert Case 2', Status = 'New', Origin = 'Web', Type = 'Other')
        };  

        Test.startTest();
        BREGSObjectUpdaterWithoutSharing.upsertRecords(new List<SObject>{ casesToUpsert[0], casesToUpsert[1] });
        Test.stopTest();

        List<Case> upsertedCases = [
            SELECT Id, Subject
            FROM Case
            WHERE Id IN :new Set<Id>{ casesToUpsert[0].Id, casesToUpsert[1].Id }
        ];
        Map<Id, Case> upsertedCasesById = new Map<Id, Case>(upsertedCases);

        System.assertEquals('Upsert Case 1', upsertedCasesById.get(casesToUpsert[0].Id).Subject);
        System.assertEquals('Upsert Case 2', upsertedCasesById.get(casesToUpsert[1].Id).Subject);
    }

    @isTest
    static void testUpsertRecordSingle() {
        Case caseRecord = new Case(Subject = 'Upsert Single Case', Status = 'New', Origin = 'Web', Type = 'Other');
        insert caseRecord;

        caseRecord.Subject = 'Upsert Single Updated';

        Test.startTest();
        BREGSObjectUpdaterWithoutSharing.upsertRecord(caseRecord);
        Test.stopTest();

        Case upsertedCase = [SELECT Subject FROM Case WHERE Id = :caseRecord.Id];
        System.assertEquals('Upsert Single Updated', upsertedCase.Subject);
    }

    @isTest
    static void testUpsertRecordsNullOrEmpty() {
        Test.startTest();
        BREGSObjectUpdaterWithoutSharing.upsertRecords(null);
        BREGSObjectUpdaterWithoutSharing.upsertRecords(new List<SObject>());
        BREGSObjectUpdaterWithoutSharing.upsertRecord(null);
        Test.stopTest();
        System.assertEquals(true, true, 'Null and empty inputs should be safely ignored.');
    }
}