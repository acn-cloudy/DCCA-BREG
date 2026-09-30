/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  00016802: Salesforce to query all applications 
 *   that meet requirements in the D1/D2 Refund Flow Lucid chart below, 
 *   create a notification document and attach it to the license.
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Alvin Zhou - PacificPointCorp 
 *  @created      PacPoint-AZ092121 - Created for PVL Phase 1
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 *  @author       Takashi Koyama - PacificPointCorp 
 *  @created      PacPoint-TK01122023 - Created for PVL Phase 1
 *  @case:        27102
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class D1D2DependencyRefundNotice implements schedulable, Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts  {
    public Set<String> types = new Set<String>{'RNEW - Renewal'
    // , 'RSTR - Restore - No A/I Status', 'RSTRA - Restore Active'
};
    public Set<String> statuses = new Set<String>{'D1 - Awaiting Dependency Review', 'D2 - Continuing Education Missing'};
    public Set<String> licenseStatus = new Set<String>{'TX - Terminated And Refunded'}; 
    List<License__c> gLicenses = new List<License__c>();   
    public String phaseStr = 'D - Dependency Review';
    public String boardProgramNameFilter = 'REAL ESTATE COMMISSION';
    public String pageName;
    public String query;
    private Integer index;
    public String licenseTypeId;
    private Map<String, Integer> lt2Index = new Map<String, Integer>();
    public List<String> notificationIds = new List<String>();
    public Map<String, List<String>> ltId2NotificationIds = new Map<String, List<String>>();
    public Map<String, String> ltId2TemplateName = new Map<String, String>();
    global D1D2DependencyRefundNotice() {
        query = 'Select Id, LicensePeriodRNEW__c, CurrentLicense__r.Id, CurrentLicense__r.LicenseType__c, CurrentLicense__r.LicenseType__r.RenewalRefundNoticeTemplate__c, '
        + ' CurrentLicense__r.RespondByDate__c from Application__c where Type__c in: types and Phase__c =: phaseStr ' 
        + ' and Status__c in: statuses and CurrentLicense__r.Status__c not in: licenseStatus and OutstandingAmount__c = 0 '
        + ' and BoardProgramName__c != :boardProgramNameFilter '        
        + ' and IsinCurrentRenewalPeriod__c = true order by CurrentLicense__r.LicenseType__c ';
    }

    global D1D2DependencyRefundNotice(String pLicenseTypeId) {
        licenseTypeId = pLicenseTypeId;
        query = 'Select Id, LicensePeriodRNEW__c, CurrentLicense__r.Id, CurrentLicense__r.LicenseType__c, CurrentLicense__r.LicenseType__r.RenewalRefundNoticeTemplate__c, '
        + ' CurrentLicense__r.RespondByDate__c from Application__c where Type__c in: types and Phase__c =: phaseStr ' 
        + ' and Status__c in: statuses and CurrentLicense__r.Status__c not in: licenseStatus and OutstandingAmount__c = 0 '
        + ' and BoardProgramName__c != :boardProgramNameFilter '
        + ' and CurrentLicense__r.LicenseType__c = :licenseTypeId '
        + ' and IsinCurrentRenewalPeriod__c = true order by CurrentLicense__r.LicenseType__c ';
    }
    
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        //generateRenewalNotification();

        List<Application__c> records = (List<Application__c>) scope;
        List<License__c> licenses = new List<License__c>();
        for(Application__c record: records) {
            License__c license = record.CurrentLicense__r;
            if(license == null) continue;
            license.RespondByDate__c = Date.today().addDays(14);
            licenses.add(license);
            gLicenses.add(license);
        }       

        List<String> licenseIds = (new LicenseDomain(licenses)).getIds();
        List<License__c> licenseRecords = [Select Id, RespondByDate__c, EffectiveExpireDate__c, 
            (Select Id, Remarks__c, TermDate__c, TransactionType__c, LicensePeriod__c from LicenseHistory__r 
                where TransactionType__c = 'RNEW - RENEWED'  
                order by CreatedDate desc) from License__c where Id in: licenseIds];        

        List<LicenseHistory__c> histories = new List<LicenseHistory__c>();
        
        Boolean foundHistory = false;

        for(License__c record: licenseRecords) {
            foundHistory = false;
            if(record.LicenseHistory__r != null && !record.LicenseHistory__r.isEmpty()) {
                LicenseHistory__c history;

                for (LicenseHistory__c h : record.LicenseHistory__r){                    
                    for(Application__c ap: records) {
                        if(h.LicensePeriod__c == ap.LicensePeriodRNEW__c){
                            foundHistory = true;
                            history = h;
                            break;
                        }
                    }      
                    if (foundHistory){ break; }
                }
               
                if (!foundHistory){ continue; }

                if(history.Remarks__c == null) history.Remarks__c = '';
                if(history.Remarks__c != null && !history.Remarks__c.contains('REFUND MADE DUE TO DEPENDENCY CONDITION.')) {
                    history.Remarks__c = history.Remarks__c + ' REFUND MADE DUE TO DEPENDENCY CONDITION.';
                }

                if(history.TransactionType__c == 'RNEW - RENEWED') {
                    history.TermDate__c = record.EffectiveExpireDate__c;
                } 
                // else {
                //     history.TermDate__c = record.RestorationDeadline__c;
                // }
                histories.add(history);
            }
        }

        if(!histories.isEmpty()) update histories;
        if(!licenses.isEmpty()) update licenses;
        // Generate D1/D2 Renewal Refund Notification

        if(!licenses.isEmpty()) {
            Map<String, List<String>> ltId2Licenses = new Map<String, List<String>>();
            Map<String, String> lId2Page = new Map<String, String>();
            for(License__c license: licenses) {
                String licenseTypeId = license.LicenseType__c;
                if(license.LicenseType__r.RenewalRefundNoticeTemplate__c == null) {
                    continue;
                }
                
                lId2Page.put(license.Id, license.LicenseType__r.RenewalRefundNoticeTemplate__c);
                List<String> lIds = new List<String>();
                if(ltId2Licenses.containsKey(licenseTypeId)) {
                    lIds = ltId2Licenses.get(licenseTypeId);
                }
                lIds.add(license.Id);
                ltId2Licenses.put(licenseTypeId, lIds);
            }
            if(!lId2Page.isEmpty()) {
                PVLProcess__e process = new PVLProcess__e();
                process.Type__c = 'Generate PDF From VF';
                process.Payload__c = JSON.serialize(lId2Page);
                EventBus.publish(process);
            }
            List<Notification__c> notifications = new List<Notification__c>();
            for(String licenseTypeId: ltId2Licenses.KeySet()) {
                List<String> recordIds = ltId2Licenses.get(licenseTypeId);
                String queryIds = String.join(recordIds, ',');
                Notification__c notification = new Notification__c();
                notification.Status__c = 'Completed';
                notification.Content__c = queryIds;
                notification.RecordId__c = licenseTypeId;
            
                notifications.add(notification);
            }
            insert notifications;
            
            for(Notification__c notification: notifications) {
                List<String> notificationIds = new List<String>();
                if(ltId2NotificationIds.containsKey(notification.RecordId__c)) {
                    notificationIds = ltId2NotificationIds.get(notification.RecordId__c);
                }
                notificationIds.add(notification.Id);
                ltId2NotificationIds.put(notification.RecordId__c, notificationIds);
            }
            notificationIds.addAll((new NotificationDomain(notifications)).getIds());
            
        }
    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new D1D2DependencyRefundNotice(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {
        generateRenewalNotification();
        //generateRenewalNotification(gLicenses);  Case 27102, the client decided not to add a notification on license page.
    }

    public void generateRenewalNotification() {
        List<String> notificationIds = new List<String>();
        for(List<String> notIds: ltId2NotificationIds.values()) {
            notificationIds.addAll(notIds);
        }
        if(notificationIds.isEmpty()) return;

        Set<String> ltIdSet = ltId2NotificationIds.keySet();
        List<LicenseType__c> licenseTypes = [Select Id, RenewalRefundNoticeTemplate__c 
            from LicenseType__c where Id in: ltIdSet and RenewalRefundNoticeTemplate__c != null];
        
        for(LicenseType__c licenseType: licenseTypes) {
            Integer index = 1;
            if(lt2Index.containsKey(licenseType.Id)) {
                index = lt2Index.get(licenseType.Id);
            }
            String pageName = licenseType.RenewalRefundNoticeTemplate__c;
            pageName = pageName.replace(' ', '');
            pageName = pageName.replace('-', '');
            PageReference pageRef = new PageReference('/apex/'+pageName);
            List<String> notIds = ltId2NotificationIds.get(licenseType.Id);
            
            String notificationIdStr = String.join(notIds, ',');
            pageRef.getParameters().put('notificationIds', notificationIdStr);
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pageRef.getContent();
                String docName = licenseType.RenewalRefundNoticeTemplate__c + '('+ index + ').pdf';
                List<SpringCMDocument> result = SpringCMConnector.createFile(licenseType.Id, docname, content);
            }
            ltId2NotificationIds.remove(licenseType.Id);
            index ++;
            lt2Index.put(licenseType.Id, index);
        }
    }

    public void generateRenewalNotification(List<License__c> licenses) {
        List<String> notificationIds = new List<String>();
        for(List<String> notIds: ltId2NotificationIds.values()) {
            notificationIds.addAll(notIds);
        }
        if(notificationIds.isEmpty()) return;

        Set<String> ltIdSet = ltId2NotificationIds.keySet();
        List<LicenseType__c> licenseTypes = [Select Id, RenewalRefundNoticeTemplate__c 
            from LicenseType__c where Id in: ltIdSet and RenewalRefundNoticeTemplate__c != null];
        
        for(LicenseType__c licenseType: licenseTypes) {
            Integer index = 1;
            if(lt2Index.containsKey(licenseType.Id)) {
                index = lt2Index.get(licenseType.Id);
            }
            String pageName = licenseType.RenewalRefundNoticeTemplate__c;
            pageName = pageName.replace(' ', '');
            pageName = pageName.replace('-', '');
            PageReference pageRef = new PageReference('/apex/'+pageName);
            List<String> notIds = ltId2NotificationIds.get(licenseType.Id);

            // Begin: adding License ID
            // for (License__c lic : licenses){
            //     notIds.add(lic.ID);
            // }
            // End: adding License ID
            
            String notificationIdStr = String.join(notIds, ',');
            pageRef.getParameters().put('notificationIds', notificationIdStr);
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pageRef.getContent();
                String docName = licenseType.RenewalRefundNoticeTemplate__c + '('+ index + ').pdf';
                List<SpringCMDocument> result = SpringCMConnector.createFile(licenseType.Id, docname, content);

                // 00027102, adding notification to License record page               
                String licenseIds = '';
                
                if (licenses.size() > 1){
                    for (License__c l : licenses){
                        licenseIds = l.ID + ','; 
                    }
                    licenseIds = licenseIds.substring(0, licenseIds.lastIndexOf(','));                    
                }
                else {
                    licenseIds = licenses[0].ID;
                }
                
                for (License__c lic : licenses){
                    List<String> notifIds = ltId2NotificationIds.get(licenseType.Id);
                    notifIds.add(lic.ID);
                    String notIdStr = String.join(notifIds, ',');       
                                 
                    PageReference pageReflic = new PageReference('/apex/'+pageName);
                    pageReflic.getParameters().put('notificationIds', notIdStr);
                    content = pageReflic.getContent();
                    List<SpringCMDocument> result2 = SpringCMConnector.createFile(lic.Id, docname, content);    
                    notifIds = null; 
                    pageReflic = null;            
                }
            }
            ltId2NotificationIds.remove(licenseType.Id);
            index ++;
            lt2Index.put(licenseType.Id, index);
        }
    }
}