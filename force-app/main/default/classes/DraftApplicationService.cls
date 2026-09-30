public without sharing class DraftApplicationService {
    private static Set<String> appCacheIds = new Set<String>();
    public static void checkSubmittedStatus(SObject oldSo, SObject so) {
        Application_Cache__c oldRecord = (Application_Cache__c) oldSo;
        Application_Cache__c record = (Application_Cache__c) so;
        if(record.Is_Submitted__c != oldRecord.Is_Submitted__c && record.Is_Submitted__c) {
            appCacheIds.add(record.Id);
            record.Status__c = 'In Progress';
            record.Is_Submitted__c = false;
        }
    }
    
    public static void generateApp() {
        if(!appCacheIds.isEmpty()) {
            for(String appId: appCacheIds) {
                System.enqueueJob(new QueueClass(appId));
            }
            appCacheIds.clear();
        }

    }

    @AuraEnabled
    public static String updateApplication(String recordId, String cardStr, String cardMetaName) {
        TransactionLinePreventDeletion.skipValidation = true;
        List<Application__c> records = [Select Id from Application__c where DraftApplication__c =: recordId];
        if(records.isEmpty()) return '';
        List<Application_Cache__c> appCaches = sc_ApplicationCacheSelector.getApplicationCacheById(recordId);
        String appMetaDataId = appCaches.get(0).Application_Meta_Data__c;
        List<Card_Cache__c> cardCaches = [select Id, Application_Cache__c, Name, values__c, files__c, 
            Card_Meta_Data__c from Card_Cache__c where Application_Cache__c =: recordId 
            and Name =: cardMetaName order by CreatedDate]; 
        cardCaches.get(0).Values__c = cardStr;
        
        List<Field_Meta_Data__c> fieldMetaDatas = sc_FieldMetaDataSelector.getFieldMetaDataByAppIdToReview(appMetaDataId);
        Map<String, List<Field_Meta_Data__c>> cardMetaId2FieldList = (new sc_FieldMetaDataDomain(fieldMetaDatas)).getCardId2FieldList();
        Map<String, Card_Cache__c> cardMetaId2Cache = (new CardCacheDomain(cardCaches)).getCardMeta2Cache();
        List<Card_Meta_Data__c> cardMetas = sc_CardMetaDataSelector.getCardsByAppId(appMetaDataId);
        List<Card_Meta_Data__c> filterCardMeta = new list<Card_Meta_Data__c>();
        for(Card_Meta_Data__c record: cardMetas) {
            if(record.Name == cardMetaName) {
                filterCardMeta.add(record);
            }
        }
        Map<String, SObject> objs = (new CardMetaDataDomain(filterCardMeta)).convert2AppData(cardMetaId2Cache, cardMetaId2FieldList);

        
        Application__c app = new Application__c();
        if(objs.containsKey('Application__c')) {
            app = (Application__c) objs.get('Application__c');
            app.Id = records.get(0).Id;
            if(!String.isBlank(app.LicenseType__c)) {
                String licenseType = app.LicenseType__c;
                LicenseType__c ltRecord = [Select Id, ApplicationRecordType__c from LicenseType__c where LicenseType__c =: licenseType];
                app.RecordTypeId = Schema.SObjectType.Application__c.getRecordTypeInfosByName()
                        .get(ltRecord.ApplicationRecordType__c)
                        .getRecordTypeId();
                app.LicenseType__c = ltRecord.Id;
            }
            List<FieldUtils.PicklistOption> stateOptions =  FieldUtils.getPicklistOptions('Application__c', 'MailingState__c');
            // if find option match, update
            Map<String, String> optionState = new Map<String, String>();
            for(FieldUtils.PicklistOption stateOption: stateOptions) {
                optionState.put(stateOption.label, stateOption.value);
            }
            if(optionState.containsKey(app.MailingState__c)){
                app.MailingState__c = optionState.get(app.MailingState__c);
            }
            // turn off the process to submit draft application
            update app;

        }   
        return JSON.serialize(app);
    }

    @AuraEnabled
    public static void createApplication(String appId){
        List<Application__c> records = [Select Id from Application__c where DraftApplication__c =: appId];
        if(!records.isEmpty()) return;
        List<Application_Cache__c> appCaches = sc_ApplicationCacheSelector.getApplicationCacheById(appId);
        String appMetaDataId = appCaches.get(0).Application_Meta_Data__c;
        
        // Get Application Metadata 
        Map<String, SObject> objs 
            = (Map<String, SObject>) JSON.deserialize(appCaches.get(0).AppDataBeforeSubmit__c, 
                Map<String, SObject>.class);
        Account acc = new Account();
        if(objs.containsKey('Account')) {
            acc = (Account) objs.get('Account');
            String bpId = acc.BPID__c;
            List<Account> accList = [Select Id, PersonEmail, BillingCity, FirstName, LastName, BillingPostalCode, BillingState, BillingStreet, BillingCountry, PersonContactId from Account where BPID__c =: bpId and BPID__c != null];
            if(accList.isEmpty()) {
                acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
                        .get('Person Account')
                        .getRecordTypeId();
                insert acc;
            } else {
                acc.Id = accList.get(0).Id;
            }
            
        }
        Application__c app = new Application__c();
        if(objs.containsKey('Application__c')) {
            app = (Application__c) objs.get('Application__c');
            if(!String.isBlank(app.LicenseType__c)) {
                String licenseType = app.LicenseType__c;
                LicenseType__c ltRecord = [Select Id, ApplicationRecordType__c from LicenseType__c where LicenseType__c =: licenseType];
                app.RecordTypeId = Schema.SObjectType.Application__c.getRecordTypeInfosByName()
                        .get(ltRecord.ApplicationRecordType__c)
                        .getRecordTypeId();
                app.LicenseType__c = ltRecord.Id;
            }
            List<FieldUtils.PicklistOption> stateOptions =  FieldUtils.getPicklistOptions('Application__c', 'MailingState__c');
            Map<String, String> optionState = new Map<String, String>();
            for(FieldUtils.PicklistOption stateOption: stateOptions) {
                optionState.put(stateOption.label, stateOption.value);
            }
            if(optionState.containsKey(app.MailingState__c)){
                app.MailingState__c = optionState.get(app.MailingState__c);
            }

            System.debug(app.MailingState__c);
            app.NotificationEmail__c = acc.PersonEmail;
            app.PVLBPID__c = acc.BPID__c;
            app.Applicant__c = acc.Id;
            app.OnlineApplicationType__c = 'Online New Application (LICN)';
            app.OnlineSubmitStatus__c = 'Draft';

            if(!String.isBlank(appCaches.get(0).FormData__c)) {
                Map<String, Object> formData = (Map<String, Object>)JSON.deserializeUntyped(appCaches.get(0).FormData__c);
                if(formData.containsKey('user_id')) {
                    app.PVLPortalUser__c = String.valueOf(formData.get('user_id'));
                }
            }

            app.Type__c = 'LICN - New License';
            app.DraftApplication__c = appId;
            insert app;
        }
        if(app.Id != null) {
            List<pymt__Processor_Connection__c> connections = [select Id,Name from pymt__Processor_Connection__c];
            
            // Find Transaction
            List<Transaction__c> transactions = [Select Id, TotalAmount__c, Application__r.Name from Transaction__c where Application__c =: app.Id];
            List<Account> accounts = [Select Id, PersonEmail, BillingCity, FirstName, LastName, BillingPostalCode, BillingState, BillingStreet, PersonContactId from Account where Id =: acc.Id];
            System.debug('#####acc.Id#####' + acc.Id);
            if(!transactions.isEmpty() && !connections.isEmpty()) {
                pymt__PaymentX__c payment = new pymt__PaymentX__c();
                payment.Name = transactions.get(0).Application__r.Name;
                payment.pymt__Amount__c = transactions.get(0).TotalAmount__c;
                payment.Transaction__c = transactions.get(0).Id;
                payment.Division__c = 'PVL';
                payment.pymt__Currency_ISO_Code__c = 'USD';
                payment.pymt__Account__c = accounts.get(0).Id;
                payment.pymt__Billing_Email__c = accounts.get(0).PersonEmail;
                payment.pymt__Billing_City__c = accounts.get(0).BillingCity;
                payment.pymt__Billing_First_Name__c = accounts.get(0).FirstName;
                payment.pymt__Billing_Last_Name__c = accounts.get(0).LastName;
                payment.pymt__Billing_Postal_Code__c = accounts.get(0).BillingPostalCode;
                payment.pymt__Billing_State__c = accounts.get(0).BillingState;
                payment.pymt__Billing_Street__c = accounts.get(0).BillingStreet;
                payment.pymt__Contact__c = accounts.get(0).PersonContactId;
                payment.pymt__Payment_Type__c = 'Credit Card';
                payment.pymt__Processor_Connection__c = connections.get(0).Id;
                insert payment;
            }
        }
    }
    
    
    public static void convertApp(String appId) {
        List<Application_Cache__c> appCaches = sc_ApplicationCacheSelector.getApplicationCacheById(appId);
        String appMetaDataId = appCaches.get(0).Application_Meta_Data__c;
        List<Card_Cache__c> cardCaches = sc_CardCacheSelector.getCardCacheByIds(new List<String>{ appId });
        List<Field_Meta_Data__c> fieldMetaDatas = sc_FieldMetaDataSelector.getFieldMetaDataByAppIdToReview(appMetaDataId);
        Map<String, List<Field_Meta_Data__c>> cardMetaId2FieldList = (new sc_FieldMetaDataDomain(fieldMetaDatas)).getCardId2FieldList();
        Map<String, Card_Cache__c> cardMetaId2Cache = (new CardCacheDomain(cardCaches)).getCardMeta2Cache();
        List<Card_Meta_Data__c> cardMetas = sc_CardMetaDataSelector.getCardsByAppId(appMetaDataId);
        Map<String, SObject> objs = (new CardMetaDataDomain(cardMetas)).convert2AppData(cardMetaId2Cache, cardMetaId2FieldList);

        Account acc = new Account();
        if(objs.containsKey('Account')) {
            acc = (Account) objs.get('Account');
        }
        Application__c app = new Application__c();
        if(objs.containsKey('Application__c')) {
            app = (Application__c) objs.get('Application__c');
            Application__c[] appRecords = [Select Id from Application__c where DraftApplication__c =: appId];
            if(appRecords.isEmpty()) return;
            Application__c application = appRecords[0];            app.Id = application.Id;
            List<Education__c> educations = [Select Id from Education__c where Application__c = : app.Id];
            List<OtherStateLicenses__c> otherStateLicenses = [Select Id from OtherStateLicenses__c where Application__c = : app.Id];
            delete educations;
            delete otherStateLicenses;

            if(!String.isBlank(app.LicenseType__c)) {
                String licenseType = app.LicenseType__c;
                LicenseType__c ltRecord = [Select Id, ApplicationRecordType__c from LicenseType__c where LicenseType__c =: licenseType];
                app.RecordTypeId = Schema.SObjectType.Application__c.getRecordTypeInfosByName()
                        .get(ltRecord.ApplicationRecordType__c)
                        .getRecordTypeId();
                app.LicenseType__c = ltRecord.Id;
            }

            List<FieldUtils.PicklistOption> stateOptions =  FieldUtils.getPicklistOptions('Application__c', 'MailingState__c');
            // if find option match, update
            Map<String, String> optionState = new Map<String, String>();
            for(FieldUtils.PicklistOption stateOption: stateOptions) {
                optionState.put(stateOption.label, stateOption.value);
            }
            if(optionState.containsKey(app.MailingState__c)){
                app.MailingState__c = optionState.get(app.MailingState__c);
            }
            // turn off the process to submit draft application
            ApplicationService.skipApplicationCacheUpdate = true;
            update app;
            ApplicationService.skipApplicationCacheUpdate = false;
        }

        Map<String, List<SObject>> recordsMap = (new CardMetaDataDomain(cardMetas)).generateTables(cardMetaId2Cache, cardMetaId2FieldList);
        Map<String, List<String>> fileMaps = (new CardMetaDataDomain(cardMetas)).generateFiles(cardMetaId2Cache, cardMetaId2FieldList);



        if(fileMaps.containsKey('Application__c')) {
            List<String> fileUrls = fileMaps.get('Application__c');
            PVLFolderFeed feed = new PVLFolderFeed();
            feed.fileUrls = fileUrls;
            feed.recordId = app.Id;
            PVLProcess__e processUnit = new PVLProcess__e();
            processUnit.Type__c = 'MoveSpringCMFiles';
            processUnit.Payload__c = JSON.serialize(feed);
            EventBus.publish(processUnit);
        }

        if(recordsMap.containsKey('Education__c')) {
            List<Education__c> educations = (List<Education__c>) recordsMap.get('Education__c');
            for(Education__c education: educations) {
                education.Application__c = app.Id;
            }
            insert educations;
        }

        if(recordsMap.containsKey('OtherStateLicenses__c')) {
            List<OtherStateLicenses__c> otherStateLicenses = (List<OtherStateLicenses__c>) recordsMap.get('OtherStateLicenses__c');
            for(OtherStateLicenses__c record: otherStateLicenses) {
                record.Application__c = app.Id;
            }
            insert otherStateLicenses;
        }
    }

    @future(callout=true)
    public static void convertFiles(List<String> fileUrls, String recordId) {
        SpringCMConnector.updateFilesAndFolder(fileUrls, recordId);
    }

    public class QueueClass implements Queueable,Database.AllowsCallouts {
        public Id appId;
        //accepts a set of records to update and their new batch number
        public QueueClass(Id appId) {
            this.appId = appId;
        }
        public void execute(QueueableContext context) {
            convertApp(appId);
        }
    }
}