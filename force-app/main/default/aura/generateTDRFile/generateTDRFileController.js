({
  doInit: function (component, event, helper) {
    const action = component.get("c.saveAsFile");
    const recordId = component.get("v.recordId");
    action.setParams({ recordId: recordId });
    action.setCallback(this, function (response) {
      let state = response.getState();
      if (state === "SUCCESS") {
        $A.get("e.force:refreshView").fire();
        $A.get("e.force:closeQuickAction").fire();
      } else if (state === "ERROR") {
        $A.get("e.force:closeQuickAction").fire();
      }
    });

    $A.enqueueAction(action);
  }
});