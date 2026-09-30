/*
* ─────────────────────────────────────────────────────────
* Used for the logics for the utilities
* ─────────────────────────────────────────────────────────
* PacPoint-AZ011119 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-11-01
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class GlobalUtilities {
    public final static String STATUSZI = 'ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)';
    private static String integrationProfileId = '';

    private static Map<String,String> prefix2SobjType;
    public static Map<String,String> getPrefixObjMap() {
        if(prefix2SobjType == null )
            prefix2SobjType = getPrefixToSObjectType();
        return prefix2SobjType;
    }

    public static String getIntegrationProfileId() {
        if (integrationProfileId != null && String.isEmpty(integrationProfileId)) {
            List<Profile> integrationProfile = [SELECT Id FROM Profile WHERE Name = 'Integration' LIMIT 1];
            if (!integrationProfile.isEmpty()) {
                integrationProfileId = integrationProfile[0].Id;
            }
        }

        return integrationProfileId;
    }
    
    public static String convertDate(Date dValue) {   
        String year = dValue.year() + '';
        String month = dValue.month() + '';
        String day = dValue.day()+ '';
        if(day.length() == 1) {
            day = '0'+ day;
        } 
        if(month.length() == 1) {
                month = '0'+ month;
        } 
        if(year.length() == 4) {
            year = year.substring(2);
        }
        String strValue = month + '/' + day + '/' + year;
        return strValue;
    }
    public static Map<String, String> getPrefixToSObjectType() {
        Map<String,String> keys = new Map<String,String>();
        Map<String,Schema.SobjectType> describe = Schema.getGlobalDescribe();
        for(String s:describe.keyset())
            keys.put(describe.get(s).getDescribe().getKeyPrefix(),s);
        return keys;
    }

    public static String convertIdsToIdStr(List<Id> idList) {
        List<String> idStrList = new List<String>();
        for (Id singleId : idList) {
            idStrList.add('\'' + singleId + '\'');
        }
        String idStr = '( ' + String.join(idStrList, ',') + ') ';
        return idStr;
    }
}