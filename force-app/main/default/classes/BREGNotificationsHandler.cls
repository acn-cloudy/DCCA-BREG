public without sharing class BREGNotificationsHandler {
    public class NotificationWrapper {
        @AuraEnabled
        public String businessName;
        @AuraEnabled
        public String certificationNumber;
        @AuraEnabled
        public String createdDate;
        @AuraEnabled
        public String expirationDate;
        @AuraEnabled
        public String fileNumber;
        @AuraEnabled
        public String recordId;
        @AuraEnabled
        public String recordType;
        @AuraEnabled
        public String sourceObject;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public List<NotificationItem> notifications;
    }

    public class NotificationItem {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public Boolean action;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public String fileNumber;
        @AuraEnabled
        public String fileCertNumber;
        @AuraEnabled
        public String expirationDate;
        @AuraEnabled
        public String cost;
        @AuraEnabled
        public String recordId;
        @AuraEnabled
        public Boolean checkedItem;
        @AuraEnabled
        public Boolean disabledItem;
        @AuraEnabled
        public String sms;
    }

    public class NotificationRecordWrapper {
        @AuraEnabled
        public String subscriptionName;
        @AuraEnabled
        public String deliveryMethod;
        @AuraEnabled
        public String associatedEntity;
        @AuraEnabled
        public Date expirationDate;
        @AuraEnabled
        public Id associatedContact;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Id recordId;
        @AuraEnabled
        public String recipient;
        @AuraEnabled
        public String status;
    }

    @AuraEnabled(cacheable=true)
    public static List<NotificationRecordWrapper> getNotificationsForCurrentUser() {
        Id currentUserContactId = BREGUtils.getCommunityUserContactId();
        List<CategoryMetadata> paidNotificationsCategories = loadCategoryMetadataWithPrices();
        Set<String> paidNotificationsCategoriesNames = new Set<String>();
        for (CategoryMetadata category : paidNotificationsCategories) {
            paidNotificationsCategoriesNames.add(category.category);
        }

        List<breg_Notification__c> notifications = [
            SELECT
                Id,
                breg_Start_Date__c,
                breg_End_Date__c,
                breg_Is_Email__c,
                breg_Is_SMS__c,
                breg_Account__c,
                breg_Account__r.Name,
                breg_TN_TM_SM__c,
                breg_TN_TM_SM__r.Name,
                breg_Contact__c,
                breg_Contact__r.Email,
                breg_Status__c,
                breg_Recipient_Email__c,
                breg_Notification_Category__c
            FROM breg_Notification__c
            WHERE
                breg_Contact__c = :currentUserContactId
                AND (breg_End_Date__c > TODAY
                OR breg_End_Date__c = NULL)
                AND breg_Notification_Category__c IN :paidNotificationsCategoriesNames
        ];
        List<NotificationRecordWrapper> resultList = new List<NotificationRecordWrapper>();
        for (breg_Notification__c notif : notifications) {
            NotificationRecordWrapper wrapper = new NotificationRecordWrapper();
            wrapper.recordId = notif.Id;
            wrapper.associatedContact = currentUserContactId;
            wrapper.subscriptionName = notif.breg_Notification_Category__c;
            wrapper.startDate = notif.breg_Start_Date__c;
            wrapper.expirationDate = notif.breg_End_Date__c;
            wrapper.recipient = String.isEmpty(notif.breg_Recipient_Email__c) ? notif.breg_Contact__r.Email : notif.breg_Recipient_Email__c;
            wrapper.status = notif.breg_Status__c == 'Inactive' ? 'Paused' : notif.breg_Status__c;
            wrapper.deliveryMethod = notif.breg_Is_Email__c ? 'Email' : 'SMS';
            wrapper.associatedEntity = notif.breg_Account__c == null ? notif.breg_TN_TM_SM__r.Name : notif.breg_Account__r.Name;
            resultList.add(wrapper);
        }
        return resultList;
    }

    @AuraEnabled
    public static void updateMultipleNotifications(Map<Id, Map<String, Object>> updatesById) {
        if (updatesById == null || updatesById.isEmpty()) {
            throw new AuraHandledException('Input is empty or null.');
        }

        List<breg_Notification__c> notificationsToUpdate = new List<breg_Notification__c>();

        for (Id recordId : updatesById.keySet()) {
            Map<String, Object> fields = updatesById.get(recordId);

            if (fields == null || fields.isEmpty()) {
                continue;
            }

            breg_Notification__c notification = new breg_Notification__c(Id = recordId);

            for (String fieldName : fields.keySet()) {
                try {
                    notification.put(fieldName, fields.get(fieldName));
                } catch (Exception e) {
                    throw new AuraHandledException('Invalid field "' + fieldName + '" for record ' + recordId);
                }
            }

            notificationsToUpdate.add(notification);
        }

        if (!notificationsToUpdate.isEmpty()) {
            try {
                update notificationsToUpdate;
            } catch (DmlException e) {
                throw new AuraHandledException('Failed to update notifications: ' + e.getMessage());
            }
        }
    }

    public class CategoryMetadata {
        public String category;
        public String feeCode;
        public Decimal amount;
        public Id feeId;

        public CategoryMetadata(String category, String feeCode, Decimal amount, Id feeId) {
            this.category = category;
            this.feeCode = feeCode;
            this.amount = amount;
            this.feeId = feeId;
        }
    }

    private static List<CategoryMetadata> loadCategoryMetadataWithPrices() {
        List<breg_Notification_Category__mdt> categories = getAllCategories();

        // Create mapping from category names to fee record types
        Map<String, String> categoryToFeeRecordType = new Map<String, String>{
            'Annual Report Reminder' => 'Annual Reminder',
            'My Business Alerts' => 'Business Alerts',
            'Trade Name, Trade Mark, Service Mark Reminder' => 'TNTMSM Reminder',
            'Trade Name, Trademark, Service Mark Reminder' => 'TNTMSM Reminder'
        };

        // Collect all fee record types we need to query
        Set<String> feeRecordTypes = new Set<String>();
        for (breg_Notification_Category__mdt cat : categories) {
            String mappedRecordType = categoryToFeeRecordType.get(cat.breg_Subscription_Category__c);
            if (mappedRecordType != null) {
                feeRecordTypes.add(mappedRecordType);
            }
        }

        // Query Fee records by record type
        Map<String, breg_Fee__c> recordTypeToFee = new Map<String, breg_Fee__c>();
        for (breg_Fee__c fee : [SELECT Id, breg_Record_Type__c, breg_Fee_Amount__c, breg_Fee_Code__c FROM breg_Fee__c WHERE breg_Record_Type__c IN :feeRecordTypes]) {
            recordTypeToFee.put(fee.breg_Record_Type__c, fee);
        }

        // Build result list
        List<CategoryMetadata> result = new List<CategoryMetadata>();
        for (breg_Notification_Category__mdt cat : categories) {
            String mappedRecordType = categoryToFeeRecordType.get(cat.breg_Subscription_Category__c);
            breg_Fee__c fee = mappedRecordType != null ? recordTypeToFee.get(mappedRecordType) : null;
            
            Decimal amount = fee != null ? fee.breg_Fee_Amount__c : 0;
            String feeCode = fee != null ? fee.breg_Fee_Code__c : cat.breg_Fee_Code__c;
            Id feeId = fee != null ? fee.Id : null;
            
            result.add(
                new CategoryMetadata(cat.breg_Subscription_Category__c, feeCode, amount, feeId)
            );
        }
        return result;
    }

    @AuraEnabled
    public static String getCurrentUserEmail() {
        Id currentUserId = UserInfo.getUserId();
        String contactEmail = [SELECT Contact.Email FROM User WHERE Id = :currentUserId LIMIT 1].Contact.Email;

        if (contactEmail == null) {
            throw new AuraHandledException('Contact not linked to user.');
        }
        return contactEmail;
    }

    @AuraEnabled
    public static void createNotifications(String jsonInput, Id contactToUse, Boolean isFree) {
        Id communityUserContactId = BREGUtils.getCommunityUserContactId();
        List<NotificationWrapper> inputList = (List<NotificationWrapper>) JSON.deserialize(jsonInput, List<NotificationWrapper>.class);
        List<breg_Notification__c> recordsToInsert = new List<breg_Notification__c>();
        Contact contact = contactToUse != null
            ? [SELECT Id, Email FROM Contact WHERE Id = :contactToUse LIMIT 1]
            : null;

        Date today = Date.today();
        Date endDate = today.addYears(1);
        Map<String, Id> feeIds = new Map<String, Id>();
        for (CategoryMetadata meta : loadCategoryMetadataWithPrices()) {
            feeIds.put(meta.category, meta.feeId);
        }
        for (NotificationWrapper item : inputList) {
            for (NotificationItem notif : item.notifications) {
                breg_Notification__c n = new breg_Notification__c();
                String email = contactToUse != null ? contact.Email : getCurrentUserEmail();
                n.breg_Start_Date__c = today;
                if (isFree) {
                    n.breg_End_Date__c = null; // No end date for free notifications
                    n.breg_Free_Of_Charge__c = true;
                } else {
                    n.breg_End_Date__c = endDate;
                }
                n.breg_Is_Email__c = true;
                n.breg_Contact__c = contactToUse != null ? contactToUse : communityUserContactId;
                n.breg_Notification_Category__c = notif.id;
                n.breg_Fee__c = feeIds.get(n.breg_Notification_Category__c);
                n.breg_Recipient_Email__c = email;
                if (item.sourceObject == 'Account') {
                    n.breg_Account__c = item.recordId;
                } else {
                    n.breg_TN_TM_SM__c = item.recordId;
                }

                recordsToInsert.add(n);
            }
        }

        insert recordsToInsert;
    }

    private static final String FIELD_BASED_DISPLAY = 'Depends on Related Object Field';
    private static final String ALWAYS_HIDE_DISPLAY = 'Always Hide';
    private static final String ALWAYS_SHOW_DISPLAY = 'Always Show Category for Related Object';

    public class NotificationCheckInput {
        @AuraEnabled
        public Id entityId;
        @AuraEnabled
        public String categoryName;
    }

    public class CategoryInfo {
        @AuraEnabled
        public String categoryName;
        @AuraEnabled
        public Decimal amount;
    }

    // === Public Methods ===

    @AuraEnabled
    public static Map<Id, Boolean> getMissingStandardNotificationsForEntities(List<Id> entityIds, String notificationCategory) {
        Map<Id, SObject> entityMap = loadEntities(new Set<Id>(entityIds));
        Map<String, List<breg_Notification_Category__mdt>> categoriesByObject = getCategoryMapByObject();
        Set<String> requiredCategories = extractRequiredCategorySet(categoriesByObject);
        Map<Id, Set<String>> existingCategories = loadNotificationCategoryMap(new Set<Id>(entityIds), requiredCategories);

        // Pre-compute object names for all entity IDs to avoid repeated describe calls in the loop
        Map<Id, String> entityObjectNames = new Map<Id, String>();
        for (Id entityId : entityIds) {
            if (entityId.getSObjectType() == Account.SObjectType) {
                entityObjectNames.put(entityId, 'Account');
            } else {
                entityObjectNames.put(entityId, 'breg_TN_TM_SM__c');
            }
        }

        Map<Id, Boolean> result = new Map<Id, Boolean>();
        for (Id entityId : entityIds) {
            SObject entity = entityMap.get(entityId);
            if (entity == null)
                continue;

            String objectName = entityObjectNames.get(entityId);
            List<breg_Notification_Category__mdt> categories = categoriesByObject.get(objectName);
            if (categories == null)
                continue;

            Set<String> existing = existingCategories.get(entityId);
            Boolean hasMissing = false;

            for (breg_Notification_Category__mdt cat : categories) {
                if (cat.Display_Options__c == ALWAYS_HIDE_DISPLAY)
                    continue;

                if (!String.isBlank(notificationCategory)) {
                    if (notificationCategory.equalsIgnoreCase('tn')) {
                        if (cat.Display_Options__c != FIELD_BASED_DISPLAY)
                            continue;
                    } else if (notificationCategory.equalsIgnoreCase('annual')) {
                        if (String.isBlank(cat.breg_Subscription_Category__c) || !cat.breg_Subscription_Category__c.containsIgnoreCase('Annual'))
                            continue;
                    } else if (notificationCategory.equalsIgnoreCase('business')) {
                        if (String.isBlank(cat.breg_Subscription_Category__c) || !cat.breg_Subscription_Category__c.containsIgnoreCase('Business'))
                            continue;
                    } else {
                        continue;
                    }
                }
                if (cat.Display_Options__c == FIELD_BASED_DISPLAY) {
                    if (!(entity instanceof breg_TN_TM_SM__c))
                        continue;
                    String typeVal = (String) entity.get('breg_Type__c');
                    if (
                        String.isBlank(typeVal) ||
                        String.isBlank(cat.breg_Subscription_Category__c) ||
                        !cat.breg_Subscription_Category__c.containsIgnoreCase(typeVal)
                    )
                        continue;
                }
                if (existing == null || !existing.contains(cat.breg_Subscription_Category__c)) {
                    hasMissing = true;
                    break;
                }
            }

            result.put(entityId, hasMissing);
        }

        return result;
    }

    @AuraEnabled
    public static Map<Id, Map<String, Boolean>> checkNotificationsForEntitiesAndCategories(String jsonInput) {
        List<NotificationCheckInput> inputs = (List<NotificationCheckInput>) JSON.deserialize(jsonInput, List<NotificationCheckInput>.class);
        Set<Id> entityIds = new Set<Id>();
        Set<String> categories = new Set<String>();

        for (NotificationCheckInput input : inputs) {
            entityIds.add(input.entityId);
            categories.add(input.categoryName);
        }

        Map<Id, Set<String>> existing = loadNotificationCategoryMap(entityIds, categories);
        Map<Id, Map<String, Boolean>> result = new Map<Id, Map<String, Boolean>>();

        for (NotificationCheckInput input : inputs) {
            if (!result.containsKey(input.entityId)) {
                result.put(input.entityId, new Map<String, Boolean>());
            }
            Boolean exists = existing.containsKey(input.entityId) && existing.get(input.entityId).contains(input.categoryName);
            result.get(input.entityId).put(input.categoryName, exists);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getNotificationCategoryPrices() {
        Map<String, Decimal> result = new Map<String, Decimal>();
        for (CategoryMetadata meta : loadCategoryMetadataWithPrices()) {
            result.put(meta.category, meta.amount);
        }
        return result;
    }

    public static Map<String, String> getCategoryToFeeCodeMap() {
        Map<String, String> result = new Map<String, String>();
        for (CategoryMetadata meta : loadCategoryMetadataWithPrices()) {
            result.put(meta.category, meta.feeCode);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getAvailableCategoriesByObject(String jsonInput) {
        Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(jsonInput);
        Map<String, String> entityIdToObjectType = extractStringMap(input, 'entityIdToObjectType');
        Map<String, String> entityIdToTypeField = extractStringMap(input, 'entityIdToTypeField');

        Map<String, List<String>> result = new Map<String, List<String>>();
        List<breg_Notification_Category__mdt> allCategories = getAllCategories();
        for (String entityId : entityIdToObjectType.keySet()) {
            String objectType = entityIdToObjectType.get(entityId);
            String entityType = entityIdToTypeField.get(entityId);
            Set<String> visibleCategories = new Set<String>();

            for (breg_Notification_Category__mdt cat : allCategories) {
                if (cat.breg_Related_Object__c != objectType)
                    continue;
                if (cat.Display_Options__c == ALWAYS_HIDE_DISPLAY)
                    continue;

                if (cat.Display_Options__c == ALWAYS_SHOW_DISPLAY) {
                    visibleCategories.add(cat.breg_Subscription_Category__c);
                } else if (cat.Display_Options__c == FIELD_BASED_DISPLAY && entityType != null) {
                    for (String allowed : cat.breg_Subscription_Category__c.split(',')) {
                        if (allowed.trim().containsIgnoreCase(entityType)) {
                            visibleCategories.add(cat.breg_Subscription_Category__c);
                            break;
                        }
                    }
                }
            }
            result.put(entityId, new List<String>(visibleCategories));
        }
        return result;
    }

    // === Private Utility Methods ===

    private static Map<Id, SObject> loadEntities(Set<Id> entityIds) {
        Map<Id, SObject> entityMap = new Map<Id, SObject>();
        List<Id> accIds = new List<Id>();
        List<Id> tnIds = new List<Id>();
        for (Id currentId : entityIds) {
            if (currentId.getSObjectType() == Account.SObjectType) {
                accIds.add(currentId);
            } else {
                tnIds.add(currentId);
            }
        }

        for (breg_TN_TM_SM__c tn : [SELECT Id, breg_Type__c FROM breg_TN_TM_SM__c WHERE Id IN :tnIds]) {
            entityMap.put(tn.Id, tn);
        }
        for (Account acc : [SELECT Id FROM Account WHERE Id IN :accIds]) {
            entityMap.put(acc.Id, acc);
        }
        return entityMap;
    }

    private static Map<String, List<breg_Notification_Category__mdt>> getCategoryMapByObject() {
        Map<String, List<breg_Notification_Category__mdt>> mapByObj = new Map<String, List<breg_Notification_Category__mdt>>();
        for (breg_Notification_Category__mdt cat : getAllCategories()) {
            if (!mapByObj.containsKey(cat.breg_Related_Object__c)) {
                mapByObj.put(cat.breg_Related_Object__c, new List<breg_Notification_Category__mdt>());
            }
            mapByObj.get(cat.breg_Related_Object__c).add(cat);
        }
        return mapByObj;
    }

    private static Set<String> extractRequiredCategorySet(Map<String, List<breg_Notification_Category__mdt>> categoryMap) {
        Set<String> categoriesSet = new Set<String>();
        for (List<breg_Notification_Category__mdt> cats : categoryMap.values()) {
            for (breg_Notification_Category__mdt cat : cats) {
                categoriesSet.add(cat.breg_Subscription_Category__c);
            }
        }
        return categoriesSet;
    }

    private static Map<Id, Set<String>> loadNotificationCategoryMap(Set<Id> entityIds, Set<String> categories) {
        Id communityUserContactId = BREGUtils.getCommunityUserContactId();
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        for (breg_Notification__c notif : [
            SELECT breg_Account__c, breg_TN_TM_SM__c, breg_Notification_Category__c
            FROM breg_Notification__c
            WHERE
                breg_Contact__c = :communityUserContactId
                AND breg_Notification_Category__c IN :categories
                AND (breg_Account__c IN :entityIds
                OR breg_TN_TM_SM__c IN :entityIds)
        ]) {
            Id entityId = notif.breg_Account__c != null ? notif.breg_Account__c : notif.breg_TN_TM_SM__c;
            if (!result.containsKey(entityId)) {
                result.put(entityId, new Set<String>());
            }
            result.get(entityId).add(notif.breg_Notification_Category__c);
        }
        return result;
    }

    private static List<breg_Notification_Category__mdt> getAllCategories() {
        if (Test.isRunningTest()) {
            return BREGTestDataFactory.getAllCategories();
        } else {
            return [
                SELECT breg_Related_Object__c, breg_Subscription_Category__c, Display_Options__c, breg_Fee_Code__c
                FROM breg_Notification_Category__mdt
                WHERE breg_Related_Object__c != NULL
            ];
        }
    }

    private static Map<String, String> extractStringMap(Map<String, Object> raw, String key) {
        Map<String, String> result = new Map<String, String>();
        if (!raw.containsKey(key))
            return result;
        Map<String, Object> rawMap = (Map<String, Object>) raw.get(key);
        for (String k : rawMap.keySet()) {
            result.put(k, String.valueOf(rawMap.get(k)));
        }
        return result;
    }
}