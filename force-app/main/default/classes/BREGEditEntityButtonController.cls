public with sharing class BREGEditEntityButtonController {
    private static final List<String> FIELD_PERMISSION_SET_PRIORITY = new List<String>{
        'BREG_Admin_User',
        'BREG_Supervisor_User',
        'BREG_DOC_R_User_permissions',
        'BREG_Standard_User'
    };

    private static final Set<String> X3_BYPASS_PERMISSION_SET_NAMES = new Set<String>{
        'BREG_Admin_User',
        'BREG_Supervisor_User',
        'BREG_DOC_R_User_permissions'
    };

    public class FieldOption {
        @AuraEnabled public String fieldName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isAddressGroup;
        @AuraEnabled public Boolean renderAsCompound;
        @AuraEnabled public List<FieldOption> childFields;

        public FieldOption() {
            this.childFields = new List<FieldOption>();
            this.isAddressGroup = false;
            this.renderAsCompound = false;
        }

        public FieldOption(String fieldName, String label) {
            this.fieldName = fieldName;
            this.label = label;
            this.isAddressGroup = false;
            this.renderAsCompound = false;
            this.childFields = new List<FieldOption>();
        }
    }

    public class InitResponse {
        @AuraEnabled public Boolean allowed;
        @AuraEnabled public String message;
        @AuraEnabled public List<FieldOption> editableFields;

        public InitResponse() {
            allowed = false;
            message = null;
            editableFields = new List<FieldOption>();
        }
    }

    @AuraEnabled
    public static InitResponse findEditableFields(Id accountId) {
        InitResponse res = new InitResponse();

        if (accountId == null) {
            res.message = 'Account Id is required.';
            return res;
        }

        if (!canEditEntity(accountId)) {
            res.message = 'Edit Entity is available only when Account has an approved case with Form Code = X-3.';
            return res;
        }

        res.allowed = true;
        res.editableFields = getEditableAccountFieldsFromPermissionSet();
        return res;
    }

    @AuraEnabled
    public static void validateBeforeSave(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }

        if (!canEditEntity(accountId)) {
            throw new AuraHandledException('Edit Entity is available only when Account has an approved case with Form Code = X-3.');
        }
    }

    private static Boolean canEditEntity(Id accountId) {
        return hasApprovedX3Case(accountId) || hasX3BypassPermissionSet();
    }

    private static Boolean hasApprovedX3Case(Id accountId) {
        return [
            SELECT COUNT()
            FROM Case
            WHERE breg_Entity__c = :accountId
              AND Status = 'Approved'
              AND breg_Form_Code__c = 'X-3'
        ] > 0;
    }

    private static Boolean hasX3BypassPermissionSet() {
        return [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.Name IN :X3_BYPASS_PERMISSION_SET_NAMES
        ] > 0;
    }

    private static String getAssignedFieldPermissionSetName() {
        Set<String> assignedPermissionSetNames = new Set<String>();

        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.Name IN :FIELD_PERMISSION_SET_PRIORITY
        ]) {
            assignedPermissionSetNames.add(psa.PermissionSet.Name);
        }

        for (String permissionSetName : FIELD_PERMISSION_SET_PRIORITY) {
            if (assignedPermissionSetNames.contains(permissionSetName)) {
                return permissionSetName;
            }
        }

        return null;
    }

    private static List<FieldOption> getEditableAccountFieldsFromPermissionSet() {
        String permissionSetName = getAssignedFieldPermissionSetName();

        if (String.isBlank(permissionSetName)) {
            return new List<FieldOption>();
        }

        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :permissionSetName
            LIMIT 1
        ];

        if (permissionSets.isEmpty()) {
            throw new AuraHandledException('Permission Set not found: ' + permissionSetName);
        }

        Id permissionSetId = permissionSets[0].Id;

        List<FieldPermissions> fieldPerms = [
            SELECT Field, PermissionsEdit, SobjectType
            FROM FieldPermissions
            WHERE ParentId = :permissionSetId
              AND SobjectType = 'Account'
              AND PermissionsEdit = true
        ];

        Set<String> permissionFieldApiNames = new Set<String>();
        for (FieldPermissions fp : fieldPerms) {
            if (String.isBlank(fp.Field)) {
                continue;
            }

            String fieldApiName = fp.Field.contains('.')
                ? fp.Field.substringAfter('.')
                : fp.Field;

            if (!String.isBlank(fieldApiName)) {
                permissionFieldApiNames.add(fieldApiName);
            }
        }

        Map<String, Schema.SObjectField> describeMap = Schema.SObjectType.Account.fields.getMap();
        Map<String, FieldDefinition> fieldDefinitionsByApiName = new Map<String, FieldDefinition>();

        if (!permissionFieldApiNames.isEmpty()) {
            for (FieldDefinition fd : [
                SELECT QualifiedApiName, Label, DataType
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName = 'Account'
                  AND QualifiedApiName IN :permissionFieldApiNames
            ]) {
                fieldDefinitionsByApiName.put(fd.QualifiedApiName, fd);
            }
        }

        Map<String, FieldOption> resultByApiName = new Map<String, FieldOption>();

        for (String fieldApiName : permissionFieldApiNames) {
            FieldDefinition fd = fieldDefinitionsByApiName.get(fieldApiName);

            if (fd != null && fd.DataType == 'Address') {
                FieldOption fieldGroup = new FieldOption();
                fieldGroup.fieldName = fieldApiName;
                fieldGroup.label = fd.Label;
                fieldGroup.isAddressGroup = true;
                fieldGroup.renderAsCompound = false;
                fieldGroup.childFields = new List<FieldOption>();

                if (fieldApiName.endsWith('__c')) {
                    String baseFieldName = fieldApiName.substring(0, fieldApiName.length() - 3);

                    List<String> addressChildFieldNames = new List<String>{
                        baseFieldName + '__Street__s',
                        baseFieldName + '__City__s',
                        baseFieldName + '__StateCode__s',
                        baseFieldName + '__PostalCode__s',
                        baseFieldName + '__CountryCode__s'
                    };

                    for (String childFieldApiName : addressChildFieldNames) {
                        if (!describeMap.containsKey(childFieldApiName)) {
                            continue;
                        }

                        Schema.DescribeFieldResult childDfr = describeMap.get(childFieldApiName).getDescribe();

                        if (!childDfr.isUpdateable()) {
                            continue;
                        }
                        if (childDfr.isCalculated()) {
                            continue;
                        }
                        if (childDfr.getName() == 'Id') {
                            continue;
                        }
                        if (childDfr.getType() == Schema.DisplayType.Address ||
                            childDfr.getType() == Schema.DisplayType.Location ||
                            childDfr.getType() == Schema.DisplayType.Base64) {
                            continue;
                        }

                        fieldGroup.childFields.add(
                            new FieldOption(childFieldApiName, childDfr.getLabel())
                        );
                    }
                }

                if (fieldGroup.childFields.isEmpty()) {
                    fieldGroup.renderAsCompound = true;
                }

                resultByApiName.put(fieldApiName, fieldGroup);
                continue;
            }

            if (!describeMap.containsKey(fieldApiName)) {
                continue;
            }

            Schema.DescribeFieldResult dfr = describeMap.get(fieldApiName).getDescribe();

            if (!dfr.isUpdateable()) {
                continue;
            }
            if (dfr.isCalculated()) {
                continue;
            }
            if (dfr.getName() == 'Id') {
                continue;
            }
            if (dfr.getType() == Schema.DisplayType.Address ||
                dfr.getType() == Schema.DisplayType.Location ||
                dfr.getType() == Schema.DisplayType.Base64) {
                continue;
            }

            resultByApiName.put(fieldApiName, new FieldOption(fieldApiName, dfr.getLabel()));
        }

        List<FieldOption> result = resultByApiName.values();
        result.sort(new FieldOptionSorter());
        return result;
    }

    public class FieldOptionSorter implements Comparator<FieldOption> {
        public Integer compare(FieldOption a, FieldOption b) {
            String left = a != null && a.label != null ? a.label : '';
            String right = b != null && b.label != null ? b.label : '';
            return left.toLowerCase().compareTo(right.toLowerCase());
        }
    }
}