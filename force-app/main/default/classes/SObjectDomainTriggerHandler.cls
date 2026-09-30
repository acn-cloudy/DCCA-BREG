public virtual without sharing class SObjectDomainTriggerHandler extends fflib_SObjectDomain {
    
    @TestVisible
    protected UnitOfWork unitOfWork;
    @TestVisible
    static Boolean skipIsTriggerActiveForTest = true;
    @TestVisible
    static String SObjectDomainTriggerHandlerTest = 'SObjectDomainTriggerHandlerTest.';

    public SObjectDomainTriggerHandler(sObject[] sObjects, sObjectType[] unitOfWorkSObjectTypes) {
        super(sObjects);
        if (unitOfWorkSObjectTypes != null && !unitOfWorkSObjectTypes.isEmpty()) {
            this.unitOfWork = new UnitOfWork(unitOfWorkSObjectTypes);
        }
        if (!isTriggerActive()) {
            fflib_SObjectDomain.getTriggerEvent(Type.forName(System.Test.isRunningTest() ? SObjectDomainTriggerHandlerTest + getHandlerName() : getHandlerName())).disableAll();
        }
        Configuration.disableTriggerCRUDSecurity();
    }

    @TestVisible
    private String getHandlerName() {
        Integer len = String.valueOf(this).indexOf(':');
        if(len > 0) {
            return String.valueOf(this).substring(0,len);
        } else {
            return String.valueOf(this);
        }
        
    }

    @TestVisible    
    private Boolean isTriggerActive() {
        if (System.Test.isRunningTest() && skipIsTriggerActiveForTest) { return true; } 
        String fieldName = this.getHandlerName() + '__c';
        if (Schema.SObjectType.ProcessSwitches__c.fields.getMap().containsKey(fieldName.toLowercase())) { 
            Boolean res = (Boolean)ProcessSwitches__c.getInstance(UserInfo.getUserId())?.get(fieldName);
            return res == null ? true : res;
        }
        return true;
    }

    protected void commitWork() {
        this.unitOfWork?.commitWork();
    }

    @TestVisible
    protected SObject[] getChangedToRecords(Schema.SObjectField fieldToken, Object changedToValue) {
        SObject[] changedRecords = new List<SObject>();
        for (SObject newRecord : Records) {
            if (ExistingRecords == null || !ExistingRecords.containsKey(newRecord.Id)) {
                if (newRecord.get(fieldToken) == changedToValue) {
                    changedRecords.add(newRecord);
                }
            } else if (ExistingRecords.get(newRecord.Id).get(fieldToken) != changedToValue && newRecord.get(fieldToken) == changedToValue) {
                changedRecords.add(newRecord);
            }
        }
        return changedRecords;
    }

    @TestVisible
    protected SObject[] getChangedToNotNullRecords(Schema.SObjectField fieldToken) {
        SObject[] changedRecords = new List<SObject>();
        for (SObject rec : Records) {
            if (rec.get(fieldToken) != null && ExistingRecords?.get(rec.Id)?.get(fieldToken) == null) {
                changedRecords.add(rec);
            }
        }
        return changedRecords;
    }


    // OVERRIDE CONTEXT METHODS TO ADD IN COMMIT WORK STATEMENT

    void logAndThrow(Exception e, String methodName) { 
        CustomLogger.logException(e, getHandlerName(), methodName, 'Records = ' + Records + (ExistingRecords != null ? ' ... Existing Records = ' + ExistingRecords : ''));
        throw e;
    }

    public virtual override void handleBeforeInsert() {
        try {
            super.handleBeforeInsert();
            this.commitWork();
        } catch (Exception e) {
            logAndThrow(e, 'handleBeforeInsert');
        }
    }

    public virtual override void handleAfterInsert() {
        try {
            super.handleAfterInsert();
            this.commitWork();
        } catch (Exception e) {
            logAndThrow(e, 'handleAfterInsert');
        }
    }

    public virtual override void handleBeforeUpdate(Map<Id,SObject> existingRecords) {
        try {
            super.handleBeforeUpdate(existingRecords);
            this.commitWork();
        } catch (Exception e) {
            logAndThrow(e, 'handleBeforeUpdate');
        }
    }

    public virtual override void handleAfterUpdate(Map<Id,SObject> existingRecords) {
        try {
            super.handleAfterUpdate(existingRecords);
            this.commitWork();
        } catch (Exception e) {
            logAndThrow(e, 'handleAfterUpdate');
        }
    }

    public virtual override void handleAfterDelete(Map<Id,SObject> existingRecords) {
        try {
            super.handleAfterDelete(existingRecords);
            this.commitWork();
        } catch (Exception e) {
            logAndThrow(e, 'handleAfterDelete');
        }
    }

    public virtual override void handleBeforeDelete() {
        try {
            super.handleBeforeDelete();
            this.commitWork();
        } catch (Exception e) {
            logAndThrow(e, 'handleBeforeDelete');
        }
    }

    public virtual override void handleAfterUndelete() {
        try {
            super.handleAfterUndelete();
            this.commitWork();
        } catch (Exception e) {
            logAndThrow(e, 'handleAfterUndelete');
        }
    }


    // STATIC METHODS

    public static void bypass(Type handlerClass) {
        fflib_SObjectDomain.getTriggerEvent(handlerClass)?.disableAll();
    }

    public static void clearBypass(Type handlerClass) {
        fflib_SObjectDomain.getTriggerEvent(handlerClass)?.enableAll();
    }

}