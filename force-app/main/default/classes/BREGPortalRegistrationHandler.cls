global class BREGPortalRegistrationHandler implements Auth.RegistrationHandler {
    private static final String COMMUNITY_PROFILE_NAME = 'DCCA BREG - CustomerCommunityUser';
    private static final String BREG_PORTAL_PERMSET_NAME = 'BREG_Portal_User';

    @TestVisible
    private String usernamePostfix {
        get {
            String sandboxName = System.DomainParser.parse(URL.getOrgDomainUrl()).getSandboxName();
            return String.isNotBlank(sandboxName) ? '.breg.hawaii.gov.' + sandboxName : '.breg.hawaii.gov';
        }
        set;
    }

    global Boolean canCreateUser(Auth.UserData data) {
        if (String.IsNotBlank(data.email) && String.IsNotBlank(data.lastname)) {
            return true;
        }
        return false;
    }

    global User createUser(Id portalId, Auth.UserData data) {
        if (!canCreateUser(data)) {
            //Returning null or throwing an exception fails the SSO flow
            return null;
        }
        system.debug('data.attributeMap=' + data.attributeMap);
        if (data.attributeMap.containsKey('sfdc_networkid')) {
            List<User> existingUsers = [
                SELECT Id, Profile.Name, ContactId
                FROM User
                WHERE Email = :data.email AND IsActive = TRUE AND ContactId != NULL
            ];
            if (!existingUsers.isEmpty()) {
                assignBregPortalPermsetIfNeeded(existingUsers[0]);
                return existingUsers[0];
            }

            List<Account> existingAccounts = [SELECT PersonEmail, PersonContactId FROM Account WHERE PersonEmail = :data.email];
            Id personContactId = null;
            if (existingAccounts.isEmpty()) {
                Account newAccount = new Account(
                    FirstName = data.firstName,
                    LastName = data.lastName,
                    PersonEmail = data.email,
                    RecordTypeId = SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
                );
                insert newAccount;
                Account createdAccount = [SELECT PersonContactId FROM Account WHERE Id = :newAccount.Id];
                personContactId = createdAccount.PersonContactId;
            } else {
                personContactId = existingAccounts[0].PersonContactId;
            }
            User newUser = initUser(data, true, personContactId);

            return newUser;
        } else {
            //This is not a community, so create a regular standard user
            User newUser = initUser(data, false, null);
            return newUser;
        }
    }

    global void updateUser(Id userId, Id portalId, Auth.UserData data) {
        User theUser = new User(Id = userId);

        theUser.email = data.email;
        theUser.lastName = data.lastName;
        theUser.firstName = data.firstName;

        update theUser;
    }

    private User initUser(Auth.UserData data, Boolean isCommunityUser, Id personContactId) {
        User newUser = new User();
        Profile userProfile = isCommunityUser
            ? [SELECT Id FROM Profile WHERE Name = :COMMUNITY_PROFILE_NAME LIMIT 1]
            : [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String username = data.email;
        newUser.username = username + usernamePostfix;
        newUser.email = data.email;
        newUser.lastName = data.lastName;
        newUser.firstName = data.firstName;
        String alias = username.split('@')[0];
        //Alias must be 8 characters or less
        if (alias.length() > 8) {
            alias = alias.substring(0, 8);
        }
        newUser.alias = alias;
        newUser.languagelocalekey = UserInfo.getLocale();
        newUser.localesidkey = UserInfo.getLocale();
        newUser.emailEncodingKey = 'UTF-8';
        newUser.timeZoneSidKey = 'Pacific/Honolulu';
        newUser.profileId = userProfile.Id;
        if (isCommunityUser) {
            newUser.contactId = personContactId;
            newUser.BREG_Portal_Registration_Complete__c = false;
        }
        return newUser;
    }

    private void assignBregPortalPermsetIfNeeded(User theUser) {
        List<PermissionSetAssignment> existingAssignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :theUser.Id AND PermissionSet.Name = :BREG_PORTAL_PERMSET_NAME
        ];
        if (!existingAssignments.isEmpty()) {
            return;
        }

        PermissionSet permSet = [SELECT Id FROM PermissionSet WHERE Name = :BREG_PORTAL_PERMSET_NAME LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = theUser.Id, PermissionSetId = permSet.Id);
    }

    global class RegistrationHandlerException extends Exception {
    }
}