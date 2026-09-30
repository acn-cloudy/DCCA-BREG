/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Account Record Search Create component
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class AccountRecordsSearchCreate {
    public class Option{
        public String label {set; get;}
        public String name {set; get;}
    }
    @AuraEnabled
    public static String getFieldSetByName(String fieldSetName) {

        return JSON.serialize(getFieldSet(fieldSetName));
    }
    public static List<Option> getFieldSet(String fieldSetName) {
        List<Option> options = new List<Option>();
        Schema.FieldSet fieldSet = Schema.SObjectType.Account.fieldSets.getMap().get(fieldSetName);
        for(Schema.FieldSetMember f : fieldSet.getFields()) {
            SObjectField field = f.getSObjectField ();            
            Option opt = new Option();
            opt.label = field.getDescribe().getLabel();
            opt.name = field.getDescribe().getName();
            options.add(opt);
        }
        return options;
    }
    
    public static List<Option> getFieldSet(String fieldSetName, String objectName) {
        Schema.FieldSet fieldSet = Schema.getGlobalDescribe().get(objectName).getDescribe().fieldSets.getMap().get(fieldSetName);
        List<Option> options = new List<Option>();
        for(Schema.FieldSetMember f : fieldSet.getFields()) {
            SObjectField field = f.getSObjectField (); 
            Option opt = new Option();           
            opt.label = field.getDescribe().getLabel();
            opt.name = field.getDescribe().getName();
            options.add(opt);
        }
        return options;
    }
    
    @AuraEnabled
    public static String searchAccountByBPID(String BPID, String accountType, String accountName, String accountFEIN) {
        String fieldSetName = 'PVLPersonAccountSearchresults';
        
        if(accountType == 'Business Account') {
            fieldSetName = 'PVLAccountSearchresults';  
        } 
          
        List<Option> options = getFieldSet(fieldSetName);
        String query = 'Select Id ';
        for(Option op: options) {
            query  = query + ' ,' + op.name;
        }
        query = query.removeEnd(',');
        
        if(accountType == 'Business Account') {
            query = query + ' from Account where IsPersonAccount = false ';
            if(accountName != null && accountName != '') {
                accountName = '%'+ accountName + '%';
                query = query + ' and  Name like \''+ accountName+'\' ';
            }
            if(accountFEIN != null && accountFEIN != '') {
                query = query + ' and FEIN__c =: accountFEIN ';   
            }
            System.debug('Query Item = '+ query);
        } else {
            query = query + ' from Account where BPID__c =: BPID';
            query = query + ' and IsPersonAccount = true';
        }
        List<Account> accounts = Database.query(query);
        return JSON.serialize(accounts);
    }
    @AuraEnabled
    public static String loadAccount(String recordId, String layoutName) {
        Set<String> fieldNames = new Set<String>();
        Account acc = [Select Id, isPersonAccount from Account where Id=: recordId];
        String sobjType = 'Account';
        if(acc.isPersonAccount) {
            sobjType = 'PersonAccount';
            fieldNames.add('FirstName__c');
            fieldNames.add('LastName__c');
            fieldNames.add('MiddleName__c');
            fieldNames.add('Salutation__c');
            fieldNames.add('FirstName');
            fieldNames.add('LastName');
            fieldNames.add('MiddleName');
            fieldNames.add('Salutation');
        }
        List<String> componentNameList = new List<String>{sobjType+ '-' + layoutName };
        List<Metadata.Metadata> components = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, componentNameList);
        System.debug(sobjType+ '-' + layoutName);
        for (Metadata.LayoutSection section : ((Metadata.Layout)components.get(0)).layoutSections) {
            if (section.style != Metadata.LayoutSectionStyle.CustomLinks && section.label != 'IGNORE') {
                if(section.layoutColumns.get(0).layoutItems != null) {
                    for(Metadata.LayoutItem item: section.layoutColumns.get(0).layoutItems) {
                        String fieldName = item.field;
                        fieldNames.add(fieldName);
                    }
                }
                
                if(section.layoutColumns.size() > 1) {
                    if(section.layoutColumns.get(1).layoutItems != null) {
                        for(Metadata.LayoutItem item: section.layoutColumns.get(1).layoutItems) {
                            String fieldName = item.field;       
                            fieldNames.add(fieldName);
                        } 
                    }
                }
            }
        }
        List<String> fieldList = new List<String>();
        for(String fieldName: fieldNames) {
            if(fieldName == null ) {
                continue;
            }
            if(fieldName.endsWith('Address')) {
                fieldNames.add(fieldName.replace('Address', 'Street'));
                fieldNames.add(fieldName.replace('Address', 'City'));
                fieldNames.add(fieldName.replace('Address', 'PostalCode'));
                fieldNames.add(fieldName.replace('Address', 'State'));
                fieldNames.add(fieldName.replace('Address', 'StateCode'));
                fieldNames.add(fieldName.replace('Address', 'Country'));
                fieldNames.remove(fieldName);
            }
        }
        for(String fieldName: fieldNames) {
            if(fieldName != null )
                fieldList.add(fieldName);
        }
        
        String queryStr = String.join(fieldList, ',');
        String query = 'Select Id, '+ queryStr + ' from Account where Id=: recordId';
        System.debug('######query####### ' + query);
        List<Account> accounts = Database.query(query);
        if(acc.isPersonAccount) {
            for(Account accRecord: accounts) {
                accRecord.FirstName__c = accRecord.FirstName;
                accRecord.LastName__c = accRecord.LastName;
                accRecord.MiddleName__c = accRecord.MiddleName;
                accRecord.Salutation__c = accRecord.Salutation;
            }
        }
        return JSON.serialize(accounts);
    }
    
    @AuraEnabled
    public static String createAccount(String record, String recordTypeName){
        // Call CustomRecordCreate to create Application record
        return CustomRecordCreate.SaveRecord('Account', record, recordTypeName);
    }

}