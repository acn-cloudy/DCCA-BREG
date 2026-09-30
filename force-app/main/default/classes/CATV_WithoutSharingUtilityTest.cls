@isTest
public with sharing class CATV_WithoutSharingUtilityTest {
    @isTest static void allMethodTest(){
        Account acc1 = CATV_TestClassUtility.createAccount('Test Account',false);
        Account acc2 = CATV_TestClassUtility.createAccount('Test Account',false);
        
        CATV_WithoutSharingUtility.doInsert(acc1);
        CATV_WithoutSharingUtility.doInsert(new List<Account>{acc2});
        CATV_WithoutSharingUtility.doUpdate(acc1);
        CATV_WithoutSharingUtility.doUpdate(new list<Account>{acc1});
        CATV_WithoutSharingUtility.doUpsert(acc1);
        CATV_WithoutSharingUtility.doUpsert(new list<Account>{acc1});
        CATV_WithoutSharingUtility.doDelete(acc1);
        CATV_WithoutSharingUtility.doDelete(new list<Account>{acc2});
        CATV_WithoutSharingUtility.queryRecords('SELECT Id FROM Account LIMIT 1', new Map<String, Object>());
        CATV_WithoutSharingUtility.fetchUserFromContactId('TEST');
        
        system.assertEquals(acc1 != null, true);
    }
    @isTest
    static void testGetParentId_FromFeedComment() {
        
        Account communityDefaultAcc = CATV_TestClassUtility.createAccount('Test Account',false);
        communityDefaultAcc.Type = 'Community';
        insert communityDefaultAcc;
        
        Contact requestorCon = CATV_TestClassUtility.createContact('lname', 'a@b.com', communityDefaultAcc.Id, false);
        requestorCon.Type__c = 'Requestor';
        insert requestorCon;
        
        Account requestorAcc = CATV_TestClassUtility.createAccount('test_acc',false);
        requestorAcc.Type = 'City';
        insert requestorAcc;
        
        Account providerAcc = CATV_TestClassUtility.createAccount('test_acc',false);
        providerAcc.Type = 'Provider';
        insert providerAcc;
        
        Contact providerCon = CATV_TestClassUtility.createContact('lname1', 'a@b1.com', providerAcc.Id, false);
        providerCon.Type__c = 'Provider';
        insert providerCon;
        
        // Create test record
        INET_Request__c request = CATV_TestClassUtility.createINETRequest(providerAcc, providerCon, requestorAcc, requestorCon, true);
        

        // Create FeedItem
        FeedItem post = new FeedItem(
            ParentId = request.Id,
            Body = 'Another post',
            Type = 'TextPost'
        );
        insert post;

        // Create FeedComment
        FeedComment comment = new FeedComment(
            FeedItemId = post.Id,
            CommentBody = 'Test comment'
        );
        insert comment;

        Test.startTest();
        Id result = CATV_WithoutSharingUtility.getParentId(comment.Id);
        Test.stopTest();

        System.assertEquals(request.Id, result, 'Should return the correct ParentId from FeedComment');
    }
}