@RestResource(urlMapping='/api/getBregStamps')
global with sharing class BREGExternalAPIGetStamps {

    global class Response {
        public List<StampResponse> stamps { get; set; }
        public String errorMessage { get; set; }
    }
    global class StampResponse {
        public String StampName { get; set; }
        public String StampLabel { get; set; }
        public Boolean IncludesDate { get; set; }
        public String DatePosLeft { get; set; }
        public String DatePosTop { get; set; }
        public String DatePosBottom { get; set; }
        public String DatePosRight { get; set; }
        public String StampImageBase64 { get; set; }
        public String DateFormat { get; set; }
    }

    @HttpGet
    global static Response getStamps() {
        Response result = new Response();

        // Get current user and profile
        Id userId = UserInfo.getUserId();
        Id profileId = UserInfo.getProfileId();

        // Container for all settings
        List<BREG_Stamp_Setting__c> allSettings = getUserStamps(userId, profileId);

        if (allSettings.isEmpty()) {
            result.errorMessage = 'No stamps found';
            RestContext.response = new System.RestResponse();
            RestContext.response.statusCode = 500;
            return result;
        }

        // Collect all unique stamp names
        Set<String> stampNames = new Set<String>();
        for (BREG_Stamp_Setting__c setting : allSettings) {
            if (String.isNotBlank(setting.breg_Stamp_Name__c)) {
                stampNames.add(setting.breg_Stamp_Name__c.trim());
            }
        }

        // Get all stamp images from static resource BREG_Resources, folder "stamps"
        // Apex cannot directly list files in a static resource folder, so we must assume
        // that the static resource is a zip file and we can access its contents by name.
        // We'll use PageReference.getContent() to get the blob for each image.
        // Assume all images are PNGs. If not found, leave blank.

        Map<String, String> stampNameToBase64 = new Map<String, String>();

        for (String stampName : stampNames) {
            try {
                // Construct the path: /resource/BREG_Resources/stamps/<stampName>.png
                // StaticResource URLs are case-sensitive and may need adjustment.
                // We'll use the StaticResource global variable.
                String resourcePath = '/resource/BREG_Resources/stamps/' + EncodingUtil.urlEncode(stampName, 'UTF-8').replace('+', '%20') + '.png';
                PageReference pr = new PageReference(resourcePath);
                Blob imgBlob = Test.isRunningTest() ? Blob.valueOf('PNG content') : pr.getContent();
                stampNameToBase64.put(stampName, imgBlob != null ? EncodingUtil.base64Encode(imgBlob) : '');
            } catch (Exception e) {
                result.errorMessage = 'Error getting stamp image: ' + e.getMessage();
                RestContext.response.statusCode = 500;
                return result;
            }
        }

        result.stamps = new List<StampResponse>();
        // Build the response
        for (BREG_Stamp_Setting__c setting : allSettings) {
            if (String.isBlank(setting.breg_Stamp_Name__c)) continue;
            StampResponse resp = new StampResponse();
            resp.StampName = setting.breg_Stamp_Name__c;
            resp.StampLabel = setting.breg_Stamp_Label__c;
            resp.IncludesDate = setting.breg_Includes_Date__c;
            resp.DatePosLeft = setting.breg_Date_Position_Left__c != null ? String.valueOf(setting.breg_Date_Position_Left__c) : null;
            resp.DatePosTop = setting.breg_Date_Position_Top__c != null ? String.valueOf(setting.breg_Date_Position_Top__c) : null;
            resp.DatePosBottom = setting.breg_Date_Position_Bottom__c != null ? String.valueOf(setting.breg_Date_Position_Bottom__c) : null;
            resp.DatePosRight = setting.breg_Date_Position_Right__c != null ? String.valueOf(setting.breg_Date_Position_Right__c) : null;
            resp.StampImageBase64 = stampNameToBase64.containsKey(setting.breg_Stamp_Name__c) ? stampNameToBase64.get(setting.breg_Stamp_Name__c) : '';
            resp.DateFormat = setting.breg_Date_format__c != null ? setting.breg_Date_format__c : 'MM/dd/yyyy hh:mm tt';
            result.stamps.add(resp);
        }

        return result;
    }
    private static List<BREG_Stamp_Setting__c> getUserStamps(Id userId, Id profileId) {
        List<BREG_Stamp_Setting__c> allUserStamps = new List<BREG_Stamp_Setting__c>();
        // Add any hardcoded or additional stamps here if needed
         List<BREG_Stamp__mdt> mdtStamps = [SELECT DeveloperName, MasterLabel,                                                breg_Date_Position_Left__c, breg_Date_Position_Top__c,
                                               breg_Date_Position_Bottom__c, breg_Date_Position_Right__c,
                                               breg_Includes_Date__c,breg_Stamp_Code__c,breg_Stamp_Image_Name__c,
                                               breg_Stamp_Label__c,breg_Date_Format__c 
                                        FROM BREG_Stamp__mdt];     

        List<BREG_Stamp_Setting__c> allSettings =  [SELECT  breg_Stamp_Name__c, breg_Stamp_Codes__c, breg_Stamp_Label__c, breg_Includes_Date__c,
                        breg_Date_Position_Left__c, breg_Date_Position_Top__c,
                        breg_Date_Position_Bottom__c, breg_Date_Position_Right__c, SetupOwnerId, breg_Date_Format__c
                FROM    BREG_Stamp_Setting__c
                WHERE   SetupOwnerId = :userId
                OR      SetupOwnerId = :profileId];
            Set<String> allStampCodes = new Set<String>();
            for (BREG_Stamp_Setting__c setting : allSettings) {
                if (setting.breg_Stamp_Codes__c!=null)
                    allStampCodes.addAll(setting.breg_Stamp_Codes__c.split(','));            
                allUserStamps.add(setting);//default user/profile stamps
            }

            BREG_Stamp_Setting__c orgDefault = BREG_Stamp_Setting__c.getOrgDefaults();
            if (orgDefault!=null && orgDefault.breg_Stamp_Name__c != null) {
                allSettings.add(orgDefault);//default org stamp
                
                if (orgDefault.breg_Stamp_Codes__c!=null)
                    allStampCodes.addAll(orgDefault.breg_Stamp_Codes__c.split(','));
            }
        for (BREG_Stamp__mdt mdt : mdtStamps) {
            if (mdt.breg_Stamp_Code__c == null || !allStampCodes.contains(mdt.breg_Stamp_Code__c)) {
                continue;
            }
            BREG_Stamp_Setting__c setting = new BREG_Stamp_Setting__c();
            setting.breg_Stamp_Name__c = mdt.breg_Stamp_Image_Name__c;
            setting.breg_Stamp_Label__c = mdt.breg_Stamp_Label__c;
            setting.breg_Includes_Date__c = mdt.breg_Includes_Date__c;
            setting.breg_Date_Position_Left__c = mdt.breg_Date_Position_Left__c;
            setting.breg_Date_Position_Top__c = mdt.breg_Date_Position_Top__c;
            setting.breg_Date_Position_Bottom__c = mdt.breg_Date_Position_Bottom__c;
            setting.breg_Date_Position_Right__c = mdt.breg_Date_Position_Right__c;
            setting.breg_Date_format__c = mdt.breg_Date_format__c;
            allUserStamps.add(setting);
        }
        return allUserStamps;
    }
}