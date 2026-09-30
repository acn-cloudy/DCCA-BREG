public without sharing class PVL_SendListBuilderURLEmails {
	@InvocableMethod(label='Send List Builder URL Emails' category='Payment')
    public static void sendListBuilderURLEmails(List<Id> ids) {
        List<pymt__PaymentX__c> payment_L = [SELECT Id, Transaction__c, Transaction__r.Name, Name, pymt__Billing_Email__c, pymt__Billing_First_Name__c, pymt__Amount__c, pymt__Date__c, PVL_Document_Expire_Date__c, PVL_License_Type__c, PVL_Zip_Code__c, PVL_Start_Date__c, PVL_End_Date__c, PVL_Pickup_Token__c,PVL_License_Status__c, PVL_Active_Status__c, PVL_Refine_Contractor__c, PVL_Selected_Contractor__c, PVL_Pickup_URL__c 
                                             FROM pymt__PaymentX__c 
                                             WHERE Id in :ids];
        for (pymt__PaymentX__c p : payment_L) {
            sendListBuilderURLEmails(p);
        }
    }

    public static void sendListBuilderURLEmails(pymt__PaymentX__c p) {
        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
        OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
        if(orgSetting.Use_Organization_Wide_Email__c) {
        	OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where address = 'noreply@dcca.hawaii.gov'];
        	if (owea.size() > 0) {
        		semail.setOrgWideEmailAddressId(owea[0].Id);
        	}
        } else {
            semail.setReplyTo('noreply@dcca.hawaii.gov');
            semail.setSenderDisplayName('noreply@dcca.hawaii.gov');
        }
        semail.setSubject('Your PVL List Builder List Is Ready For Pickup');
        String[] sendTo = new String[]{p.pymt__Billing_Email__c};
        semail.setToAddresses(sendTo);
        String plainTextBody = '';
        plainTextBody += 'Aloha ' + p.pymt__Billing_First_Name__c + '\n\n';
        plainTextBody += 'Your PVL results list has been compiled and is ready for download. \n\n';
        plainTextBody += 'To download your results: \n';
        plainTextBody += '1) Navigate to ' + p.PVL_Pickup_URL__c + '\n';
        plainTextBody += '2) Follow the onscreen instructions \n\n';
        String s_paymentDate = ''; 
        String s_documentExpireDate = ''; 
        if (p.pymt__Date__c != null) {
            Datetime dt_paymentDate = datetime.newInstance(p.pymt__Date__c.year(), p.pymt__Date__c.month(), p.pymt__Date__c.day());
            s_paymentDate = dt_paymentDate.formatGMT('MM/dd/yyyy');
        } 

        if (p.PVL_Document_Expire_Date__c != null) {
            Datetime dt_documentExpireDate = datetime.newInstance(p.PVL_Document_Expire_Date__c.year(), p.PVL_Document_Expire_Date__c.month(), p.PVL_Document_Expire_Date__c.day());
            s_documentExpireDate = dt_documentExpireDate.formatGMT('MM/dd/yyyy');
        } 
        
        plainTextBody += 'Your results will be available until midnight (HST) on ' + s_documentExpireDate  + '. After that time, you will no longer be able to access your list and no refunds will be given. \n\n';
        plainTextBody += 'Your PVL Result Details: \n\n';

        plainTextBody += 'Purchase Date: ' + s_paymentDate + '\n';
        plainTextBody += 'Expiration Date: ' + s_documentExpireDate + '\n';
        //plainTextBody += 'Record Count: ' + this.recordCount + '\n';
        plainTextBody += 'Purchase Price: $' + p.pymt__Amount__c + '\n\n';
        plainTextBody += 'Refinement Criteria Used: \n\n';

        List<String> licenseTypeId_L = new List<String>();
        Set<String> licenseTypeId_S = new Set<String>();
        if (p.PVL_License_Type__c != null) {
            licenseTypeId_L = p.PVL_License_Type__c.split(',');
            licenseTypeId_S.addAll(licenseTypeId_L);
        }

        List<String> licenseType_L = new List<String>();
        for (LicenseType__c l : [select Name from LicenseType__c where id IN: licenseTypeId_S]) {
            licenseType_L.add(l.Name);
        }
        string licenseType_S = string.join(licenseType_L,',');

        plainTextBody += 'License Type(s): ' + licenseType_S + '\n';
        plainTextBody += 'Zip Code(s): ' + p.PVL_Zip_Code__c + '\n';
        String s_startDate = ''; 
        String s_endDate = ''; 
        if (p.PVL_Start_Date__c != null) {
            Datetime dt_startDate = datetime.newInstance(p.PVL_Start_Date__c.year(), p.PVL_Start_Date__c.month(), p.PVL_Start_Date__c.day());
            s_startDate = dt_startDate.formatGMT('MM/dd/yyyy');
        } 

        if (p.PVL_End_Date__c != null) {
            Datetime dt_endDate = datetime.newInstance(p.PVL_End_Date__c.year(), p.PVL_End_Date__c.month(), p.PVL_End_Date__c.day());
            s_endDate = dt_endDate.formatGMT('MM/dd/yyyy');
        } 

        plainTextBody += 'License Issuance Range: ' + s_startDate + ' - ' + s_endDate+ '\n';
        plainTextBody += 'License Status: ' + p.PVL_License_Status__c + '\n';
        plainTextBody += 'Active Status: ' + p.PVL_Active_Status__c + '\n';

        If (p.PVL_Refine_Contractor__c == True) {
            plainTextBody += 'Refine Contractor: ' + p.PVL_Refine_Contractor__c  + '\n';
            List<String> contractorId_L = new List<String>();
            if (p.PVL_Selected_Contractor__c != null) {
                contractorId_L = p.PVL_Selected_Contractor__c.split(',');
            }
            List<String> classification_L = new List<String>();
            for (Classification__c c : [select ID, Name from Classification__c where id IN: contractorId_L]) {
                classification_L.add(c.Name);
            }
            string classification_S = string.join(classification_L,',');    
            plainTextBody += 'Selected Contractor: ' + classification_S + '\n\n';
        } else {
            plainTextBody += '\n';
        }

        plainTextBody += 'If you have any questions or issues with obtaining your results, please contact PVL at (808) 586-3000 or email us at pvl@dcca.hawaii.gov \n\n';
        plainTextBody += 'Mahalo for using the PVL List Builder! \n\n';
        plainTextBody += 'To view a list of all the services that we provide, please visit http://secure-web.cisco.com/1J1N7MbccObdjLHBMgnutWrwAobT_19lfXFdc600dhlW1nkAIYSNqyYbQCJQp4goaAHHa-sRpm-RS2wI53oXfkfVSoic6d34DnSB2XNlsNROwM6fpWgHL8k75Mj5QT_aNgDg7HyGhR3hkk_ttvCEqsplojV4EqyIcTcdy3pDBVwyRgUtoSbhEOEL5ghlIXw60bry0fVn9o3S_R4WMGMRv9xppj2zRFlB_6DYc5fHwRrSYBuUS5NSazu-Lhh3DgnMpIs8sa--X_nzMP0Et7iGEEYC5vtmdoswBR99FcKP3-FQwCHLu2Us21pIOs3HszBdenbAIZ6qYTv7rVyEt6Ra-Yg/http%3A%2F%2Fwww.ehawaii.gov.';

        semail.setPlainTextBody(plainTextBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
    }
}