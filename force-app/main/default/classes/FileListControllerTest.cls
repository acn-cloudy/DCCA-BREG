/*
* ─────────────────────────────────────────────────────────
* Controller Test for the FileListController
* ─────────────────────────────────────────────────────────
* PacPoint-AZ250919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* 
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
@isTest
public class FileListControllerTest {
    @TestSetup
    static void init(){
        Account acc = new Account();
        acc.Name = 'Test 398624';
        acc.BPID__c = '2323442';
        insert acc;
        createContentDocument('test',acc.Id);
    }
    public static void createContentDocument(string docName,Id parentId){ 
       
		ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = EncodingUtil.base64Decode(EncodingUtil.urlDecode(docName, 'UTF-8'));
        cv.Title = docName;
        cv.PathOnClient = '/'+docName;
        try{
        	NetworkMember membership = [SELECT networkID, memberID FROM NetworkMember WHERE memberID = :userinfo.getUserId() ];
			cv.NetworkId = membership.NetworkId;
        }catch(Exception e){
            system.debug('Not a community user');
        }
        insert cv;
        
        // First get the content document Id from ContentVersion
		Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;
 
        //Create ContentDocumentLink
        ContentDocumentLink cDe = new ContentDocumentLink();
        cDe.ContentDocumentId = conDoc;
        cDe.LinkedEntityId = parentId;
        cDe.ShareType = 'I';
        cDe.Visibility = 'AllUsers';
        insert cDe;
    }
    public static testMethod void testUpdateDescription(){
        List<ContentDocument> cDs = [select Id from ContentDocument];
        String contentId = cDs.get(0).Id;
        String comment = 'Test Comment';
        FileListController.updateDescription(contentId, comment);
        
        ContentDocument updatedCD = [select Id, Description from ContentDocument where Id =: contentId];
        System.assertEquals(updatedCD.Description, comment);
    }

    public static testMethod void testDeleteFile(){
        List<ContentDocument> cDs = [select Id from ContentDocument];
        String contentId = cDs.get(0).Id;
        FileListController.deleteFile(contentId);
        List<ContentDocument> deletedFiles =[select Id from ContentDocument where Id = : contentId];
        System.assertEquals(deletedFiles.size(), 0);
    }
}