public without sharing class BREGPaymentController {
    @TestVisible
    private static Boolean allowPaymentContactFallbackInTests = false;

    @AuraEnabled
    public static String downloadDocument(String docusignDocumentId) {
        try {
            Blob documentBlob = DocuSignAPI.getDocumentBlob(docusignDocumentId, false);
            // Convert the response body to base64 for browser download
            String base64Document = EncodingUtil.base64Encode(documentBlob);
            return base64Document;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static DocumentInfo getInitialFilingDocument(Id caseId) {
        try {
            if (caseId == null) {
                return null;
            }

            List<breg_Document__c> documents = [
                SELECT Id, Name, breg_Docusign_Document_Id__c
                FROM breg_Document__c
                WHERE
                    breg_Case__c = :caseId
                    AND breg_Is_Irrelevant__c = FALSE
                    AND Name LIKE '%- Initial Filing.pdf'
                    AND breg_Docusign_Document_Id__c != NULL
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (documents.isEmpty()) {
                return null;
            }

            DocumentInfo info = new DocumentInfo();
            info.docusignDocumentId = documents[0].breg_Docusign_Document_Id__c;
            info.name = documents[0].Name;
            return info;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class DocumentInfo {
        @AuraEnabled
        public String docusignDocumentId { get; set; }
        @AuraEnabled
        public String name { get; set; }
    }

    @AuraEnabled
    public static String getPaymentStatus(Id paymentId) {
        try {
            if (paymentId == null) {
                return null;
            }

            List<pymt__PaymentX__c> payments = [
                SELECT pymt__Status__c
                FROM pymt__PaymentX__c
                WHERE Id = :paymentId
                LIMIT 1
            ];

            if (!payments.isEmpty()) {
                return payments[0].pymt__Status__c;
            }

            return null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<TransactionLine__c> getTransactionLines(Id paymentId) {
        try {
            return getTransactionLines(new Set<Id>{ paymentId });
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id getFeeIdForTransactionLineItem(Id transactionLineItemId) {
        try {
            if (transactionLineItemId == null) {
                return null;
            }

            List<TransactionLine__c> lines = [
                SELECT
                    Id,
                    breg_Fee__c,
                    breg_Type__c,
                    Description__c,
                    CashierCode__r.CashierCode__c,
                    breg_Case__r.breg_Form_Configuration__r.breg_Form_Code__c
                FROM TransactionLine__c
                WHERE Id = :transactionLineItemId
                LIMIT 1
            ];

            if (lines.isEmpty()) {
                return null;
            }

            TransactionLine__c line = lines[0];
            if (line.breg_Fee__c != null) {
                return line.breg_Fee__c;
            }

            String cashierCode = line.CashierCode__r != null ? line.CashierCode__r.CashierCode__c : null;
            String formCode = line.breg_Case__r?.breg_Form_Configuration__r?.breg_Form_Code__c;
            String purchaseType = getPurchaseTypeForTransactionLine(line);

            Boolean hasCashierCode = String.isNotBlank(cashierCode);
            Boolean hasFormCode = String.isNotBlank(formCode);
            Boolean hasPurchaseType = String.isNotBlank(purchaseType);
            Boolean hasFormAndType = hasFormCode && hasPurchaseType;

            if (!hasCashierCode && !hasFormCode && !hasPurchaseType) {
                return null;
            }

            List<String> whereClauses = new List<String>();
            if (hasCashierCode) {
                whereClauses.add('breg_Cashier_Code__c = \'' + String.escapeSingleQuotes(cashierCode) + '\'');
            }
            if (hasFormAndType) {
                whereClauses.add(
                    'breg_Form_Code__c = \'' +
                    String.escapeSingleQuotes(formCode) +
                    '\' AND breg_Purchase_Type_Fee_type__c = \'' +
                    String.escapeSingleQuotes(purchaseType) +
                    '\''
                );
            }
            if (hasFormCode) {
                whereClauses.add('breg_Form_Code__c = \'' + String.escapeSingleQuotes(formCode) + '\'');
            }
            if (hasPurchaseType) {
                whereClauses.add('breg_Purchase_Type_Fee_type__c = \'' + String.escapeSingleQuotes(purchaseType) + '\'');
            }

            List<breg_Fee__c> candidateFees = Database.query(
                'SELECT Id, breg_Form_Code__c, breg_Purchase_Type_Fee_type__c ' +
                'FROM breg_Fee__c ' +
                'WHERE ' + String.join(whereClauses, ' OR ') + ' ' +
                'LIMIT 200'
            );

            if (candidateFees.isEmpty()) {
                return null;
            }

            for (breg_Fee__c fee : candidateFees) {
                if (
                    String.isNotBlank(formCode) &&
                    String.isNotBlank(purchaseType) &&
                    fee.breg_Form_Code__c == formCode &&
                    fee.breg_Purchase_Type_Fee_type__c == purchaseType
                ) {
                    return fee.Id;
                }
            }

            for (breg_Fee__c fee : candidateFees) {
                if (String.isNotBlank(formCode) && fee.breg_Form_Code__c == formCode) {
                    return fee.Id;
                }
            }

            for (breg_Fee__c fee : candidateFees) {
                if (String.isNotBlank(purchaseType) && fee.breg_Purchase_Type_Fee_type__c == purchaseType) {
                    return fee.Id;
                }
            }

            return candidateFees[0].Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<TransactionLineWrapper> getPaymentTransactionLineWrappers(Id paymentId) {
        try {
            List<TransactionLine__c> transactionLines = getTransactionLines(new Set<Id>{ paymentId });
            return getTransactionLineWrappers(transactionLines);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static PaymentConfirmationWrapper getPaymentConfirmation(Id paymentId) {
        try {
            pymt__PaymentX__c payment = getPaymentRecord(paymentId);
            PaymentConfirmationWrapper wrapper = new PaymentConfirmationWrapper();

            // If payment is not completed, return status only
            if (payment.pymt__Status__c != 'Completed') {
                wrapper.paymentStatus = payment.pymt__Status__c;
                wrapper.isCompleted = false;
                return wrapper;
            }

            // Payment information
            wrapper.paymentStatus = payment.pymt__Status__c;
            wrapper.isCompleted = true;
            wrapper.referenceId = payment.Transaction__r.Name;
            wrapper.transactionId = payment.pymt__Transaction_Id__c;
            wrapper.authorizationId = payment.pymt__Authorization_Id__c;
            wrapper.transactionDate = payment.pymt__Date__c;
            wrapper.paymentAmount = payment.pymt__Amount__c;
            wrapper.currencyCode = payment.pymt__Currency_ISO_Code__c;
            wrapper.cardType = payment.pymt__Card_Type__c;
            wrapper.last4Digits = payment.pymt__Last_4_Digits__c;
            // Contact Information
            if (!isGuestUser()) {
                wrapper.contactName = payment.pymt__Contact__r?.Name;
                wrapper.contactPhone = payment.pymt__Contact__r?.Phone;
                wrapper.contactEmail = payment.pymt__Contact__r?.Email;
            }
            // Billing Information
            wrapper.billingEmail = payment.pymt__Billing_Email__c;
            wrapper.billingFirstName = payment.pymt__Billing_First_Name__c;
            wrapper.billingLastName = payment.pymt__Billing_Last_Name__c;
            // Billing Address
            wrapper.billingStreet = payment.pymt__Billing_Street__c;
            wrapper.billingCity = payment.pymt__Billing_City__c;
            wrapper.billingState = payment.pymt__Billing_State__c;
            wrapper.billingPostalCode = payment.pymt__Billing_Postal_Code__c;
            wrapper.billingCountry = payment.pymt__Billing_Country__c;

            // Transaction lines
            List<TransactionLine__c> transactionLines = getTransactionLines(new Set<Id>{ paymentId });
            List<TransactionLineWrapper> transactionLineWrappers = getTransactionLineWrappers(transactionLines);
            wrapper.transactionLineWrappers = transactionLineWrappers;

            return wrapper;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getPaymentSiteBaseUrl() {
        String orgHost = URL.getOrgDomainUrl().getHost();
        String sitesHost = orgHost.replace('.salesforce.com', '.salesforce-sites.com');
        return 'https://' + sitesHost;
    }

    @AuraEnabled
    public static String generatePaymentReceiptPdf(Id paymentId) {
        try {
            String paymentSiteBaseUrl = getPaymentSiteBaseUrl();
            // Generate the PDF using the Visualforce page
            PageReference pdfPage = new PageReference(paymentSiteBaseUrl + '/pmtx/BREG_PaymentReceipt');
            pdfPage.getParameters().put('id', paymentId);

            // Get the PDF blob
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                // In test context, create a mock blob
                pdfBlob = Blob.valueOf('Mock PDF content for testing');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // Convert to base64 string
            return EncodingUtil.base64Encode(pdfBlob);
        } catch (Exception e) {
            throw new AuraHandledException('Error generating payment receipt PDF: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id createPayment(Double amount, String cartItemsJson, String deliveryDetailsJson, Boolean skipPaymentCreation) {
        try {
            // Determine the status of transaction line item records
            String tliStatus = amount > 0 ? 'Pending' : 'Paid';
            // Get cart items
            List<Object> cartItems = (List<Object>) JSON.deserializeUntyped(cartItemsJson);
            List<Object> filteredCartItems = new List<Object>();
            for (Object cartItemObj : cartItems) {
                Map<String, Object> cartItem = (Map<String, Object>) cartItemObj;
                Integer quantity = cartItem.get('quantity') != null ? Integer.valueOf(String.valueOf(cartItem.get('quantity'))) : 0;
                Decimal price = cartItem.get('price') != null ? Decimal.valueOf(String.valueOf(cartItem.get('price'))) : 0;
                Decimal unitPrice = cartItem.get('unitPrice') != null ? Decimal.valueOf(String.valueOf(cartItem.get('unitPrice'))) : 0;

                if (quantity > 0) {
                    filteredCartItems.add(cartItemObj);
                }
            }
            cartItems = filteredCartItems;
            // Analyze documents and create cases for document cart items
            Map<String, DocumentCaseMapping> documentMappingByOldDocumentId = analyzeDocumentsAndCreateCases(cartItems, deliveryDetailsJson);
            // Get document by case id for initial filing cart items (filing with DCCA)
            Map<String, String> documentByCaseId = getDocumentByCaseId(cartItems);
            // Get FeeId to Cashier Code Id mapping
            Map<Id, Id> feeIdToCashierCodeId = getFeeIdToCashierCodeId(cartItems);
            // Create transaction record
            Transaction__c trans = createTransactionRecord(amount);
            Id transId = trans.Id;
            // Create payment record
            pymt__PaymentX__c payment;
            Id paymentId;
            if (!skipPaymentCreation) {
                payment = createPaymentRecord(amount, transId);
                paymentId = payment.Id;
            }
            // Void pending Transaction Line Items for current user before creating new ones
            voidPendingTransactionLineItems();

            // Create transaction line item records
            createTransactionLineItemRecords(
                cartItems,
                transId,
                paymentId,
                documentMappingByOldDocumentId,
                documentByCaseId,
                feeIdToCashierCodeId,
                deliveryDetailsJson,
                tliStatus
            );
            // return the transaction or payment id
            return skipPaymentCreation ? transId : paymentId;
        } catch (Exception e) {
            System.debug('** exception:' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isExpeditedProcessingDisabled() {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        return setting != null && setting.Expedited_Processing_Disabled__c == true;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isPaymentAuthorizationNoticeEnabled() {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        return setting != null && setting.Payment_Authorization_Notice_Enabled__c == true;
    }

    private static void voidPendingTransactionLineItems() {
        List<TransactionLine__c> pendingLines = [
            SELECT Id
            FROM TransactionLine__c
            WHERE PaidStatus__c = 'Pending'
            AND CreatedById = :UserInfo.getUserId()
        ];
        if (!pendingLines.isEmpty()) {
            for (TransactionLine__c line : pendingLines) {
                line.PaidStatus__c = 'Voided';
            }
            List<Database.SaveResult> saveResults = Database.update(pendingLines, false);
        }
    }

    private static Transaction__c createTransactionRecord(Double amount) {
        Transaction__c trans = new Transaction__c();
        trans.Division__c = 'BREG';
        trans.PaymentAmount__c = amount;
        trans.TotalAmount__c = amount;
        trans.Status__c = amount > 0 ? 'Pending' : 'Completed';
        trans.TransactionType__c = 'Payment';
        trans.Date__c = Date.today();
        insert trans;

        return trans;
    }

    private static pymt__PaymentX__c createPaymentRecord(Double amount, Id transId) {
        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.RecordTypeId = Schema.SObjectType.pymt__PaymentX__c.getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();
        payment.Name = 'BREG Portal Payment';
        payment.Division__c = 'BREG';
        payment.Transaction__c = transId;
        payment.pymt__Transaction_Type__c = 'Payment';
        payment.pymt__Payment_Processor__c = amount > 0 ? 'Authorize.Net' : null;
        payment.pymt__Payment_Type__c = amount > 0 ? 'Credit Card' : null;
        payment.pymt__Date__c = Date.today();
        payment.pymt__Status__c = amount > 0 ? 'In Process' : 'Completed';
        payment.pymt__Amount__c = amount;
        payment.pymt__Currency_ISO_Code__c = 'USD';
        setContact(payment);
        insert payment;

        return payment;
    }

    private static void updatePaymentContactFromCase(Id paymentId) {
        if (paymentId == null || (Test.isRunningTest() && !allowPaymentContactFallbackInTests) || currentUserHasContact()) {
            return;
        }

        Contact contact = getContactFromCase(paymentId);
        if (contact == null) {
            return;
        }

        pymt__PaymentX__c payment = new pymt__PaymentX__c(Id = paymentId);
        payment.pymt__Contact__c = contact.Id;
        setBillingInfoFromContact(payment, contact);
        update payment;
    }

    private static void createTransactionLineItemRecords(
        List<Object> cartItems,
        Id transId,
        Id paymentId,
        Map<String, DocumentCaseMapping> documentMappingByOldDocumentId,
        Map<String, String> documentByCaseId,
        Map<Id, Id> feeIdToCashierCodeId,
        String deliveryDetailsJson,
        String tliStatus
    ) {
        List<TransactionLine__c> transLineItems = new List<TransactionLine__c>();

        for (Object cartItemObj : cartItems) {
            TransactionLine__c transLineItem;
            Map<String, Object> cartItem = (Map<String, Object>) cartItemObj;
            String type = cartItem.get('type') != null ? String.valueOf(cartItem.get('type')) : '';
            Id feeId = cartItem.get('feeId') != null ? Id.valueOf(String.valueOf(cartItem.get('feeId'))) : null;
            Id cashierCodeId = null;
            if (feeId != null && feeIdToCashierCodeId.containsKey(feeId)) {
                cashierCodeId = feeIdToCashierCodeId.get(feeId);
            }

            // handle Entity List cart items
            if (type.equalsIgnoreCase('Entity List')) {
                // If the document type is 'Entity List', create only one transaction line item
                Id entityListId = cartItem.get('entityListId') != null ? Id.valueOf(String.valueOf(cartItem.get('entityListId'))) : null;
                transLineItem = createTransactionLine(
                    cartItem, // cartItem
                    null, // documentId
                    null, // caseId
                    transId, // transId
                    paymentId, // paymentId
                    entityListId, // entityListId
                    null, // agentSearchListId
                    null, // description
                    cashierCodeId, // cashierCodeId
                    null // deliveryContact
                );
            }
            // handle COGS (Certificate of Good Standing) document cart items
            else if (type.equalsIgnoreCase('Document') && String.valueOf(cartItem.get('documentType')).contains('COGS')) {
                String entityId = getDocOrEntityId((String) cartItem.get('id'), false);
                String templateDocId = getDocOrEntityId((String) cartItem.get('id'), true);
                Contact deliveryContact = parseContact(deliveryDetailsJson);
                DocumentCaseMapping documentCaseMapping = documentMappingByOldDocumentId.get(templateDocId);

                breg_Document__c relatedCogsDocument = createCOGSDocument(String.valueOf(cartItem.get('documentType')), entityId, templateDocId, (String) cartItem.get('format'), documentCaseMapping?.caseId, deliveryContact);
                
                insert relatedCogsDocument;

                transLineItem = createTransactionLine(
                    cartItem, // cartItem
                    relatedCogsDocument.Id, // documentId
                    relatedCogsDocument.breg_Case__c, // caseId
                    transId, // transId
                    paymentId, // paymentId
                    null, // entityListId
                    null, // agentSearchListId
                    null, // description
                    cashierCodeId, // cashierCodeId
                    deliveryContact // deliveryContact
                );
            }
            // handle Form Filing cart items
            else if (isInitialFiling(type)) {
                Id caseId = cartItem.get('caseId') != null ? Id.valueOf(String.valueOf(cartItem.get('caseId'))) : null;
                Id documentId = documentByCaseId.containsKey(caseId) ? Id.valueOf(documentByCaseId.get(caseId)) : null;

                transLineItem = createTransactionLine(
                    cartItem, // cartItem
                    documentId, // documentId
                    caseId, // caseId
                    transId, // transId
                    paymentId, // paymentId
                    null, // entityListId
                    null, // agentSearchListId
                    null, // description
                    cashierCodeId, // cashierCodeId
                    null // deliveryContact
                );
            }
            // handle Agent Search cart items
            else if (type.equalsIgnoreCase('Agent Search List')) {
                Id agentSearchListId = cartItem.get('agentSearchListId') != null ? Id.valueOf(String.valueOf(cartItem.get('agentSearchListId'))) : null;
                transLineItem = createTransactionLine(
                    cartItem, // cartItem
                    null, // documentId
                    null, // caseId
                    transId, // transId
                    paymentId, // paymentId
                    null, // entityListId
                    agentSearchListId, // agentSearchListId
                    null, // description
                    cashierCodeId, // cashierCodeId
                    null // deliveryContact
                );
            }
            // handle Certified Copy Fee cart items for documents
            else if (type.equalsIgnoreCase('Document') && String.valueOf(cartItem.get('documentType')).contains('Certified Copy Fee')) {
                String parentItemId = cartItem.get('parentItemId') != null ? String.valueOf(cartItem.get('parentItemId')) : null;
                Contact deliveryContact = parseContact(deliveryDetailsJson);
                Id documentId = null;
                Id caseId = null;
                if (String.isNotBlank(parentItemId)) {
                    String parentDocId = getDocOrEntityId(parentItemId, true);
                    if (documentMappingByOldDocumentId.containsKey(parentDocId)) {
                        DocumentCaseMapping documentCaseMapping = documentMappingByOldDocumentId.get(parentDocId);
                        documentId = documentCaseMapping.documentId;
                        caseId = documentCaseMapping.caseId;
                    }
                }

                transLineItem = createTransactionLine(
                    cartItem, // cartItem
                    documentId, // documentId
                    caseId, // caseId
                    transId, // transId
                    paymentId, // paymentId
                    null, // entityListId
                    null, // agentSearchListId
                    null, // description
                    cashierCodeId, // cashierCodeId
                    deliveryContact // deliveryContact
                );
            }
            // handle other Document cart items
            else if (type.equalsIgnoreCase('Document')) {
                String docId = getDocOrEntityId((String) cartItem.get('id'), true);
                Contact deliveryContact = parseContact(deliveryDetailsJson);
                Id documentId = null;
                Id caseId = null;
                if (documentMappingByOldDocumentId.containsKey(docId)) {
                    DocumentCaseMapping documentCaseMapping = documentMappingByOldDocumentId.get(docId);
                    documentId = documentCaseMapping.documentId;
                    caseId = documentCaseMapping.caseId;
                }

                transLineItem = createTransactionLine(
                    cartItem, // cartItem
                    documentId, // documentId
                    caseId, // caseId
                    transId, // transId
                    paymentId, // paymentId
                    null, // entityListId
                    null, // agentSearchListId
                    null, // description
                    cashierCodeId, // cashierCodeId
                    deliveryContact // deliveryContact
                );
            } else {
                Id caseId = cartItem.get('caseId') != null ? Id.valueOf(String.valueOf(cartItem.get('caseId'))) : null;

                transLineItem = createTransactionLine(
                    cartItem, // cartItem
                    null, // documentId
                    caseId, // caseId
                    transId, // transId
                    paymentId, // paymentId
                    null, // entityListId
                    null, // agentSearchListId
                    null, // description
                    cashierCodeId, // cashierCodeId
                    null // deliveryContact
                );
            }
            if (transLineItem != null) {
                transLineItem.PaidStatus__c = tliStatus;
                transLineItems.add(transLineItem);
            }
        }
        insert transLineItems;
        if (!isGuestUser() && !currentUserHasContact()) {
            updatePaymentContactFromCase(paymentId);
        }
    }

    public static breg_Document__c createCOGSDocument(String name, String entityId, String templateDocId, String format, Id caseId, Contact deliveryContact) {
        breg_Document__c relatedCogsDocument = new breg_Document__c();
        if (((Id) entityId).getSObjectType().getDescribe().getName() == 'Account') {
            relatedCogsDocument.breg_Account__c = entityId;
        } else {
            relatedCogsDocument.breg_TN_TM_SM__c = entityId;
        }
        relatedCogsDocument.breg_Template_Document__c = templateDocId;
        relatedCogsDocument.breg_Availability__c = format == 'Printed' ? 'Available by Mail or Pickup' : 'Available Now';
        relatedCogsDocument.breg_Case__c = caseId;
        relatedCogsDocument.Name = name;
        relatedCogsDocument.breg_Is_Certificate_Of_Good_Standing__c = true;
        relatedCogsDocument.breg_Is_Public__c = true;
        relatedCogsDocument.breg_Annotation__c = deliveryContact?.FirstName + ' ' + deliveryContact?.LastName;
        relatedCogsDocument.breg_Delivery_Email__c = deliveryContact?.Email;
        relatedCogsDocument.breg_Type__c = format == 'Printed' ? 'Printed' : 'Digital';
        return relatedCogsDocument;
    }

    private static TransactionLine__c createTransactionLine(
        Map<String, Object> cartItem,
        Id documentId,
        Id caseId,
        Id transId,
        Id paymentId,
        Id entityListId,
        Id agentSearchListId,
        String description,
        Id cashierCodeId,
        Contact deliveryContact
    ) {
        // get data from cart item
        String type = cartItem.get('type') != null ? String.valueOf(cartItem.get('type')) : null;
        String companyName = cartItem.get('companyName') != null ? String.valueOf(cartItem.get('companyName')) : '';
        companyName = String.isNotBlank(companyName) ? companyName + ' - ' : '';
        // String format = cartItem.get('format') != null ? ' - ' + String.valueOf(cartItem.get('format')) : '';
        description = String.isNotBlank(description) ? description : companyName + String.valueOf(cartItem.get('documentType'));
        Integer quantity = cartItem.get('quantity') != null ? Integer.valueOf(cartItem.get('quantity')) : 1;
        Decimal unitPrice = cartItem.get('unitPrice') != null ? (Decimal) cartItem.get('unitPrice') : 0;
        // we don't need to take into account the certify price because it is a separate transaction line item
        // Decimal certifyPrice = cartItem.get('certifyPrice') != null ? (Decimal) cartItem.get('certifyPrice') : 0;
        // Boolean isCertified = cartItem.get('isCertified') != null ? (Boolean) cartItem.get('isCertified') : false;
        // Decimal amount = isCertified ? (certifyPrice + unitPrice) * quantity : unitPrice * quantity;
        Decimal amount = unitPrice * quantity;
        Id feeId = cartItem.get('feeId') != null ? Id.valueOf(String.valueOf(cartItem.get('feeId'))) : null;

        // Create TransactionLine__c record
        TransactionLine__c transLineItem = new TransactionLine__c();
        transLineItem.breg_Document__c = documentId;
        transLineItem.breg_Case__c = caseId;
        transLineItem.Transaction__c = transId;
        transLineItem.Payment__c = paymentId;
        transLineItem.Description__c = description;
        transLineItem.breg_Quantity__c = quantity;
        transLineItem.breg_Unit_Price__c = unitPrice;
        transLineItem.Amount__c = amount;
        transLineItem.breg_Type__c = type;
        transLineItem.breg_Fee__c = feeId;
        transLineItem.breg_Entity_List__c = entityListId;
        transLineItem.breg_Agent_Search_List__c = agentSearchListId;
        transLineItem.CashierCode__c = cashierCodeId;
        transLineItem.breg_Delivery_Contact__c = deliveryContact != null ? deliveryContact.Id : null;
        return transLineItem;
    }

    private static Map<Id, Id> getFeeIdToCashierCodeId(List<Object> cartItems) {
        Map<Id, Id> feeIdToCashierCodeId = new Map<Id, Id>();

        // Get fee ids from cart items
        Set<Id> feeIds = new Set<Id>();
        for (Object cartItemObj : cartItems) {
            Map<String, Object> cartItem = (Map<String, Object>) cartItemObj;
            Id feeId = cartItem.get('feeId') != null ? Id.valueOf(String.valueOf(cartItem.get('feeId'))) : null;
            Id certifyFeeId = cartItem.get('certifyFeeId') != null ? Id.valueOf(String.valueOf(cartItem.get('certifyFeeId'))) : null;
            if (certifyFeeId != null) {
                feeIds.add(certifyFeeId);
            }
            if (feeId != null) {
                feeIds.add(feeId);
            }
        }

        if (feeIds.isEmpty()) {
            return feeIdToCashierCodeId;
        }

        // Get cashier codes from fees
        List<breg_Fee__c> fees = [
            SELECT Id, breg_Cashier_Code__c
            FROM breg_Fee__c
            WHERE Id IN :feeIds
        ];
        Set<String> cashierCodes = new Set<String>();
        for (breg_Fee__c fee : fees) {
            cashierCodes.add(fee.breg_Cashier_Code__c);
        }

        // Get cashier codes from cashier codes
        List<CashierCode__c> cashierCodeRecords = [
            SELECT Id, CashierCode__c
            FROM CashierCode__c
            WHERE CashierCode__c IN :cashierCodes AND Division__c = 'BREG'
        ];
        for (CashierCode__c cashierCodeRecord : cashierCodeRecords) {
            for (breg_Fee__c fee : fees) {
                if (fee.breg_Cashier_Code__c == cashierCodeRecord.CashierCode__c) {
                    feeIdToCashierCodeId.put(fee.Id, cashierCodeRecord.Id);
                }
            }
        }

        return feeIdToCashierCodeId;
    }

    public static Map<Id, Id> getCashierCodeIdToFeeId(Set<Id> cashierCodeIds) {
        Map<Id, Id> cashierCodeIdToFeeId = new Map<Id, Id>();
        if (cashierCodeIds == null || cashierCodeIds.isEmpty()) {
            return cashierCodeIdToFeeId;
        }

        List<CashierCode__c> cashierCodeRecords = [
            SELECT Id, CashierCode__c
            FROM CashierCode__c
            WHERE Id IN :cashierCodeIds
        ];

        Set<String> cashierCodes = new Set<String>();
        for (CashierCode__c cashierCodeRecord : cashierCodeRecords) {
            if (String.isNotBlank(cashierCodeRecord.CashierCode__c)) {
                cashierCodes.add(cashierCodeRecord.CashierCode__c);
            }
        }

        if (cashierCodes.isEmpty()) {
            return cashierCodeIdToFeeId;
        }

        Map<String, Id> feeIdByCashierCode = new Map<String, Id>();
        for (breg_Fee__c fee : [
            SELECT Id, breg_Cashier_Code__c
            FROM breg_Fee__c
            WHERE breg_Cashier_Code__c IN :cashierCodes
        ]) {
            if (String.isNotBlank(fee.breg_Cashier_Code__c) && !feeIdByCashierCode.containsKey(fee.breg_Cashier_Code__c)) {
                feeIdByCashierCode.put(fee.breg_Cashier_Code__c, fee.Id);
            }
        }

        for (CashierCode__c cashierCodeRecord : cashierCodeRecords) {
            if (feeIdByCashierCode.containsKey(cashierCodeRecord.CashierCode__c)) {
                cashierCodeIdToFeeId.put(cashierCodeRecord.Id, feeIdByCashierCode.get(cashierCodeRecord.CashierCode__c));
            }
        }

        return cashierCodeIdToFeeId;
    }

    public static List<TransactionLine__c> getTransactionLines(Set<Id> paymentIds) {
        return [
            SELECT
                Id,
                Description__c,
                CashierCodeDescription__c,
                Amount__c,
                Payment__c,
                RefundAmount__c,
                breg_Quantity__c,
                breg_Unit_Price__c,
                breg_Fee__c,
                breg_Entity_List__c,
                breg_Type__c,
                breg_Case__c,
                breg_Case__r.Status,
                breg_Case__r.CaseNumber,
                breg_Case__r.breg_Workitem_Number__c,
                breg_Case__r.breg_Delivery_Method__c,
                breg_Case__r.breg_Form_Configuration__r.breg_Form_Name__c,
                breg_Case__r.breg_Form_Configuration__r.breg_Form_Code__c,
                breg_Case__r.breg_Portal_User_Entity_Selected__c,
                breg_Case__r.breg_Portal_User_Entity_Selected__r.Name,
                breg_Case__r.breg_Entity__c,
                breg_Case__r.breg_Entity__r.Name,
                breg_Case__r.breg_TN_TM_SM__c,
                breg_Case__r.breg_TN_TM_SM__r.Name,
                breg_Case__r.breg_Annual__c,
                breg_Case__r.breg_Annual__r.Name,
                breg_Case__r.breg_Annual__r.breg_Account__c,
                breg_Case__r.breg_Annual__r.breg_Account__r.Name,
                breg_Case__r.breg_Form_Action__c,
                breg_Case__r.breg_GP_Case__c,
                breg_Case__r.breg_GP_Case__r.breg_Workitem_Number__c,
                breg_Case__r.breg_GP_Case__r.Status,
                breg_Case__r.breg_GP_Case__r.breg_Delivery_Method__c,
                breg_Case__r.breg_GP_Case__r.breg_Form_Configuration__r.breg_Form_Name__c,
                breg_Document__c,
                breg_Document__r.Name,
                breg_Document__r.breg_Availability__c,
                breg_Document__r.breg_Docusign_Document_Id__c,
                breg_Document__r.breg_Type__c,
                breg_Document__r.CreatedDate,
                breg_Document__r.breg_Case__r.Status,
                breg_Document__r.breg_Case__r.CaseNumber,
                breg_Document__r.breg_Account__c,
                breg_Document__r.breg_Account__r.Name,
                breg_Document__r.breg_TN_TM_SM__c,
                breg_Document__r.breg_TN_TM_SM__r.Name,
                breg_Document__r.breg_Annual__c,
                breg_Document__r.breg_Annual__r.Name,
                breg_Document__r.breg_Annual__r.breg_Account__c,
                breg_Document__r.breg_Annual__r.breg_Account__r.Name,
                breg_Document__r.breg_Is_Public__c,
                Transaction__c,
                Transaction__r.Date__c,
                breg_Agent_Search_List__c,
                breg_Agent_Search_List__r.Name,
                breg_Agent_Search_List__r.breg_Agents_JSON__c
            FROM TransactionLine__c
            WHERE Payment__c IN :paymentIds
            ORDER BY Transaction__r.Date__c DESC, breg_Case__c DESC
        ];
    }

    public static List<TransactionLineWrapper> getTransactionLineWrappers(List<TransactionLine__c> transactionLines) {
        Set<Id> caseIds = new Set<Id>();
        Set<String> docusignDocumentIds = new Set<String>();

        for (TransactionLine__c line : transactionLines) {
            if (line.breg_Document__r?.breg_Docusign_Document_Id__c != null) {
                docusignDocumentIds.add(line.breg_Document__r.breg_Docusign_Document_Id__c);
            }
            if (line.breg_Case__c != null) {
                caseIds.add(line.breg_Case__c);
            }
            if (line.breg_Case__r?.breg_GP_Case__c != null) {
                caseIds.add(line.breg_Case__r.breg_GP_Case__c);
            }
        }
        Map<Id, List<breg_Document__c>> caseIdToDocumentsMap = getCaseIdToDocumentMap(caseIds);
        Map<String, Date> docusignDocumentIdToExpirationDateMap = getDocusignDocumentIdToExpirationDateMap(docusignDocumentIds);

        List<TransactionLineWrapper> transactionLineWrappers = new List<TransactionLineWrapper>();
        for (TransactionLine__c line : transactionLines) {
            TransactionLineWrapper lineWrapper = new TransactionLineWrapper();
            String type = line.breg_Type__c != null ? String.valueOf(line.breg_Type__c) : null;

            lineWrapper.type = type;
            lineWrapper.description = line.Description__c != null ? line.Description__c : line.CashierCodeDescription__c;
            lineWrapper.description = String.isNotBlank(lineWrapper.description) ? lineWrapper.description : '';
            lineWrapper.isCertified = false;
            lineWrapper.isExpedited = false;
            lineWrapper.isAgentSearchList = type == 'Agent Search List';
            lineWrapper.isEntityListDocument = type == 'Entity List';
            lineWrapper.paymentId = line.Payment__c;
            lineWrapper.purchaseDate = line.Transaction__r?.Date__c;
            lineWrapper.deliveryMethod = line.breg_Case__r?.breg_Delivery_Method__c;
            lineWrapper.workItemNumber = line.breg_Case__r?.breg_Workitem_Number__c;
            lineWrapper.caseStatus = line.breg_Case__r?.Status;
            lineWrapper.quantity = line.breg_Quantity__c != null ? Integer.valueOf(line.breg_Quantity__c) : 1;
            lineWrapper.price = line.Amount__c;
            lineWrapper.entityId = getEntityIdFromCase(line.breg_Case__r);
            lineWrapper.entityName = getEntityNameFromCase(line.breg_Case__r);
            lineWrapper.formName = line.breg_Case__r?.breg_Form_Configuration__r?.breg_Form_Name__c;
            lineWrapper.formCode = line.breg_Case__r?.breg_Form_Configuration__r?.breg_Form_Code__c;
            lineWrapper.formAction = line.breg_Case__r?.breg_Form_Action__c;

            lineWrapper.isDocumentRelated =
                (line.breg_Document__c != null &&
                (line.breg_Document__r.breg_Is_Public__c == true ||
                lineWrapper.isAgentSearchList == true ||
                lineWrapper.isEntityListDocument == true)) || (line.breg_Case__c != null && caseIdToDocumentsMap.containsKey(line.breg_Case__c));

            List<breg_Document__c> docsToProcess = new List<breg_Document__c>();
            if (
                line.breg_Document__c != null &&
                (line.breg_Document__r.breg_Is_Public__c == true ||
                lineWrapper.isAgentSearchList == true ||
                lineWrapper.isEntityListDocument == true)
            ) {
                docsToProcess.add(line.breg_Document__r);
            } else if (line.breg_Case__c != null && caseIdToDocumentsMap.containsKey(line.breg_Case__c)) {
                docsToProcess = caseIdToDocumentsMap.get(line.breg_Case__c);
            }

            lineWrapper.downloadableDocuments = new List<DocumentDownloadInfo>();

            if (
                !docsToProcess.isEmpty() &&
                lineWrapper.isDocumentRelated &&
                (type == 'Document' ||
                !lineWrapper.description.contains('Fee') ||
                lineWrapper.description.contains('Annual Filing Fee')) ||
                (type == 'NBR Form' && lineWrapper.description.contains('Certified Copy Fee'))
            ) {
                for (breg_Document__c doc : docsToProcess) {
                    if (doc.breg_Docusign_Document_Id__c == null) {
                        continue;
                    }

                    Boolean isEntityListDocumentDownloadable = false;
                    if (docusignDocumentIdToExpirationDateMap.containsKey(doc.breg_Docusign_Document_Id__c)) {
                        Date today = Date.today();
                        isEntityListDocumentDownloadable = docusignDocumentIdToExpirationDateMap.get(doc.breg_Docusign_Document_Id__c) > today;
                    }

                    Boolean isDownloadable = (!lineWrapper.isEntityListDocument) || (lineWrapper.isEntityListDocument && isEntityListDocumentDownloadable);

                    if (isDownloadable) {
                        DocumentDownloadInfo info = new DocumentDownloadInfo();
                        info.docusignDocumentId = doc.breg_Docusign_Document_Id__c;
                        info.name = doc.Name;
                        lineWrapper.downloadableDocuments.add(info);
                    }
                }

                lineWrapper.isAvailableToDownload = !lineWrapper.downloadableDocuments.isEmpty();

                if (lineWrapper.isAvailableToDownload) {
                    breg_Document__c firstDoc = docsToProcess[0];
                    lineWrapper.documentType = firstDoc.breg_Type__c;
                    if (type == 'Document' && lineWrapper.documentType == 'Digital') {
                        lineWrapper.deliveryMethod = 'Email';
                    }
                    if (lineWrapper.entityId == null) {
                        lineWrapper.entityId = getEntityIdFromDocument(firstDoc);
                    }
                    if (lineWrapper.entityName == null) {
                        lineWrapper.entityName = getEntityNameFromDocument(firstDoc);
                    }
                }
            }

            if (lineWrapper.isEntityListDocument || lineWrapper.isAgentSearchList) {
                lineWrapper.documentType = 'Digital';
                lineWrapper.deliveryMethod = 'Email';
            }

            transactionLineWrappers.add(lineWrapper);
        }
        return consolidateTransactionLineWrappers(transactionLineWrappers, transactionLines, caseIdToDocumentsMap);
    }

    private static String getPurchaseTypeForTransactionLine(TransactionLine__c line) {
        String description = line.Description__c != null ? line.Description__c.toLowerCase() : '';

        if (description.contains('certif')) {
            return 'Certify';
        }
        if (description.contains('expedite')) {
            return 'Expedite Fees';
        }
        if (description.contains('archive')) {
            return 'Archive Fees';
        }
        if (description.contains('late fee')) {
            return 'Late Fees';
        }
        if (description.contains('annual filing fee')) {
            return 'Annual Filing Fee';
        }
        if (line.breg_Type__c != null && line.breg_Type__c.contains('Form')) {
            return 'Form Fees';
        }
        if (line.breg_Type__c != null && line.breg_Type__c.equalsIgnoreCase('Document')) {
            return 'Document';
        }

        return null;
    }

    private static List<TransactionLineWrapper> consolidateTransactionLineWrappers(
        List<TransactionLineWrapper> wrappers,
        List<TransactionLine__c> transactionLines,
        Map<Id, List<breg_Document__c>> caseIdToDocumentsMap
    ) {
        Map<Id, List<Integer>> caseIdToIndices = new Map<Id, List<Integer>>();

        for (Integer i = 0; i < transactionLines.size(); i++) {
            Id caseId = transactionLines[i].breg_Case__c;
            if (caseId != null) {
                if (!caseIdToIndices.containsKey(caseId)) {
                    caseIdToIndices.put(caseId, new List<Integer>());
                }
                caseIdToIndices.get(caseId).add(i);
            }
        }

        Set<Integer> indicesToRemove = new Set<Integer>();

        for (Id caseId : caseIdToIndices.keySet()) {
            List<Integer> indices = caseIdToIndices.get(caseId);
            if (indices.size() <= 1) {
                continue;
            }

            List<Integer> primaryIndices = findAllPrimaryIndices(indices, transactionLines);

            if (primaryIndices.size() <= 1) {
                consolidateSinglePrimary(primaryIndices.isEmpty() ? indices[0] : primaryIndices[0], indices, wrappers, transactionLines, indicesToRemove);
            } else {
                consolidateMultiFiling(primaryIndices, indices, wrappers, transactionLines, caseIdToDocumentsMap, indicesToRemove);
            }
        }

        List<TransactionLineWrapper> result = new List<TransactionLineWrapper>();
        for (Integer i = 0; i < wrappers.size(); i++) {
            if (!indicesToRemove.contains(i)) {
                result.add(wrappers[i]);
            }
        }
        return result;
    }

    private static void consolidateSinglePrimary(
        Integer primaryIndex,
        List<Integer> indices,
        List<TransactionLineWrapper> wrappers,
        List<TransactionLine__c> transactionLines,
        Set<Integer> indicesToRemove
    ) {
        Decimal totalPrice = 0;
        Boolean hasCertified = false;
        Boolean hasExpedited = false;

        for (Integer idx : indices) {
            String lineDescription = transactionLines[idx].Description__c != null ? transactionLines[idx].Description__c : '';
            totalPrice += wrappers[idx].price != null ? wrappers[idx].price : 0;
            if (lineDescription.containsIgnoreCase('Expedite')) {
                hasExpedited = true;
            }
            if (lineDescription.containsIgnoreCase('Certified')) {
                hasCertified = true;
            }
        }

        TransactionLineWrapper primary = wrappers[primaryIndex];
        primary.price = totalPrice;
        primary.isCertified = hasCertified;
        primary.isExpedited = hasExpedited;

        for (Integer idx : indices) {
            if (idx != primaryIndex) {
                indicesToRemove.add(idx);
            }
        }
    }

    private static void consolidateMultiFiling(
        List<Integer> primaryIndices,
        List<Integer> allIndices,
        List<TransactionLineWrapper> wrappers,
        List<TransactionLine__c> transactionLines,
        Map<Id, List<breg_Document__c>> caseIdToDocumentsMap,
        Set<Integer> indicesToRemove
    ) {
        Map<Integer, String> primaryToEntityType = new Map<Integer, String>();
        for (Integer pIdx : primaryIndices) {
            primaryToEntityType.put(pIdx, extractEntityType(transactionLines[pIdx].Description__c));
        }

        Map<Integer, List<Integer>> subGroups = new Map<Integer, List<Integer>>();
        for (Integer pIdx : primaryIndices) {
            subGroups.put(pIdx, new List<Integer>{ pIdx });
        }

        for (Integer idx : allIndices) {
            if (primaryIndices.contains(idx)) {
                continue;
            }
            String feeDescription = transactionLines[idx].Description__c != null ? transactionLines[idx].Description__c : '';
            Integer matchedPrimary = null;
            for (Integer pIdx : primaryIndices) {
                String entityType = primaryToEntityType.get(pIdx);
                if (String.isNotBlank(entityType) && feeDescription.containsIgnoreCase(entityType)) {
                    matchedPrimary = pIdx;
                    break;
                }
            }
            if (matchedPrimary == null) {
                matchedPrimary = primaryIndices[0];
            }
            subGroups.get(matchedPrimary).add(idx);
        }

        String parentFormName = transactionLines[allIndices[0]].breg_Case__r?.breg_Form_Configuration__r?.breg_Form_Name__c;
        Id gpCaseId = transactionLines[allIndices[0]].breg_Case__r?.breg_GP_Case__c;

        for (Integer pIdx : primaryIndices) {
            List<Integer> subGroup = subGroups.get(pIdx);

            Decimal totalPrice = 0;
            Boolean hasCertified = false;
            Boolean hasExpedited = false;

            for (Integer idx : subGroup) {
                String lineDescription = transactionLines[idx].Description__c != null ? transactionLines[idx].Description__c : '';
                totalPrice += wrappers[idx].price != null ? wrappers[idx].price : 0;
                if (lineDescription.containsIgnoreCase('Expedite')) {
                    hasExpedited = true;
                }
                if (lineDescription.containsIgnoreCase('Certified')) {
                    hasCertified = true;
                }
            }

            TransactionLineWrapper primary = wrappers[pIdx];
            primary.price = totalPrice;
            primary.isCertified = hasCertified;
            primary.isExpedited = hasExpedited;

            Boolean isGpSubGroup = gpCaseId != null && isGpPrimary(primaryToEntityType.get(pIdx), parentFormName);
            if (isGpSubGroup) {
                updateGpPrimaryWrapper(primary, transactionLines[allIndices[0]], caseIdToDocumentsMap, gpCaseId);
            }

            for (Integer idx : subGroup) {
                if (idx != pIdx) {
                    indicesToRemove.add(idx);
                }
            }
        }
    }

    private static Boolean isGpPrimary(String entityType, String parentFormName) {
        if (String.isBlank(entityType) || String.isBlank(parentFormName)) {
            return false;
        }
        return !parentFormName.containsIgnoreCase(entityType);
    }

    private static void updateGpPrimaryWrapper(
        TransactionLineWrapper gpWrapper,
        TransactionLine__c anyLine,
        Map<Id, List<breg_Document__c>> caseIdToDocumentsMap,
        Id gpCaseId
    ) {
        gpWrapper.workItemNumber = anyLine.breg_Case__r?.breg_GP_Case__r?.breg_Workitem_Number__c;
        gpWrapper.caseStatus = anyLine.breg_Case__r?.breg_GP_Case__r?.Status;
        gpWrapper.deliveryMethod = anyLine.breg_Case__r?.breg_GP_Case__r?.breg_Delivery_Method__c;

        gpWrapper.downloadableDocuments = new List<DocumentDownloadInfo>();
        if (caseIdToDocumentsMap.containsKey(gpCaseId)) {
            for (breg_Document__c doc : caseIdToDocumentsMap.get(gpCaseId)) {
                if (doc.breg_Docusign_Document_Id__c != null) {
                    DocumentDownloadInfo info = new DocumentDownloadInfo();
                    info.docusignDocumentId = doc.breg_Docusign_Document_Id__c;
                    info.name = doc.Name;
                    gpWrapper.downloadableDocuments.add(info);
                }
            }
        }

        gpWrapper.isAvailableToDownload = !gpWrapper.downloadableDocuments.isEmpty();
        gpWrapper.isDocumentRelated = gpWrapper.isAvailableToDownload;
    }

    private static String extractEntityType(String description) {
        if (String.isBlank(description)) {
            return null;
        }
        Integer dashIndex = description.lastIndexOf(' - ');
        Integer filingIndex = description.indexOfIgnoreCase(' filing with DCCA');
        if (dashIndex < 0 || filingIndex < 0 || dashIndex >= filingIndex) {
            return null;
        }
        return description.substring(dashIndex + 3, filingIndex);
    }

    private static List<Integer> findAllPrimaryIndices(List<Integer> indices, List<TransactionLine__c> transactionLines) {
        List<Integer> primaries = new List<Integer>();
        Integer documentIndex = null;

        for (Integer idx : indices) {
            String lineType = transactionLines[idx].breg_Type__c != null ? transactionLines[idx].breg_Type__c : '';
            String lineDescription = transactionLines[idx].Description__c != null ? transactionLines[idx].Description__c : '';

            if (lineDescription.containsIgnoreCase('filing with DCCA')) {
                primaries.add(idx);
            } else if (lineDescription.containsIgnoreCase('Annual Filing Fee')) {
                primaries.add(idx);
            } else if (lineType.equalsIgnoreCase('NBR Form') && lineDescription.containsIgnoreCase('Certified Copy Fee')) {
                primaries.add(idx);
            } else if (lineType.equalsIgnoreCase('Document') && !lineDescription.containsIgnoreCase('Certified Copy Fee')) {
                documentIndex = idx;
            }
        }

        if (primaries.isEmpty()) {
            primaries.add(documentIndex != null ? documentIndex : indices[0]);
        }
        return primaries;
    }

    private static Map<String, Date> getDocusignDocumentIdToExpirationDateMap(Set<String> docusignDocumentIds) {
        Map<String, Date> docusignDocumentIdToExpirationDateMap = new Map<String, Date>();

        List<breg_Entity_List_Result__c> entityListResults = [
            SELECT Id, breg_Docusign_Document_Id__c, breg_Expiration_Date__c
            FROM breg_Entity_List_Result__c
            WHERE breg_Docusign_Document_Id__c IN :docusignDocumentIds AND breg_Docusign_Document_Id__c != NULL
        ];

        for (breg_Entity_List_Result__c result : entityListResults) {
            docusignDocumentIdToExpirationDateMap.put(result.breg_Docusign_Document_Id__c, result.breg_Expiration_Date__c);
        }

        return docusignDocumentIdToExpirationDateMap;
    }

    private static Map<Id, List<breg_Document__c>> getCaseIdToDocumentMap(Set<Id> caseIds) {
        Map<Id, List<breg_Document__c>> caseIdToDocumentsMap = new Map<Id, List<breg_Document__c>>();

        List<breg_Document__c> documents = [
            SELECT
                Id,
                breg_Case__c,
                Name,
                breg_Availability__c,
                breg_Docusign_Document_Id__c,
                breg_Type__c,
                CreatedDate,
                breg_Case__r.Status,
                breg_Case__r.CaseNumber,
                breg_Account__c,
                breg_Account__r.Name,
                breg_TN_TM_SM__c,
                breg_TN_TM_SM__r.Name,
                breg_Annual__c,
                breg_Annual__r.Name,
                breg_Annual__r.breg_Account__c,
                breg_Annual__r.breg_Account__r.Name
            FROM breg_Document__c
            WHERE
                breg_Case__c IN :caseIds
                AND (breg_Is_Public__c = TRUE
                OR (Name LIKE '%- Initial Filing.pdf'
                AND (NOT Name LIKE 'I_%')
                AND (NOT Name LIKE 'P_%')))
                AND breg_Is_Irrelevant__c = FALSE
        ];

        for (breg_Document__c doc : documents) {
            if (!caseIdToDocumentsMap.containsKey(doc.breg_Case__c)) {
                caseIdToDocumentsMap.put(doc.breg_Case__c, new List<breg_Document__c>());
            }
            caseIdToDocumentsMap.get(doc.breg_Case__c).add(doc);
        }

        return caseIdToDocumentsMap;
    }

    private static breg_Document__c getValidCogsForRecord(Id recordId) {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        Integer validDays = (Integer) setting.Published_Document_Code_Valid_Days__c;
        try {
            breg_Document__c document = [
                SELECT
                    Id,
                    Name,
                    CreatedDate,
                    breg_Account__c,
                    breg_TN_TM_SM__c,
                    breg_TN_TM_SM__r.breg_Type__c,
                    breg_Annual__c,
                    breg_Availability__c,
                    breg_Available_To_Certify__c,
                    breg_Case__c,
                    breg_Case__r.breg_Form_Configuration__c,
                    breg_Case__r.breg_Form_Configuration__r.breg_Suffix_Code__c,
                    breg_Is_Public__c,
                    breg_File_Number__c,
                    breg_File_Storage_Id__c,
                    breg_File_Storage_URL__c,
                    breg_Type__c,
                    breg_Price__c,
                    breg_Is_Certificate_Of_Good_Standing__c
                FROM breg_Document__c
                WHERE
                    breg_Account__c = :recordId
                    AND breg_Is_Certificate_Of_Good_Standing__c = TRUE
                    AND breg_Template_Document__c != NULL
                    AND breg_Is_Template_Copy__c != TRUE
                    AND Id IN (
                        SELECT breg_Document__c
                        FROM breg_Certificate__c
                        WHERE
                            breg_Document__c != NULL
                            AND breg_Is_Published__c = TRUE
                            AND breg_Published_Timestamp__c > :DateTime.now().addDays(-validDays)
                    )
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return document;
        } catch (QueryException e) {
            return null;
        }
    }

    private static String getEntityIdFromDocument(breg_Document__c doc) {
        if (doc == null) {
            return null;
        }

        String entityId = null;
        if (doc.breg_Annual__r?.breg_Account__c != null) {
            entityId = doc.breg_Annual__r.breg_Account__c;
        } else if (doc.breg_Account__c != null) {
            entityId = doc.breg_Account__c;
        } else if (doc.breg_TN_TM_SM__c != null) {
            entityId = doc.breg_TN_TM_SM__c;
        }
        return entityId;
    }

    private static String getEntityNameFromDocument(breg_Document__c doc) {
        if (doc == null) {
            return null;
        }

        String entityName = null;
        if (doc.breg_Annual__r?.breg_Account__c != null) {
            entityName = doc.breg_Annual__r.breg_Account__r.Name;
        } else if (doc.breg_Account__c != null) {
            entityName = doc.breg_Account__r.Name;
        } else if (doc.breg_TN_TM_SM__c != null) {
            entityName = doc.breg_TN_TM_SM__r.Name;
        }
        return entityName;
    }

    private static String getEntityIdFromCase(Case caseRecord) {
        if (caseRecord == null) {
            return null;
        }

        String entityId = null;
        if (caseRecord.breg_Annual__r?.breg_Account__c != null) {
            entityId = caseRecord.breg_Annual__r.breg_Account__c;
        } else if (caseRecord.breg_Portal_User_Entity_Selected__c != null) {
            entityId = caseRecord.breg_Portal_User_Entity_Selected__c;
        } else if (caseRecord.breg_Entity__c != null) {
            entityId = caseRecord.breg_Entity__c;
        } else if (caseRecord.breg_TN_TM_SM__c != null) {
            entityId = caseRecord.breg_TN_TM_SM__c;
        }
        return entityId;
    }

    private static String getEntityNameFromCase(Case caseRecord) {
        if (caseRecord == null) {
            return null;
        }

        String entityName = null;
        if (caseRecord.breg_Annual__r?.breg_Account__r?.Name != null) {
            entityName = caseRecord.breg_Annual__r.breg_Account__r.Name;
        } else if (caseRecord.breg_Portal_User_Entity_Selected__r?.Name != null) {
            entityName = caseRecord.breg_Portal_User_Entity_Selected__r.Name;
        } else if (caseRecord.breg_Entity__r?.Name != null) {
            entityName = caseRecord.breg_Entity__r.Name;
        } else if (caseRecord.breg_TN_TM_SM__r?.Name != null) {
            entityName = caseRecord.breg_TN_TM_SM__r.Name;
        }
        return entityName;
    }

    private static void setContact(pymt__PaymentX__c payment) {
        if (!isGuestUser() && !Test.isRunningTest()) {
            User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            Contact contact = [
                SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
                FROM Contact
                WHERE Id = :currentUser.ContactId
                LIMIT 1
            ];
            if (contact != null) {
                payment.pymt__Contact__c = contact.Id;
                setBillingInfoFromContact(payment, contact);
            } else {
                setGuestContact(payment);
            }
        } else {
            setGuestContact(payment);
        }
    }

    private static Contact getContactFromCase(Id paymentId) {
        if (paymentId == null) {
            return null;
        }

        List<TransactionLine__c> transactionLines = [
            SELECT breg_Case__r.ContactId
            FROM TransactionLine__c
            WHERE Payment__c = :paymentId
            LIMIT 1
        ];

        if (transactionLines.isEmpty() || transactionLines[0].breg_Case__r?.ContactId == null) {
            return null;
        }

        return getContactById(transactionLines[0].breg_Case__r.ContactId);
    }

    private static Contact getContactById(Id contactId) {
        if (contactId == null) {
            return null;
        }

        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        return contacts.isEmpty() ? null : contacts[0];
    }

    private static Boolean currentUserHasContact() {
        List<User> users = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return !users.isEmpty() && users[0].ContactId != null;
    }

    private static void setGuestContact(pymt__PaymentX__c payment) {
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Name = 'BREG Portal Guest User Contact' LIMIT 1];
        if (!contacts.isEmpty()) {
            payment.pymt__Contact__c = contacts[0].Id;
            payment.pymt__Billing_State__c = 'HI';
            payment.pymt__Billing_Country__c = 'US';
        }
    }

    /**
     * Prepopulates billing information on the payment record from the associated contact.
     * @param payment The payment record to populate billing info on
     * @param contact The contact to populate billing info from
     */
    private static void setBillingInfoFromContact(pymt__PaymentX__c payment, Contact contact) {
        payment.pymt__Billing_First_Name__c = contact.FirstName != null ? contact.FirstName : '';
        payment.pymt__Billing_Last_Name__c = contact.LastName != null ? contact.LastName : '';
        payment.pymt__Billing_Email__c = contact.Email != null ? contact.Email : '';
        payment.pymt__Billing_Phone__c = contact.Phone != null ? contact.Phone : '';
        payment.pymt__Billing_Street__c = contact.MailingStreet != null ? contact.MailingStreet : '';
        payment.pymt__Billing_City__c = contact.MailingCity != null ? contact.MailingCity : '';
        payment.pymt__Billing_State__c = contact.MailingState != null ? contact.MailingState : 'HI';
        payment.pymt__Billing_Postal_Code__c = contact.MailingPostalCode != null ? contact.MailingPostalCode : '';
        payment.pymt__Billing_Country__c = contact.MailingCountry != null ? contact.MailingCountry : 'US';
    }

    private static Boolean isGuestUser() {
        return UserInfo.getUserType().equalsIgnoreCase('Guest');
    }

    private static pymt__PaymentX__c getPaymentRecord(Id paymentId) {
        return [
            SELECT
                Id,
                Name,
                pymt__Status__c,
                pymt__Amount__c,
                pymt__Date__c,
                pymt__Transaction_Id__c,
                pymt__Currency_ISO_Code__c,
                pymt__Billing_First_Name__c,
                pymt__Billing_Last_Name__c,
                pymt__Billing_Email__c,
                pymt__Billing_Street__c,
                pymt__Billing_City__c,
                pymt__Billing_State__c,
                pymt__Billing_Postal_Code__c,
                pymt__Billing_Country__c,
                pymt__Card_Type__c,
                pymt__Last_4_Digits__c,
                pymt__Authorization_Id__c,
                Transaction__c,
                Transaction__r.Name,
                Transaction__r.Status__c,
                pymt__Contact__c,
                pymt__Contact__r.Name,
                pymt__Contact__r.Phone,
                pymt__Contact__r.Email
            FROM pymt__PaymentX__c
            WHERE Id = :paymentId
            LIMIT 1
        ];
    }

    private static Map<String, DocumentCaseMapping> analyzeDocumentsAndCreateCases(List<Object> cartItems, String deliveryDetailsJson) {
        Map<String, DocumentCaseMapping> output = new Map<String, DocumentCaseMapping>();

        if (String.isBlank(deliveryDetailsJson) || deliveryDetailsJson == '{}') {
            return output;
        }

        List<String> documentIds = new List<String>();
        Map<Id, Id> docEntityIdsMap = new Map<Id, Id>();
        Map<String, Boolean> isCertifiedByDocId = new Map<String, Boolean>();
        Map<String, Integer> certifiedCopiesMap = new Map<String, Integer>();

        for (Object cartItemObj : cartItems) {
            Map<String, Object> cartItem = (Map<String, Object>) cartItemObj;
            String type = String.valueOf(cartItem.get('type'));
            if (!type.equalsIgnoreCase('Document')) {
                continue;
            }
            // Skip certified copy fee items - they are processed in the second pass
            String documentType = cartItem.get('documentType') != null ? String.valueOf(cartItem.get('documentType')) : '';
            if (documentType.contains('Certified Copy Fee')) {
                continue;
            }
            Id nextDocId;
            Id relatedEntityId;
            try {
                nextDocId = Id.valueOf(getDocOrEntityId((String) cartItem.get('id'), true));
                relatedEntityId = Id.valueOf(getDocOrEntityId((String) cartItem.get('id'), false));
            } catch (Exception e) {
                continue;
            }
            documentIds.add(nextDocId);
            docEntityIdsMap.put(nextDocId, relatedEntityId);
            isCertifiedByDocId.put(nextDocId, false);
        }

        // Second pass: detect certification from separate "Certified Copy Fee" cart items
        for (Object cartItemObj : cartItems) {
            Map<String, Object> cartItem = (Map<String, Object>) cartItemObj;
            String documentType = cartItem.get('documentType') != null ? String.valueOf(cartItem.get('documentType')) : '';
            String parentItemId = cartItem.get('parentItemId') != null ? String.valueOf(cartItem.get('parentItemId')) : null;
            if (!documentType.contains('Certified Copy Fee') || String.isBlank(parentItemId)) {
                continue;
            }
            Id parentDocId;
            try {
                parentDocId = Id.valueOf(getDocOrEntityId(parentItemId, true));
            } catch (Exception e) {
                continue;
            }
            if (isCertifiedByDocId.containsKey(parentDocId)) {
                isCertifiedByDocId.put(parentDocId, true);
                Integer certQuantity = cartItem.get('quantity') != null ? Integer.valueOf(cartItem.get('quantity')) : 1;
                certifiedCopiesMap.put(parentDocId, certQuantity);
            }
        }

        if (documentIds.isEmpty()) {
            return output;
        }

        List<breg_Document__c> documents = [
            SELECT
                Id,
                Name,
                breg_Case__c,
                breg_Case__r.breg_Form_Configuration__r.breg_Form_Code__c,
                breg_Case__r.breg_Entity__r.Name,
                breg_Case__r.breg_TNTMSM_Description__c,
                breg_Account__c,
                breg_TN_TM_SM__c,
                breg_Annual__c,
                breg_Availability__c,
                breg_Available_To_Certify__c,
                breg_Is_Public__c,
                breg_Type__c,
                breg_Price__c,
                breg_Is_Certificate_Of_Good_Standing__c,
                breg_Docusign_Document_Id__c,
                breg_Is_Certified__c
            FROM breg_Document__c
            WHERE Id IN :documentIds
            FOR UPDATE
        ];
        Id caseRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case'
            LIMIT 1
        ]
        .Id;

        Map<Id, Account> relatedAccountsMap = new Map<Id, Account>([
            SELECT Id, Name, breg_File__c, breg_Entity_Type__c
            FROM Account
            WHERE Id IN :docEntityIdsMap.values()
        ]);

        //Create documents from the templates
        Map<String, breg_Document__c> newDocumentByTemplateId = new Map<String, breg_Document__c>();
        Contact deliveryContact = parseContact(deliveryDetailsJson);

        for (breg_Document__c nextDoc : documents) {
            //The document is a template, need to create empty document and link with template document
            if (nextDoc.breg_Availability__c == 'Available in 7 business days' || isCertifiedByDocId.get(nextDoc.Id) == true) {
                breg_Document__c nextDocClone = nextDoc.clone(false, true, false, false);
                nextDocClone.Name = appendSuffixBeforeExtension(nextDocClone.Name, '- Certified Copy');
                nextDocClone.breg_Template_Document__c = nextDoc.Id;
                nextDocClone.breg_Availability__c = null;
                nextDocClone.breg_Is_Template_Copy__c = true;
                nextDocClone.breg_Is_Public__c = false;
                nextDocClone.breg_Delivery_Email__c = deliveryContact?.Email;
                nextDocClone.breg_Annotation__c = deliveryContact?.FirstName + ' ' + deliveryContact?.LastName;
                if (isCertifiedByDocId.get(nextDoc.Id) == true) {
                    nextDocClone.breg_Available_To_Certify__c = true;
                    nextDocClone.breg_Docusign_Document_Id__c = null;
                }
                newDocumentByTemplateId.put(nextDoc.Id, nextDocClone);
            }
        }

        //Create cases
        Id contactId = deliveryContact?.Id;
        String phone = parsePhone(deliveryDetailsJson);
        Map<String, Object> deliveryAddress = parseDeliveryAddress(deliveryDetailsJson);
        List<Case> cases = new List<Case>();
        Map<String, breg_Document__c> clonedDocumentByOriginalDocId = new Map<String, breg_Document__c>();
        Map<String, Case> caseByOriginalDocIdToUpdate = new Map<String, Case>();
        Map<String, Case> caseByOriginalDocId = new Map<String, Case>();
        breg_Form_Configuration__c docdlvrFormConfig = getFormConfigByFormCode('DOCDLVR');

        for (breg_Document__c nextDoc : documents) {
            //If document is available by mail or pickup, available in 7 business days, or certified, then create case
            if (
                nextDoc.breg_Availability__c == 'Available by Mail or Pickup' ||
                nextDoc.breg_Availability__c == 'Available in 7 business days' ||
                isCertifiedByDocId.get(nextDoc.Id) == true
            ) {
                breg_Document__c nextDocOrClone = nextDoc;
                if (newDocumentByTemplateId.containsKey(nextDoc.Id)) {
                    nextDocOrClone = newDocumentByTemplateId.get(nextDoc.Id);
                }

                //Set delivery method
                String deliveryMethod = 'Email';
                if (nextDoc.breg_Availability__c == 'Available by Mail or Pickup') {
                    deliveryMethod = String.isBlank(phone) ? 'Mail To The Address' : 'Pickup at DCCA';
                }
                //Create case
                Account relatedAcc = relatedAccountsMap.get(docEntityIdsMap.get(nextDoc.Id));
                String parentCaseFormCode = nextDoc.breg_Case__r?.breg_Form_Configuration__r?.breg_Form_Code__c;
                String resolvedAccountName = BREGUtils.isTNTMSMForm(parentCaseFormCode)
                    ? nextDoc.breg_Case__r?.breg_TNTMSM_Description__c
                    : (relatedAcc != null ? relatedAcc.Name : nextDoc.breg_Case__r?.breg_Entity__r?.Name);
                Boolean isCertified = isCertifiedByDocId.get(nextDoc.Id) == true;
                Boolean isNameReservationEntity = relatedAcc != null && relatedAcc.breg_Entity_Type__c == ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE;
                String caseSubjectPrefix = isCertified ? 'Document Certified Copy' : 'Document Delivery';
                Case newCase = new Case(
                    RecordTypeId = caseRecordTypeId,
                    Subject = caseSubjectPrefix +
                        ' (' +
                        nextDoc.breg_Type__c +
                        ') - ' +
                        nextDoc.Name +
                        (resolvedAccountName != null ? ' for ' + resolvedAccountName : ''),
                    Description = 'Process linked document',
                    breg_Document__c = nextDocOrClone.Id,
                    ContactId = contactId,
                    Origin = 'Web',
                    breg_Delivery_Method__c = deliveryMethod,
                    PhoneNumber__c = phone,
                    breg_Form_Configuration__c = docdlvrFormConfig?.Id,
                    breg_Name_of_the_Entity__c = resolvedAccountName,
                    breg_Entity__c = isNameReservationEntity ? null : (relatedAcc != null ? relatedAcc.Id : null),
                    breg_File__c = relatedAcc != null ? relatedAcc.breg_File__c : null,
                    breg_Processing_Speed__c = 'Normal',
                    ParentId = nextDoc.breg_Case__c
                    // the logic for breg_Number_of_copies_to_be_certified__c calculation has been moved to the BREG_Set_Number_Of_Copies_To_Be_Certified flow
                    //breg_Number_of_copies_to_be_certified__c = certifiedCopiesMap.get(nextDoc.Id)
                );
                //Set delivery address if delivery method is mail to the address
                if (newCase.breg_Delivery_Method__c == 'Mail To The Address') {
                    newCase.breg_Delivery_Address__Street__s =
                        (String) deliveryAddress.get('street') +
                        (deliveryAddress.get('street2') != null ? ' ' + (String) deliveryAddress.get('street2') : '');
                    newCase.breg_Delivery_Address__City__s = (String) deliveryAddress.get('city');
                    newCase.breg_Delivery_Address__StateCode__s = (String) deliveryAddress.get('state');
                    newCase.breg_Delivery_Address__PostalCode__s = (String) deliveryAddress.get('postalCode');
                    newCase.breg_Delivery_Address__CountryCode__s = (String) deliveryAddress.get('country');
                }
                cases.add(newCase);
                //If document is available in 7 business days or certified, then add to the map
                if (nextDoc.breg_Availability__c == 'Available in 7 business days' || isCertifiedByDocId.get(nextDoc.Id) == true) {
                    clonedDocumentByOriginalDocId.put((String) nextDoc.Id, nextDocOrClone);
                    caseByOriginalDocIdToUpdate.put((String) nextDoc.Id, newCase);
                }
                caseByOriginalDocId.put((String) nextDoc.Id, newCase);
            }
        }
        insertCasesWithCallAssignmentRule(cases);

        //Set breg_Case__c on cloned documents before inserting so the afterInsert trigger has access to the case
        List<Case> casesToUpdateWithDoc = new List<Case>();
        List<breg_Document__c> docsForCaseUpdate = new List<breg_Document__c>();
        for (String originalDocId : caseByOriginalDocIdToUpdate.keySet()) {
            breg_Document__c nextDocClone = clonedDocumentByOriginalDocId.get(originalDocId);
            Case relatedCase = caseByOriginalDocIdToUpdate.get(originalDocId);
            nextDocClone.breg_Case__c = relatedCase.Id;
            casesToUpdateWithDoc.add(relatedCase);
            docsForCaseUpdate.add(nextDocClone);
        }
        insert newDocumentByTemplateId.values();

        //Backfill breg_Document__c on cases that were created for cloned documents
        for (Integer i = 0; i < casesToUpdateWithDoc.size(); i++) {
            casesToUpdateWithDoc[i].breg_Document__c = docsForCaseUpdate[i].Id;
        }
        update casesToUpdateWithDoc;

        //Create Affiliation Account records
        List<breg_Account_Affiliation__c> contacts = new List<breg_Account_Affiliation__c>();
        Id currentUserContactId;
        if (!isGuestUser()) {
            User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            currentUserContactId = currentUser.ContactId;
        }
        for (Case nextCase : cases) {
            breg_Account_Affiliation__c deliveryAffiliation = new breg_Account_Affiliation__c(
                breg_Case__c = nextCase.Id,
                breg_Contact__c = contactId == null ? currentUserContactId : contactId,
                breg_Role__c = 'Delivery Contact',
                breg_First_Name__c = deliveryContact?.FirstName,
                breg_Last_Name__c = deliveryContact?.LastName
            );
            if (nextCase.breg_Delivery_Method__c == 'Mail To The Address') {
                deliveryAffiliation.breg_Address__City__s = nextCase.breg_Delivery_Address__City__s;
                deliveryAffiliation.breg_Address__CountryCode__s = nextCase.breg_Delivery_Address__CountryCode__s;
                deliveryAffiliation.breg_Address__PostalCode__s = nextCase.breg_Delivery_Address__PostalCode__s;
                deliveryAffiliation.breg_Address__StateCode__s = nextCase.breg_Delivery_Address__StateCode__s;
                deliveryAffiliation.breg_Address__Street__s = nextCase.breg_Delivery_Address__Street__s;
            }
            contacts.add(deliveryAffiliation);
        }
        insert contacts;

        // Build the final mapping with document IDs and case IDs
        for (String nextDocId : documentIds) {
            DocumentCaseMapping mapping = new DocumentCaseMapping();

            // Get the final document ID (clone if created, original otherwise)
            mapping.documentId = newDocumentByTemplateId.containsKey(nextDocId) ? newDocumentByTemplateId.get(nextDocId).Id : nextDocId;

            // Get the case ID if a case was created for this document
            if (caseByOriginalDocId.containsKey(nextDocId)) {
                mapping.caseId = caseByOriginalDocId.get(nextDocId).Id;
            }

            output.put(nextDocId, mapping);
        }

        return output;
    }

    private static breg_Form_Configuration__c getFormConfigByFormCode(String formCode) {
        List<breg_Form_Configuration__c> formConfigs = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Form_Code__c = :formCode
            LIMIT 1
        ];
        if (formConfigs.isEmpty()) {
            return null;
        }
        return formConfigs[0];
    }

    private static Map<String, String> getDocumentByCaseId(List<Object> cartItems) {
        Map<String, String> output = new Map<String, String>();
        Set<String> caseIds = new Set<String>();
        for (Object cartItemObj : cartItems) {
            Map<String, Object> cartItem = (Map<String, Object>) cartItemObj;
            String type = String.valueOf(cartItem.get('type'));
            if (isInitialFiling(type)) {
                String caseId = String.valueOf(cartItem.get('caseId'));
                if (caseId != null) {
                    caseIds.add(caseId);
                }
            }
        }
        if (caseIds.isEmpty()) {
            return output;
        }
        List<Case> cases = [
            SELECT Id, breg_Document__c
            FROM Case
            WHERE Id IN :caseIds
        ];
        for (Case nextCase : cases) {
            if (nextCase.breg_Document__c != null) {
                output.put(nextCase.Id, nextCase.breg_Document__c);
            }
        }
        return output;
    }

    private static Boolean isInitialFiling(String type) {
        return type.equalsIgnoreCase('NBR Form') ||
            type.equalsIgnoreCase('TNTMSM Form') ||
            type.equalsIgnoreCase('Change Form') ||
            type.equalsIgnoreCase('Annual Form') ||
            type.equalsIgnoreCase('Name Reservation Form') ||
            type.equalsIgnoreCase('CRA Registration Form');
    }

    private static void insertCasesWithCallAssignmentRule(List<Case> cases) {
        //Creating the DMLOptions for "Assign using active assignment rules" checkbox
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.AssignmentRuleHeader.useDefaultRule = true;
        List<Case> casesToInsert = new List<Case>();
        for (Case c : cases) {
            c.setOptions(dmlOpts);
            casesToInsert.add(c);
        }

        insert casesToInsert;
    }

    private static Contact parseContact(String deliveryDetailsJson) {
        Map<String, Object> details = (Map<String, Object>) JSON.deserializeUntyped(deliveryDetailsJson);
        Map<String, Object> contactValues = (Map<String, Object>) details.get('contact');
        if (contactValues == null) {
            return null;
        }
        Contact cont = new Contact();
        for (String key : contactValues.keySet()) {
            cont.put(key, contactValues.get(key));
        }
        if (cont.Id != null) {
            Contact existingContact = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id = :cont.Id LIMIT 1];
            if (existingContact.Email == cont.Email) {
                return cont;
            } else {
                cont.Id = null;
            }
        }
        if (cont.Email == null) {
            return cont;
        }
        List<Contact> duplicates = [
            SELECT Id, FirstName, LastName, Email
            FROM Contact
            WHERE Email != NULL AND Email = :cont.Email
        ];
        if (duplicates.isEmpty()) {
            insert cont;
            return cont;
        }
        return duplicates[0];
    }

    private static String parsePhone(String deliveryDetailsJson) {
        Map<String, Object> details = (Map<String, Object>) JSON.deserializeUntyped(deliveryDetailsJson);
        if (details.containsKey('phone')) {
            return (String) details.get('phone');
        }
        return null;
    }

    private static Map<String, Object> parseDeliveryAddress(String deliveryDetailsJson) {
        Map<String, Object> details = (Map<String, Object>) JSON.deserializeUntyped(deliveryDetailsJson);
        if (details.containsKey('deliveryAddress')) {
            return (Map<String, Object>) details.get('deliveryAddress');
        }
        return null;
    }

    private static String getDocOrEntityId(String accountPlusDocId, Boolean isDocId) {
        List<String> splittedIds = accountPlusDocId?.split('_');
        if (splittedIds != null && splittedIds.size() == 2) {
            if (isDocId) {
                return splittedIds[1];
            } else {
                return splittedIds[0];
            }
        }
        return accountPlusDocId;
    }

    /**
     * @description Appends a suffix to a file name, inserting it before the file extension if one exists.
     * @param fileName The original file name.
     * @param suffix The suffix to append.
     * @return The modified file name with the suffix applied.
     */
    private static String appendSuffixBeforeExtension(String fileName, String suffix) {
        Integer lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex > 0) {
            return fileName.substring(0, lastDotIndex) + ' ' + suffix + fileName.substring(lastDotIndex);
        }
        return fileName + ' ' + suffix;
    }

    // Payment Confirmation Wrapper Classes
    public class PaymentConfirmationWrapper {
        @AuraEnabled
        public String paymentStatus { get; set; }
        @AuraEnabled
        public Boolean isCompleted { get; set; }
        @AuraEnabled
        public String referenceId { get; set; }
        @AuraEnabled
        public String transactionId { get; set; }
        @AuraEnabled
        public String authorizationId { get; set; }
        @AuraEnabled
        public Date transactionDate { get; set; }
        @AuraEnabled
        public Decimal paymentAmount { get; set; }
        @AuraEnabled
        public String currencyCode { get; set; }
        @AuraEnabled
        public String contactName { get; set; }
        @AuraEnabled
        public String contactPhone { get; set; }
        @AuraEnabled
        public String contactEmail { get; set; }
        @AuraEnabled
        public String cardType { get; set; }
        @AuraEnabled
        public String last4Digits { get; set; }
        @AuraEnabled
        public String billingFirstName { get; set; }
        @AuraEnabled
        public String billingLastName { get; set; }
        @AuraEnabled
        public String billingEmail { get; set; }
        @AuraEnabled
        public String billingStreet { get; set; }
        @AuraEnabled
        public String billingCity { get; set; }
        @AuraEnabled
        public String billingState { get; set; }
        @AuraEnabled
        public String billingPostalCode { get; set; }
        @AuraEnabled
        public String billingCountry { get; set; }
        @AuraEnabled
        public List<TransactionLineWrapper> transactionLineWrappers { get; set; }
    }

    public class TransactionLineWrapper {
        @AuraEnabled
        public Boolean isDocumentRelated { get; set; }
        @AuraEnabled
        public Boolean isEntityListDocument { get; set; }
        @AuraEnabled
        public Boolean isAgentSearchList { get; set; }
        @AuraEnabled
        public Boolean isAvailableToDownload { get; set; }
        @AuraEnabled
        public String paymentId { get; set; }
        @AuraEnabled
        public String entityId { get; set; } // Account Id or TN/TM/SM Id
        @AuraEnabled
        public String entityName { get; set; } // Account Name or TN/TM/SM Name
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String documentType { get; set; } // Digital or Printed
        @AuraEnabled
        public String type { get; set; } // NBR Form, TNTMSM Form, Change Form, Annual Form, Name Reservation Form, CRA Registration Form, Document, Entity List, Agent Search List, Notification
        @AuraEnabled
        public Date purchaseDate { get; set; }
        @AuraEnabled
        public String deliveryMethod { get; set; } // Email, Mail To The Address, Pickup at DCCA
        @AuraEnabled
        public String workItemNumber { get; set; }
        @AuraEnabled
        public String caseStatus { get; set; }
        @AuraEnabled
        public String formName { get; set; }
        @AuraEnabled
        public String formCode { get; set; }
        @AuraEnabled
        public String formAction { get; set; }
        @AuraEnabled
        public Integer quantity { get; set; }
        @AuraEnabled
        public Decimal price { get; set; }
        @AuraEnabled
        public List<DocumentDownloadInfo> downloadableDocuments { get; set; }
        @AuraEnabled
        public String agentSearchListJson { get; set; }
        @AuraEnabled
        public Boolean isCertified { get; set; }
        @AuraEnabled
        public Boolean isExpedited { get; set; }
    }

    public class DocumentDownloadInfo {
        @AuraEnabled
        public String docusignDocumentId { get; set; }
        @AuraEnabled
        public String name { get; set; }
    }

    // Helper wrapper class for document and case mapping
    public class DocumentCaseMapping {
        public String documentId { get; set; }
        public String caseId { get; set; }
    }
}