/****
 * Description: used to capture application logs.
 * 
 * ** */
public class ApplicationLogService {
    public static void logApplicationError(String type, String recordId, String info, String error) {
        PVLErrorHandler__e log = new PVLErrorHandler__e();
        log.Debug_Level__c = 'Error';
        log.Type__c = type;
        log.Reference_Id__c = recordId;
        log.Message__c = info;
        log.Stack_Trace__c = error;
        EventBus.publish(log);
    }
    
}