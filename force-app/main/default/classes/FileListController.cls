/*
* ─────────────────────────────────────────────────────────
* Controller controller for the FileList
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
public with sharing class FileListController {
    // update description of the files 
    @Auraenabled 
    public static void updateDescription(String fileId, String comment){
        List<ContentVersion> versions = [Select Id, Description from ContentVersion where ContentDocumentId =: fileId];
        for(ContentVersion version: versions) {
            version.Description = comment;
        }
        update versions;
    }
    
    
    // Delete files 
    @Auraenabled 
    public static void deleteFile(String fileId){
        List<ContentDocument> documents = [Select Id from ContentDocument where Id=: fileId];
        delete documents;
    }
}