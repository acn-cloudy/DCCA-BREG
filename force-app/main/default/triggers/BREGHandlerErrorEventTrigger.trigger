trigger BREGHandlerErrorEventTrigger on BREG_Handler_Error__e (after insert) {
    BREGHandlerErrorEventHandler.handleEvents(Trigger.new);
}