public class FieldSetWrapper {
    public String name { get; private set; }
    public FieldSetMemberWrapper[] fields { get; private set; }

    public FieldSetWrapper(Schema.FieldSet fs) {
        this.name = fs.name;
        this.fields = new List<FieldSetMemberWrapper>();
        for (Schema.FieldSetMember fsm : fs.fields) {
            this.fields.add(new FieldSetMemberWrapper(fsm));
        }
    }

    @TestVisible
    private FieldSetWrapper() {
        this.fields = new List<FieldSetMemberWrapper>();
    }

    public String[] getFieldsAsStrings() {
        String[] fieldsAsStrings = new List<String>();
        for (FieldSetMemberWrapper fsmw : this.fields) {
            fieldsAsStrings.add(fsmw.fieldPath);
        }
        return fieldsAsStrings;
    }
}