public class OnlineRenewalController {
    public String recordId {
        get; set;
    }
    public Date dToday {
        get; set;
    }
    public List<Application__c> records {
        get; set;
    }
    public List<ApplicationRenewalFeed> feeds {
        get; set;
    }

    public void generateApplications() {
        List<String> applicationIds = new List<String>();
        if (recordId != null) {
            applicationIds.add(recordId);
        }

        records = [
                SELECT
                        Id,
                        Name,
                        LicenseType__r.BoardProgram__r.Name,
                        LicenseType__r.LicenseType__c,
                        CurrentLicense__r.PocketIDLicenseNumber__c,
                        CurrentLicense__r.Licensee__r.BPID__c,
                        CurrentLicense__r.Licensee__r.Name,
                        CurrentLicense__c,
                        RenewalMailToStreet__c,
                        RenewalMailToCity__c,
                        RenewalMailToStateHist__c,
                        RenewalMailToZipCode__c,
                        RenewalMailToCountry__c,
                        ResidenceStreet__c,
                        ResidenceCity__c,
                        ResidenceState__c,
                        ResidenceZipCode__c,
                        ResidenceCountry__c,
                        BusinessStreet__c,
                        BusinessCity__c,
                        BusinessState__c,
                        BusinessZipCode__c,
                        BusinessCountry__c,
                        MailingStreet__c,
                        MailingCity__c,
                        MailingState__c,
                        MailingZipCode__c,
                        MailingCountry__c,
                        ApplicationReceivedDate__c,
                        CompleteApplicationBy__c,
                        OnlineRenewalAnswers__c,
                        RenewalApplicationSignature__c,
                        OnlineRenewalEmployment__c,
                        OnlineRenewalClasses__c,
                        OnlineRenewalInsurance__c,
                        OnlineRenewalResidenceAddress__c,
                        OnlineRenewalBusinessAddress__c,
                        OnlineRenewalMailingAddress__c,
                        ResidenceStreetOnlineRenewal__c,
                        ResidenceCityOnlineRenewal__c,
                        ResidenceStateOnlineRenewal1__c,
                        ResidenceZipCodeOnlineRenewal__c,
                        ResidenceCountryOnlineRenewal__c,
                        RecordTypeId,
                        LicenseTypeCode__c,
                        EmployerName__c,
                        EmployerStreet__c,
                        EmployerCity__c,
                        EmployerState__c,
                        EmployerZipCode__c,
                        ActiveInactive__c,
                        ApplicationRenewingInactive__c,
                        (SELECT Id, Name, TotalAmount__c, PaymentAmount__c
                        FROM Transactions__r)
                FROM Application__c
                WHERE Id IN :applicationIds
        ];

        List<String> transactionIds = new List<String>();
        for (Application__c app : records) {
            if (app.OnlineRenewalAnswers__c != null) {
                app.OnlineRenewalAnswers__c = app.OnlineRenewalAnswers__c.replace('<p', '<div');
            }

            for (Transaction__c tran : app.Transactions__r) {
                transactionIds.add(tran.Id);
            }
        }

        List<pymt__PaymentX__c> payments = [
                SELECT
                        Id,
                        Transaction__c,
                        pymt__Payment_Type__c,
                        pymt__Billing_First_Name__c,
                        pymt__Billing_Last_Name__c,
                        pymt__Billing_City__c,
                        pymt__Billing_State__c,
                        pymt__Billing_Postal_Code__c,
                        pymt__Billing_Street__c
                FROM pymt__PaymentX__c
                WHERE Transaction__c IN :transactionIds
        ];

        Map<String, List<pymt__PaymentX__c>> tranId2Payments = new Map<String, List<pymt__PaymentX__c>>();

        for (pymt__PaymentX__c payment : payments) {
            List<pymt__PaymentX__c> paymentUnits = new List<pymt__PaymentX__c>();
            if (tranId2Payments.containsKey(payment.Transaction__c)) {
                paymentUnits = tranId2Payments.get(payment.Transaction__c);
            }
            paymentUnits.add(payment);
            tranId2Payments.put(payment.Transaction__c, paymentUnits);
        }

        feeds = new List<ApplicationRenewalFeed>();
        for (Application__c app : records) {
            ApplicationRenewalFeed feed = new ApplicationRenewalFeed();
            feed.app = app;
            feed.trans = app.Transactions__r;
            feed.associatedLicenses = new List<AssociatedLicense__c>();
            feed.associatedEmployeeLicenses = new List<AssociatedLicense__c>();
            feed.licenseClassifications = new List<LicenseClassification__c>();
            feed.insuranceBonds = new List<InsuranceBond__c>();

            if (app.OnlineRenewalEmployment__c != null) {
                OnlineRenewalEmploymentSnapshot employmentSnapshot = (OnlineRenewalEmploymentSnapshot) JSON.deserialize(app.OnlineRenewalEmployment__c, OnlineRenewalEmploymentSnapshot.class);
                if (employmentSnapshot.employees != null) {
                    feed.associatedEmployeeLicenses = employmentSnapshot.employees;
                }

                if (employmentSnapshot.employers != null) {
                    feed.associatedLicenses = employmentSnapshot.employers;
                }
            }

            if (app.OnlineRenewalClasses__c != null) {
                feed.licenseClassifications = (List<LicenseClassification__c>) JSON.deserialize(app.OnlineRenewalClasses__c, List<LicenseClassification__c>.class);
            }

            if (app.OnlineRenewalInsurance__c != null) {
                feed.insuranceBonds = (List<InsuranceBond__c>) JSON.deserialize(app.OnlineRenewalInsurance__c, List<InsuranceBond__c>.class);
            }

            List<pymt__PaymentX__c> paymentUnits = new List<pymt__PaymentX__c>();
            for (Transaction__c tran : app.Transactions__r) {
                if (tranId2Payments.containsKey(tran.Id))
                    paymentUnits.addAll(tranId2Payments.get(tran.Id));
            }

            feed.payments = paymentUnits;
            feeds.add(feed);
        }
    }

    public OnlineRenewalController() {
        recordId = System.currentPageReference().getParameters().get('id');
        generateApplications();
        dToday = Date.today();
    }

    public class OnlineRenewalEmploymentSnapshot{
        public List<AssociatedLicense__c> employees;
        public List<AssociatedLicense__c> employers;
        public OnlineRenewalEmploymentSnapshot(){}
    }
}