public with sharing class BREGRunFlowScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Flow.Interview flow = Flow.Interview.createInterview('BREG_Notification_Sending', new Map<String, Object>());
        flow.start();
    }
}