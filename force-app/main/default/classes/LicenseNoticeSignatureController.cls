/*
 * ___________________________________________________________________________________
 * License Notice Signature Controller
 * For License Notice Email Templates
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-CL02142022 - Created for Case 00013106
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 02/14/2022
 * __________________________________________________________________________________
 */
public class LicenseNoticeSignatureController {
    public License__c lic{
        public get; public set;
    }

    public String getImageData() {
        if (lic == null || lic.Id == null) {
            return null;
        }

        License__c li = [
                SELECT
                        Id,
                        LicenseType__r.BoardProgram__c
                FROM License__c
                WHERE Id = :lic.Id
        ];

        List<ContentDocumentLink> cdl = [
                SELECT
                        Id,
                        ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :li.LicenseType__r.BoardProgram__c
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