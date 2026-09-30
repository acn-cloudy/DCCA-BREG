/*
 * ___________________________________________________________________________________
 * Controller for LicenseScannerResult VF Page
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-CL11222019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/22/2019
 * __________________________________________________________________________________
 */
public class LicenseScannerResultController {
    public LicenseMassScannerController.ScanResult scanResult{
        get;set;
    }

    public Integer successCount{
        get;set;
    }

    public Integer failCount{
        get;set;
    }

    public LicenseScannerResultController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        scanResult = (LicenseMassScannerController.ScanResult) JSON.deserialize(params.get('scanResult'),
                        LicenseMassScannerController.ScanResult.class);
        successCount = scanResult.success.size();
        failCount = scanResult.failed.size();
    }
}