public class LicenseTypeCashierCodeDomain extends SObjectDomain{
    public LicenseTypeCashierCodeDomain(List<LicenseTypeCashierCode__c> records) {
        super(records);
    }
    public Map<String, List<LicenseTypeCashierCode__c>> updateCashierCode(
        Map<String, Set<String>> key2ClassificationIds,
        Map<String, List<LicenseTypeCashierCode__c>> keyToLTCC, 
            Boolean hasLicenseYear) {
        for (LicenseTypeCashierCode__c ltcc : (List<LicenseTypeCashierCode__c>) records) {
			String island = ltcc.Island__c;
			String methodofLicensure = ltcc.MethodofLicensure__c;
			String activeInactive = ltcc.ActiveInactive__c;
			if (island == null) island = '';
			if (methodofLicensure == null) methodofLicensure = '';
			if (activeInactive != 'Inactive') activeInactive = '';
			String tempKey = methodofLicensure + ltcc.Type__c + ltcc.Status__c + ltcc.LicenseType__c;
            if(hasLicenseYear) {
                tempKey = tempKey + ltcc.RenewalFeePeriod__c;
            }
            tempKey = tempKey + island + '-' + activeInactive;
            
			if (keyToLTCC.containsKey(tempKey) 
                && (ltcc.Classification__c == null || (key2ClassificationIds.containsKey(tempKey) 
                && key2ClassificationIds.get(tempKey).contains(ltcc.Classification__c)))) {
				keyToLTCC.get(tempKey).add(ltcc);
			}
		}
        return keyToLTCC;
    }

    public List<LicenseTypeCashierCode__c> filterCodes(Set<String> appType, Set<String> appStatus,Set<String> appLicenseType, set<String> appCurrentLicenseYear) {
        List<LicenseTypeCashierCode__c> codes = new List<LicenseTypeCashierCode__c>();
        for(LicenseTypeCashierCode__c record: (List<LicenseTypeCashierCode__c>) records) {
            if(appType.contains(record.Type__c) 
                && appStatus.contains(record.Status__c) 
                && appLicenseType.contains(record.LicenseType__c) && !record.PermitFee__c) {
                if(appCurrentLicenseYear == null && record.RenewalFeePeriod__c == null) {
                    codes.add(record);
                } else if(appCurrentLicenseYear != null && appCurrentLicenseYear.contains(record.RenewalFeePeriod__c)) {
                    codes.add(record);
                }
            }
        }
        return codes;
    }

    public List<LicenseTypeCashierCode__c> filterRenewalCodes(Set<String> appLicenseType) {
        List<LicenseTypeCashierCode__c> codes = new List<LicenseTypeCashierCode__c>();
        for(LicenseTypeCashierCode__c record: (List<LicenseTypeCashierCode__c>) records) {
            if(appLicenseType.contains(record.LicenseType__c) && record.Type__c == 'RNEW - Renewal' && !record.PermitFee__c) {
                codes.add(record);
            }
        }
        return codes;
    }

    public List<LicenseTypeCashierCode__c> filterPermitCodes() {
        List<LicenseTypeCashierCode__c> codes = new List<LicenseTypeCashierCode__c>();
        for(LicenseTypeCashierCode__c record: (List<LicenseTypeCashierCode__c>) records) {
            if(record.PermitFee__c) {
                codes.add(record);
            }
        }
        return codes;
    }

    public List<TransactionLine__c> getTranLines(Application__c app, Transaction__c tran) {
        List<TransactionLine__c> lines = new List<TransactionLine__c>();
        for(LicenseTypeCashierCode__c record: (List<LicenseTypeCashierCode__c>) records) {
            if(record.Type__c == app.Type__c && record.Status__c == app.Status__c && record.LicenseType__c == app.LicenseType__c) {
                TransactionLine__c line = new TransactionLine__c();
                line.CashierCode__c = record.CashierCode__c;
                line.Amount__c = record.FeeAmount__c;
                line.Transaction__c = tran.Id;
                lines.add(line);
            }
        }
        return lines;
    }
}