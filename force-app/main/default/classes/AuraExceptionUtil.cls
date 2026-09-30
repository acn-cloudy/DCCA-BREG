public class AuraExceptionUtil {
    
    public static AuraHandledException getAuraExceptionWithApexMessage(Exception e) {
        String message = e.getMessage() + '. ' + e.getStackTraceString();
        AuraHandledException auraEx = new AuraHandledException(message);
        auraEx.setMessage(message);
        return auraEx;
    }

}