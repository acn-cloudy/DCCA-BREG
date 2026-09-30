/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Creates Exam Results record when an application classification is created with Conditions:
* Exam Type Status = Active and License Type = Application's License Type
* Covered by
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-IC080619 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author Irene Cahilo - Pacificpoint
* @created 08/06/19
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class ApplicationClassificationCreateRecords {
    public static void appClassCreateExamResultsRecords(List<ApplicationClassifications__c> applicationClassificationsList){
        List<ExamsRequired__c> examRequiredToCreate = new List<ExamsRequired__c>();
        Set<Id> classificationIds = new Set<Id>();
        Set<Id> applicationIds = new Set<Id>();
        for(ApplicationClassifications__c ac : applicationClassificationsList){
            if(String.isNotBlank(ac.Classification__c)){
                classificationIds.add(ac.Classification__c);
            }
            if(String.isNotBlank(ac.Application__c)){
                applicationIds.add(ac.Application__c);
            }
        }

        List<ExamTypes__c> examTypesResult = [SELECT Id, Classification__c FROM ExamTypes__c WHERE Classification__c =: classificationIds AND Status__c = 'Active'];

        //Maps the Exam Type records to their corresponding Classification
        Map<Id, List<ExamTypes__c>> classificationIdExamTypesMap = new Map<Id, List<ExamTypes__c>>();

        for (ExamTypes__c examType : examTypesResult){

            if(!classificationIdExamTypesMap.containsKey(examType.Classification__c)){
                List<ExamTypes__c> newExamTypes = new List<ExamTypes__c>();
                classificationIdExamTypesMap.put(examType.Classification__c, newExamTypes);
            }

            classificationIdExamTypesMap.get(examType.Classification__c).add(examType);
        }

        //For the account record (Applicant__c)
        List<Application__c> applicationList = [SELECT Id, Applicant__c FROM Application__c WHERE Id =: applicationIds];

        //Maps the Application records to their corresponding License Type
        Map<Id, Application__c> applicationMap = new Map<Id, Application__c>();

        for (Application__c app : applicationList){
            if(!applicationMap.containsKey(app.Id)){
                applicationMap.put(app.Id, app);
            }
        }

        for(ApplicationClassifications__c applicationClassRecord : applicationClassificationsList){
            if(applicationClassRecord.Classification__c != null 
                && applicationClassRecord.Application__c != null
                && classificationIdExamTypesMap.containsKey(applicationClassRecord.Classification__c)){ //checks if the license type exists on the Map
                //Retrieves the Exam Type Records of the License Type from the Map
                List<ExamTypes__c> examTypesList = classificationIdExamTypesMap.get(applicationClassRecord.Classification__c);
                //For each Exam Type, create an Exams Required Record
                for(ExamTypes__c examTypeRecord : examTypesList){
                    ExamsRequired__c examRequiredRecord = new ExamsRequired__c();
                    examRequiredRecord.ExamType__c = examTypeRecord.Id;
                    examRequiredRecord.Application__c = applicationClassRecord.Application__c;
                    examRequiredRecord.Applicant__c = applicationMap.get(applicationClassRecord.Application__c).Applicant__c;
                    examRequiredToCreate.add(examRequiredRecord);
                }
            }
        }
        if(!examRequiredToCreate.isEmpty()){
            insert examRequiredToCreate;
        }
    }
}