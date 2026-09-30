public class ProfileSelector {
    public static List<Profile> getProfiles(List<String> profileNames) {
        return [SELECT Id, Name FROM Profile WHERE Name in: profileNames];
    }

    public static List<Profile> getProfileByName(String profileName) {
        return [SELECT Id FROM Profile WHERE Name =: profileName];
    }
    public static List<Profile> getProfilesWithKeyword(String keyword) {
        String profileName = '%' + keyword + '%';
        return [SELECT Id FROM Profile WHERE Name like: profileName];
    }
}