/*--------------------------------------------------------
Author:			Ronald Pascual
Company: 		Pacific Point Corp
Description:	A handler class for the exam result load trigger
Inputs:			"Exam Results Load Records" - Exam Result Load object that are being triggered
Test Class:

History
<Date>			<Authors Name>			<Brief Description of Change>
2019-09-16		Ronald Pascual			Created the logic for the exam result load trigger
 --------------------------------------------------------*/
public class ExamResultLoadHandler implements ITrigger {
	public ExamResultLoadHandler() {}
    public void bulkBefore() {}
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    
    public void beforeInsert(List<SObject> newlstObj) {
        ExamResultLoadService.populateExamResults(newlstObj);
    }
    
    public void bulkAfter() {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {}
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {}
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {}
}