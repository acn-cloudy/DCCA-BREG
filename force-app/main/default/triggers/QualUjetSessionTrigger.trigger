/**
 * @description Trigger for UJET Session - independent Qualtrics Call payloads.
 */
trigger QualUjetSessionTrigger on UJET__UJET_Session__c(
  after insert,
  after update
) {
  if (Trigger.isInsert) {
    QualUjetSessionTriggerHandler.handleAfterInsert(Trigger.new);
  }
  if (Trigger.isUpdate) {
    QualUjetSessionTriggerHandler.handleAfterUpdate(
      Trigger.new,
      Trigger.oldMap
    );
  }
}