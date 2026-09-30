public class FieldSetMemberWrapper {
    @TestVisible
    public String fieldPath { get; private set; }
    @TestVisible
    public String label { get; private set; }
    @TestVisible
    public Schema.DisplayType type { get; private set; }
    @TestVisible
    public Boolean required { get; private set; }
    @TestVisible
    public Boolean dbrequired { get; private set; }

    public FieldSetMemberWrapper(Schema.FieldSetMember fsm) {
        this.fieldPath = fsm.getFieldPath();
        this.label = fsm.getLabel();
        this.type = fsm.getType();
        this.required = fsm.getRequired();
        this.dbrequired = fsm.getDbRequired();
    }

    @TestVisible
    private FieldSetMemberWrapper() {}
}