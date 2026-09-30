public class BREGMetadataDeployCallback implements Metadata.DeployCallback {
    
    /**
     * @description Handle the deployment result
     * @param result The deployment result containing success/failure information
     * @param context The deployment context
     */
    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        try {            
            if (result.status == Metadata.DeployStatus.Succeeded) {
                System.debug(LoggingLevel.INFO, 'BREG Metadata Deployment: Successfully updated custom metadata records');
                System.debug(LoggingLevel.DEBUG, 'Deployment ID: ' + result.id);
                
                // Log details about what was deployed
                if (result.details != null && result.details.componentSuccesses != null) {
                    for (Metadata.DeployMessage successMsg : result.details.componentSuccesses) {
                        System.debug(LoggingLevel.DEBUG, 'Successfully deployed: ' + successMsg.fullName + 
                                   ' (Type: ' + successMsg.componentType + ')');
                    }
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'BREG Metadata Deployment: Failed to update custom metadata records');
                System.debug(LoggingLevel.ERROR, 'Deployment ID: ' + result.id);
                
                // Log failure details
                if (result.details != null && result.details.componentFailures != null) {
                    for (Metadata.DeployMessage failureMsg : result.details.componentFailures) {
                        System.debug(LoggingLevel.ERROR, 'Failed to deploy: ' + failureMsg.fullName + 
                                   ' - Problem: ' + failureMsg.problem + 
                                   ' (Type: ' + failureMsg.componentType + ')');
                    }
                }
            }                        
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'BREG Metadata Deploy Callback: Exception in handleResult - ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
}