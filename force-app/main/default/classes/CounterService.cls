/*
* ─────────────────────────────────────────────────────────
* class for the Custom Setting Service.
* ─────────────────────────────────────────────────────────
* PacPoint-AZ291119 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-11-29
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class CounterService {
    private static Decimal apprenticeApplicationCounter {set;get;}
    private static ApprenticeApplicationCounter__c setting {set;get;}
    public static String getApprenticeApplicationCounter() {
        setting = ApprenticeApplicationCounter__c.getOrgDefaults();
        if( setting.Counter__c == null) setting.Counter__c = 1;
        if (system.today() != setting.ResetDate__c)  {
            setting.Counter__c = 1;
            setting.ResetDate__c = system.today();
        } 

        Decimal rInteger = setting != null ? setting.Counter__c : 1;
        String countString = convertToApprenticeApplicationString();
        return countString;

    }
    private static String convertToString(Decimal inNumber) {
        String outString = '';
        if (inNumber > 0 && inNumber < 10) {
            outString = '00' + string.valueof(inNumber.format());
        } else if (inNumber >= 10 && inNumber < 100) {
            outString = '0' + string.valueof(inNumber.format());
        } else {
            outString = string.valueof(inNumber.format());
        }
        return outString;
    }

    private static String convertToApprenticeApplicationString() {
        if(apprenticeApplicationCounter == null ) {
            apprenticeApplicationCounter = setting.Counter__c;
        }

        Date resetDate = setting.ResetDate__c;
        String year = resetDate.year() + '';
        String month = resetDate.month() + '';
        String day = resetDate.day() + '';
        if(day.length() == 1) {
            day = ('0'+day);
        }
        if(year.length() == 4) {
            year = year.substring(2);
        }
        String tagNumber = 'R-' + year  + month + day + convertToString(apprenticeApplicationCounter);
        apprenticeApplicationCounter ++;
        
        return tagNumber;
    }
    public static void saveApprenticeApplication() {
        if(apprenticeApplicationCounter == null ) return;
        ApprenticeApplicationCounter__c setting = ApprenticeApplicationCounter__c.getOrgDefaults();
        setting.Counter__c = apprenticeApplicationCounter;
        setting.ResetDate__c = system.today();
        upsert setting;
        apprenticeApplicationCounter = null;
    }
    
}