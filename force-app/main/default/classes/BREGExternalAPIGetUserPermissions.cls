@RestResource(urlMapping='/api/getBregUserPermissions')
global with sharing class BREGExternalAPIGetUserPermissions {
    private static Set<String> BREG_CUSTOM_PERMISSION_NAMES = new Set<String>{'BREG_Publish_Documents'};
    global class Response {
        public List<BREGUserPermission> permissions { get; set; }
        public String errorMessage { get; set; }
    }
    global class BREGUserPermission {
        public String permissionName { get; set; }  
        public Boolean isAvailable { get; set; }  
    }

    @HttpGet
    global static Response getUserPermissions() {
        Response result = new Response();
        result.permissions = new List<BREGUserPermission>();

        // Get current user and profile
        Id userId = UserInfo.getUserId();
        Id profileId = UserInfo.getProfileId();
        // Query all defined custom permissions in the org
        List<CustomPermission> allCustomPermissions = [
            SELECT DeveloperName
            FROM CustomPermission
            LIMIT 1000
        ];

        // Check each permission against the current user’s access
        for (CustomPermission cp : allCustomPermissions) {
            if (BREG_CUSTOM_PERMISSION_NAMES.contains(cp.DeveloperName)
                && FeatureManagement.checkPermission(cp.DeveloperName)) {
                BREGUserPermission permission = new BREGUserPermission();
                permission.permissionName = cp.DeveloperName;
                permission.isAvailable = true;
                result.permissions.add(permission);
            }
        }

        return result;
    }
}