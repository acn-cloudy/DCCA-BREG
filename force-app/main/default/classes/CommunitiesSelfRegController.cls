/**
 * An apex page controller that supports self registration of users in communities that allow self registration
 */
public without sharing class CommunitiesSelfRegController {
    private final String COMMUNITY_PROFILE_NAME = 'DCCA BREG - CustomerCommunityUser';
    private final String BREG_PORTAL_USER = 'BREG_Portal_User';
    public String firstName { get; set; }
    public String lastName { get; set; }
    public String email { get; set; }
    public String password {
        get;
        set {
            password = value == null ? value : value.trim();
        }
    }
    /**
     * Creates a Person Account based on a User's email.
     * @param userEmail The email address of the user.
     * @return The created Account Id, or null if no user was found.
     */
    public static Id createPersonAccount(String userEmail, String firstName, String lastName, Id profileId) {
        if (String.isBlank(userEmail)) {
            throw new IllegalArgumentException('Email address cannot be blank.');
        }

        // Find user by email
        List<User> users = [
            SELECT Id, FirstName, LastName, Email
            FROM User
            WHERE Email = :userEmail AND ProfileId = :profileId
            LIMIT 1
        ];
        if (!users.isEmpty()) {
            throw new IllegalArgumentException('User registration failed'); //change to custom label
        }
        // Get Person Account RecordType
        RecordType personRt = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = TRUE
            LIMIT 1
        ];

        // Create Person Account
        Account personAcc = new Account(
            RecordTypeId = personRt.Id,
            FirstName = firstName != null ? firstName : 'Unknown',
            LastName = lastName != null ? lastName : 'Portal User',
            PersonEmail = userEmail
        );

        insert personAcc;
        return personAcc.Id;
    }
    public String confirmPassword {
        get;
        set {
            confirmPassword = value == null ? value : value.trim();
        }
    }
    public String communityNickname {
        get;
        set {
            communityNickname = value == null ? value : value.trim();
        }
    }

    public CommunitiesSelfRegController() {
        String expid = ApexPages.currentPage().getParameters().get('expid');
        if (expId != null) {
            Site.setExperienceId(expId);
        }
    }

    private boolean isValidPassword() {
        return password == confirmPassword;
    }

    public PageReference registerUser() {
        System.debug('Registering user: ' + email);
        // it's okay if password is null - we'll send the user a random password in that case
        if (!isValidPassword()) {
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR, Label.site.passwords_dont_match);
            ApexPages.addMessage(msg);
            return null;
        }

        String profileId = [SELECT Id FROM Profile WHERE Name = :COMMUNITY_PROFILE_NAME LIMIT 1].Id;

        String userName = email;

        User u = new User();
        u.Username = userName;
        u.Email = email;
        u.FirstName = firstName;
        u.LastName = lastName;
        u.CommunityNickname = communityNickname;
        u.ProfileId = profileId;

        String userId;

        try {
            Id accountId = createPersonAccount(email, firstName, lastName, profileId);
            userId = Site.createExternalUser(u, accountId, password);
        } catch (Site.ExternalUserCreateException ex) {
            List<String> errors = ex.getDisplayMessages();
            for (String error : errors) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, error));
            }

            // This message is used for debugging. Do not display this in the UI to the end user.
            // It has the information around why the user creation failed.
            System.debug(ex.getMessage());
        }

        if (userId != null) {
            if (password != null && password.length() > 1) {
                return Site.login(userName, password, ApexPages.currentPage().getParameters().get('startURL'));
            } else {
                PageReference page = System.Page.CommunitiesSelfRegConfirm;
                page.setRedirect(true);
                return page;
            }
        }
        return null;
    }
}