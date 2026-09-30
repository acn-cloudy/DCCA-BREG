/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for CashierCodeLookup
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
@isTest
public class CashierCodeLookupTest {

    @isTest
    public static void Test1(){
        
        User user = new user();
        user.Id = UserInfo.getUserId();
        user.Division__c = 'PVL';
        update user;
        
		CashierCode__c cc = new CashierCode__c();
        cc.Name = '000 - Test';
        cc.Division__c = 'PVL';
        insert cc;
        
		// Run the code
        Test.startTest();
        List<CashierCode__c> codes = CashierCodeLookup.searchCodes('000');
        Test.stopTest();
        
        // Verify Results
        System.assertEquals(1, codes.size());
    }
}