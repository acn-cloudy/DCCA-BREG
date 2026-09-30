@IsTest
public with sharing class BREGMetadataDeployCallbackTest {
    
    /**
     * Test successful deployment scenario
     */
    @IsTest
    static void testHandleResult_SuccessfulDeployment() {
        // Create mock deployment result for successful deployment
        Metadata.DeployResult result = new Metadata.DeployResult();
        result.status = Metadata.DeployStatus.Succeeded;
        result.id = '0Af000000000001';
        
        // Create deployment details with successful components
        Metadata.DeployDetails details = new Metadata.DeployDetails();
        List<Metadata.DeployMessage> successMessages = new List<Metadata.DeployMessage>();
        
        Metadata.DeployMessage successMsg = new Metadata.DeployMessage();
        successMsg.fullName = 'TestCustomMetadata.TestRecord';
        successMsg.componentType = 'CustomMetadata';
        successMessages.add(successMsg);
        
        details.componentSuccesses = successMessages;
        result.details = details;
        
        Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();
        
        Test.startTest();
        BREGMetadataDeployCallback callback = new BREGMetadataDeployCallback();
        callback.handleResult(result, context);
        Test.stopTest();
    }
    
    /**
     * Test failed deployment scenario
     */
    @IsTest
    static void testHandleResult_FailedDeployment() {
        // Create mock deployment result for failed deployment
        Metadata.DeployResult result = new Metadata.DeployResult();
        result.status = Metadata.DeployStatus.Failed;
        result.id = '0Af000000000002';
        
        // Create deployment details with failed components
        Metadata.DeployDetails details = new Metadata.DeployDetails();
        List<Metadata.DeployMessage> failureMessages = new List<Metadata.DeployMessage>();
        
        Metadata.DeployMessage failureMsg = new Metadata.DeployMessage();
        failureMsg.fullName = 'TestCustomMetadata.FailedRecord';
        failureMsg.componentType = 'CustomMetadata';
        failureMsg.problem = 'Invalid field value';
        failureMessages.add(failureMsg);
        
        details.componentFailures = failureMessages;
        result.details = details;
        
        Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();
        
        Test.startTest();
        BREGMetadataDeployCallback callback = new BREGMetadataDeployCallback();
        callback.handleResult(result, context);
        Test.stopTest();
    }
}