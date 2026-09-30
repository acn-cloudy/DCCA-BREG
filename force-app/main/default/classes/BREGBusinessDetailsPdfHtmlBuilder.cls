public inherited sharing class BREGBusinessDetailsPdfHtmlBuilder {

    static final Map<String, String> COUNTRY_CODE_MAP = BREGUtils.getPicklistLabelMap('breg_Account_Affiliation__c', 'breg_Address__CountryCode__s');
    static final Map<String, String> STATE_CODE_MAP = BREGUtils.getPicklistLabelMap('breg_Account_Affiliation__c', 'breg_Address__StateCode__s');

    public static String build(Id entityId) {
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(entityId);

        String html = buildPdfHeader();
        html += buildFieldsSection(wrapper.companyInfo.fields);
        html += buildAnnualFilingsSection(wrapper.companyInfo.annualFilingData);
        html += buildOtherFilingsSection(wrapper.companyInfo.otherFilingData);
        html += buildAffiliationsSection(wrapper.companyInfo.accountAffiliationData);
        html += buildStocksSection(wrapper.companyInfo.stockData);
        html += buildTnTmSmSection(wrapper.companyInfo.tnTmSmData);
        html += '</body></html>';
        return html;
    }

    private static String buildPdfHeader() {
        String portalLink = BREG_Setting__c.getOrgDefaults().Link_to_Portal__c;
        Date orgDate = BREGTransactionUtils.getOrgDateByUserTimezone();
        DateTime dt = DateTime.newInstance(orgDate, Time.newInstance(0, 0, 0, 0));
        String formattedDate = dt.format('MMMM d, yyyy');

        String html = '<html><head><meta charset="utf-8"/><style>';
        html += 'body { font-family: "Arial Unicode MS", sans-serif; font-size: 11px; color: #333; padding: 20px; }';
        html += '* { font-family: "Arial Unicode MS", sans-serif; }';
        html += 'h1 { font-size: 22px; color: #1a1a1a; }';
        html += 'h2 { font-size: 15px; color: #1a1a1a; margin-top: 16px; margin-bottom: 4px; }';
        html += '.header-meta { color: #777; font-size: 9px; }';
        html += '.section-box { border: 1px solid #333; padding: 10px; }';
        html += '.full-table { width: 100%; }';
        html += '.fixed-table { width: 100%; table-layout: fixed; }';
        html += '.half-col { padding: 0 12px 0 0; width: 50%; vertical-align: top; }';
        html += '.th { text-align: left; font-weight: bold; }';
        html += '.td { vertical-align: top; }';
        html += '.label { font-weight: bold; color: #777; }';
        html += '.value { color: #1a1a1a; }';
        html += '</style></head><body>';

        html += '<h1>DCCA State of Hawaii</h1>';
        html += '<div class="header-meta">Downloaded on ' + formattedDate + '<br/>';
        html += 'The information provided below is not a certification of good standing and does not constitute any other certification by the State.<br/>';
        html += 'Website URL: <a href="' + portalLink + '">' + portalLink + '</a></div><br/>';
        return html;
    }

    private static String buildFieldsSection(List<BREGBusinessDetailsController.CompanyInfoFieldWrapper> fields) {
        if (fields == null || fields.isEmpty()) {
            return '';
        }

        Integer halfPoint = (Integer) Math.ceil(fields.size() / 2.0);

        String html = '<h2>Business Information</h2>';
        html += '<div class="section-box">';
        html += '<table class="full-table"><tr><td class="half-col"><table>';
        for (Integer i = 0; i < halfPoint; i++) {
            html += buildFieldSection(fields[i]);
        }
        html += '</table></td><td class="half-col"><table>';
        for (Integer i = halfPoint; i < fields.size(); i++) {
            html += buildFieldSection(fields[i]);
        }
        html += '</table></td></tr></table></div>';
        return html;
    }

    private static String buildFieldSection(BREGBusinessDetailsController.CompanyInfoFieldWrapper fieldWrapper) {
        List<String> multiRowsFields = new List<String>{ 'Agent Address', 'Principal Address', 'Mailing Address' };
        String valueToDisplay = escapeHtml(fieldWrapper.value);

        if (multiRowsFields.contains(fieldWrapper.label)) {
            valueToDisplay = valueToDisplay.replaceAll('\\n', '<br/>');
        }

        String html = '<tr><td>';
        html += '<span class="label">' + escapeHtml(fieldWrapper.label) + '</span><br/>';
        html += '<span class="value">' + valueToDisplay + '</span>';
        html += '</td></tr>';
        return html;
    }

    private static String buildAnnualFilingsSection(List<breg_Annual__c> annualFilings) {
        if (annualFilings == null || annualFilings.isEmpty()) {
            return '';
        }

        String html = '<h2>Annual Filings</h2>';
        html += '<div class="section-box">';
        html += '<table class="full-table"><tr>';
        html += '<th class="th">Filing Year</th><th class="th">Date Received</th><th class="th">Status</th></tr>';
        for (breg_Annual__c annual : annualFilings) {
            html += '<tr>';
            html += '<td class="td">' + escapeHtml(String.valueOf(annual.breg_Filing_Year__c)) + '</td>';
            html += '<td class="td">' + (annual.breg_Received_Date__c != null ? formatDate(annual.breg_Received_Date__c.date()) : '') + '</td>';
            html += '<td class="td">' + escapeHtml(annual.breg_Status__c != null ? annual.breg_Status__c : '') + '</td>';
            html += '</tr>';
        }
        html += '</table></div>';
        return html;
    }

    private static String buildOtherFilingsSection(List<breg_Transaction__c> otherFilings) {
        if (otherFilings == null || otherFilings.isEmpty()) {
            return '';
        }

        String html = '<h2>Other Filings</h2>';
        html += '<div class="section-box">';
        html += '<table class="fixed-table"><tr>';
        html += '<th class="th">Date</th>';
        html += '<th class="th">Description</th>';
        html += '<th class="th">Remarks</th></tr>';

        for (breg_Transaction__c trans : otherFilings) {
            html += '<tr>';
            html += '<td class="td">' + (trans.breg_Effective_Date__c != null ? formatDate(trans.breg_Effective_Date__c) : '') + '</td>';
            html += '<td class="td">' + escapeHtml(trans.breg_Description__c != null ? trans.breg_Description__c : '') + '</td>';
            html += '<td class="td">' + escapeHtml(trans.breg_Remarks__c != null ? trans.breg_Remarks__c : '') + '</td>';
            html += '</tr>';
        }
        html += '</table></div>';
        return html;
    }

    private static String buildAffiliationsSection(List<breg_Account_Affiliation__c> affiliations) {
        if (affiliations == null || affiliations.isEmpty()) {
            return '';
        }

        String html = '<h2>' + getAffiliationsTitle(affiliations) + '</h2>';
        html += '<div class="section-box">';
        html += '<table class="full-table">';
        html += '<colgroup>';
        html += '<col style="width:30%;"/>';
        html += '<col style="width:45%;"/>';
        html += '<col style="width:25%;"/>';
        html += '</colgroup>';
        html += '<tr>';
        html += '<th class="th">Name</th>';
        html += '<th class="th">Office</th>';
        html += '<th class="th">Date</th></tr>';

        for (breg_Account_Affiliation__c aff : affiliations) {
            html += buildAffiliationRow(aff);
        }
        html += '</table></div>';
        return html;
    }

    private static String buildStocksSection(List<breg_Stock__c> stocks) {
        if (stocks == null || stocks.isEmpty()) {
            return '';
        }

        String html = '<h2>Stocks</h2>';
        html += '<div class="section-box">';
        html += '<table class="full-table"><tr>';
        html += '<th class="th">Class / Detail</th>';
        html += '<th class="th">Issued Shares</th>';
        html += '<th class="th">Par Value</th>';
        html += '<th class="th">Start Date</th></tr>';

        for (breg_Stock__c stock : stocks) {
            html += '<tr>';
            html += '<td class="td">' + escapeHtml(stock.breg_Class_Detail__c != null ? stock.breg_Class_Detail__c : '') + '</td>';
            html += '<td class="td">' + (stock.breg_Number_of_Issued_Shares__c != null ? String.valueOf(stock.breg_Number_of_Issued_Shares__c) : '') + '</td>';
            html += '<td class="td">' + (stock.breg_Per_Value__c != null ? String.valueOf(stock.breg_Per_Value__c) : '') + '</td>';
            html += '<td class="td">' + (stock.breg_Start_Date__c != null ? formatDate(stock.breg_Start_Date__c) : '') + '</td>';
            html += '</tr>';
        }
        html += '</table></div>';
        return html;
    }

    private static String buildTnTmSmSection(List<breg_TN_TM_SM__c> tnTmSmList) {
        if (tnTmSmList == null || tnTmSmList.isEmpty()) {
            return '';
        }

        String html = '<h2>Trade Names / Trademarks / Service Marks</h2>';
        html += '<div class="section-box">';
        html += '<table class="full-table"><tr>';
        html += '<th class="th">Name</th>';
        html += '<th class="th">Type</th>';
        html += '<th class="th">Category</th>';
        html += '<th class="th">Certificate No.</th>';
        html += '<th class="th">Status</th>';
        html += '<th class="th">Registration Date</th>';
        html += '<th class="th">Expiration Date</th></tr>';

        for (breg_TN_TM_SM__c tn : tnTmSmList) {
            html += buildTnTmSmRow(tn);
        }
        html += '</table></div>';
        return html;
    }

    private static String getAffiliationsTitle(List<breg_Account_Affiliation__c> affiliations) {
        Boolean hasOfficer = false;
        Boolean hasDirector = false;
        Boolean hasPartner = false;
        Boolean hasMember = false;
        Boolean hasManager = false;

        for (breg_Account_Affiliation__c aff : affiliations) {
            String role = aff.breg_Role__c;
            if (String.isBlank(role)) {
                continue;
            }
            if (role.equalsIgnoreCase('Officer')) {
                hasOfficer = true;
            } else if (role.equalsIgnoreCase('Director')) {
                hasDirector = true;
            } else if (role.equalsIgnoreCase('Officer/Director')) {
                hasOfficer = true;
                hasDirector = true;
            } else if (role.equalsIgnoreCase('General Partner') || role.equalsIgnoreCase('Partner')) {
                hasPartner = true;
            } else if (role.equalsIgnoreCase('Member')) {
                hasMember = true;
            } else if (role.equalsIgnoreCase('Manager')) {
                hasManager = true;
            }
        }

        if (hasPartner) {
            return 'Partners';
        }
        if (hasMember || hasManager) {
            return 'Managers / Members';
        }
        if (hasOfficer && hasDirector) {
            return 'Officers / Directors';
        }
        if (hasDirector) {
            return 'Directors';
        }
        return 'Officers';
    }

    private static String buildAffiliationRow(breg_Account_Affiliation__c affiliation) {
        String affTitle = escapeHtml(affiliation.breg_Officer_Director_TitlesText_Formula__c != null ? affiliation.breg_Officer_Director_TitlesText_Formula__c : '');
        affTitle = affTitle.replace(', ', '<br/>');

        String html = '<tr>';
        html += '<td class="td">' + escapeHtml(affiliation.breg_Affiliation_Name__c != null ? affiliation.breg_Affiliation_Name__c : '') + '</td>';
        html += '<td class="td">' + affTitle + '</td>';
        html += '<td class="td">' + (affiliation.breg_As_of_Date__c != null ? formatDate(affiliation.breg_As_of_Date__c) : '') + '</td>';
        html += '</tr>';
        return html;
    }

    private static String buildTnTmSmRow(breg_TN_TM_SM__c tnTmSmRecord) {
        String html = '<tr>';
        html += '<td class="td">' + escapeHtml(tnTmSmRecord.breg_Trade_Name__c != null ? tnTmSmRecord.breg_Trade_Name__c : tnTmSmRecord.Name) + '</td>';
        html += '<td class="td">' + escapeHtml(tnTmSmRecord.breg_Type__c != null ? tnTmSmRecord.breg_Type__c : '') + '</td>';
        html += '<td class="td">' + escapeHtml(tnTmSmRecord.breg_TM_SM_Category__c != null ? tnTmSmRecord.breg_TM_SM_Category__c : '') + '</td>';
        html += '<td class="td">' + escapeHtml(tnTmSmRecord.breg_Cert_Number__c != null ? tnTmSmRecord.breg_Cert_Number__c : '') + '</td>';
        html += '<td class="td">' + escapeHtml(tnTmSmRecord.breg_Status__c != null ? tnTmSmRecord.breg_Status__c : '') + '</td>';
        html += '<td class="td">' + (tnTmSmRecord.breg_Registration_Date__c != null ? formatDate(tnTmSmRecord.breg_Registration_Date__c) : '') + '</td>';
        html += '<td class="td">' + (tnTmSmRecord.breg_Expiration_Date__c != null ? formatDate(tnTmSmRecord.breg_Expiration_Date__c) : '') + '</td>';
        html += '</tr>';
        return html;
    }

    private static String formatDate(Date dateToFormat) {
        if (dateToFormat == null) {
            return '';
        }

        DateTime dt = DateTime.newInstance(dateToFormat.year(), dateToFormat.month(), dateToFormat.day());
        return dt.format('MMM d, yyyy');
    }

    private static String formatAddress(Address address) {
        if (address == null) {
            return '';
        }

        List<String> addressLines = new List<String>();
        if (String.isNotBlank(address.getStreet())) {
            addressLines.add(address.getStreet());
        }

        List<String> cityStateZip = new List<String>();
        if (String.isNotBlank(address.getCity())) {
            cityStateZip.add(address.getCity());
        }
        if (String.isNotBlank(address.getState())) {
            cityStateZip.add(address.getState());
        }
        if (String.isNotBlank(address.getPostalCode())) {
            cityStateZip.add(address.getPostalCode());
        }
        if (!cityStateZip.isEmpty()) {
            addressLines.add(String.join(cityStateZip, ' '));
        }

        if (String.isNotBlank(address.getCountry())) {
            addressLines.add(address.getCountry());
        }

        return String.join(addressLines, '\n');
    }

    private static String formatAffiliationAddress(breg_Account_Affiliation__c affiliation) {
        if (affiliation == null ||affiliation.breg_Address__c == null) {
            return '';
        }

        List<String> addressLines = new List<String>();
        if (String.isNotBlank(affiliation.breg_Address__Street__s)) {
            addressLines.add(affiliation.breg_Address__Street__s);
        }

        List<String> cityStateZip = new List<String>();
        if (String.isNotBlank(affiliation.breg_Address__City__s)) {
            cityStateZip.add(affiliation.breg_Address__City__s);
        }
        if (String.isNotBlank(affiliation.breg_Address__StateCode__s)) {
            cityStateZip.add(STATE_CODE_MAP.get(affiliation.breg_Address__StateCode__s));
        }
        if (String.isNotBlank(affiliation.breg_Address__PostalCode__s)) {
            cityStateZip.add(affiliation.breg_Address__PostalCode__s);
        }
        if (!cityStateZip.isEmpty()) {
            addressLines.add(String.join(cityStateZip, ' '));
        }

        if (String.isNotBlank(affiliation.breg_Address__CountryCode__s)) {
            addressLines.add(COUNTRY_CODE_MAP.get(affiliation.breg_Address__CountryCode__s));
        }

        return String.join(addressLines, '\n');
    }

    private static String escapeHtml(String input) {
        if (String.isBlank(input)) {
            return '';
        }

        return input.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;');
    }
}