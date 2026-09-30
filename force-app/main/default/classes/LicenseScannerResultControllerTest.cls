/*
 * ___________________________________________________________________________________
 * Code coverage for LicenseScannerResultController
 * __________________________________________________________________________________
 * PacPoint-CL12132019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 12/13/2019
 * __________________________________________________________________________________
 */
@IsTest
private class LicenseScannerResultControllerTest {
    @TestSetup
    static void setup() {
        LicenseMassScannerControllerTest.setup();
    }

    @IsTest
    static void testLicenseScannerResultController() {
        
        LicenseMassScannerController.ScanResult scanResult = LicenseMassScannerController.scanCreate(new List<String>{'acc',
                                                                                                                'vcc'},
                Date.today(), 'Inactive', 'Yes', 'Partner', false);

        PageReference pg = Page.LicenseScannerResult;
        Test.setCurrentPage(pg);
        ApexPages.currentPage().getParameters().put('scanResult', JSON.serialize(scanResult));

        LicenseScannerResultController controller = new LicenseScannerResultController();
    }
}