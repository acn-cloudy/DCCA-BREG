public with sharing class PVLApplicationStatusPhoneMatchClient {
    private static final Integer QUERY_LIMIT = 50;

    public static List<Account> findMatchingPersonAccounts(String rawPhone, String ssnLast4) {
        String normalizedPhone = normalizePhone(rawPhone);
        if (normalizedPhone.length() != 10 || String.isBlank(ssnLast4)) {
            return new List<Account>();
        }

        Set<String> phoneVariants = phoneVariants(rawPhone, normalizedPhone);
        Map<Id, Account> candidatesById = new Map<Id, Account>();

        for (Account accountRecord : [
            SELECT
                Id,
                BPID__c,
                Phone
            FROM Account
            WHERE IsPersonAccount = true
            AND BPID__c != null
            AND Phone IN :phoneVariants
            LIMIT :QUERY_LIMIT
        ]) {
            if (accountMatches(accountRecord, normalizedPhone, ssnLast4)) {
                candidatesById.put(accountRecord.Id, accountRecord);
            }
        }

        return candidatesById.values();
    }

    public static String normalizePhone(String rawPhone) {
        if (String.isBlank(rawPhone)) {
            return '';
        }
        String digits = rawPhone.replaceAll('\\D', '');
        if (digits.length() >= 10) {
            return digits.right(10);
        }
        return digits;
    }

    private static Boolean accountMatches(Account accountRecord, String normalizedPhone, String ssnLast4) {
        return bpidMatchesLast4(accountRecord.BPID__c, ssnLast4) &&
            normalizePhone(accountRecord.Phone) == normalizedPhone;
    }

    private static Boolean bpidMatchesLast4(String bpid, String ssnLast4) {
        return !String.isBlank(bpid) && bpid.length() >= 4 && bpid.right(4) == ssnLast4;
    }

    private static Set<String> phoneVariants(String rawPhone, String normalizedPhone) {
        Set<String> variants = new Set<String>();
        if (!String.isBlank(rawPhone)) {
            variants.add(rawPhone.trim());
        }
        variants.add(normalizedPhone);
        variants.add('1' + normalizedPhone);
        variants.add('+1' + normalizedPhone);
        variants.add(
            '(' + normalizedPhone.left(3) + ') ' +
            normalizedPhone.substring(3, 6) + '-' +
            normalizedPhone.right(4)
        );
        variants.add(
            normalizedPhone.left(3) + '-' +
            normalizedPhone.substring(3, 6) + '-' +
            normalizedPhone.right(4)
        );
        variants.add(
            normalizedPhone.left(3) + '.' +
            normalizedPhone.substring(3, 6) + '.' +
            normalizedPhone.right(4)
        );
        return variants;
    }
}