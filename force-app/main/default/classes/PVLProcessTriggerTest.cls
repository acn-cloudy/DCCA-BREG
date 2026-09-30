@isTest
private class PVLProcessTriggerTest {
    @isTest
    static void testGeneratePDF() {
        TestDataFactory.createNotification(); 
        Notification__c notification = [Select Id, RecordId__c from Notification__c limit 1];
        Test.startTest();
        String type = 'Generate PDF';
        Map<String, String> payload = new Map<String, String>();
        payload.put('fileEngines', 'test,files');
        payload.put('notificationId', notification.Id);
        payload.put('Id', notification.RecordId__c);
        PVLProcess__e process = new PVLProcess__e();
        process.Payload__c = JSON.serialize(payload);
        process.Type__c = type;
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testGeneratePdfWithoutNotificationId() {
        TestDataFactory.createNotification();
        Notification__c notification = [SELECT Id, RecordId__c FROM Notification__c LIMIT 1];
        Test.startTest();
        Map<String, String> payload = new Map<String, String>();
        payload.put('fileEngines', 'engineOne,engineTwo');
        payload.put('Id', notification.RecordId__c);
        PVLProcess__e process = new PVLProcess__e();
        process.Payload__c = JSON.serialize(payload);
        process.Type__c = 'Generate PDF';
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testGenerateVfPage() {
        TestDataFactory.createNotification();
        Notification__c notification = [SELECT Id, RecordId__c FROM Notification__c LIMIT 1];
        Test.startTest();
        Map<String, String> payload = new Map<String, String>();
        payload.put('Id', notification.RecordId__c);
        payload.put('notificationId', notification.Id);
        payload.put('fileEngines', 'TestVFPage');
        payload.put('fileName', 'TestDoc.pdf');
        PVLProcess__e process = new PVLProcess__e();
        process.Payload__c = JSON.serialize(payload);
        process.Type__c = 'Generate VF Page';
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testCreateCollectionAllocation() {
        pymt__PaymentX__c payment = TestDataFactory.createDummyChargebackPayment();
        insert payment;
        Set<Id> pIds = new Set<Id>();
        pIds.add(payment.Id);
        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'Create collection allocation';
        process.Payload__c = JSON.serialize(pIds);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testTerminateAssociatedLicense() {
        TestDataFactory.prepareAssociatedLicenses();
        Map<Id, Date> associateIdToEndDate = new Map<Id, Date>();
        for (AssociatedLicense__c al : [SELECT Id FROM AssociatedLicense__c LIMIT 3]) {
            associateIdToEndDate.put(al.Id, Date.today());
        }
        System.assert(!associateIdToEndDate.isEmpty(), 'Expected AssociatedLicense__c from prepareAssociatedLicenses');

        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'Terminate Associated License';
        process.Payload__c = JSON.serialize(associateIdToEndDate);
        EventBus.publish(process);
        Test.stopTest();

        AssociatedLicense__c updated = [
            SELECT EmploymentStatus__c, EndDate__c
            FROM AssociatedLicense__c
            WHERE Id = :associateIdToEndDate.keySet().iterator().next()
        ];
        System.assertEquals('Terminated', updated.EmploymentStatus__c);
    }

    @isTest
    static void testTerminateInsuranceBonds() {
        TestDataFactory.insertInsuranceBonds();
        List<License__c> records = [Select Id from License__c];
        List<String> licenseIds = (new LicenseDomain(records)).getIds();
        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'Terminate Insurance Bonds';
        process.Payload__c = JSON.serialize(licenseIds);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testTerminateInsuranceBondsNoMatchingBonds() {
        TestDataFactory.createLicense();
        List<String> licenseIds = (new LicenseDomain([SELECT Id FROM License__c])).getIds();
        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'Terminate Insurance Bonds';
        process.Payload__c = JSON.serialize(licenseIds);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testTerminateLicense() {
        TestDataFactory.createLicense();
        Map<Id, String> licenseId2Status = new Map<Id, String>();
        for (License__c record : [SELECT Id, Status__c FROM License__c]) {
            licenseId2Status.put(record.Id, record.Status__c);
        }
        System.assert(!licenseId2Status.isEmpty(), 'Expected License__c from createLicense');

        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'Terminate License';
        process.Payload__c = JSON.serialize(licenseId2Status);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testCallLicenseHistoryFlow() {
        TestDataFactory.prepareAssociatedLicenses();
        List<License__c> records = [SELECT Id FROM License__c LIMIT 5];
        List<String> licenseIds = (new LicenseDomain(records)).getIds();
        System.assert(!licenseIds.isEmpty(), 'Expected licenses');

        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'CallLicenseHistoryFlow';
        process.Payload__c = JSON.serialize(licenseIds);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testDependencyFlow() {
        TestDataFactory.prepareAssociatedLicenses();
        Set<Id> employeeLicenseIds = new Set<Id>();
        for (AssociatedLicense__c al : [
            SELECT EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c != NULL
            LIMIT 5
        ]) {
            employeeLicenseIds.add(al.EmployeeLicense__c);
        }
        System.assert(!employeeLicenseIds.isEmpty(), 'Expected employee licenses for DependencyFlow payload');

        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'DependencyFlow';
        process.Payload__c = JSON.serialize(employeeLicenseIds);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testMultiDependencyFlowEmptyLicenseList() {
        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'MultiDependencyFlow';
        process.Payload__c = JSON.serialize(new List<License__c>());
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testAppRecreateTransactionLines() {
        Account acc = new Account();
        acc.Name = 'PVL Process Recreate';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'PVL LT Recreate';
        insert lt;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'PVL Cnt';
        insert cnt;

        Id ctRt = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'PVL Lic Recreate';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctRt;
        insert lic;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'LICN - New License';
        app.Phase__c = 'A - Application Received';
        insert app;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 10;
        trn.Contact__c = cnt.Id;
        trn.Application__c = app.Id;
        trn.Status__c = 'New';
        insert trn;

        Map<String, List<String>> payLoadMap = new Map<String, List<String>>();
        payLoadMap.put('applicationIds', new List<String>{ String.valueOf(app.Id) });
        payLoadMap.put('onlineRenewalCopyAppIds', new List<String>());

        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'App - Recreate Transaction Lines';
        process.Payload__c = JSON.serialize(payLoadMap);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testScanResultApplication() {
        String u = String.valueOf(Datetime.now().getTime()) + '_' + String.valueOf(Math.round(Math.random() * 1000000));
        Account acc1 = new Account(Name = 'PVL ScanResult Account 1 ' + u);
        Account acc2 = new Account(Name = 'PVL ScanResult Account 2 ' + u);
        insert new List<Account>{ acc1, acc2 };

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'PVL ScanResult LT ' + u;
        insert lt;

        Application__c app1 = new Application__c();
        app1.Applicant__c = acc1.Id;
        app1.LicenseType__c = lt.Id;
        app1.Type__c = 'LICN - New License';
        app1.Phase__c = 'A - Application Received';

        Application__c app2 = new Application__c();
        app2.Applicant__c = acc2.Id;
        app2.LicenseType__c = lt.Id;
        app2.Type__c = 'LICN - New License';
        app2.Phase__c = 'A - Application Received';
        insert new List<Application__c>{ app1, app2 };

        List<Application__c> apps = [
            SELECT Id, Status__c, Phase__c
            FROM Application__c
            WHERE Id IN :new Set<Id>{ app1.Id, app2.Id }
        ];
        System.assertEquals(2, apps.size());

        Test.startTest();
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'ScanResultApplication';
        process.Payload__c = JSON.serialize(apps);
        EventBus.publish(process);
        Test.stopTest();
    }

    @isTest
    static void testMoveSpringCMFiles() {
        Application__c app = TestDataFactory.createDummyApplication();
        insert app;
        Test.startTest();
        PVLFolderFeed feed = new PVLFolderFeed();
        feed.fileUrls = new List<String>{ 'https://test.salesforce.com' };
        feed.recordId = app.Id;
        PVLProcess__e processUnit = new PVLProcess__e();
        processUnit.Type__c = 'MoveSpringCMFiles';
        processUnit.Payload__c = JSON.serialize(feed);
        EventBus.publish(processUnit);
        Test.stopTest();
    }
}