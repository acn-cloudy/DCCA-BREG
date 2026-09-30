@IsTest 
public class fflibe_ApplicationTest {

    static void setMockMdt() {
        fflibe_Application.selectorMdt = new fflibe_Selector__mdt[] {
            new fflibe_Selector__mdt(SObjectApiName__c = 'Account', ApexClassName__c = 'fflibe_TestAccountsSelector'),
            new fflibe_Selector__mdt(SObjectApiName__c = 'Contact', ApexClassName__c = 'fflibe_TestContactsSelector')
        };
        fflibe_Application.domainMdt = new fflibe_Domain__mdt[] {
            new fflibe_Domain__mdt(SObjectApiName__c = 'Contact', ApexClassName__c = 'fflibe_TestContactsDomain'),
            new fflibe_Domain__mdt(SObjectApiName__c = 'Account', ApexClassName__c = 'fflibe_TestAccountsDomain')
        };
    }

    @IsTest 
    static void testServiceFactory() {
        // test that service methods are constructable
        fflibe_TestAccountService accService = fflibe_TestAccountService.INSTANCE;
        fflibe_TestContactService conService = fflibe_TestContactService.INSTANCE;

        // test that service methods are mockable
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        fflibe_TestAccountService mockfflibe_ApplicationTestAccountService = (fflibe_TestAccountService)mocks.mock(fflibe_TestAccountService.class);
        fflibe_ApplicationImpl.SERVICE.setMock(fflibe_TestAccountService.class, mockfflibe_ApplicationTestAccountService);
        
        fflibe_TestAccountService res = (fflibe_TestAccountService)fflibe_ApplicationImpl.SERVICE.newInstance(fflibe_TestAccountService.class);
        System.assertNotEquals(accService, res);
        System.assertEquals(mockfflibe_ApplicationTestAccountService, res);
    }

    @IsTest 
    static void testSelectorFactory() {
        setMockMdt();
        Test.startTest();
        // test that selectors are constructable
        fflibe_TestAccountsSelector accSelector = fflibe_TestAccountsSelector.INSTANCE;
        fflibe_TestContactsSelector conSelector = fflibe_TestContactsSelector.INSTANCE;

        // test that selectors are mockable
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        fflibe_TestAccountsSelector mockfflibe_TestAccountsSelector = (fflibe_TestAccountsSelector)mocks.mock(fflibe_TestAccountsSelector.class);
        fflibe_ApplicationImpl.SELECTOR.setMock1(Account.sObjectType, mockfflibe_TestAccountsSelector);
        
        fflibe_TestAccountsSelector res = (fflibe_TestAccountsSelector)fflibe_ApplicationImpl.SELECTOR.newInstance(Account.getSObjectType());
        System.assertNotEquals(accSelector, res);
        System.assertEquals(mockfflibe_TestAccountsSelector, res);
        Test.stopTest();
    }

    @IsTest 
    static void testDomainFactory() {
        setMockMdt();
        Contact[] cons = new Contact[] { new Contact(), new Contact() };
        Account[] accs = new Account[] { new Account(), new Account() };
        Test.startTest();
        // test that domains are constructable
        fflibe_TestAccountsDomain accDomain = fflibe_TestAccountsDomain.newInstance(accs);
        fflibe_TestContactsDomain conDomain = fflibe_TestContactsDomain.newInstance(cons);

        // test that domains are mockable
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        fflibe_TestContactsDomain mockContactsDomain = (fflibe_TestContactsDomain)mocks.mock(fflibe_TestContactsDomain.class);
        fflibe_ApplicationImpl.DOMAIN.setMock1(Contact.getSObjectType(), (fflib_ISObjectDomain)mockContactsDomain);
        fflibe_TestAccountsDomain mockfflibe_TestAccountsDomain = (fflibe_TestAccountsDomain)mocks.mock(fflibe_TestAccountsDomain.class);
        fflibe_ApplicationImpl.DOMAIN.setMock1(Account.getSObjectType(), (fflib_ISObjectDomain)mockfflibe_TestAccountsDomain);
        
        fflibe_TestContactsDomain conRes = (fflibe_TestContactsDomain)fflibe_ApplicationImpl.DOMAIN.newInstance(cons);
        System.assertNotEquals(conDomain, conRes);
        System.assertEquals(mockContactsDomain, conRes);
        
        Test.stopTest();
    }

    
}