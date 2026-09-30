/*
 * ___________________________________________________________________________________
 * Application Notice Signature Controller
 * For Application Notice Email Templates
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-EA10062023 - Created for Case 00030984
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 10/06/2023
 * __________________________________________________________________________________
 */
public with sharing class ApplicationNoticeSignatureController {
    public Application__c app{
        public get; public set;
    }

    public String getImageData() {
        if (app == null || app.Id == null) {
            return null;
        }

        Application__c appItem = [
                SELECT
                        Id,
                        LicenseType__r.BoardProgram__c
                FROM Application__c
                WHERE Id = :app.Id
        ];

        List<ContentDocumentLink> cdl = [
                SELECT
                        Id,
                        ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :appItem.LicenseType__r.BoardProgram__c
                AND ContentDocument.Title = 'EOSignature'
                LIMIT 1
        ];

        if (cdl.isEmpty()) {
            return null;
        }

        return [
                SELECT
                        Id,
                        ContentDownloadUrl
                FROM ContentDistribution
                WHERE ContentDocumentId = :cdl[0].ContentDocumentId
                LIMIT 1
        ]?.ContentDownloadUrl;
    }
}