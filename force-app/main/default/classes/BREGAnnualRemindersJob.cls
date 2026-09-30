public with sharing class BREGAnnualRemindersJob extends BREGBatchInterface {
    public override BatchProcessingResult processRecords(Map<Id, SObject> recordsMap, String sObjectType) {
        BatchProcessingResult result = new BatchProcessingResult();
        List<Account> accounts = (List<Account>) recordsMap.values();

        Map<Id, Account> accountsMap = new Map<Id, Account>(accounts);
        Map<Id, Contact> contactsInfoMap = getContactsInfoMap(accountsMap.keySet());
        result.tasksToUpsert = createEmailTasks(accounts, contactsInfoMap);
        return result;
    }

    private List<Task> createEmailTasks(List<Account> accounts, Map<Id, Contact> contactsInfoMap) {
        Date today = Date.today();
        List<Task> tasks = new List<Task>();
        for (Account nextAcc : accounts) {
            if (nextAcc.breg_Subscribe_Owner_Free_Email_Alerts__c == true){
                if (today.addMonths(1) == nextAcc.breg_Annuals_Due_Date__c) {
                    tasks.add(
                        createTask(
                            'Annual Renewal Upcoming Alert',
                            nextAcc.Id,
                            contactsInfoMap.get(nextAcc.Id),
                            'Annual Renewal Upcoming. Your annual filing date is set to be in a month',
                            today
                        )
                    );
                } else if (today == nextAcc.breg_Annuals_Due_Date__c) {
                    tasks.add(
                        createTask('Annual Renewal Alert', nextAcc.Id, contactsInfoMap.get(nextAcc.Id), 'Your annual filing date is set for today', today)
                    );
                } else if (today.addDays(-13) == nextAcc.breg_Annuals_Due_Date__c) {
                    tasks.add(
                        createTask('Annual Renewal Expired Alert', nextAcc.Id, contactsInfoMap.get(nextAcc.Id), 'Your annual filing date is expired', today)
                    );
                }
            }
        }
        return tasks;
    }

    private Task createTask(String subject, Id accountId, Contact theContact, String body, Date dueDate) {
        return new Task(
            TaskSubtype = 'Email',
            Subject = subject,
            WhatId = accountId,
            WhoId = theContact?.Id,
            breg_To__c = theContact?.Email,
            Description = body,
            ActivityDate = dueDate
        );
    }

    private Map<Id, Contact> getContactsInfoMap(Set<Id> accountIds) {
        Map<Id, Contact> contactsInfoMap = new Map<Id, Contact>();
        List<Case> nbrCases = [
            SELECT Contact.Id, Contact.Email, breg_Entity__c
            FROM Case
            WHERE breg_Entity__c IN :accountIds AND breg_Form_Configuration__r.breg_Business_Process__c = 'New Business' AND Status = 'Completed'
            ORDER BY CreatedDate DESC
        ];
        for (Case theCase : nbrCases) {
            contactsInfoMap.put(theCase.breg_Entity__c, theCase.Contact);
        }
        return contactsInfoMap;
    }
}