public with sharing class BREGFileNumberAssignmentController {
    private static final Integer fileNumberMinimumLength = 6;
    @InvocableMethod(label='Generate File Number' description='Generates a file number for a case based on its form configuration' category='Case')
    public static List<FlowOutput> generateFileNumber(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        try {
            List<Case> casesToUpdate = new List<Case>();
            for (FlowInput input : inputs) {
                Case c = getCase(input.caseId);

                if (String.isNotBlank(c.breg_File__c)) {
                    outputs.add(new FlowOutput(true, 'File number is already assigned. Cannot generate a new file number.'));
                    continue;
                }

                FileNumberAssignmentResult result = generateFileNumber(c, null);
                if (result.fileNumber == null) {
                    outputs.add(new FlowOutput(true, 'File number cannot be assigned.'));
                    continue;
                } else {
                    c.breg_File__c = result.fileNumber != null ? result.fileNumber : c.breg_File__c;
                    c.breg_File_Suffix__c = result.fileSuffix != null ? result.fileSuffix : c.breg_File_Suffix__c;
                    c.breg_BRIM_FILE_NO__c = result.brimFileNumber != null ? result.brimFileNumber : c.breg_BRIM_FILE_NO__c;
                    c.breg_TNTMSM_Certificate__c = result.tntmsmCertificate != null ? result.tntmsmCertificate : c.breg_TNTMSM_Certificate__c;
                    casesToUpdate.add(c);
                }
            }

            if (!casesToUpdate.isEmpty()) {
                update casesToUpdate;
            }
        } catch (BREGFileNumberAssignmentException e) {
            System.debug(e.errorMessage);
            outputs.add(new FlowOutput(true, e.errorMessage));
        } catch (Exception e) {
            System.debug(e.getMessage());
            outputs.add(new FlowOutput(true, e.getMessage()));
        }

        return outputs;
    }

    public static FileNumberAssignmentResult generateFileNumber(Case c, String entityType) {
        FileNumberAssignmentResult result = new FileNumberAssignmentResult();

        if (entityType != null && entityType != 'ZZ') {
            Integer nextNumber = BREGFileNumberGenerator.getNextNumber(entityType);
            result.brimFileNumber = nextNumber;
            result.fileNumber = getStringValueOfNextNumber(nextNumber) + entityType;
            result.fileSuffix = entityType;
        } else {
            // TNTMSM form
            if (BREGUtils.isTNTMSMForm(c.breg_Form_Code__c)) {
                Integer nextNumber = BREGFileNumberGenerator.getNextNumber(c.breg_Form_Configuration__r.breg_Suffix_Code__c);
                if (c.breg_Entity__r?.breg_File__c != null && c.breg_Entity__r?.breg_File_Suffix__c != null) {
                    result.fileNumber = c.breg_Entity__r.breg_File__c;
                    result.fileSuffix = c.breg_Entity__r.breg_File_Suffix__c;
                } else {
                    result.fileSuffix = result.fileSuffix == null ? 'ZZ' : result.fileSuffix;
                    result.fileNumber = result.fileNumber == null ? getStringValueOfNextNumber(nextNumber) + result.fileSuffix : result.fileNumber;
                }
                if (c.breg_TNTMSM_Certificate__c != null) {
                    result.tntmsmCertificate = c.breg_TNTMSM_Certificate__c;
                } else {
                    result.tntmsmCertificate = getStringValueOfNextNumber(nextNumber);
                }
                
                
            }
            // NBR form
            else if (BREGUtils.isNBRForm(c.breg_Form_Code__c) || BREGUtils.isNameReservationForm(c.breg_Form_Code__c) || c.breg_Form_Code__c == 'T-7') {
                Integer nextNumber = BREGFileNumberGenerator.getNextNumber(c.breg_Form_Configuration__r.breg_Suffix_Code__c);
                result.brimFileNumber = nextNumber;
                result.fileNumber = getStringValueOfNextNumber(nextNumber) + c.breg_Form_Configuration__r.breg_Suffix_Code__c;
                result.fileSuffix = c.breg_Form_Configuration__r.breg_Suffix_Code__c;
            }
            // CRA Registration form
            else if (BREGUtils.isCRARegistrationForm(c.breg_Form_Code__c) && c.breg_Reg_Agent_Type__c == 'Individual') {
                Integer nextNumber = BREGFileNumberGenerator.getNextNumber('ZZ');
                result.brimFileNumber = nextNumber;
                result.fileNumber = getStringValueOfNextNumber(nextNumber) + 'CA';
                result.fileSuffix = 'CA';
            }
        }

        return result;
    }

    private static String getStringValueOfNextNumber(Integer nextNumber) {
        if (nextNumber == null) {
            return null;
        }
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        Integer minimumLength = setting != null &&
            setting.breg_File_Number_Minimum_Length__c != null
            ? Integer.valueOf(setting.breg_File_Number_Minimum_Length__c)
            : fileNumberMinimumLength;
        String nextNumberString = String.valueOf(nextNumber);
        while (nextNumberString.length() < minimumLength) {
            nextNumberString = '0' + nextNumberString;
        }
        return nextNumberString;
    }

    private static Case getCase(Id caseId) {
        return [
            SELECT
                breg_File__c,
                breg_File_Suffix__c,
                breg_BRIM_FILE_NO__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Suffix_Code__c,
                breg_Form_Code__c,
                breg_Entity__r.breg_File__c,
                breg_Entity__r.breg_File_Suffix__c,
                breg_TNTMSM_Certificate__c,
                breg_Reg_Agent_Type__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    public class FileNumberAssignmentResult {
        public String fileNumber;
        public String fileSuffix;
        public Integer brimFileNumber;
        public String tntmsmCertificate;
    }

    public class FlowInput {
        @InvocableVariable(required=true)
        public Id caseId;
    }

    public class FlowOutput {
        @InvocableVariable(label='Is Error' description='Indicates if the file number generation is not valid')
        public Boolean isError;

        @InvocableVariable(label='Error Message' description='Error message if the file number generation is not valid')
        public String errorMessage;

        public FlowOutput(Boolean isError, String errorMessage) {
            this.isError = isError;
            this.errorMessage = errorMessage;
        }
    }

    public class BREGFileNumberAssignmentException extends Exception {
        public String errorMessage { get; set; }
    }
}