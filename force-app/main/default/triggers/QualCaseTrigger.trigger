/**
 * @description Trigger for Case - Qualtrics integration
 * Detects Case lifecycle events (opened, updated, closed) and initiates Qualtrics workflow
 * @author Qualtrics Integration Team
 */
trigger QualCaseTrigger on Case (after insert, after update) {
    if (Trigger.isInsert) {
        QualCaseTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
        QualCaseTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}