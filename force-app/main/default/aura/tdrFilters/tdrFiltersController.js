({
  doInit: function (component, event, helper) {
    const myPageRef = component.get("v.pageReference");
    const recordId = myPageRef.state.c__recordId;
    component.set("v.recordId", recordId);
  }
});