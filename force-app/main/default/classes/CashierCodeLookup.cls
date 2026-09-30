/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Cashier Code Lookup component - Simulates a cashier code lookup in lightning
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint-LC040819 - Created for DCCA phase 1
* @author       Lucian Ciobanu - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class CashierCodeLookup {

    @AuraEnabled
    public static List<CashierCode__c> searchCodes(string code) {
        User myUser = [SELECT Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        List<string> divisions = new List<string>();
        if (myuser.Division__c != null)
            divisions = myUser.Division__c.split(';');
        string codeSearch = code + '%';
        return [SELECT Id, Name, Amount__c FROM CashierCode__c WHERE Name LIKE :codeSearch AND Division__c IN :divisions ORDER BY Name];
    }
    
}