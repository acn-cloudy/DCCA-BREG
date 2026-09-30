public virtual class UnitOfWork extends fflib_SObjectUnitOfWork {

    private UnitOfWork.PostCommitWorkAction[] postCommitWorkSuccessActions;
    private UnitOfWork.PostCommitWorkAction[] postCommitWorkFailureActions;

    public UnitOfWork(List<Schema.SObjectType> sObjectTypes) {
        super(sObjectTypes);
        init();
    }
    public UnitOfWork(List<Schema.SObjectType> sObjectTypes, fflib_SObjectUnitOfWork.IDML dml) {
        super(sObjectTypes, dml);
        init();
    }

    private void init() {
        this.postCommitWorkSuccessActions = new List<UnitOfWork.PostCommitWorkAction>();
        this.postCommitWorkFailureActions = new List<UnitOfWork.PostCommitWorkAction>();
    }

    public override void onCommitWorkFinished(Boolean wasSuccessful) {
        if (wasSuccessful) {
            for (UnitOfWork.PostCommitWorkAction action : this.postCommitWorkSuccessActions) {
                action.action.doPostCommitWorkAction(action.param);
            }
        } else {
            for (UnitOfWork.PostCommitWorkAction action : this.postCommitWorkFailureActions) {
                action.action.doPostCommitWorkAction(action.param);
            }
        }
    }

    public void addPostCommitWorkAction(Boolean onSuccess, IPostCommitWorkAction action, SObject[] param) {
        if (onSuccess) {
            this.postCommitWorkSuccessActions.add(new UnitOfWork.PostCommitWorkAction(action, param));
        } else {
            this.postCommitWorkFailureActions.add(new UnitOfWork.PostCommitWorkAction(action, param));
        }
    }


    private class PostCommitWorkAction {
        IPostCommitWorkAction action;
        SObject[] param;
        public PostCommitWorkAction(IPostCommitWorkAction action, SObject[] param) {
            this.action = action;
            this.param = param;
        }
    }

}