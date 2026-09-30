public without sharing class PVL_RenewalDependency1wayFlowHelper {
  @InvocableMethod(
    label='Process Potential 1-Way Dependent Applications'
    description='Kick off the Renewal Dependency Flow for any possible license on the dependent side of the 1-way dependency'
    category='License'
  )
  public static void processOneWayApplications(
    List<License__c> licenses
  ) {
    Map<Id, License__c> licenseMap = new Map<Id, License__c>(licenses);
    if (!licenseMap.isEmpty()) {
      Eventbus.publish(new PVLProcess__e(
        Type__c = 'DependencyFlow',
        Payload__c = JSON.serialize(licenseMap.keySet())
      ));
    }
  }
}