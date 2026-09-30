/*
 * ___________________________________________________________________________________
 * Server Side Controller for Custom RelatedListTreeViewer component
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-CL11062019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/6/2019
 * __________________________________________________________________________________
 */
public class RelatedListTreeViewerController {
    @AuraEnabled
    public static String getIdObjectName(Id recordId) {
        return recordId.getSobjectType()
                .getDescribe()
                .getName();
    }

    @AuraEnabled
    public static CreateNewDef getChild1ObjectNameForNewRecord(String parentId, String childRel1) {
        GetDataParam param = new GetDataParam();
        param.parentId = parentId;
        param.childRel1 = childRel1;

        CreateNewDef newDef = new CreateNewDef();
        newDef.objectApiName = param.getChildRel1RelationshipDef().getChildSObject().getDescribe().getName();
        newDef.lookupFieldApiName = param.getChildRel1RelationshipDef().getField().getDescribe().getName();

        return newDef;
    }

    @AuraEnabled
    public static void saveUpdate(List<SObject> sObjects) {
        update sObjects;
    }

    @AuraEnabled
    public static List<GridColumn> getChild1Columns(String parentId,
                                                    String childRel1,
                                                    String childRel2,
                                                    String fields,
                                                    String editableFields) {
        GetDataParam param = new GetDataParam();
        param.parentId = parentId;
        param.childRel1 = childRel1;
        param.childRel2 = childRel2;


        List<String> cols = fields.split(',');
        List<String> editableCols = editableFields.split(',');

        Map<String, SObjectField> fieldMap = param.getChildRel1FieldMap();
        Set<String> editableFieldsSet = new Set<String>();
        editableFieldsSet.addAll(editableCols);

        List<GridColumn> result = new List<GridColumn>();

        for (String fieldApiName : cols) {
            DescribeFieldResult fieldResult = fieldMap.get(fieldApiName).getDescribe();
            GridColumn gridCol = new GridColumn(fieldResult);
            gridCol.editable = editableFieldsSet.contains(fieldApiName) && !gridCol.isCalculated;
            result.add(gridCol);
        }

        return result;
    }

    @AuraEnabled
    public static List<SObject> getData(String parentId,
                                        String childRel1,
                                        String childRel2,
                                        String childRel1SortField,
                                        String childRel1SortDirection,
                                        String child1RelAdditionalSort,
                                        Integer child1RecordLimit,
                                        String childRel2SortField,
                                        String childRel2SortDirection) {
        GetDataParam param = new GetDataParam();
        param.parentId = parentId;
        param.childRel1 = childRel1;

        //initialize first level relationship variables
        ChildRelationship childRel1Def = param.getChildRel1RelationshipDef();
        List<String> childRel1Fields = new List<String>();
        childRel1Fields.addAll(param.getChildRel1FieldMap().keySet());
        //end initialize first level relationship variables

        String child1RelQuery = 'SELECT ';
        child1RelQuery += String.join(childRel1Fields, ',');

        ChildRelationship childRel2Def;

        if (!String.isBlank(childRel2)) {
            //initialize second level relationship variables
            param.childRel2 = childRel2;
            childRel2Def = param.getChildRel2RelationshipDef();
            List<String> childRel2Fields = new List<String>();
            childRel2Fields.addAll(param.getChildRel2FieldMap().keySet());
            //end initialize second level relationship variables

            //construct second level child query
            String childRel2SubQuery = 'SELECT ';
            childRel2SubQuery += String.join(childRel2Fields, ',');
            childRel2SubQuery += ' FROM ';
            childRel2SubQuery += childRel2Def.getRelationshipName();
            if (childRel2SortField.length() > 0) {
                childRel2SubQuery += ' ORDER BY ' + childRel2SortField + ' ' + childRel2SortDirection;
            }
            child1RelQuery += ',(' + childRel2SubQuery + ')';
        }

        //construct first level child query
        child1RelQuery += ' FROM ';
        child1RelQuery += childRel1Def.getChildSObject().getDescribe().getName();
        child1RelQuery += ' WHERE ' + childRel1Def.getField().getDescribe().getName();
        child1RelQuery += ' = :parentId';

        if (!String.isBlank(childRel2)) {
            //condition to retrieve first level child only
            child1RelQuery += ' AND ' + childRel2Def.getField().getDescribe().getName() + ' = null';
        }

        Boolean child1OrderByAdded = false;

        if (childRel1SortField.length() > 0) {
            child1RelQuery += ' ORDER BY ' + childRel1SortField + ' ' + childRel1SortDirection;
            child1OrderByAdded = true;
        }

        if (child1RelAdditionalSort.length() > 0) {
            if (child1OrderByAdded) {
                child1RelQuery += ',' + child1RelAdditionalSort;
            } else {
                child1RelQuery += 'ORDER BY ' + child1RelAdditionalSort;
            }
        }

        if (child1RecordLimit > 0) {
            child1RelQuery += ' LIMIT ' + String.valueOf(child1RecordLimit);
        }

        List<SObject> sObjects = Database.query(child1RelQuery);
        return sObjects;
    }

    public class GridColumn{
        @AuraEnabled
        public String fieldApiName;

        @AuraEnabled
        public String fieldLabel;

        @AuraEnabled
        public Boolean editable;

        @AuraEnabled
        public String type;

        @AuraEnabled
        public Boolean isCalculated;

        @AuraEnabled
        public String referenceObjectName;

        @AuraEnabled
        public Boolean isNameField;

        @AuraEnabled
        public List<RelatedListTreeViewerController.PickListOption> pickListOptions;

        public GridColumn(DescribeFieldResult fieldResult) {
            isNameField = fieldResult.isNameField();
            fieldApiName = fieldResult.getName();
            fieldLabel = fieldResult.getLabel();
            type = fieldResult.getType().name();
            isCalculated = fieldResult.isCalculated();

            if (type == 'PICKLIST' || type == 'MULTIPICKLIST') {
                List<PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
                pickListOptions = new List<RelatedListTreeViewerController.PickListOption>();

                //default --None-- value
                if (type == 'PICKLIST') {
                    PickListOption opt = new PickListOption();
                    opt.label = '--None--';
                    opt.value = '';
                    pickListOptions.add(opt);
                }

                for (picklistEntry entry : picklistEntries) {
                    if (entry.isActive()) {
                        pickListOptions.add(new RelatedListTreeViewerController.PickListOption(entry));
                    }
                }
            }

            if (type == 'REFERENCE') {
                referenceObjectName = fieldResult.getReferenceTo()[0].getDescribe().getName();
            }
        }
    }

    public class PickListOption{
        @AuraEnabled
        public String label;

        @AuraEnabled
        public String value;

        public PickListOption() {
        }

        public PickListOption(PicklistEntry entry) {
            label = entry.getLabel();
            value = entry.getValue();
        }
    }

    public class CreateNewDef{
        @AuraEnabled
        public String objectApiName;

        @AuraEnabled
        public String lookupFieldApiName;
    }

    private class GetDataParam{
        Id parentId;
        String childRel1;
        String childRel2;

        public Map<String, SObjectField> getChildRel1FieldMap() {
            return getChildRel1RelationshipDef().getChildSObject().getDescribe().fields.getMap();
        }

        public Map<String, SObjectField> getChildRel2FieldMap() {
            return getChildRel2RelationshipDef().getChildSObject().getDescribe().fields.getMap();
        }

        public ChildRelationship getChildRel1RelationshipDef() {
            List<ChildRelationship> relationships = parentId.getSobjectType().getDescribe().getChildRelationships();

            Map<String, ChildRelationship> mapRel = new Map<String, ChildRelationship>();

            for (ChildRelationship cr : relationships) {
                mapRel.put(cr.getRelationshipName(), cr);
            }

            return mapRel.get(childRel1);
        }

        private ChildRelationship getChildRel2RelationshipDef() {
            List<ChildRelationship> relationships = getChildRel1RelationshipDef().getChildSObject()
                    .getDescribe()
                    .getChildRelationships();

            Map<String, ChildRelationship> mapRel = new Map<String, ChildRelationship>();

            for (ChildRelationship cr : relationships) {
                mapRel.put(cr.getRelationshipName(), cr);
            }

            return mapRel.get(childRel2);
        }
    }
}