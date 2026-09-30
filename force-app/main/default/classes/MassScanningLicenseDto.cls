/*--------------------------------------------------------
Author:			Ronald Pascual
Company: 		Pacific Point Corp
Description:	A data transfer object class for the mass scanning
Inputs:			"Licence Number Records" - License object that are being queried once you fill-in the text-area field. 
Test Class:

History
<Date>			<Authors Name>			<Brief Description of Change>
2019-10-28		Ronald Pascual			Created the data transfer object propoerties for mass scan controller
 --------------------------------------------------------*/
public class MassScanningLicenseDto {
    
    @AuraEnabled 
    public Boolean isSuccess {get; set;}
    
    @AuraEnabled 
    public String message {get; set;}

	@AuraEnabled
    public List<String> statusValues {get; set;}
    
    @AuraEnabled
    public List<Application__c> applicationList {get; set;}
    
    @AuraEnabled
    public List<License__c> licenseList {get; set;}
    
    @AuraEnabled
    public List<RenewalScanningResults__c> successScanResultsList {get; set;}
    
    @AuraEnabled
    public List<RenewalScanningResults__c> failscanResultsList {get; set;}
    
    @AuraEnabled
    public Integer noOfSuccessLicense {get; set;}
    
    @AuraEnabled
    public Integer noOfFailLicense {get; set;}
    
    public MassScanningLicenseDto(Boolean isSuccess, String message) {
        this.isSuccess = isSuccess;
        this.message = message;
    }        

}