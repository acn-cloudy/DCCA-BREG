({
    handleClick: function(component, event, helper) {
        // event.getSource().set("v.disabled", true);
        var action = component.get("c.runD1D2DependencyRefundNotice");
        var recordId = component.get("v.recordId");
        action.setParams({ recordId: recordId });
        action.setCallback(this, function(response) {
          var resultData = response.getReturnValue();
          let toastEvent = $A.get('e.force:showToast');
          toastEvent.setParams({
            title: "Success",
            message: "Batch job is succesfully queued. ",
            type: 'success'
          });
          toastEvent.fire();
          $A.get("e.force:closeQuickAction").fire()
        });
        
        $A.enqueueAction(action);
      }
})