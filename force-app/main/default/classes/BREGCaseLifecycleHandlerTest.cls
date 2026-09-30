@isTest
private class BREGCaseLifecycleHandlerTest {

    @isTest
    static void testExecuteActionFromFlowInvalidInput() {
        Case caseRecord = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web'
        );
        insert caseRecord;

        BREGCaseLifecycleHandler.FlowInput input = new BREGCaseLifecycleHandler.FlowInput();
        input.caseRecord = caseRecord;
        input.action = 'invalidAction';
        
        Test.startTest();
        boolean exceptionCaught = false;
        try {
            // Execute the flow action
            List<BREGCaseLifecycleHandler.FlowOutput> outputs = BREGCaseLifecycleHandler.executeActionFromFlow(
                new List<BREGCaseLifecycleHandler.FlowInput>{input}
            );
        } catch (Exception e) {
            exceptionCaught = true;
            Assert.isInstanceOfType(e, BREGCaseLifecycleHandler.CustomException.class, 'Expected CustomException');
            Assert.isTrue(e.getMessage().contains('Invalid action'), 'Expected message to contain "Invalid action"');
        }
        Test.stopTest();
        
        // Verify exception was caught
        Assert.isTrue(exceptionCaught, 'Expected an exception to be thrown');
    }

    @isTest
    static void testUpdateCaseWithAssignmentRules() {
        Case caseRecord = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web'
        );
        insert caseRecord;

        BREGCaseLifecycleHandler.FlowInput input = new BREGCaseLifecycleHandler.FlowInput();
        input.caseRecord = caseRecord;
        input.action = 'updateCaseWithAssignmentRules';
        
        Test.startTest();
        List<BREGCaseLifecycleHandler.FlowOutput> outputs = BREGCaseLifecycleHandler.executeActionFromFlow(
            new List<BREGCaseLifecycleHandler.FlowInput>{input}
        );
        Test.stopTest();
        
        // Verify the case was returned
        Assert.isNotNull(outputs[0].caseRecord, 'Expected a case to be returned');
    }
}