/**
 * @description Wrapper classes for JSON serialization of Qualtrics payload
 * @author Qualtrics Integration Team
 */
public with sharing class QualCasePayload {
    
    public CaseData caseData { get; set; }
    public ContactData contact { get; set; }
    public AgentData agent { get; set; }
    public MetadataInfo metadata { get; set; }
    // Deprecated: Call payloads now use QualCallPayloadBuilder and the Call endpoint.
    public Object call { get; set; }
    
    public QualCasePayload() {
        this.caseData = new CaseData();
        this.contact = new ContactData();
        this.agent = new AgentData();
        this.metadata = new MetadataInfo();
        this.call = null;
    }
    
    /**
     * @description Serialize to JSON with 'case' as root element name
     * @return JSON string with proper structure
     */
    public String toJson() {
        Map<String, Object> caseMap = new Map<String, Object>{
            'caseNumber' => this.caseData.caseNumber,
            'division' => this.caseData.division,
            'branch' => this.caseData.branch,
            'disposition' => this.caseData.disposition,
            'status' => this.caseData.status,
            'openDate' => this.caseData.openDate,
            'closeDate' => this.caseData.closeDate,
            'caseTimeSeconds' => this.caseData.caseTimeSeconds,
            'callDurationSeconds' => this.caseData.callDurationSeconds,
            'holdDurationSeconds' => this.caseData.holdDurationSeconds,
            'waitDurationSeconds' => this.caseData.waitDurationSeconds,
            'priority' => this.caseData.priority,
            'origin' => this.caseData.origin,
            'callIds' => this.caseData.callIds,
            'callForwardingDivision' => this.caseData.callForwardingDivision,
            'autoCloseReason' => this.caseData.autoCloseReason,
            'abandonedCall' => this.caseData.abandonedCall,
            'speedToAnswerSeconds' => this.caseData.speedToAnswerSeconds
        };
        Map<String, Object> payload = new Map<String, Object>{
            'case' => caseMap,
            'contact' => this.contact,
            'agent' => this.agent,
            'metadata' => this.metadata
        };
        return JSON.serialize(payload);
    }
    
    /**
     * @description Case data section of payload
     */
    public class CaseData {
        public String caseNumber { get; set; }
        public String division { get; set; }
        public String branch { get; set; }
        public String disposition { get; set; }
        public String status { get; set; }
        public String openDate { get; set; }
        public String closeDate { get; set; }
        public Integer caseTimeSeconds { get; set; }
        public Integer callDurationSeconds { get; set; }
        public Integer holdDurationSeconds { get; set; }
        public Integer waitDurationSeconds { get; set; }
        public String priority { get; set; }
        public String origin { get; set; }
        public List<Long> callIds { get; set; }
        public String voiceCallTranscript { get; set; }
        public String callForwardingDivision { get; set; }
        public String autoCloseReason { get; set; }
        public Boolean abandonedCall { get; set; }
        public Integer speedToAnswerSeconds { get; set; }
    }
    
    /**
     * @description Contact data section of payload
     */
    public class ContactData {
        public String firstName { get; set; }
        public String lastName { get; set; }
        public String email { get; set; }
        public String phone { get; set; }
        public String salesforceContactId { get; set; }
    }
    
    /**
     * @description Agent data section of payload
     */
    public class AgentData {
        public String agentId { get; set; }
        public String agentName { get; set; }
        public String teamId { get; set; }
        public String supervisorName { get; set; }
    }
    
    /**
     * @description Metadata section of payload
     */
    public class MetadataInfo {
        public String salesforceCaseId { get; set; }
        public String salesforceOrgId { get; set; }
        public String integrationTimestamp { get; set; }
        public String payloadVersion { get; set; }
        public String eventType { get; set; }
        public Boolean isTestContact { get; set; }
    }
}