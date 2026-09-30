public without sharing class BREGTransactionLineTriggerHandler extends BREGBaseTriggerHandler {
    private static final String STATUS_PAID = 'Paid';
    private static final String COGS_DESCRIPTION = 'COGS';
    private static final String FILING_DESCRIPTION = 'filing';
    private static final String REGULAR_COPY_WORKFLOW = 'BREG Send Document Copy Email';
    private static final String CERTIFICATES_WORKFLOW = 'BREG Certificate Process';
    private static final String COGS_CASHIER_CODE_DESCRIPTION = 'CERTIFICATE OF COMPLIANCE';
    private static final String CREATE_PATCH_SHEET_WORKFLOW = 'BREG Create Patch Sheet for Case';
    private static final String INITIAL_FILING_WORKFLOW = 'BREG Initial Filing Generation by Form';
    
    public override void afterInsert() {
        List<TransactionLine__c> paidLines = getChangedLines(STATUS_PAID, false);
        if (!paidLines.isEmpty()) {
            updateRelatedCaseFields(paidLines);
            //updateCaseOnRelatedTransaction(paidLines);
        }

        List<TransactionLine__c> paidFilingsLines = getLinesForFilings(STATUS_PAID, true, FILING_DESCRIPTION, false);
        if (!paidFilingsLines.isEmpty()) {
            updateCasePaymentRefNumber(paidFilingsLines);
        }

        List<TransactionLine__c> newCogsLines = getManualCogsLines(this.newList);
        if (!newCogsLines.isEmpty()) {
            List<TransactionLine__c> cogsLinesWithoutCertificates = new List<TransactionLine__c>();
            for (TransactionLine__c line : newCogsLines) {
                if (!isCOGSalreadyCreated(line.breg_Case__c)) {
                    cogsLinesWithoutCertificates.add(line);
                }
            }
            createCOGSDocuments(cogsLinesWithoutCertificates);
        }
        
    }

    @TestVisible
    private static Boolean isCOGSalreadyCreated(Id caseId) {
        List<breg_Document__c> cogsDocuments = [SELECT Id FROM breg_Document__c WHERE breg_Case__c = :caseId AND Name LIKE 'Certificate of Good Standing (COGS)%' LIMIT 1];
        return !cogsDocuments.isEmpty();
    }

    private static void createCOGSDocuments(List<TransactionLine__c> newCogsLines){
        List<breg_Document__c> documentsToInsert = new List<breg_Document__c>();
        List<breg_Document__c> cogsTemplateDocs = getCogsTemplateDocs();
        Map<String, Id> cogsTypeTemplateDocsMap = new Map<String, Id>();
        for (breg_Document__c doc : cogsTemplateDocs) {
            cogsTypeTemplateDocsMap.put(doc.breg_Type__c, doc.Id);
        }
        Set<Id> contactIds = new Set<Id>();
        for (TransactionLine__c line : newCogsLines) {
            if (line.breg_Case__r.ContactId != null) {
                contactIds.add(line.breg_Case__r.ContactId);
            }
        }
        Map<Id,Contact> casesContactsMap = new Map<Id,Contact>([SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id IN :contactIds]);
        Map<Id, breg_Document__c> lineDocumentMap = new Map<Id, breg_Document__c>();
        for (TransactionLine__c line : newCogsLines) {
            String deliveryMethod = line.breg_Case__r.breg_Delivery_Method__c;
            String format = deliveryMethod == 'Email' ? 'Digital' : 'Printed';
            Id templateDocId = cogsTypeTemplateDocsMap.get(format);
            breg_Document__c relatedCogsDocument = BREGPaymentController.createCOGSDocument(
                'Certificate of Good Standing (COGS)',
                String.valueOf(line.breg_Case__r.breg_Entity__c), 
                String.valueOf(templateDocId), 
                format, 
                line.breg_Case__c, 
                casesContactsMap.get(line.breg_Case__r.ContactId)
            );
            documentsToInsert.add(relatedCogsDocument);
            lineDocumentMap.put(line.Id, relatedCogsDocument);
        }
        insert documentsToInsert;
        List<TransactionLine__c> linesToUpdate = new List<TransactionLine__c>();
        for (TransactionLine__c line : newCogsLines) {
            breg_Document__c relatedCogsDocument = lineDocumentMap.get(line.Id);
            if (relatedCogsDocument != null) {
                line.breg_Document__c = relatedCogsDocument.Id;
                line.Account__c = line.breg_Case__r.breg_Entity__c;
                linesToUpdate.add(line);
            }
        }
        if (!linesToUpdate.isEmpty()) {
            update linesToUpdate;
        }
    }

    public override void afterUpdate() {
        List<TransactionLine__c> paidCogsLines = getLinesForFilings(STATUS_PAID, false, COGS_DESCRIPTION, true);
        if (paidCogsLines.isEmpty()) {
            paidCogsLines = getLinesForFilings(STATUS_PAID, false, COGS_CASHIER_CODE_DESCRIPTION, true);
        }

        List<breg_Certificate__c> certificates = new List<breg_Certificate__c>();
        List<Id> certificateCaseIds = new List<Id>();

        for (TransactionLine__c theLine : paidCogsLines) {
            breg_Certificate__c cert = createCertificate(theLine);
            certificates.add(cert);
            certificateCaseIds.add(theLine.breg_Case__c);
        }

        insert certificates;
        Map<Id, Id> certificateToCaseIdMap = buildCertificateToCaseIdMap(certificates, certificateCaseIds);

        Set<Id> casesWithStartedDocumentGeneration = new Set<Id>();
        casesWithStartedDocumentGeneration.addAll(certificateToCaseIdMap.values());

        for (breg_Certificate__c cert : certificates) {
            cert.breg_Authentication_Code__c = BREGUtils.generateAuthCode(cert);
        }

        update certificates;

        if (!Test.isRunningTest()) {
            for (breg_Certificate__c cert : certificates) {
                // Start integration with DocuSign
                    Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(certificateToCaseIdMap.get(cert.Id), 'Transaction Line Trigger Handler, Certificate of Good Standing (COGS) Generation');
                    System.enqueueJob(new BREGStartDocusignWorkflow(CERTIFICATES_WORKFLOW, certificateToCaseIdMap.get(cert.Id), '<recordId>' + cert.Id + '</recordId>', 'Transaction Line Trigger Handler, Certificate of Good Standing (COGS) Generation', workflowLogId));
            }
        }

        List<TransactionLine__c> paidLines = getChangedLines(STATUS_PAID, true);
        if (!paidLines.isEmpty()) {
            updateCasePaymentRefNumber(paidLines);
            updateRelatedCaseFields(paidLines);
            
            //updateCaseOnRelatedTransaction(paidLines);
            
        }

        List<TransactionLine__c> paidRegularCopyLines = getLinesForRegularCopy();
        if (!paidRegularCopyLines.isEmpty() && !Test.isRunningTest()) {
            for (TransactionLine__c line : paidRegularCopyLines) {
                Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(line.breg_Document__r.breg_Case__c, 'Transaction Line Trigger Handler, Regular Copy Generation');
                System.enqueueJob(
                    new BREGStartDocusignWorkflow(
                        REGULAR_COPY_WORKFLOW, 
                        line.breg_Document__r.breg_Case__c, 
                        buildRegularCopyWorkflowParams(line),
                        'Transaction Line Trigger Handler, Regular Copy Generation',
                        workflowLogId
                    )
                );

            }
        }
        
    }

    @InvocableMethod(label='Process Paid Filings Workflows' category='Transaction Line')
    public static void processPaidFilingsWorkflows(List<Id> transactionLineIds) {
        if (transactionLineIds == null || transactionLineIds.isEmpty()) {
            return;
        }

        List<TransactionLine__c> lines = getLinesWithRelatedFields(new Set<Id>(transactionLineIds));
        List<TransactionLine__c> paidFilingsLines = new List<TransactionLine__c>();
        Set<Id> casesWithStartedDocumentGeneration = new Set<Id>();
        for (TransactionLine__c line : lines) {
            casesWithStartedDocumentGeneration.add(line.breg_Case__c);
            String formCode = line.breg_Case__r.breg_Form_Code__c;
            Boolean hasDescription = line.Description__c != null;
            Boolean matchesDescription = hasDescription && line.Description__c.toUpperCase().contains(FILING_DESCRIPTION.toUpperCase());
            Boolean formRelatedTransaction = line.breg_Type__c != null && line.breg_Type__c.contains('Form');
            Boolean isFilingCandidate = formCode != null && formCode != 'DOCDLVR';
            String purchaseType = line.breg_Fee__r.breg_Purchase_Type_Fee_type__c;
            Boolean isFormRelatedPurchaseType = purchaseType == 'Form Fees' || purchaseType == 'Annual Filing Fee';
            if (
                (isFormRelatedPurchaseType || matchesDescription || (!hasDescription && formRelatedTransaction)) &&
                isFilingCandidate
            ) {
                paidFilingsLines.add(line);
            }
        }

        if (paidFilingsLines.isEmpty()) {
            return;
        }

        Set<Id> llpCaseIds = new Set<Id>();
        List<TransactionLine__c> uniqueCaseLines = getUniqueLinesByCaseId(paidFilingsLines);
        for (TransactionLine__c line : uniqueCaseLines) {
            processMainCaseWorkflows(line, llpCaseIds);
        }
        Set<Id> gpCaseIds = processRelatedLlpCases(llpCaseIds);
        if (!gpCaseIds.isEmpty()) {
            casesWithStartedDocumentGeneration.addAll(gpCaseIds);
        }
        List<Case> casesToUpdate = new List<Case>();
        for (Id caseId : casesWithStartedDocumentGeneration) {
            casesToUpdate.add(new Case(Id = caseId, breg_Document_Generation_Status__c = 'Generation in Process'));
        }
        update casesToUpdate;
    }

    @TestVisible
    private static List<TransactionLine__c> getUniqueLinesByCaseId(List<TransactionLine__c> lines) {
        List<TransactionLine__c> uniqueCaseLines = new List<TransactionLine__c>();
        Set<Id> processedCaseIds = new Set<Id>();

        for (TransactionLine__c line : lines) {
            Id caseId = line.breg_Case__c;
            if (caseId == null || processedCaseIds.contains(caseId)) {
                continue;
            }

            processedCaseIds.add(caseId);
            uniqueCaseLines.add(line);
        }

        return uniqueCaseLines;
    }

    private static void processMainCaseWorkflows(TransactionLine__c line, Set<Id> llpCaseIds) {
        if (line.breg_Case__r.breg_Form_Code__c == 'LLP-1' || line.breg_Case__r.breg_Form_Code__c == 'FLLP-1') {
            llpCaseIds.add(line.breg_Case__c);
        }

        // Start integration with DocuSign
        startWorkflowAsync(CREATE_PATCH_SHEET_WORKFLOW, line.breg_Case__c, 'Create Patch Sheet for Case');
        if (
            line.breg_Case__r.breg_Form_Configuration__c != null && 
            line.breg_Case__r.breg_Form_Code__c != 'DOCDLVR' && 
            line.breg_Case__r.Origin == 'Web' &&
            (!line.breg_Case__r.breg_Override_Payment__c || line.breg_Case__r.breg_Form_Action__c == 'Resubmit') &&
            line.breg_Case__r.breg_Document_Generation_Status__c != 'Generation in Process'
            ) {
            // Start integration with DocuSign
            startWorkflowAsync(INITIAL_FILING_WORKFLOW, line.breg_Case__c, 'Initial Filing Generation by Form after paying for filing');
        }
    }

    @TestVisible
    private static void updateCaseOnRelatedTransaction(List<TransactionLine__c> lines) {
        Set<Id> transactionIds = new Set<Id>();
        List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();

        for (TransactionLine__c line : lines) {
            if (line.breg_Case__c != null && line.Transaction__r.breg_Case__c == null && !transactionIds.contains(line.Transaction__c)) {
                transactionIds.add(line.Transaction__c);
                transactionsToUpdate.add(new Transaction__c(Id = line.Transaction__c, breg_Case__c = line.breg_Case__c));
            }
        }

        update transactionsToUpdate;
    }

    private static Set<Id> processRelatedLlpCases(Set<Id> llpCaseIds) {
        if (llpCaseIds.isEmpty()) {
            return new Set<Id>();
        }
        Set<Id> processedCaseIds = new Set<Id>();

        List<Case> relatedCases = BREGUtils.getLinkedGPCasesForLLPCases(llpCaseIds);
        for (Case relatedCase : relatedCases) {
            // Start integration with DocuSign
            startWorkflowAsync(CREATE_PATCH_SHEET_WORKFLOW, relatedCase.Id, 'Create Patch Sheet for Related Case');
            if (relatedCase.breg_Form_Code__c != null && 
                relatedCase.breg_Form_Code__c != 'DOCDLVR' && 
                relatedCase.Origin == 'Web' &&
                (!relatedCase.breg_Override_Payment__c || relatedCase.breg_Form_Action__c == 'Resubmit')) {
                // Start integration with DocuSign
                startWorkflowAsync(INITIAL_FILING_WORKFLOW, relatedCase.Id, 'Initial Filing Generation for Related Case');
                processedCaseIds.add(relatedCase.Id);
            }
        }
        return processedCaseIds;
    }

    public static void updateCasePaymentRefNumber(List<TransactionLine__c> paidFilingsLines) {
        Set<Id> caseIds = new Set<Id>();
        List<Case> relatedCases = new List<Case>();
        for (TransactionLine__c line : paidFilingsLines) {
            if (line.breg_Case__c != null && line.breg_Case__r.breg_Payment_Transaction_Ref__c == null && !caseIds.contains(line.breg_Case__c)) {
                caseIds.add(line.breg_Case__c);
                relatedCases.add(new Case(Id = line.breg_Case__c, breg_Payment_Transaction_Ref__c = line.Transaction__r.Name));
            }
        }
        update relatedCases;
    }


    public static void updateRelatedCaseFields(List<TransactionLine__c> lines) {
        Set<Id> caseIds = new Set<Id>();
        List<Case> casesToUpdate = new List<Case>();

        for (TransactionLine__c line : lines) {
            if (line.breg_Case__c != null && line.CashierCodeDescription__c != null && line.CashierCodeDescription__c.contains('EXPEDITED REVIEW') && !caseIds.contains(line.breg_Case__c)) {
                caseIds.add(line.breg_Case__c);
                casesToUpdate.add(new Case(Id = line.breg_Case__c, breg_Processing_Speed__c = 'Expedited', Priority = 'Priority 2'));
            }
        }

        update casesToUpdate;
    }

    public static List<TransactionLine__c> getManualCogsLines(List<TransactionLine__c> lines) {
        List<TransactionLine__c> manualCogsLines = new List<TransactionLine__c>();
        Set<Id> linesIds = new Set<Id>();
        for (TransactionLine__c line : lines) {
            linesIds.add(line.Id);
        }
        List<TransactionLine__c> linesWithRelatedFields = getLinesWithRelatedFields(linesIds);
        for (TransactionLine__c line : linesWithRelatedFields) {
            String description = line.Description__c != null ? line.Description__c : line.CashierCode__r.Description__c;
            if (
                line.breg_Case__r.breg_Form_Code__c == 'DOCDLVR' && 
                line.breg_Case__r.RecordType.DeveloperName == 'BREG_Case' && 
                line.breg_Case__r.Origin != 'Web' && 
                !line.breg_Case__r.breg_Override_Payment__c &&
                description != null && 
                (
                    description.toUpperCase().contains(COGS_DESCRIPTION) || 
                    description.toUpperCase().contains(COGS_CASHIER_CODE_DESCRIPTION)
                )
            ) {
                manualCogsLines.add(line);
            }
        }

        return manualCogsLines;
    }

    @TestVisible
    private List<TransactionLine__c> getLinesForRegularCopy() {
        List<TransactionLine__c> linesForLoop = getChangedLines(STATUS_PAID, true);
        List<TransactionLine__c> linesToReturn = new List<TransactionLine__c>();
        for (TransactionLine__c line : linesForLoop) {
            Boolean emptyCase = line.breg_Case__c == null;
            Boolean cashierCodeIsBOC = line.CashierCodeCode__c  == 'BOC';
            Boolean docDontHaveCertCopyName = line.breg_Document__r.Name != null && !line.breg_Document__r.Name.contains('Certified Copy');
            Boolean docNotAvailableToCertify = line.breg_Document__r.breg_Available_To_Certify__c == false;
            Boolean docNotCertified = line.breg_Document__r.breg_Is_Certified__c == false;
            Boolean docIsPublic = line.breg_Document__r.breg_Is_Public__c == true;
            Boolean deliveryContactExists = line.breg_Delivery_Contact__c != null;
            if (emptyCase && cashierCodeIsBOC && docDontHaveCertCopyName && docNotAvailableToCertify && docNotCertified && docIsPublic && deliveryContactExists) {
                linesToReturn.add(line);
            }
        }
        return linesToReturn;
    }

    public List<TransactionLine__c> getLinesForFilings(String status,  Boolean isFilings, String description, Boolean changedOnly) {
        List<TransactionLine__c> linesForLoop = new List<TransactionLine__c>();
        if (status != null){
            linesForLoop = getChangedLines(status, changedOnly);
        } else {
            linesForLoop = (List<TransactionLine__c>) this.newList;
        }
        List<TransactionLine__c> linesToReturn = new List<TransactionLine__c>();
        for (TransactionLine__c line : linesForLoop) {
            String formCode = line.breg_Case__r.breg_Form_Code__c;
            Boolean hasDescription = line.Description__c != null && description != null;
            Boolean matchesDescription = hasDescription && line.Description__c.toUpperCase().contains(description.toUpperCase());
            String businessProcess = line.breg_Case__r.breg_Form_Configuration__r.breg_Business_Process__c;
            Boolean isDocDeliveryOrEmpty = formCode == null || formCode == 'DOCDLVR';
            Boolean formRelatedTransaction = line.breg_Type__c != null && line.breg_Type__c.contains('Form');
            Boolean isFilingCandidate = formCode != null && formCode != 'DOCDLVR';
            String purchaseType = line.breg_Fee__r.breg_Purchase_Type_Fee_type__c;
            Boolean isFormRelatedPurchaseType = purchaseType == 'Form Fees' || purchaseType == 'Annual Filing Fee';
            if (
                (isFormRelatedPurchaseType || matchesDescription || (!hasDescription && formRelatedTransaction)) &&
                ((isFilings && isFilingCandidate) || (!isFilings && isDocDeliveryOrEmpty))
            ) {
                linesToReturn.add(line);
            }
        }

        return linesToReturn;
    }

    public List<TransactionLine__c> getChangedLines(String status, Boolean changedOnly){
        Set<Id> linesIds = new Set<Id>();
        Map<Id,Id> caseToTransactionMap = new Map<Id,Id>();
        for (TransactionLine__c theLine : (List<TransactionLine__c>) this.newList) {
            if (changedOnly) {
                TransactionLine__c oldLine = (TransactionLine__c) this.oldMap.get(theLine.Id);
                if (oldLine != null && oldLine.PaidStatus__c != theLine.PaidStatus__c && theLine.PaidStatus__c == status) {
                    linesIds.add(theLine.Id);

                }
            } else {
                if (theLine.PaidStatus__c == status) {
                    linesIds.add(theLine.Id);
                }
            }
            if (theLine.breg_Case__c != null && !caseToTransactionMap.containsKey(theLine.breg_Case__c)) {
                caseToTransactionMap.put(theLine.breg_Case__c, theLine.Transaction__c);
            }
            
        }
        return getLinesWithRelatedFields(linesIds);
    }

    private static List<TransactionLine__c> getLinesWithRelatedFields(Set<Id> linesIds){
            List<TransactionLine__c> changedLines = [
            SELECT
                Id,
                Account__c,
                CashierCode__c,
                CashierCode__r.Description__c,
                CashierCodeCode__c,
                breg_Case__c,
                breg_Case__r.Subject,
                breg_Case__r.RecordType.DeveloperName,
                breg_Case__r.breg_Form_Code__c,
                breg_Case__r.Origin,
                breg_Case__r.breg_Override_Payment__c,
                breg_Case__r.breg_Form_Action__c,
                breg_Case__r.ContactId,
                breg_Case__r.breg_Delivery_Method__c,
                breg_Case__r.breg_Form_Configuration__c,
                breg_Case__r.breg_Form_Configuration__r.breg_Business_Process__c,
                breg_Case__r.breg_Payment_Transaction_Ref__c,
                breg_Case__r.breg_Entity__c,
                breg_Case__r.breg_Document_Generation_Status__c,
                Transaction__r.breg_Case__c,
                Transaction__r.Name,
                Transaction__c,
                Description__c,
                breg_Document__c,
                breg_Document__r.breg_Case__c,
                breg_Document__r.Name,
                breg_Document__r.breg_Docusign_Document_Id__c,
                breg_Document__r.breg_Type__c,
                breg_Document__r.breg_Available_To_Certify__c,
                breg_Document__r.breg_Is_Certified__c,
                breg_Document__r.breg_Is_Public__c,
                breg_Document__r.breg_Account__c,
                breg_Type__c,
                breg_Delivery_Contact__c,
                breg_Delivery_Contact__r.FirstName,
                breg_Delivery_Contact__r.LastName,
                breg_Delivery_Contact__r.Email,
                breg_Fee__c, 
                breg_Fee__r.breg_Purchase_Type_Fee_type__c,
                CashierCodeDescription__c
            FROM TransactionLine__c
            WHERE Id IN :linesIds
        ];
        return changedLines;

    }

    public static List<breg_Document__c> getCogsTemplateDocs() {
        List<breg_Document__c> cogsTemplateDocs = [
            SELECT Id, Name, breg_Type__c, breg_Is_Certificate_Of_Good_Standing__c
            FROM breg_Document__c
            WHERE breg_Is_Certificate_Of_Good_Standing__c = TRUE
                AND breg_Template_Document__c = NULL
                AND breg_Is_Template_Copy__c != TRUE
        ];
        return cogsTemplateDocs;
    }

    public static breg_Certificate__c createCertificate(TransactionLine__c line) {
        breg_Certificate__c cert = new breg_Certificate__c();
        cert.breg_Account__c = line.Account__c != null ? line.Account__c : line.breg_Document__r.breg_Account__c;
        cert.breg_Authentication_Code__c = '';
        cert.Name = trimNameToLimit(line.Description__c);
        cert.breg_Certificate_Name__c = line.Description__c;
        cert.breg_Correspondence_Type__c = line.breg_Document__r.breg_Type__c == 'Printed' ? 'Postal' : 'Email';
        cert.breg_Document__c = line.breg_Document__c;
        cert.breg_Is_Published__c = true;
        cert.breg_Published_Timestamp__c = Datetime.now();
        //cert.breg_Current_Certificate_Number__c = '';
        //cert.breg_Legacy_Certificate_Number__c = '';
        return cert;
    }

    public static String trimNameToLimit(String fullName) {
        final Integer MAX_LENGTH = 80;

        List<String> parts = fullName.split(' - ');
        if (parts.isEmpty()) {
            return fullName.length() > MAX_LENGTH ? fullName.substring(0, MAX_LENGTH) : fullName;
        }

        String accountName = parts[0];
        String result = accountName;

        if (result.length() >= MAX_LENGTH) {
            return result.substring(0, MAX_LENGTH);
        }

        String cogPart = parts.size() > 1 ? parts[1] : null;
        String cogText = cogPart != null && cogPart.trim().equalsIgnoreCase('Certificate of Good Standing (COGS)') ? ' - COGS' : null;

        if (cogText != null && result.length() + cogText.length() <= MAX_LENGTH) {
            result += cogText;
        } else {
            return result;
        }

        if (parts.size() > 2) {
            String suffix = parts[2];
            String optionalSuffix = ' - ' + suffix;

            if (result.length() + optionalSuffix.length() <= MAX_LENGTH) {
                result += optionalSuffix;
            }
        }

        return result;
    }


    public static void startWorkflowAsync(String workflowName, Id recordId, String description) {
        if (!Test.isRunningTest()) {
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(recordId, 'Transaction Line Trigger Handler, ' + description);
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, recordId, null, 'Transaction Line Trigger Handler, ' + description, workflowLogId));
        }
    }

    private static Map<Id, Id> buildCertificateToCaseIdMap(List<breg_Certificate__c> certificates, List<Id> certificateCaseIds) {
        Map<Id, Id> certificateToCaseIdMap = new Map<Id, Id>();
        Integer numberOfCertificates = Math.min(certificates.size(), certificateCaseIds.size());

        for (Integer index = 0; index < numberOfCertificates; index++) {
            addCertificateToCaseIdMapEntry(certificateToCaseIdMap, certificates[index], certificateCaseIds[index]);
        }

        return certificateToCaseIdMap;
    }

    private static void addCertificateToCaseIdMapEntry(Map<Id, Id> certificateToCaseIdMap, breg_Certificate__c cert, Id caseId) {
        if (certificateToCaseIdMap == null || cert == null || cert.Id == null || caseId == null) {
            return;
        }

        certificateToCaseIdMap.put(cert.Id, caseId);
    }

    @TestVisible
    private static String buildRegularCopyWorkflowParams(TransactionLine__c line) {
        String fullName = ((line.breg_Delivery_Contact__r.FirstName == null ? '' : line.breg_Delivery_Contact__r.FirstName) +
            ' ' + (line.breg_Delivery_Contact__r.LastName == null ? '' : line.breg_Delivery_Contact__r.LastName)).trim();

        return '<recordId>' + line.breg_Document__r.breg_Case__c + '</recordId>' +
            '<documentId>' + line.breg_Document__r.breg_Docusign_Document_Id__c + '</documentId>' +
            '<email>' + DocuSignAPI.escapeXml(line.breg_Delivery_Contact__r.Email) + '</email>' +
            '<fullName>' + DocuSignAPI.escapeXml(fullName) + '</fullName>' +
            '<description>' + DocuSignAPI.escapeXml(line.Description__c) + '</description>' +
            '<contactId>' + line.breg_Delivery_Contact__c + '</contactId>';
    }
}