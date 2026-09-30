/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for CustomCommunityRegistration component
* Custom component that allows the user to self register
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC012519 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp
* @created      2019-01-25
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class CustomCommunityRegistrationController {

    public static string ObjectName { get; set; }
    public static Map<String, Schema.SObjectField> fMap { get; set; }

    @AuraEnabled
    public static List<FieldWrapper> getContactFields()
    {
        fMap = Schema.getGlobalDescribe().get('contact').getDescribe().Fields.getMap();

        ObjectName = 'Contact';

        List<FieldWrapper> toReturn = new List<FieldWrapper>();

        for (Schema.FieldSetMember fsm : Schema.SObjectType.Contact.fieldSets.CustomCommunityRegistrationField.getFields())
        {
            toReturn.add(new FieldWrapper(fsm));
        }

        return toReturn;
    }

    @AuraEnabled
    public static List<FieldWrapper> getAccountFields()
    {
        fMap = Schema.getGlobalDescribe().get('account').getDescribe().Fields.getMap();

        ObjectName = 'Account';
        List<FieldWrapper> toReturn = new List<FieldWrapper>();

        for (Schema.FieldSetMember fsm : Schema.SObjectType.Account.fieldSets.CustomCommunityRegistrationField.getFields())
        {
            toReturn.add(new FieldWrapper(fsm));
        }

        return toReturn;
    }

    @AuraEnabled
    public static Map<String, Object> getExistingContact(String params)
    {
        Map<String, String> paramsMap = (Map<String, String>)Json.deserialize(params, Map<String, String>.class);

        string firstName = paramsMap.get('firstName');
        string lastName = paramsMap.get('lastName');
        string email = paramsMap.get('email');
        String profileName = paramsMap.get('profileName');
        String query = 'SELECT Id';

        for (Schema.FieldSetMember fsm : Schema.SObjectType.Contact.fieldSets.CustomCommunityRegistrationField.getFields())
        {
            query += ', ' + fsm.getFieldPath();
        }

        query += ' FROM Contact WHERE AccountId != null AND Owner.IsActive = true AND (Email LIKE :email OR (Email LIKE :email AND FirstName LIKE :firstName AND LastName LIKE :lastName)) LIMIT 1';

        List<Contact> contacts = (List<Contact>)Database.query(query);
        System.debug(query);
        System.debug(firstName);
        System.debug(email);
        System.debug(contacts);
        if (contacts.isEmpty())
        {
            return null;
        }
        else
        {
            //Check if contact already is a user
            Id cntId = contacts[0].Id;
            List<User> existingUsers = [SELECT Id FROM User WHERE Profile.Name=:profileName AND ContactId = :cntId];
System.debug('has contact');
            //contact is already a user
            if (!existingUsers.isEmpty()) {
                System.debug('has user');
                Map<String, Object> toReturn = new Map<String, Object>();

                toReturn.put('Id', contacts[0].Id);
                List<Schema.FieldSetMember> contactFields = Schema.SObjectType.Contact.fieldSets.CustomCommunityRegistrationField.getFields();

                for (Schema.FieldSetMember fsm : contactFields) {
                    toReturn.put(fsm.getFieldPath(), contacts[0].get(fsm.getFieldPath()));
                }

                return toReturn;
            }else{
                Profile profile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
                User u = new User();
                u.ProfileId = profile.Id;
                u.firstName = contacts[0].FirstName;
                u.middleName = contacts[0].MiddleName;
                u.lastName = contacts[0].LastName;
                u.ContactId = cntId;
                u.Username = contacts[0].Email;
                u.Email = contacts[0].Email;
                u.Alias = buildAlias(contacts[0].FirstName, contacts[0].LastName);
                u.CommunityNickname = u.Alias + DateTime.now().format('yyMMddHHmmss');
                u.TimeZoneSidKey = 'Pacific/Honolulu'; // Required
                u.LocaleSidKey = 'en_US'; // Required
                u.EmailEncodingKey = 'ISO-8859-1'; // Required
                u.LanguageLocaleKey = 'en_US'; // Required
                u.Division__c = 'BREG';

                insert u;
                Map<String, Object> toReturnUser = new Map<String, Object>();
                toReturnUser.put('IsUserCreated', true);
                return toReturnUser;
            }
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> getExistingAccount(String params)
    {
        Map<String, String> paramsMap = (Map<String, String>)Json.deserialize(params, Map<String, String>.class);

        String nameFuzzy = '%' + paramsMap.get('accountName') + '%';
        String street = paramsMap.get('street');
        String streetFuzzy = '%' + street + '%';
        String dba = paramsMap.get('dba');
        String crd = paramsMap.get('crd');
        String query = 'SELECT Id';

        for (Schema.FieldSetMember fsm : Schema.SObjectType.Account.fieldSets.CustomCommunityRegistrationField.getFields())
        {
            query += ', ' + fsm.getFieldPath();
        }

        query += ' FROM Account WHERE Owner.IsActive = true AND Name LIKE :nameFuzzy AND (';
        List<String> queries = new List<String>();
        if(String.isNotEmpty(dba)){
        queries.add('DBA__c = :dba');
        }

        if(String.isNotEmpty(crd)){
         queries.add('CRD__c = :crd');
        }

        if(String.isNotEmpty(street)){
            queries.add('BillingStreet LIKE :streetFuzzy');
        }

        query += String.join(queries, ' OR ');

        query += ') AND RecordType.DeveloperName = \'' + paramsMap.get('businessAccRecordTypeDeveloperName') + '\'';

        List<Account> accounts = (List<Account>)Database.query(query);

        List<Map<String, Object>> toReturn = new List<Map<String, Object>>();

        for (Account acc : accounts)
        {
            Map<String, Object> toReturnObj = new Map<String, Object>();
            toReturnObj.put('Id', acc.Id);

            for (Schema.FieldSetMember fsm : Schema.SObjectType.Account.fieldSets.CustomCommunityRegistrationField.getFields())
            {
                toReturnObj.put(fsm.getFieldPath(), acc.get(fsm.getFieldPath()));
            }

            toReturn.add(toReturnObj);
        }

        return toReturn;
    }

    @AuraEnabled
    public static CallResponse finalizeRecords(Account account, Contact contact, string profileName, string workForCompany, string useExistingAccount, String businessAccRecordTypeDeveloperName, String personAccRecordTypeDeveloperName)
    {
        Savepoint sp = Database.setSavepoint();

        Id cntId = null;

        if (workForCompany == 'true')
        {
            // Working for a company
            Id accId;

            if (useExistingAccount == 'false')
            {
                // If not existing account
                Id accRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(businessAccRecordTypeDeveloperName).getRecordTypeId();

                Account acc = new Account();
                acc.OwnerId = Label.CustomRegistrationAccountOwner;
                acc.RecordTypeId = accRTId;

                for (Schema.FieldSetMember fsm : Schema.SObjectType.Account.fieldSets.CustomCommunityRegistrationField.getFields())
                {
                    acc.put(fsm.getFieldPath(), account.get(fsm.getFieldPath()));
                }

                try
                {
                    insert acc;
                }
                catch (DmlException e)
                {
                    Database.rollback(sp);
                    return new CallResponse(e.getMessage());
                }

                accId = acc.Id;
            }
            else
            {
                accId = account.Id;
            }

            //Id cntRTId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('BusinessContact').getRecordTypeId();
            Contact cnt = new Contact();
            //cnt.RecordTypeId = cntRTId;
            cnt.AccountId = accId;

            for (Schema.FieldSetMember fsm : Schema.SObjectType.Contact.fieldSets.CustomCommunityRegistrationField.getFields())
            {
                cnt.put(fsm.getFieldPath(), contact.get(fsm.getFieldPath()));
            }

            try
            {
                cnt.OwnerId = Label.CustomRegistrationAccountOwner;

                insert cnt;
            }
            catch (DmlException e)
            {
                Database.rollback(sp);
                return new CallResponse(e.getMessage());
            }

            cntId = cnt.Id;
        }
        else
        {
            fMap = Schema.getGlobalDescribe().get('account').getDescribe().Fields.getMap();

            // Not working for a company
            Id accRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(personAccRecordTypeDeveloperName).getRecordTypeId();
            Account acc = new Account();
            acc.OwnerId = Label.CustomRegistrationAccountOwner;
            acc.RecordTypeId = accRTId;

            for (Schema.FieldSetMember fsm : Schema.SObjectType.Contact.fieldSets.CustomCommunityRegistrationField.getFields())
            {
                if (fMap.containsKey(fsm.getFieldPath().toLowerCase()))
                {
                    acc.put(fsm.getFieldPath(), contact.get(fsm.getFieldPath()));
                }
                else if (fMap.containsKey('person' + fsm.getFieldPath().toLowerCase()))
                {
                    acc.put('Person' + fsm.getFieldPath(), contact.get(fsm.getFieldPath()));
                }
            }

            acc.BillingStreet = acc.PersonMailingStreet;
            acc.BillingCity = acc.PersonMailingCity;
            acc.BillingCountryCode = acc.PersonMailingCountryCode;
            acc.BillingPostalCode = acc.PersonMailingPostalCode;
            acc.BillingStateCode = acc.PersonMailingStateCode;

            try
            {
                insert acc;
            }
            catch (DmlException e)
            {
                Database.rollback(sp);
                return new CallResponse(e.getMessage());
            }

            acc = [SELECT PersonContactId FROM Account WHERE Id = :acc.Id];
            cntId = acc.PersonContactId;
        }

        Profile profile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        User u = new User();
        u.ProfileId = profile.Id;
        u.firstName = contact.FirstName;
        u.middleName = contact.MiddleName;
        u.lastName = contact.LastName;
        u.ContactId = cntId;
        u.Username = contact.Email;
        u.Email = contact.Email;
        u.Alias = buildAlias(contact.FirstName, contact.LastName);
        u.CommunityNickname = u.Alias + DateTime.now().format('yyMMddHHmmss');
        u.TimeZoneSidKey = 'Pacific/Honolulu'; // Required
        u.LocaleSidKey = 'en_US'; // Required
        u.EmailEncodingKey = 'ISO-8859-1'; // Required
        u.LanguageLocaleKey = 'en_US'; // Required
        u.Division__c = 'BREG';

        try
        {
            insert u;
        }
        catch (DmlException e)
        {
            Database.rollback(sp);
            return new CallResponse(e.getMessage());
        }

        return new CallResponse();
    }

    public class CallResponse {
        @AuraEnabled
        public boolean success { get; set; }
        @AuraEnabled
        public string errorMessage { get; set; }

        public CallResponse() {
            success = true;
        }
        public CallResponse(String errorMessage) {
            success = false;
            this.errorMessage = errorMessage;
        }
    }

    public class FieldWrapper
    {
        public Schema.FieldSetMember fsm { get; set; }

        @AuraEnabled
        public string fieldAPIName {
            get {
                return fsm.getFieldPath();
            }
        }

        @AuraEnabled
        public string fieldLabel {
            get {
                if (fieldAPIName == null)
                    return '';
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getLabel();
            }
        }

        @AuraEnabled
        public string fieldHelpText {
            get {
                if (fieldAPIName == null)
                    return '';
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getInlineHelpText();
            }
        }

        @AuraEnabled
        public boolean fieldIsCreatable {
            get {
                return fieldAPIName != null && (fieldType == 'ADDRESS' || fMap.get(fieldAPIName.toLowerCase()).getDescribe().isCreateable() || fMap.get(fieldAPIName.toLowerCase()).getDescribe().isUpdateable());
            }
        }
        @AuraEnabled
        public boolean fieldIsMandatory {
            get {
                return fsm.getRequired() || fsm.getDbRequired();
            }
        }
        @AuraEnabled
        public string fieldType {
            get {
                if (fieldAPIName == null)
                    return '';
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getType().name();
            }
        }

        @AuraEnabled
        public List<PicklistOption> statesOptions
        {
            get
            {
                List<PicklistOption> optoReturn = new List<PicklistOption>();
                Schema.sObjectType objType = Account.getSObjectType();
                Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
                map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
                list<Schema.PicklistEntry> values = fieldMap.get('ShippingStateCode').getDescribe().getPickListValues();

                List<SelectOption> options = new List<SelectOption>();
                for (Schema.PicklistEntry v : values){
                    optoReturn.add(new PicklistOption(v));
                }

                return optoReturn;
            }
        }

        @AuraEnabled
        public List<PicklistOption> piclistOptions
        {
            get
            {
                List<PicklistOption> toReturn = new List<PicklistOption>();

                if(fieldAPIName != null)
                {
                    if (fieldAPIName.endsWith('StateCode')) {
                        string countryAPIName = fieldAPIName.replace('StateCode', 'CountryCode');
                    	Map<String, List<String>> dependencies = getFieldDependencies(ObjectName, countryAPIName, fieldAPIName);
                        for (Schema.PicklistEntry plE : fMap.get(fieldAPIName.toLowerCase()).getDescribe().getPicklistValues())
                        {
                            string depValue = '';
                            for (string key : dependencies.keyset()) {
                                if (dependencies.get(key).contains(plE.getLabel())) {
                                    depValue = key;
                                }
                            }

                            toReturn.add(new PicklistOption(plE, countryAPIName, depValue));
                        }
                    } else {
                        for (Schema.PicklistEntry plE : fMap.get(fieldAPIName.toLowerCase()).getDescribe().getPicklistValues())
                        {
                            toReturn.add(new PicklistOption(plE));
                        }
                    }
                }

                return toReturn;
            }
        }

        @AuraEnabled
        public object defaultValue {
            get {
                if (sObj != null) {
                    return sObj.get(fieldAPIName);
                }
                if (fieldAPIName != null)
                    return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getDefaultValue();
                return null;
            }
        }

        private sObject sObj { get; set; }

        public FieldWrapper(Schema.FieldSetMember field)
        {
            this.fsm = field;
        }
    }

    public class PicklistOption {
        @AuraEnabled
        public string label { get; set; }
        @AuraEnabled
        public string value { get; set; }
        @AuraEnabled
        public string dependentOnField { get; set; }
        @AuraEnabled
        public string dependentOnValue { get; set; }

        public PicklistOption(Schema.PicklistEntry plE) {
            label = plE.getLabel();
            value = plE.getValue();
            dependentOnField = '';
            dependentOnValue = '';
        }

        public PicklistOption(Schema.PicklistEntry plE, String fName, String fValue) {
            label = plE.getLabel();
            value = plE.getValue();
            dependentOnField = fName;
            dependentOnValue = fValue;
        }
    }

    public class MyPickListInfo
    {
        public String validFor;
    }

    public static Map<String, List<String>> getFieldDependencies(String objectName, String controllingField, String dependentField)
    {
        Map<String, List<String>> controllingInfo = new Map<String, List<String>>();

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);

        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        Schema.DescribeFieldResult controllingFieldInfo = describeResult.fields.getMap().get(controllingField).getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = describeResult.fields.getMap().get(dependentField).getDescribe();

        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();

        for(Schema.PicklistEntry currControllingValue : controllingValues)
        {
            controllingInfo.put(currControllingValue.getValue(), new List<String>());
        }

        for(Schema.PicklistEntry currDependentValue : dependentValues)
        {
            String jsonString = JSON.serialize(currDependentValue);

            MyPickListInfo info = (MyPickListInfo) JSON.deserialize(jsonString, MyPickListInfo.class);

            String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(info.validFor)).toUpperCase();

            Integer baseCount = 0;

            for(Integer curr : hexString.getChars())
            {
                Integer val = 0;

                if(curr >= 65)
                {
                    val = curr - 65 + 10;
                }
                else
                {
                    val = curr - 48;
                }

                if((val & 8) == 8)
                {
                    controllingInfo.get(controllingValues[baseCount + 0].getValue()).add(currDependentValue.getLabel());
                }
                if((val & 4) == 4)
                {
                    controllingInfo.get(controllingValues[baseCount + 1].getValue()).add(currDependentValue.getLabel());
                }
                if((val & 2) == 2)
                {
                    controllingInfo.get(controllingValues[baseCount + 2].getValue()).add(currDependentValue.getLabel());
                }
                if((val & 1) == 1)
                {
                    controllingInfo.get(controllingValues[baseCount + 3].getValue()).add(currDependentValue.getLabel());
                }

                baseCount += 4;
            }
        }

        System.debug('ControllingInfo: ' + controllingInfo);

        return controllingInfo;
    }

    public static string buildAlias(string fName, string lName)
    {
        String alias = '';
        integer left = 8;

        if (fName != null && fname != '')
        {
            alias = fName.substring(0,1);
            left = 7;
        }

        if (lName != null)
        {
            if (lName.length() <= left)
            {
                alias += lName;
            }
            else
            {
                alias += lName.substring(0, left);
            }
        }

        return alias;
    }

}