public with sharing class RecordAccessUtil {

    @AuraEnabled
    public static Map<Id, String> getAccessLevels(Id[] relatedRecordIds, Id userId) {
        try {
            UserRecordAccess[] uras = UserRecordAccessSelector.INSTANCE.getAccessToRecords(userId, new Set<Id>(relatedRecordIds));
            return UserRecordAccessesDomain.newInstance(uras).getRecordIdToMaxAccessLevelMap();
        } catch (Exception e) {
            CustomLogger.logException(e, 'RecordAccessUtil', 'getAccessLevels', 'userid = ' + userId + ', rec ids = ' + relatedRecordIds);
            throw AuraExceptionUtil.getAuraExceptionWithApexMessage(e);
        }
    }
    @InvocableMethod(category='Utilities' label='Record Access Checker' description='Checks access level for the given records Ids')
    public static String[] getAccessLevels(Id[] relatedRecordIds){
        try{
            UserRecordAccess[] uras = UserRecordAccessSelector.INSTANCE.getAccessToRecords(UserInfo.getUserId(), new Set<Id>(relatedRecordIds));
            Map<Id, String> accessMap = UserRecordAccessesDomain.newInstance(uras).getRecordIdToMaxAccessLevelMap();

            String[] accessLevels = new List<String>();
            for(Id recordId : relatedRecordIds) {
                accessLevels.add(accessMap.get(recordId));
            }

            return accessLevels;
        } catch (Exception e) {
            CustomLogger.logException(e, 'RecordAccessUtil', 'getAccessLevels', 'userid = ' + UserInfo.getUserId() + ', rec ids = ' + relatedRecordIds);
            throw new RecordAccessUtilException(e);
        }
    }

    public class RecordAccessUtilException extends Exception {}

}