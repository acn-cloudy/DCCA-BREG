@isTest
public class BREGNotificationsHandlerTest {
    public static Id contactId;
    public static User communityUser;
    public static Id notificationId;

    @testSetup
    static void setupData() {

        UserRole userRole = [SELECT Id FROM UserRole LIMIT 1];
        Profile internalProfile = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];

        User accountOwner = new User(
            FirstName = 'Owner',
            LastName = 'Internal',
            Email = 'notif-owner@example.com',
            Username = 'notif-owner' + System.currentTimeMillis() + '@example.com',
            Alias = 'nownr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = internalProfile.Id,
            UserRoleId = userRole.Id
        );
        insert accountOwner;

        Account acc;
        Contact con;
        System.runAs(accountOwner) {
            acc = new Account(Name = 'Test Business');
            insert acc;

            con = new Contact(LastName = 'Test', Email = 'test@example.com', AccountId = acc.Id);
            insert con;
        }
        contactId = con.Id;

        communityUser = new User(
            LastName = 'test',
            Alias = 'testu',
            Email = 'test@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            ProfileId = [SELECT Id FROM Profile WHERE Name LIKE 'DCCA BREG - CustomerCommunity%' LIMIT 1]
            .Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = contactId
        );
        insert communityUser;

        System.runAs(communityUser) {
            breg_TN_TM_SM__c tn = new breg_TN_TM_SM__c(Name = 'Test TN', breg_Type__c = 'Publicity Rights Name');
            insert tn;
            insert new breg_Fee__c(breg_Record_Type__c = 'Annual Reminder', breg_Fee_Amount__c = 15);
            insert new breg_Fee__c(breg_Record_Type__c = 'Business Alerts', breg_Fee_Amount__c = 20);
            insert new breg_Fee__c(breg_Record_Type__c = 'TNTMSM Reminder', breg_Fee_Amount__c = 2.5);
            breg_Notification__c notif = new breg_Notification__c(
                breg_TN_TM_SM__c = tn.Id,
                breg_Contact__c = con.Id,
                breg_Notification_Category__c = 'Trade Name, Trademark, Service Mark Reminder',
                breg_Start_Date__c = Date.today(),
                breg_End_Date__c = Date.today().addYears(1),
                breg_Is_Email__c = true,
                breg_Status__c = 'Active'
            );
            insert notif;

            notificationId = notif.Id;
        }
    }
    @isTest
    static void testGetCommunityUserContactId() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        Id contactId = communityUser.ContactId;
        System.runAs(communityUser) {
            Id result = BREGUtils.getCommunityUserContactId();
            System.assertEquals(contactId, result);
        }
    }

    @isTest
    static void testGetNotificationCategoryPrices() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            Map<String, Decimal> prices = BREGNotificationsHandler.getNotificationCategoryPrices();
            System.assertEquals(15, prices.get('Annual Report Reminder'));
        }
    }

    @isTest
    static void testGetCategoryToFeeCodeMap() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            Map<String, String> categoryToFeeCodeMap = BREGNotificationsHandler.getCategoryToFeeCodeMap();
            System.assert(categoryToFeeCodeMap.containsKey('Annual Report Reminder'), 'Map should contain Annual Report Reminder');
        }
    }

    @isTest
    static void testCreateNotifications() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        System.runAs(communityUser) {
            BREGNotificationsHandler.NotificationItem notif = new BREGNotificationsHandler.NotificationItem();
            notif.id = 'Annual Report Reminder';

            BREGNotificationsHandler.NotificationWrapper wrapper = new BREGNotificationsHandler.NotificationWrapper();
            wrapper.businessName = 'Test Business';
            wrapper.recordId = acc.Id;
            wrapper.sourceObject = 'Account';
            wrapper.notifications = new List<BREGNotificationsHandler.NotificationItem>{ notif };

            String jsonInput = JSON.serialize(new List<BREGNotificationsHandler.NotificationWrapper>{ wrapper });

            Test.startTest();
            BREGNotificationsHandler.createNotifications(jsonInput, null, false);
            Test.stopTest();
            List<breg_Notification__c> result = [
                SELECT Id, breg_Account__c, breg_Notification_Category__c
                FROM breg_Notification__c
                WHERE breg_Account__c = :acc.Id
            ];
            System.assertEquals(1, result.size());
            System.assertEquals('Annual Report Reminder', result[0].breg_Notification_Category__c);
        }

    }

    @isTest
    static void testUpdateMultipleNotifications() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            breg_Notification__c notif = [
                SELECT Id, breg_Status__c, breg_Recipient_Email__c
                FROM breg_Notification__c
                WHERE breg_Notification_Category__c = 'Trade Name, Trademark, Service Mark Reminder'
            ];

            Map<Id, Map<String, Object>> updates = new Map<Id, Map<String, Object>>();
            updates.put(notif.Id, new Map<String, Object>{ 'breg_Status__c' => 'Paused', 'breg_Recipient_Email__c' => 'updated@example.com' });

            Test.startTest();
            BREGNotificationsHandler.updateMultipleNotifications(updates);
            Test.stopTest();

            notif = [
                SELECT breg_Status__c, breg_Recipient_Email__c
                FROM breg_Notification__c
                WHERE Id = :notif.Id
            ];

            System.assertEquals('Paused', notif.breg_Status__c, 'Status should be updated');
            System.assertEquals('updated@example.com', notif.breg_Recipient_Email__c, 'Email should be updated');
        }
    }

    @isTest
    static void testGetMissingStandardNotificationsForEntities() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            Id accId = [SELECT Id FROM Account LIMIT 1].Id;
            Map<Id, Boolean> result = BREGNotificationsHandler.getMissingStandardNotificationsForEntities(new List<Id>{ accId }, '');
            System.assert(result.containsKey(accId));
            System.assert(result.get(accId), 'Should return true because nothing is subscribed yet');
        }
    }

    @isTest
    static void testCheckNotificationsForEntitiesAndCategories() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            Id accId = [SELECT Id FROM Account LIMIT 1].Id;
            BREGNotificationsHandler.NotificationCheckInput input = new BREGNotificationsHandler.NotificationCheckInput();
            input.entityId = accId;
            input.categoryName = 'Annual Report Reminder';
            String inputJson = JSON.serialize(new List<BREGNotificationsHandler.NotificationCheckInput>{ input });

            Map<Id, Map<String, Boolean>> result = BREGNotificationsHandler.checkNotificationsForEntitiesAndCategories(inputJson);
            System.assert(result.containsKey(accId));
            System.assertEquals(false, result.get(accId).get('Annual Report Reminder'));
        }
    }

    @isTest
    static void testGetAvailableCategoriesByObject() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            Id accId = [SELECT Id FROM Account LIMIT 1].Id;
            Map<String, Object> rawInput = new Map<String, Object>{
                'entityIdToObjectType' => new Map<String, String>{ accId => 'Account' },
                'entityIdToTypeField' => new Map<String, String>{ accId => null }
            };
            String json = JSON.serialize(rawInput);

            Map<String, List<String>> result = BREGNotificationsHandler.getAvailableCategoriesByObject(json);
            System.assert(result.containsKey(accId));
            System.assert(result.get(accId).contains('Annual Report Reminder'));
        }

    }

    @isTest
    static void testGetNotificationsForCurrentUser() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            Id accId = [SELECT Id FROM Account WHERE Name = 'Test Business' LIMIT 1].Id;
            breg_Notification__c existingNotification = new breg_Notification__c(
                breg_Account__c = accId,
                breg_Contact__c = communityUser.ContactId,
                breg_Notification_Category__c = 'Annual Report Reminder',
                breg_Start_Date__c = Date.today(),
                breg_End_Date__c = Date.today().addYears(1),
                breg_Is_Email__c = true,
                breg_Status__c = 'Paused',
                breg_Recipient_Email__c = 'override@example.com'
            );
            insert existingNotification;

            List<BREGNotificationsHandler.NotificationRecordWrapper> wrappers = BREGNotificationsHandler.getNotificationsForCurrentUser();

            System.assert(wrappers.size() > 0, 'Expected at least one notification for current community user');

            Boolean foundExpectedNotification = false;
            for (BREGNotificationsHandler.NotificationRecordWrapper wrapper : wrappers) {
                if (wrapper.recordId == existingNotification.Id) {
                    foundExpectedNotification = true;
                    System.assertEquals('Paused', wrapper.status, 'Paused notification should remain Paused in response');
                    System.assertEquals('override@example.com', wrapper.recipient, 'Recipient should prefer override email');
                    System.assertEquals('Email', wrapper.deliveryMethod, 'Delivery method should be Email when breg_Is_Email__c is true');
                    System.assertEquals(
                        'Test Business',
                        wrapper.associatedEntity,
                        'Associated entity should resolve account name for account notifications'
                    );
                    break;
                }
            }

            System.assertEquals(true, foundExpectedNotification, 'Expected inserted annual reminder notification in the result set');
        }
    }

    @isTest
    static void testGetMissingStandardNotificationsForEntitiesWithCategoryFilter() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            Id accId = [SELECT Id FROM Account WHERE Name = 'Test Business' LIMIT 1].Id;
            Id tnId = [SELECT Id FROM breg_TN_TM_SM__c LIMIT 1].Id;

            Map<Id, Boolean> tnResult = BREGNotificationsHandler.getMissingStandardNotificationsForEntities(new List<Id>{ tnId }, 'tn');
            System.assert(tnResult.containsKey(tnId), 'TN entity should be included in TN category check result');
            System.assertEquals(true, tnResult.get(tnId), 'TN filtered check should detect missing TN-specific standard notifications');

            Map<Id, Boolean> annualResult = BREGNotificationsHandler.getMissingStandardNotificationsForEntities(new List<Id>{ accId }, 'annual');
            System.assert(annualResult.containsKey(accId), 'Account should be included in annual category check result');
            System.assertEquals(true, annualResult.get(accId), 'Annual filtered check should detect missing annual standard notifications');

            Map<Id, Boolean> businessResult = BREGNotificationsHandler.getMissingStandardNotificationsForEntities(new List<Id>{ accId }, 'business');
            System.assert(businessResult.containsKey(accId), 'Account should be included in business category check result');
            System.assertEquals(
                false,
                businessResult.get(accId),
                'Business filter should reflect current metadata visibility rules for this account context'
            );

            Map<Id, Boolean> unknownResult = BREGNotificationsHandler.getMissingStandardNotificationsForEntities(new List<Id>{ accId }, 'unknown');
            System.assert(unknownResult.containsKey(accId), 'Account should be included even for unknown category filter');
            System.assertEquals(false, unknownResult.get(accId), 'Unknown category filter should not evaluate categories and should return false');
        }
    }

    private class LocalNotificationCheckInput {
        public Id entityId { get; set; }
        public String categoryName { get; set; }
    }

    @isTest
    static void testWithTN_TM_SM_Record() {
        User communityUser = [SELECT Id, ContactId, Username FROM User WHERE Username LIKE 'testuser%@example.com' LIMIT 1];
        System.runAs(communityUser) {
            breg_TN_TM_SM__c tn = [SELECT Id, breg_Type__c FROM breg_TN_TM_SM__c LIMIT 1];

            Map<Id, Boolean> result = BREGNotificationsHandler.getMissingStandardNotificationsForEntities(new List<Id>{ tn.Id }, '');
            System.assert(result.containsKey(tn.Id), 'TN should be present in the result');
            System.assertEquals(true, result.get(tn.Id), 'Notification should be missing initially');

            Map<String, Object> rawInput = new Map<String, Object>{
                'entityIdToObjectType' => new Map<String, String>{ tn.Id => 'breg_TN_TM_SM__c' },
                'entityIdToTypeField' => new Map<String, String>{ tn.Id => 'Publicity Rights Name' }
            };
            String json = JSON.serialize(rawInput);
            Map<String, List<String>> categories = BREGNotificationsHandler.getAvailableCategoriesByObject(json);
            System.assert(categories.containsKey(tn.Id), 'Result should contain TN Id');
            System.assertEquals(true, categories.get(tn.Id).contains('Publicity Rights Name Renewal Reminder'));

            LocalNotificationCheckInput input = new LocalNotificationCheckInput();
            input.entityId = tn.Id;
            input.categoryName = 'Publicity Rights Name Renewal Reminder';
            String inputJsonString = '[{"entityId": "' + tn.Id + '", "categoryName": "Publicity Rights Name Renewal Reminder"}]';
            //List<LocalNotificationCheckInput> inputsList = new List<LocalNotificationCheckInput>();
            //inputsList.add(input);
            //String inputJson = JSON.serialize(inputsList);

            Map<Id, Map<String, Boolean>> existsMap = BREGNotificationsHandler.checkNotificationsForEntitiesAndCategories(inputJsonString);
            System.assertEquals(false, existsMap.get(tn.Id).get('Publicity Rights Name Renewal Reminder'));
        }
    }
}