/*
 * ___________________________________________________________________________________
 * Lic Notice Classifications Tbl Controller
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
public class LicNoticeClassificationsTblController {
    public License__c lic{
        public get; public set;
    }

    public List<LicenseClassification__c> getClassifications() {
        return [
                SELECT
                        Id,
                        Name,
                        ClassificationName__c
                FROM LicenseClassification__c
                WHERE License__c = :lic.Id
                AND Status__c = 'C - Current, Valid & In Good Standing'
        ];
    }
}