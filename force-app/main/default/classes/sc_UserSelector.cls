/****
 * Used for the Data retrieve from contact object
 * Created By: Alvin Zhou
 * Date: 11/02/2019
****/
public without sharing class sc_UserSelector {
    public static User getCurrentUserInformation() {
        List<User> records = [select Id, profile.Name, Email, Phone, Name, Contact.Account.Id 
            from User where UserType != 'Guest' and id=: Userinfo.getUserId()];
        
        return  records.isEmpty() ? new User() : records.get(0);
    }
}