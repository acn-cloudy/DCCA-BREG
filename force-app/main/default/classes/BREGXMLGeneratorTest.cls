@IsTest
public with sharing class BREGXMLGeneratorTest {
    @IsTest
    static void testGetXMLforDecreeDocumentReturnsNullForEmptyInput() {
        System.assertEquals(null, BREGXMLGenerator.getXMLforDecreeDocument(null, 'D1, P1, A1, C1, S1'), 'Null list should return null');
        System.assertEquals(null, BREGXMLGenerator.getXMLforDecreeDocument(new List<Account>(), 'D1, P1, A1, C1, S1'), 'Empty list should return null');
    }

    @IsTest
    static void testGetXMLforDecreeDocumentBuildsExpectedXml() {
        Date dueDate = Date.newInstance(2026, 3, 31);
        List<Account> dissolvedEntities = new List<Account>{
            new Account(Name = 'Entity One', breg_Entity_Type__c = 'F1', breg_Delinquency_Due_Date__c = dueDate),
            new Account(Name = 'Entity Two', breg_Entity_Type__c = 'F2', breg_Delinquency_Due_Date__c = dueDate)
        };

        String xml = BREGXMLGenerator.getXMLforDecreeDocument(dissolvedEntities, 'F1, F2');
        String expectedFullMonth = DateTime.newInstance(dueDate, Time.newInstance(0, 0, 0, 0)).format('MMMM');

        System.assertNotEquals(null, xml, 'XML should be generated for non-empty input');
        System.assert(xml.startsWith('<TemplateFieldData>'), 'XML should start with TemplateFieldData root');
        System.assert(xml.contains('<EffectiveDay>'), 'XML should include EffectiveDay tag');
        System.assert(xml.contains('<EffectiveFullMonth>'), 'XML should include EffectiveFullMonth tag');
        System.assert(xml.contains('<EffectiveYear>'), 'XML should include EffectiveYear tag');
        System.assert(xml.contains('<Status2DueDate>' + dueDate.format() + '</Status2DueDate>'), 'XML should include formatted due date from first entity');
        System.assert(xml.contains('<Status2DueDateDay>31</Status2DueDateDay>'), 'XML should include due date day from first entity');
        System.assert(xml.contains('<Status2DueDateFullMonth>' + expectedFullMonth + '</Status2DueDateFullMonth>'), 'XML should include due date full month from first entity');
        System.assert(xml.contains('<Status2DueDateYear>2026</Status2DueDateYear>'), 'XML should include due date year from first entity');
        System.assert(xml.contains('<Status2DueDate_unformatted />'), 'XML should include unformatted due date placeholder');
        System.assert(xml.contains('<ByCommissioner>'), 'XML should include ByCommissioner tag');
        System.assert(xml.contains('<UpdatedEntities_Container displayName="UpdatedEntities" displayValue="UpdatedEntities">'), 'XML should include UpdatedEntities container');
        System.assert(xml.contains('<UpdatedEntities2_Container displayName="UpdatedEntities2" displayValue="UpdatedEntities2">'), 'XML should include UpdatedEntities2 container');
        System.assert(xml.contains('<EntityName>Entity One</EntityName>'), 'XML should include first entity name in base container');
        System.assert(xml.contains('<EntityName2>Entity Two</EntityName2>'), 'XML should include second entity name in second container');
        System.assert(xml.endsWith('</TemplateFieldData>'), 'XML should end with TemplateFieldData closing tag');
    }

    @IsTest
    static void testGetXMLforDecreeDocumentBuildsSixGroupContainers() {
        Date dueDate = Date.newInstance(2026, 3, 31);
        List<Account> dissolvedEntities = new List<Account>{
            new Account(Name = 'G5 Name', breg_Entity_Type__c = 'G5', breg_Delinquency_Due_Date__c = dueDate),
            new Account(Name = 'G6 Name', breg_Entity_Type__c = 'G6', breg_Delinquency_Due_Date__c = dueDate),
            new Account(Name = 'L5 Name', breg_Entity_Type__c = 'L5', breg_Delinquency_Due_Date__c = dueDate),
            new Account(Name = 'L6 Name', breg_Entity_Type__c = 'L6', breg_Delinquency_Due_Date__c = dueDate),
            new Account(Name = 'Q5 Name', breg_Entity_Type__c = 'Q5', breg_Delinquency_Due_Date__c = dueDate),
            new Account(Name = 'Q6 Name', breg_Entity_Type__c = 'Q6', breg_Delinquency_Due_Date__c = dueDate)
        };

        String xml = BREGXMLGenerator.getXMLforDecreeDocument(dissolvedEntities, 'G5, G6, L5, L6, Q5, Q6');

        System.assert(xml.contains('<UpdatedEntities_Container displayName="UpdatedEntities" displayValue="UpdatedEntities">'), 'Should include base container');
        System.assert(xml.contains('<UpdatedEntities2_Container displayName="UpdatedEntities2" displayValue="UpdatedEntities2">'), 'Should include second container');
        System.assert(xml.contains('<UpdatedEntities3_Container displayName="UpdatedEntities3" displayValue="UpdatedEntities3">'), 'Should include third container');
        System.assert(xml.contains('<UpdatedEntities4_Container displayName="UpdatedEntities4" displayValue="UpdatedEntities4">'), 'Should include fourth container');
        System.assert(xml.contains('<UpdatedEntities5_Container displayName="UpdatedEntities5" displayValue="UpdatedEntities5">'), 'Should include fifth container');
        System.assert(xml.contains('<UpdatedEntities6_Container displayName="UpdatedEntities6" displayValue="UpdatedEntities6">'), 'Should include sixth container');
        System.assert(xml.contains('<EntityName6>Q6 Name</EntityName6>'), 'Should include typed entity name tag for sixth container');
    }

    @IsTest
    static void testGetXMLforDecreeDocumentKeepsEmptyContainersByGroupOrder() {
        Date dueDate = Date.newInstance(2026, 3, 31);
        List<Account> dissolvedEntities = new List<Account>{
            new Account(Name = 'Only K5', breg_Entity_Type__c = 'K5', breg_Delinquency_Due_Date__c = dueDate)
        };

        String xml = BREGXMLGenerator.getXMLforDecreeDocument(dissolvedEntities, 'K5, K6');

        System.assert(xml.contains('<UpdatedEntities_Container displayName="UpdatedEntities" displayValue="UpdatedEntities">'), 'Should include first container for K5');
        System.assert(xml.contains('<EntityName>Only K5</EntityName>'), 'Should include K5 entity in first container');
        System.assert(xml.contains('<UpdatedEntities2_Container displayName="UpdatedEntities2" displayValue="UpdatedEntities2">'), 'Should include second container for K6 even when empty');
        System.assert(!xml.contains('<EntityName2>'), 'Second container should be empty when no K6 records exist');
    }

    @IsTest
    static void testGetXMLforDecreeDocumentUsesEmptyStatus2DueDatePartsWhenDueDateIsNull() {
        List<Account> dissolvedEntities = new List<Account>{
            new Account(Name = 'No Due Date Entity', breg_Entity_Type__c = 'F1')
        };

        String xml = BREGXMLGenerator.getXMLforDecreeDocument(dissolvedEntities, 'F1');

        System.assertNotEquals(null, xml, 'XML should be generated when due date is null');
        System.assert(xml.contains('<Status2DueDate></Status2DueDate>'), 'Status2DueDate should be empty when due date is null');
        System.assert(xml.contains('<Status2DueDateDay></Status2DueDateDay>'), 'Status2DueDateDay should be empty when due date is null');
        System.assert(xml.contains('<Status2DueDateFullMonth></Status2DueDateFullMonth>'), 'Status2DueDateFullMonth should be empty when due date is null');
        System.assert(xml.contains('<Status2DueDateYear></Status2DueDateYear>'), 'Status2DueDateYear should be empty when due date is null');
        System.assert(xml.contains('<Status2DueDate_unformatted />'), 'XML should still include unformatted due date placeholder');
        System.assert(xml.contains('<EntityName>No Due Date Entity</EntityName>'), 'XML should still include the entity name');
    }
}