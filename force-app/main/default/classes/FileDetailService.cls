public class FileDetailService {
    private static set<String> fileUrlSet = new Set<String>();
    public static void andFinally() {
        if(!fileUrlSet.isEmpty()) {
            deleteFiles(fileUrlSet);
            fileUrlSet.clear();
        }
    }
    @future(callout=true)
    public static void deleteFiles(Set<String> fileUrls) {
        for(String url: fileUrls) {
            SpringCMConnector.deleteFile(url);
        }
    }

    public static void captureDeletion(SObject so) {
        FileDetails__c record = (FileDetails__c) so;
        if(record.FileUrl__c != null) {
            fileUrlSet.add(record.FileUrl__c);
        }

    }
    public static Map<String, String> checkFilePermissions(List<String> recordIds) {
        List<FileDetails__c> records = FileDetailSelector.getFileDetails(recordIds);
        
        List<String> profileNames = new List<String>{
            GlobalConstants.SYSTEMADMIN, GlobalConstants.SESYSTEMADMIN, GlobalConstants.CUSTOMCOMMUNITYLOGIN};

        List<Profile> profiles = ProfileSelector.getProfiles(profileNames);
        Set<String> examValidProfile = new Set<String>();
        Set<String> filingValidProfile = new Set<String>();
        for(Profile profileRecord: profiles) {
            if(profileRecord.Name != GlobalConstants.CUSTOMCOMMUNITYLOGIN) {
                examValidProfile.add(profileRecord.Id);
            }
            filingValidProfile.add(profileRecord.Id);
        }
        Map<String, String> errors = new Map<String, String>();
        Map<String, String> examErrors = new Map<String, String>();
        if(!examValidProfile.contains(UserInfo.getProfileId()))
            examErrors = (new FileDetailDomain(records)).checkForExamValidations();

        Map<String, String> filingErrors = new Map<String, String>();
        if(!filingValidProfile.contains(UserInfo.getProfileId()))
            filingErrors = (new FileDetailDomain(records)).checkForFilingValidations();

        for(String recordId: examErrors.KeySet()) {
            errors.put(recordId, examErrors.get(recordId));
        }

        for(String recordId: filingErrors.KeySet()) {
            errors.put(recordId, filingErrors.get(recordId));
        }
        
        return errors;
    }
}