public with sharing class TriggerUtils {
    public static Boolean disableTrigger = false;

    @InvocableMethod(
        label='Reset Disable Trigger'
        description='Resets the disableTrigger flag to false'
        category='Trigger Utils'
    )
    public static void resetDisableTrigger(List<String> ignored) {
        disableTrigger = false;
    }
}