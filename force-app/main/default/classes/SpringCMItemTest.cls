@isTest
public with sharing class SpringCMItemTest {
    public static testMethod void testItems() {
        SpringCMApiCollection collection = new SpringCMApiCollection();
        SpringCMDocumentItem item = new SpringCMDocumentItem();
        SpringCMFeed.Folder folderFeed = new SpringCMFeed.Folder();
        SpringCMFeed.FolderResult folderResult = new SpringCMFeed.FolderResult();
        SpringCMSearchResult result = new SpringCMSearchResult();
        collection.Items = null;
        collection.Href = null;
        collection.Offset = null;
        collection.scmLimit = null;
        collection.First = null;
        collection.Previous = null;
        collection.Next = null;
        collection.Last = null;
        collection.Total = null;
        item.Items = null;
        folderFeed.Name = null;
        folderFeed.CreateDocumentHref = null;
        folderResult.Items = null;
        result.Result = null;

        HttpError errorRec = new HttpError();
        errorRec.Status = null;
        errorRec.StatusCode = 0;



        SpringCMDocument rec = new SpringCMDocument();
        rec.Name = null;
        rec.CreatedDate = null;
        rec.CreatedBy = null;
        rec.UpdatedDate = null;
        rec.UpdatedBy = null;
        rec.Description = null;
        rec.Path = null;
        rec.AttributeGroups = null;
        rec.PageCount = null;
        rec.Version = null;
        rec.PreviewUrl = null;
        rec.DownloadDocumentHref = null;
        rec.NativeFileSize = null;
        rec.PdfFileSize = null;
        rec.Href = null;
    }
}