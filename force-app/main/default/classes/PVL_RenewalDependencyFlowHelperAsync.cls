public with sharing class PVL_RenewalDependencyFlowHelperAsync {
  @InvocableMethod(
    label='Get Related Multidependency Application - Async'
    description='Process Any Multidependent Applications Asynchronously'
    category='License'
  )
  public static void getRelatedMultidependentApplications(
    List<License__c> licenses
  ) {
    Eventbus.publish(new PVLProcess__e(
      Type__c = 'MultiDependencyFlow',
      Payload__c = JSON.serialize(licenses)
    ));
  }
}