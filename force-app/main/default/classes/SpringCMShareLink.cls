global with sharing class SpringCMShareLink {

    @AuraEnabled global String Url {get;set;}
    global DateTime ExpirationDate;
    global Boolean AllowNativeDownload;
    global Boolean AllowPdfDownload;
    global String PreviewBehavior;
    global String CreatedBy;
    global String UpdatedBy;
    global DateTime CreatedDate;
    global DateTime UpdatedDate;
    global SpringCMDocument Document;
    @AuraEnabled global String Href {get;set;}

    global SpringCMShareLink() {}
}