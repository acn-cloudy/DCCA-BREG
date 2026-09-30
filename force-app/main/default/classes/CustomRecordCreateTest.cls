/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for CustomRecordCreate
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
public class CustomRecordCreateTest {

    @isTest
    public static void Test1(){
        // Run the code
        Test.startTest();
        CustomRecordCreate.LayoutWrapper lw = CustomRecordCreate.GetLayout('Account', 'Account Layout', null);
        CustomRecordCreate.SaveRecord('Account', '{ "Name" : "Test 837844" }', null);
        
        string strLabel = lw.sections[0].label;
        integer intAux = lw.sections[0].columns;
        string strAux = lw.sections[0].fields[0].field1.fieldAPIName;
        strAux = lw.sections[0].fields[0].field1.fieldLabel;
        strAux = lw.sections[0].fields[0].field1.fieldType;
        strAux = lw.sections[0].fields[0].field1.fieldHelpText;
        object objAux = lw.sections[0].fields[0].field1.defaultValue;
        List<CustomRecordCreate.PicklistOption> listAux1 = lw.sections[0].fields[0].field1.piclistOptions;
        listAux1 = lw.sections[0].fields[0].field1.statesOptions;
        boolean strBool = lw.sections[0].fields[0].field1.fieldIsCreatable;
        strBool = lw.sections[0].fields[0].field1.fieldIsMandatory;
        Test.stopTest();
        
        // Verify Results
        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        //System.assertEquals('Account Information', strLabel);
    }
    public static testMethod void testCreateFiles() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        SEBCase__c sbCase = new SEBCase__c();
        sbCase.Account__c = acct.Id;
        // sbCase.Name = 'dummySebCase';
        sbCase.Status__c = 'Intake';
        insert sbCase;
        ContentVersion contentVersion_1 = new ContentVersion(
            Title = 'Penguins',
            PathOnClient = 'Penguins.jpg',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert contentVersion_1;
    
        List<ContentDocument> contentDocumentList = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];

        String fileStr = '[{"Type__c":"Contracts ","Category__c":"SEB Complaint","SEB_Case__c":"' + sbCase.Id + '",'
        + '"ContentDocumentTitle__c":"100px-Seal_of_the_State_of_Hawaii.png","ContentDocumentId__c":"' + contentDocumentList.get(0).Id 
        + '"}]"';
        CustomRecordCreate.saveFileDetails(fileStr, 'SEB');

    }
}