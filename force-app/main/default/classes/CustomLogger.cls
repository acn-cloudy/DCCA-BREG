/**
 * @author Mike Ceryak
 * @since 10/11/2021
 * 
 * Test Class: CustomLoggerTest
 * Description: Utilize this class to create CustomLog__c records for Errors or Info based on CustomLogLevelSettings__c custom setting.
 */
public without sharing class CustomLogger {

    public static Boolean alwaysAsync = false;
    // PUBLIC METHODS

    public static void log(String className, String methodName, String message, String parameters, String stackTrace, Integer logLevel) {
        if (validateLogLevelSettings(className, logLevel)) { 
            createLog(className, methodName, parameters, stackTrace, message, logLevel); 
        }
    }

    public static void logException(Exception e, String className, String methodName, String parameters) {
        if (validateLogLevelSettings(className, 1)) {
            logImmediately(className, methodName, parameters, e.getStackTraceString(), e.getMessage(), 1);
        }
    }


    // PRIVATE METHODS

    // Determines if log record should be created based on CustomLogLevelSettings__c custom setting.If the logLevel <= the value in the custom setting, return true. Else, return false. 
    // Default to true if no custom setting field is found for this class name.
    private static Boolean validateLogLevelSettings(String className, Integer logLevel) {
        if (logLevel < 1 || logLevel > 9) {
            throw new CustomLogException('logLevel must be in range [1, 9]. Given: ' + logLevel);
        }
        String fieldName = className + '__c';
        if (Schema.SObjectType.CustomLogLevelSettings__c.fields.getMap().containsKey(fieldName.toLowercase())) { 
            return logLevel <= Integer.valueOf(CustomLogLevelSettings__c.getInstance(UserInfo.getUserId()).get(fieldName));
        }
        return true;
    }

    // Publishes a log event immediately so that an error can still be thrown without rolling back the creation of the log record, which happens in a platform event-triggered flow
    public static void logImmediately(String className, String methodName, String parameters, String stackTrace, String message, Integer logLevel) {
        CustomLogEvent__e logEvent = new CustomLogEvent__e(
            Class__c = className,
            Method__c = methodName,
            Message__c = StringUtil.shortenedTo(255, message),
            StackTrace__c = StringUtil.shortenedTo(255, stackTrace),
            Parameters__c = parameters,
            LogLevel__c = logLevel,
            Occured__c = System.now()
        );
        Eventbus.publish(logEvent);
    }

    private static void createLog(String className, String methodName, String parameters, String stackTrace, String message, Integer logLevel) {
        CustomLog__c log = new CustomLog__c(
            Class__c = className,
            Method__c = methodName,
            Message__c = StringUtil.shortenedTo(255, message),
            StackTrace__c = StringUtil.shortenedTo(255, stackTrace),
            Parameters__c = stackTrace + '\n' + parameters,
            LogLevel__c = logLevel,
            Occured__c = System.now()
        );
        if (alwaysAsync || (!System.isBatch() && !System.isFuture())) {
            insertLogFuture(JSON.serialize(log));
        } else {
            handleLogInsert(log);
        }
    }

    @TestVisible
    private static void handleLogInsert(CustomLog__c log) {
        try {
            insert log;
        } catch (Exception e) {
            System.debug('failed to insert custom log because of exception: ' + e.getMessage() + ', ' + e.getStackTraceString());
        }
    }

    @future
    private static void insertLogFuture(String jsonLog) {
        CustomLog__c log = (CustomLog__c)JSON.deserialize(jsonLog, CustomLog__c.class);
        handleLogInsert(log);
    }

    public class CustomLogException extends Exception {}

}