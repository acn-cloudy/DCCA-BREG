// File: PersonAccountInvalidAddressFinder.cls
public class PersonAccountInvalidAddressFinder implements Database.Batchable<SObject>, Database.Stateful {
    
    // Used to collect results across all batches
    public List<DuplicateAccountInfo> invalidAddressResults = new List<DuplicateAccountInfo>();
    
    // The default query for live execution must include the address fields and the flag field
    private final String QUERY = 
        'SELECT ' +
            'Id, ' +
            'PersonContactId, ' +
            'PersonMailingStreet, ' +
            'PersonMailingCity, ' + 
            'PersonMailingState, ' + 
            'PersonMailingPostalCode, ' + 
            'PersonEmail, ' + 
            'Invalid_Address__c ' + 
        'FROM ' +
            'Account ' +
        'WHERE ' +
            'IsPersonAccount = true ' +
            'AND PersonMailingStreet != NULL AND PersonMailingStreet != \'\'';

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(QUERY);
    }
    
    // Helper method to determine if a city/state match is followed by an exclusion word
    private Boolean isFollowedByDesignator(String remainder, Set<String> designators) {
        if (remainder == null) return false;
        String trimmedRemainder = remainder.trim().toLowerCase();
        for (String designator : designators) {
            if (trimmedRemainder.startsWith(designator)) {
                Integer len = designator.length();
                
                // Check if the designator is at the end of the string OR 
                // is followed by a common separator (space, period, hash, or comma).
                if (trimmedRemainder.length() == len || 
                    trimmedRemainder.substring(len).startsWith(' ') || 
                    trimmedRemainder.substring(len).startsWith('.') ||
                    trimmedRemainder.substring(len).startsWith('#') || 
                    trimmedRemainder.substring(len).startsWith(',')) {  
                    return true;
                }
            }
        }
        return false;
    }

    public void execute(Database.BatchableContext BC, List<Account> scope) {
        Integer checkLength = 6;

        // Set of common street designators
        Set<String> streetDesignators = new Set<String>{
            'hwy', 'highway', 'hway', 'rd', 'road', 'st', 'street', 'ave', 'avenue', 
            'blvd', 'boulevard', 'dr', 'drive', 'ln', 'lane', 'pl', 'place', 
            'tr', 'trail', 'cir', 'circle', 'ct', 'court', 'pkwy', 'parkway', 
            'way', 'loop', 'village', 'kai', 'valley', 'suite', 'bay','heights',
            'unit', 'beach'
        };

        for (Account pa : scope) {
            Boolean isInvalid = false;
            String street = pa.PersonMailingStreet;

            if (street == null) continue; 

            String lowerStreet = street.toLowerCase();
            
            // --- CRITERIA 1: REPETITIVE STREET SEGMENT ---
            String unifiedStreet = street.replaceAll('\\s+', '').toLowerCase();

            if (unifiedStreet.length() >= checkLength * 2) { 
                String addressSignature = unifiedStreet.substring(0, checkLength);
                if (unifiedStreet.indexOf(addressSignature, checkLength) >= checkLength) {
                    isInvalid = true;
                }
            }

            // --- CRITERIA 2: STREET CONTAINS CITY NAME (WITH EXCLUSION) ---
            if (!isInvalid && pa.PersonMailingCity != null) {
                String lowerCity = pa.PersonMailingCity.toLowerCase();
                if (lowerStreet.contains(lowerCity)) {
                    String remainder = lowerStreet.substring(lowerStreet.indexOf(lowerCity) + lowerCity.length());
                    if (!isFollowedByDesignator(remainder, streetDesignators)) {
                        isInvalid = true;
                    }
                }
            }
            
            // --- CRITERIA 3: STREET CONTAINS STATE NAME (WITH EXCLUSION) ---
            if (!isInvalid && pa.PersonMailingState != null) {
                String lowerState = pa.PersonMailingState.toLowerCase();
                if (lowerStreet.contains(lowerState)) {
                    String remainder = lowerStreet.substring(lowerStreet.indexOf(lowerState) + lowerState.length());
                    if (!isFollowedByDesignator(remainder, streetDesignators)) {
                        isInvalid = true;
                    }
                }
            }
            
            // --- CRITERIA 4: STREET CONTAINS ZIPCODE ---
            if (!isInvalid && pa.PersonMailingPostalCode != null) {
                if (lowerStreet.contains(pa.PersonMailingPostalCode)) {
                    isInvalid = true;
                }
            }
            
            // --- DML LOGIC AND RESULT COLLECTION ---
            if (isInvalid && pa.Invalid_Address__c == false) {
                pa.Invalid_Address__c = true;
                
                DuplicateAccountInfo info = new DuplicateAccountInfo();
                info.accountId = pa.Id;
                info.contactId = pa.PersonContactId;
                info.mailingAddress = pa.PersonMailingStreet;
                info.personEmail = pa.PersonEmail;
                
                info.bpid = 'N/A - Not Queried';
                info.attendeeCode = 'N/A - Not Queried';
                info.certificateNumber = 'N/A - Not Queried';
                
                invalidAddressResults.add(info);
            } 
            else if (!isInvalid && pa.Invalid_Address__c == true) {
                 pa.Invalid_Address__c = false;
            }
        }
        
        // DML Execution with error logging for auditing bypassed records
        Database.SaveResult[] results = Database.update(scope, false); 

        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            if (!sr.isSuccess()) {
                String errorMessages = '';
                for (Database.Error err : sr.getErrors()) {
                    errorMessages += ' (' + err.getStatusCode() + ') ' + err.getMessage();
                }
                System.debug('*** DML FAILURE: Record Skipped (Bypassed) ***');
                System.debug('Account ID: ' + scope[i].Id);
                System.debug('Attempted Change: Invalid_Address__c = ' + scope[i].Invalid_Address__c);
                System.debug('Reason for Bypass: ' + errorMessages);
                System.debug('------------------------------------------');
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Total invalid addresses found: ' + invalidAddressResults.size());
        if (!invalidAddressResults.isEmpty()) {
            List<Id> accountIds = new List<Id>();
            for (DuplicateAccountInfo info : invalidAddressResults) {
                accountIds.add(info.accountId);
            }
            String idList = String.join(accountIds, '\',\'');
            System.debug('IDs to query: \'' + idList + '\'');
        }
    }
}