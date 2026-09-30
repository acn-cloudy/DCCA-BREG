/**
 * Test class to validate that Platform license users can attach files to tickets.
 * This tests whether the tkt_Ticket_User_Platform permission set grants
 * sufficient access to ContentVersion and ContentDocumentLink objects.
 */
@isTest
private class tkt_PlatformUserFilePermissionsTest {

    private static final String PLATFORM_PROFILE_NAME = 'DCCA PVL Koan Access';
    private static final String PLATFORM_PERMISSION_SET = 'tkt_Ticket_User_Platform';

    /**
     * Helper to create a Platform license user with the ticket permission set.
     */
    private static User createPlatformUserWithPermissions() {
        // Query for Platform license profile
        List<Profile> platformProfiles = [
            SELECT Id, Name, UserLicense.Name
            FROM Profile
            WHERE UserLicense.Name = 'Salesforce Platform'
            AND Name = :PLATFORM_PROFILE_NAME
            LIMIT 1
        ];

        // If specific profile not found, try any Platform profile
        if (platformProfiles.isEmpty()) {
            platformProfiles = [
                SELECT Id, Name, UserLicense.Name
                FROM Profile
                WHERE UserLicense.Name = 'Salesforce Platform'
                LIMIT 1
            ];
        }

        System.assertNotEquals(0, platformProfiles.size(),
            'No Platform license profile found in org. Test requires a Platform license profile.');

        Profile platformProfile = platformProfiles[0];
        System.debug('Using Platform profile: ' + platformProfile.Name +
            ' (License: ' + platformProfile.UserLicense.Name + ')');

        // Create user with Platform license
        String uniqueId = tkt_TestDataFactory.generateRandomString(8);
        User platformUser = new User(
            Alias = uniqueId.substring(0, 5),
            Email = uniqueId + '@testplatform.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Platform',
            LastName = 'TestUser ' + uniqueId,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = platformProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueId + '@testplatform.com'
        );
        insert platformUser;

        // Assign the Platform ticket permission set
        List<PermissionSet> permSets = [
            SELECT Id, Name FROM PermissionSet
            WHERE Name = :PLATFORM_PERMISSION_SET
            LIMIT 1
        ];

        if (!permSets.isEmpty()) {
            PermissionSetAssignment psa = new PermissionSetAssignment(
                AssigneeId = platformUser.Id,
                PermissionSetId = permSets[0].Id
            );
            insert psa;
            System.debug('Assigned permission set: ' + PLATFORM_PERMISSION_SET);
        } else {
            System.debug(LoggingLevel.WARN,
                'Permission set ' + PLATFORM_PERMISSION_SET + ' not found. ' +
                'Test will run with profile permissions only.');
        }

        return platformUser;
    }

    /**
     * Test that a Platform user can create a ticket.
     * This should pass if the permission set is correctly configured.
     */
    @isTest
    static void testPlatformUserCanCreateTicket() {
        User platformUser = createPlatformUserWithPermissions();

        Test.startTest();
        Id ticketId;
        Exception caughtException;

        System.runAs(platformUser) {
            try {
                ticketId = tkt_TicketController.createTicket(
                    'Platform User Test Ticket',
                    'Testing ticket creation from Platform license user',
                    'Medium',
                    'General Inquiry',
                    'Individual',
                    'Production',
                    null
                );
            } catch (Exception e) {
                caughtException = e;
                System.debug(LoggingLevel.ERROR, 'Platform user failed to create ticket: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
        }
        Test.stopTest();

        System.assertEquals(null, caughtException,
            'Platform user should be able to create ticket. Error: ' +
            (caughtException != null ? caughtException.getMessage() : 'none'));
        System.assertNotEquals(null, ticketId,
            'Ticket ID should not be null - Platform user should have create permission');
    }

    /**
     * Test that a Platform user can attach a file to a ticket.
     * This is the critical test - it validates ContentVersion/ContentDocumentLink access.
     */
    @isTest
    static void testPlatformUserCanAttachFile() {
        User platformUser = createPlatformUserWithPermissions();

        // First create a ticket as the platform user
        Id ticketId;
        System.runAs(platformUser) {
            ticketId = tkt_TicketController.createTicket(
                'Ticket for File Attachment Test',
                'Testing file attachment from Platform license user',
                'Medium',
                'Technical Issue',
                'Individual',
                'Production',
                null
            );
        }

        System.assertNotEquals(null, ticketId, 'Ticket must be created for file attachment test');

        Test.startTest();
        Id contentVersionId;
        Exception caughtException;
        String base64Data = tkt_TestDataFactory.createMockBase64Data();

        System.runAs(platformUser) {
            try {
                contentVersionId = tkt_TicketController.attachFile(
                    ticketId,
                    'test-screenshot.png',
                    base64Data,
                    'image/png'
                );
            } catch (Exception e) {
                caughtException = e;
                System.debug(LoggingLevel.ERROR, 'Platform user failed to attach file: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Exception type: ' + e.getTypeName());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
        }
        Test.stopTest();

        // Assert results
        System.assertEquals(null, caughtException,
            'Platform user should be able to attach files. Error: ' +
            (caughtException != null ? caughtException.getMessage() : 'none'));
        System.assertNotEquals(null, contentVersionId,
            'ContentVersion ID should not be null - file attachment should succeed');

        // Verify ContentDocumentLink was created
        List<ContentDocumentLink> cdls = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ticketId
        ];
        System.assertEquals(1, cdls.size(),
            'ContentDocumentLink should be created linking file to ticket');
    }

    /**
     * Test Platform user can attach multiple files to a ticket.
     */
    @isTest
    static void testPlatformUserCanAttachMultipleFiles() {
        User platformUser = createPlatformUserWithPermissions();

        // Create ticket as platform user
        Id ticketId;
        System.runAs(platformUser) {
            ticketId = tkt_TicketController.createTicket(
                'Ticket for Multiple Files Test',
                'Testing multiple file attachments',
                'High',
                'Bug Report',
                'Branch',
                'Production',
                null
            );
        }

        Test.startTest();
        List<Id> contentVersionIds = new List<Id>();
        Exception caughtException;
        String base64Data = tkt_TestDataFactory.createMockBase64Data();

        System.runAs(platformUser) {
            try {
                contentVersionIds.add(tkt_TicketController.attachFile(
                    ticketId, 'screenshot1.png', base64Data, 'image/png'
                ));
                contentVersionIds.add(tkt_TicketController.attachFile(
                    ticketId, 'log-file.txt', base64Data, 'text/plain'
                ));
                contentVersionIds.add(tkt_TicketController.attachFile(
                    ticketId, 'error-report.pdf', base64Data, 'application/pdf'
                ));
            } catch (Exception e) {
                caughtException = e;
                System.debug(LoggingLevel.ERROR, 'Platform user failed to attach multiple files: ' + e.getMessage());
            }
        }
        Test.stopTest();

        System.assertEquals(null, caughtException,
            'Platform user should attach multiple files without error');
        System.assertEquals(3, contentVersionIds.size(),
            'All 3 files should be attached');

        // Verify all links created
        List<ContentDocumentLink> cdls = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :ticketId
        ];
        System.assertEquals(3, cdls.size(),
            'All 3 ContentDocumentLinks should be created');
    }

    /**
     * Test that Platform user can read files attached to their ticket.
     */
    @isTest
    static void testPlatformUserCanReadAttachedFiles() {
        User platformUser = createPlatformUserWithPermissions();

        // Create ticket and attach file as platform user
        Id ticketId;
        Id contentVersionId;
        String base64Data = tkt_TestDataFactory.createMockBase64Data();

        System.runAs(platformUser) {
            ticketId = tkt_TicketController.createTicket(
                'Ticket for File Read Test',
                'Testing file read access',
                'Low',
                'General Inquiry',
                'Individual',
                'Production',
                null
            );
            contentVersionId = tkt_TicketController.attachFile(
                ticketId, 'readable-file.txt', base64Data, 'text/plain'
            );
        }

        Test.startTest();
        List<ContentDocumentLink> accessibleFiles;
        Exception caughtException;

        System.runAs(platformUser) {
            try {
                accessibleFiles = [
                    SELECT Id, ContentDocumentId, ContentDocument.Title
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :ticketId
                ];
            } catch (Exception e) {
                caughtException = e;
                System.debug(LoggingLevel.ERROR, 'Platform user failed to read files: ' + e.getMessage());
            }
        }
        Test.stopTest();

        System.assertEquals(null, caughtException,
            'Platform user should be able to query attached files');
        System.assertEquals(1, accessibleFiles.size(),
            'Platform user should see the attached file');
    }

    /**
     * Diagnostic test to output current Platform user permissions.
     * This helps identify what permissions are missing if other tests fail.
     */
    @isTest
    static void testDiagnosticPlatformUserPermissions() {
        User platformUser = createPlatformUserWithPermissions();

        Test.startTest();
        System.runAs(platformUser) {
            // Log user info
            System.debug('=== PLATFORM USER DIAGNOSTIC INFO ===');
            System.debug('User ID: ' + UserInfo.getUserId());
            System.debug('User Name: ' + UserInfo.getUserName());
            System.debug('Profile ID: ' + UserInfo.getProfileId());

            // Check object accessibility
            Schema.DescribeSObjectResult ticketDescribe =
                Schema.SObjectType.tkt_Ticket__c;
            System.debug('Ticket__c isAccessible: ' + ticketDescribe.isAccessible());
            System.debug('Ticket__c isCreateable: ' + ticketDescribe.isCreateable());

            // Check ContentVersion accessibility
            Schema.DescribeSObjectResult cvDescribe =
                Schema.SObjectType.ContentVersion;
            System.debug('ContentVersion isAccessible: ' + cvDescribe.isAccessible());
            System.debug('ContentVersion isCreateable: ' + cvDescribe.isCreateable());

            // Check ContentDocumentLink accessibility
            Schema.DescribeSObjectResult cdlDescribe =
                Schema.SObjectType.ContentDocumentLink;
            System.debug('ContentDocumentLink isAccessible: ' + cdlDescribe.isAccessible());
            System.debug('ContentDocumentLink isCreateable: ' + cdlDescribe.isCreateable());

            // Check ContentDocument accessibility
            Schema.DescribeSObjectResult cdDescribe =
                Schema.SObjectType.ContentDocument;
            System.debug('ContentDocument isAccessible: ' + cdDescribe.isAccessible());
            System.debug('ContentDocument isCreateable: ' + cdDescribe.isCreateable());
            System.debug('ContentDocument isDeletable: ' + cdDescribe.isDeletable());

            // Assert minimum required permissions
            System.assert(ticketDescribe.isAccessible(),
                'Platform user must have read access to Ticket__c');
            System.assert(ticketDescribe.isCreateable(),
                'Platform user must have create access to Ticket__c');

            // These are the critical assertions for file permissions
            System.assert(cvDescribe.isAccessible(),
                'Platform user must have read access to ContentVersion for file operations');
            System.assert(cvDescribe.isCreateable(),
                'Platform user must have create access to ContentVersion to upload files');
            System.assert(cdlDescribe.isAccessible(),
                'Platform user must have read access to ContentDocumentLink');
            System.assert(cdlDescribe.isCreateable(),
                'Platform user must have create access to ContentDocumentLink to attach files to records');
        }
        Test.stopTest();
    }

    /**
     * Test directly creating ContentVersion without going through controller.
     * This isolates whether the issue is with permissions or controller logic.
     */
    @isTest
    static void testPlatformUserDirectContentVersionInsert() {
        User platformUser = createPlatformUserWithPermissions();

        // Create ticket first
        Id ticketId;
        System.runAs(platformUser) {
            ticketId = tkt_TicketController.createTicket(
                'Direct CV Insert Test',
                'Testing direct ContentVersion insert',
                'Medium',
                'General Inquiry',
                'Individual',
                'Production',
                null
            );
        }

        Test.startTest();
        Id contentVersionId;
        Id contentDocumentId;
        Exception caughtException;

        System.runAs(platformUser) {
            try {
                // Direct insert of ContentVersion (without controller)
                ContentVersion cv = new ContentVersion(
                    Title = 'Direct Upload Test',
                    PathOnClient = 'direct-test.txt',
                    VersionData = Blob.valueOf('Direct test content'),
                    FirstPublishLocationId = ticketId
                );
                insert cv;
                contentVersionId = cv.Id;

                // Query back to get ContentDocumentId
                cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
                contentDocumentId = cv.ContentDocumentId;

                System.debug('Direct CV insert succeeded. CV Id: ' + contentVersionId);
                System.debug('ContentDocumentId: ' + contentDocumentId);
            } catch (DmlException e) {
                caughtException = e;
                System.debug(LoggingLevel.ERROR, 'Direct ContentVersion insert failed: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'DML Status Code: ' + e.getDmlStatusCode(0));
                System.debug(LoggingLevel.ERROR, 'DML Fields: ' + e.getDmlFieldNames(0));
            } catch (Exception e) {
                caughtException = e;
                System.debug(LoggingLevel.ERROR, 'Unexpected error: ' + e.getTypeName() + ': ' + e.getMessage());
            }
        }
        Test.stopTest();

        System.assertEquals(null, caughtException,
            'Direct ContentVersion insert should succeed for Platform user. Error: ' +
            (caughtException != null ? caughtException.getMessage() : 'none'));
        System.assertNotEquals(null, contentVersionId,
            'ContentVersion should be created');
    }
}